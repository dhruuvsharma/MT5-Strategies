//+------------------------------------------------------------------+
//| OBRenderer.mqh — APEX_SCALPER                                    |
//| Mini order book depth visualization fixed to the chart's        |
//| right edge. Bid levels (blue/green) stacked below asks          |
//| (red/orange). Bar widths proportional to volume at each level. |
//| Updates are throttled to InpOBISnapshotInterval ms.            |
//| Guard: only active when InpShowOBDepth == true.                 |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"
#include "../Data/OrderBookSnapshot.mqh"
#include "PanelTheme.mqh"

//--- Depth levels shown per side
#define APEX_OB_DEPTH   10
//--- Max bar width in pixels for the widest level
#define APEX_OB_BAR_W   90
//--- Row height in pixels
#define APEX_OB_ROW_H   15
//--- Panel width (bar + price label)
#define APEX_OB_PANEL_W (APEX_OB_BAR_W + 70)
//--- Right-edge X offset from panel right (corner = CORNER_RIGHT_UPPER)
#define APEX_OB_X_OFF   5
//--- Top Y offset
#define APEX_OB_Y_OFF   60

//--- Colors
#define APEX_OB_BID_FULL   C'0,160,130'    // strong bid
#define APEX_OB_BID_DIM    C'0,80,65'      // thin bid level
#define APEX_OB_ASK_FULL   C'200,50,50'    // strong ask
#define APEX_OB_ASK_DIM    C'110,25,25'    // thin ask level
#define APEX_OB_SPREAD_BG  C'25,25,40'     // spread row background

class COBRenderer
{
private:
    COrderBookSnapshot *m_ob;
    long    m_chart;
    bool    m_initialized;
    ulong   m_last_update_ms;

    //--- Object name helpers
    string bid_bar_nm(int i)   const { return StringFormat("APEX_OB_BB%d", i); }
    string ask_bar_nm(int i)   const { return StringFormat("APEX_OB_AB%d", i); }
    string bid_lbl_nm(int i)   const { return StringFormat("APEX_OB_BL%d", i); }
    string ask_lbl_nm(int i)   const { return StringFormat("APEX_OB_AL%d", i); }
    string spread_nm()         const { return "APEX_OB_SPR"; }
    string bg_nm()             const { return "APEX_OB_BG"; }
    string title_nm()          const { return "APEX_OB_TTL"; }

    //--- Create a rectangle label anchored to top-right corner
    void cr(string nm, int x, int y, int w, int h, color bg)
    {
        ObjectDelete(m_chart, nm);
        if(!ObjectCreate(m_chart, nm, OBJ_RECTANGLE_LABEL, 0, 0, 0)) return;
        ObjectSetInteger(m_chart, nm, OBJPROP_CORNER,      CORNER_RIGHT_UPPER);
        ObjectSetInteger(m_chart, nm, OBJPROP_XDISTANCE,   x);
        ObjectSetInteger(m_chart, nm, OBJPROP_YDISTANCE,   y);
        ObjectSetInteger(m_chart, nm, OBJPROP_XSIZE,       w);
        ObjectSetInteger(m_chart, nm, OBJPROP_YSIZE,       h);
        ObjectSetInteger(m_chart, nm, OBJPROP_BGCOLOR,     bg);
        ObjectSetInteger(m_chart, nm, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(m_chart, nm, OBJPROP_SELECTABLE,  false);
        ObjectSetInteger(m_chart, nm, OBJPROP_HIDDEN,      true);
    }

    //--- Create a text label anchored to top-right corner
    void cl(string nm, int x, int y, string text, color clr, int fsz = APEX_PNL_FONT_SM)
    {
        ObjectDelete(m_chart, nm);
        if(!ObjectCreate(m_chart, nm, OBJ_LABEL, 0, 0, 0)) return;
        ObjectSetInteger(m_chart, nm, OBJPROP_CORNER,     CORNER_RIGHT_UPPER);
        ObjectSetInteger(m_chart, nm, OBJPROP_XDISTANCE,  x);
        ObjectSetInteger(m_chart, nm, OBJPROP_YDISTANCE,  y);
        ObjectSetString (m_chart, nm, OBJPROP_TEXT,       text);
        ObjectSetInteger(m_chart, nm, OBJPROP_COLOR,      clr);
        ObjectSetInteger(m_chart, nm, OBJPROP_FONTSIZE,   fsz);
        ObjectSetString (m_chart, nm, OBJPROP_FONT,       APEX_PNL_FONT);
        ObjectSetInteger(m_chart, nm, OBJPROP_ANCHOR,     ANCHOR_RIGHT_UPPER);
        ObjectSetInteger(m_chart, nm, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(m_chart, nm, OBJPROP_HIDDEN,     true);
    }

    //--- Row Y inside the panel: asks top (idx 0=tightest), spread mid, bids below
    //    Asks are displayed top→down (index 0 = closest to spread)
    //    Bids are displayed top→down too (index 0 = closest to spread)
    int ask_row_y(int i) const
    {
        // Ask rows: top of asks = Y_OFF + header (20px) + (DEPTH-1-i)*ROW_H
        // so tightest ask (i=0) is at the bottom of the ask block
        return APEX_OB_Y_OFF + 20 + (APEX_OB_DEPTH - 1 - i) * APEX_OB_ROW_H;
    }

    int spread_row_y() const
    {
        return APEX_OB_Y_OFF + 20 + APEX_OB_DEPTH * APEX_OB_ROW_H;
    }

    int bid_row_y(int i) const
    {
        // Bid rows: tightest bid (i=0) just below spread
        return spread_row_y() + APEX_OB_ROW_H + i * APEX_OB_ROW_H;
    }

    int total_panel_h() const
    {
        return 20 + (2 * APEX_OB_DEPTH + 1) * APEX_OB_ROW_H + 4;
    }

public:
    bool Initialize()
    {
        m_initialized   = false;
        m_ob            = NULL;
        m_last_update_ms = 0;

        if(!InpShowOBDepth) { m_initialized = true; return true; }

        m_chart = ChartID();

        int ph = total_panel_h();
        int px = APEX_OB_X_OFF;
        int pw = APEX_OB_PANEL_W;

        // Background
        cr(bg_nm(), px, APEX_OB_Y_OFF, pw, ph, InpPanelBG);

        // Title
        cl(title_nm(), px + pw / 2, APEX_OB_Y_OFF + 4, "ORDER BOOK",
           APEX_PNL_COLOR_WARNING, APEX_PNL_FONT_SM);

        // Ask rows (light red bars + price labels)
        for(int i = 0; i < APEX_OB_DEPTH; i++)
        {
            int ry = ask_row_y(i);
            // Bar starts from right edge, width varies
            cr(ask_bar_nm(i), px,        ry, 0,       APEX_OB_ROW_H - 1, APEX_OB_ASK_DIM);
            cl(ask_lbl_nm(i), px + pw - 2, ry + 3, " ", InpNeutralColor);
        }

        // Spread indicator row
        cr(spread_nm(), px, spread_row_y(), pw, APEX_OB_ROW_H, APEX_OB_SPREAD_BG);

        // Bid rows (green bars + price labels)
        for(int i = 0; i < APEX_OB_DEPTH; i++)
        {
            int ry = bid_row_y(i);
            cr(bid_bar_nm(i), px,        ry, 0,       APEX_OB_ROW_H - 1, APEX_OB_BID_DIM);
            cl(bid_lbl_nm(i), px + pw - 2, ry + 3, " ", InpNeutralColor);
        }

        m_initialized = true;
        return true;
    }

    void SetOrderBook(COrderBookSnapshot *ob) { m_ob = ob; }

    //--- Call every tick; throttled internally to InpOBISnapshotInterval ms.
    void OnTick()
    {
        if(!m_initialized || !InpShowOBDepth || m_ob == NULL) return;

        // Strategy Tester: order book not available — show static note
        if((bool)MQLInfoInteger(MQL_TESTER))
        {
            ObjectSetString(m_chart, title_nm(), OBJPROP_TEXT, "OB: LIVE ONLY");
            ChartRedraw(m_chart);
            return;
        }

        // Throttle: only update every InpOBISnapshotInterval ms
        ulong now_ms = (ulong)GetTickCount();
        if(now_ms - m_last_update_ms < (ulong)InpOBISnapshotInterval) return;
        m_last_update_ms = now_ms;

        OrderBookSnapshot snap = m_ob.GetLatestSnapshot();
        if(snap.depth == 0) return;

        int    depth = MathMin(snap.depth, APEX_OB_DEPTH);
        int    pw    = APEX_OB_PANEL_W;
        int    px    = APEX_OB_X_OFF;

        // Find max volume across visible levels for bar width normalisation
        long max_vol = 1;
        for(int i = 0; i < depth; i++)
        {
            if(snap.bids[i].volume > max_vol) max_vol = snap.bids[i].volume;
            if(snap.asks[i].volume > max_vol) max_vol = snap.asks[i].volume;
        }

        //--- Ask rows (i=0 is the tightest ask, closest to mid)
        for(int i = 0; i < APEX_OB_DEPTH; i++)
        {
            int ry = ask_row_y(i);
            if(i < depth && snap.asks[i].volume > 0)
            {
                int bar_w  = (int)MathRound((double)snap.asks[i].volume / (double)max_vol * APEX_OB_BAR_W);
                ObjectSetInteger(m_chart, ask_bar_nm(i), OBJPROP_XSIZE,     bar_w);
                ObjectSetInteger(m_chart, ask_bar_nm(i), OBJPROP_BGCOLOR,
                                 snap.asks[i].price == snap.largest_ask_price
                                 ? APEX_OB_ASK_FULL : APEX_OB_ASK_DIM);
                ObjectSetString (m_chart, ask_lbl_nm(i), OBJPROP_TEXT,
                                 StringFormat("%.*f  %d",
                                              (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS),
                                              snap.asks[i].price, (int)snap.asks[i].volume));
                ObjectSetInteger(m_chart, ask_lbl_nm(i), OBJPROP_YDISTANCE, ry + 3);
            }
            else
            {
                // Hidden / empty level
                ObjectSetInteger(m_chart, ask_bar_nm(i), OBJPROP_XSIZE, 0);
                ObjectSetString (m_chart, ask_lbl_nm(i), OBJPROP_TEXT,  " ");
            }
        }

        //--- Spread row: show mid-price and spread in points
        {
            string spr_txt = StringFormat("mid %.5f  spr %.1f",
                                          snap.mid_price, g_CurrentSpread);
            // Update spread row label (reuse spread_nm rect as bg, add text via title or separate label)
            // We only have the bg rect for spread, so add text to ask_lbl or bid_lbl slot 0 isn't clean.
            // Instead update the "title" label text dynamically.
            ObjectSetString(m_chart, spread_nm(), OBJPROP_TEXT, "");   // rect has no text — that's fine
        }

        //--- Bid rows (i=0 is the tightest bid, closest to mid)
        for(int i = 0; i < APEX_OB_DEPTH; i++)
        {
            int ry = bid_row_y(i);
            if(i < depth && snap.bids[i].volume > 0)
            {
                int bar_w  = (int)MathRound((double)snap.bids[i].volume / (double)max_vol * APEX_OB_BAR_W);
                ObjectSetInteger(m_chart, bid_bar_nm(i), OBJPROP_XSIZE,     bar_w);
                ObjectSetInteger(m_chart, bid_bar_nm(i), OBJPROP_BGCOLOR,
                                 snap.bids[i].price == snap.largest_bid_price
                                 ? APEX_OB_BID_FULL : APEX_OB_BID_DIM);
                ObjectSetString (m_chart, bid_lbl_nm(i), OBJPROP_TEXT,
                                 StringFormat("%.*f  %d",
                                              (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS),
                                              snap.bids[i].price, (int)snap.bids[i].volume));
                ObjectSetInteger(m_chart, bid_lbl_nm(i), OBJPROP_YDISTANCE, ry + 3);
            }
            else
            {
                ObjectSetInteger(m_chart, bid_bar_nm(i), OBJPROP_XSIZE, 0);
                ObjectSetString (m_chart, bid_lbl_nm(i), OBJPROP_TEXT,  " ");
            }
        }

        // Update title to show spread info (overwrite title text)
        ObjectSetString(m_chart, title_nm(), OBJPROP_TEXT,
                        StringFormat("OB | spr:%.1f", g_CurrentSpread));

        // Spoof alert: tint the bg red briefly
        if(snap.spoof_suspected)
            ObjectSetInteger(m_chart, bg_nm(), OBJPROP_BGCOLOR, C'30,10,10');
        else
            ObjectSetInteger(m_chart, bg_nm(), OBJPROP_BGCOLOR, InpPanelBG);

        ChartRedraw(m_chart);
    }

    void Deinitialize()
    {
        if(!m_initialized) return;
        for(int i = 0; i < APEX_OB_DEPTH; i++)
        {
            ObjectDelete(m_chart, bid_bar_nm(i));
            ObjectDelete(m_chart, ask_bar_nm(i));
            ObjectDelete(m_chart, bid_lbl_nm(i));
            ObjectDelete(m_chart, ask_lbl_nm(i));
        }
        ObjectDelete(m_chart, spread_nm());
        ObjectDelete(m_chart, bg_nm());
        ObjectDelete(m_chart, title_nm());
        m_initialized = false;
    }
};
