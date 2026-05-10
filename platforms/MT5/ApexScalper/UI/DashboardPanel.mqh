//+------------------------------------------------------------------+
//| DashboardPanel.mqh — APEX_SCALPER                                |
//| Live chart panel: signal matrix, composite, risk, session.     |
//| All chart objects are created once in Initialize() and updated  |
//| via ObjectSet* in Redraw(). No ObjectCreate() calls in Redraw. |
//| Header click toggles minimize/maximize.                         |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"
#include "PanelTheme.mqh"
#include "SignalLEDs.mqh"

//--- Maximum signal rows shown in the panel
#define APEX_PNL_MAX_SIG_ROWS  10

class CDashboardPanel
{
private:
    bool        m_initialized;
    bool        m_minimized;
    long        m_chart;
    int         m_panel_h;       // total panel height in pixels
    int         m_sig_rows;      // number of signal rows to display
    CSignalLEDs m_leds;

    //+----------------------------------------------------------------+
    //| Object name helpers                                            |
    //+----------------------------------------------------------------+
    string O(string id) const { return "APEX_D_" + id; }
    string SI(int i)    const { return StringFormat("%d", i); }

    //+----------------------------------------------------------------+
    //| Low-level: create a rectangle label, deleting any prior copy. |
    //+----------------------------------------------------------------+
    void cr(string id, int x, int y, int w, int h, color bg,
            color border = C'0,0,0', ENUM_BORDER_TYPE btype = BORDER_FLAT)
    {
        string nm = O(id);
        ObjectDelete(m_chart, nm);
        if(!ObjectCreate(m_chart, nm, OBJ_RECTANGLE_LABEL, 0, 0, 0)) return;
        ObjectSetInteger(m_chart, nm, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
        ObjectSetInteger(m_chart, nm, OBJPROP_XDISTANCE,   x);
        ObjectSetInteger(m_chart, nm, OBJPROP_YDISTANCE,   y);
        ObjectSetInteger(m_chart, nm, OBJPROP_XSIZE,       w);
        ObjectSetInteger(m_chart, nm, OBJPROP_YSIZE,       h);
        ObjectSetInteger(m_chart, nm, OBJPROP_BGCOLOR,     bg);
        ObjectSetInteger(m_chart, nm, OBJPROP_BORDER_TYPE, btype);
        ObjectSetInteger(m_chart, nm, OBJPROP_COLOR,       border);
        ObjectSetInteger(m_chart, nm, OBJPROP_SELECTABLE,  false);
        ObjectSetInteger(m_chart, nm, OBJPROP_HIDDEN,      true);
    }

    //+----------------------------------------------------------------+
    //| Low-level: create a text label, deleting any prior copy.      |
    //+----------------------------------------------------------------+
    void cl(string id, int x, int y, string text, color clr, int font_sz = APEX_PNL_FONT_MD)
    {
        string nm = O(id);
        ObjectDelete(m_chart, nm);
        if(!ObjectCreate(m_chart, nm, OBJ_LABEL, 0, 0, 0)) return;
        ObjectSetInteger(m_chart, nm, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
        ObjectSetInteger(m_chart, nm, OBJPROP_XDISTANCE,  x);
        ObjectSetInteger(m_chart, nm, OBJPROP_YDISTANCE,  y);
        ObjectSetString (m_chart, nm, OBJPROP_TEXT,       text);
        ObjectSetInteger(m_chart, nm, OBJPROP_COLOR,      clr);
        ObjectSetInteger(m_chart, nm, OBJPROP_FONTSIZE,   font_sz);
        ObjectSetString (m_chart, nm, OBJPROP_FONT,       APEX_PNL_FONT);
        ObjectSetInteger(m_chart, nm, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(m_chart, nm, OBJPROP_HIDDEN,     true);
    }

    //+----------------------------------------------------------------+
    //| Update helpers — never call ObjectCreate.                      |
    //+----------------------------------------------------------------+
    void ur(string id, int x, int y, int w, int h, color bg)
    {
        string nm = O(id);
        ObjectSetInteger(m_chart, nm, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(m_chart, nm, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(m_chart, nm, OBJPROP_XSIZE,     MathMax(w, 0));
        ObjectSetInteger(m_chart, nm, OBJPROP_YSIZE,     h);
        ObjectSetInteger(m_chart, nm, OBJPROP_BGCOLOR,   bg);
    }

    void ul(string id, string text, color clr)
    {
        string nm = O(id);
        ObjectSetString (m_chart, nm, OBJPROP_TEXT,  text);
        ObjectSetInteger(m_chart, nm, OBJPROP_COLOR, clr);
    }

    void set_vis(string id, bool visible)
    {
        ObjectSetInteger(m_chart, O(id), OBJPROP_TIMEFRAMES,
                         visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
    }

    //+----------------------------------------------------------------+
    //| Pixel Y for signal row i (within the signal section).         |
    //+----------------------------------------------------------------+
    int sig_row_y(int i) const
    {
        // header + gap + section-header + i rows
        return InpPanelY + APEX_PNL_HDR_H + APEX_PNL_SEC_GAP + APEX_PNL_SEC_H
               + i * APEX_PNL_ROW_H;
    }

    //+----------------------------------------------------------------+
    //| Y of the start of each major section (above its sub-header).  |
    //+----------------------------------------------------------------+
    int section_y(int sec) const
    {
        int y = InpPanelY + APEX_PNL_HDR_H + APEX_PNL_SEC_GAP;
        // sec=0 : signals header
        if(sec >= 1) y += APEX_PNL_SEC_H + m_sig_rows * APEX_PNL_ROW_H + APEX_PNL_SEC_GAP;
        // sec=1 : composite header
        if(sec >= 2) y += APEX_PNL_SEC_H + 3 * APEX_PNL_ROW_H + APEX_PNL_SEC_GAP;
        // sec=2 : risk header
        if(sec >= 3) y += APEX_PNL_SEC_H + 2 * APEX_PNL_ROW_H + APEX_PNL_SEC_GAP;
        // sec=3 : session/filter header
        return y;
    }

    //+----------------------------------------------------------------+
    //| Show or hide all non-header panel objects.                     |
    //+----------------------------------------------------------------+
    void apply_visibility(bool visible)
    {
        long tf = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
        for(int i = ObjectsTotal(m_chart, -1, -1) - 1; i >= 0; i--)
        {
            string nm = ObjectName(m_chart, i, -1, -1);
            if(StringFind(nm, "APEX_D_") != 0) continue;
            // Keep header objects always visible
            if(nm == O("BG")        || nm == O("HDR_BG") ||
               nm == O("HDR_TITLE") || nm == O("HDR_SYM") ||
               nm == O("HDR_REG"))   continue;
            ObjectSetInteger(m_chart, nm, OBJPROP_TIMEFRAMES, tf);
        }
        m_leds.SetAllVisible(visible);
    }

    //+----------------------------------------------------------------+
    //| Update the score bar fill rect for signal row i.               |
    //+----------------------------------------------------------------+
    void update_bar(int i, double score, int direction)
    {
        int fill_w  = (direction != 0) ? ApexBarFillWidth(score) : 0;
        int center  = InpPanelX + APEX_PNL_COL_BAR + APEX_PNL_BAR_W / 2;
        int bar_y   = sig_row_y(i) + (APEX_PNL_ROW_H - APEX_PNL_BAR_H) / 2;
        int fill_x  = (direction >= 0) ? center : center - fill_w;
        color clr   = (direction != 0) ? ApexScoreColor(direction) : InpNeutralColor;
        ur("SR_BAR_" + SI(i), fill_x, bar_y, fill_w, APEX_PNL_BAR_H, clr);
    }

public:
    //+----------------------------------------------------------------+
    //| Create all chart objects. Returns true on success.             |
    //| No-ops and returns true if InpShowDashboard is false.          |
    //+----------------------------------------------------------------+
    bool Initialize()
    {
        m_initialized = false;
        m_minimized   = false;
        m_chart       = ChartID();
        m_sig_rows    = MathMin(APEX_MAX_SIGNAL_COUNT, APEX_PNL_MAX_SIG_ROWS);

        if(!InpShowDashboard) { m_initialized = true; return true; }

        // Compute total panel height:
        // header + signals-section + composite-section + risk-section + filter-section
        m_panel_h = APEX_PNL_HDR_H
                    + (APEX_PNL_SEC_GAP + APEX_PNL_SEC_H + m_sig_rows * APEX_PNL_ROW_H)
                    + (APEX_PNL_SEC_GAP + APEX_PNL_SEC_H + 3 * APEX_PNL_ROW_H)
                    + (APEX_PNL_SEC_GAP + APEX_PNL_SEC_H + 2 * APEX_PNL_ROW_H)
                    + (APEX_PNL_SEC_GAP + APEX_PNL_SEC_H + 2 * APEX_PNL_ROW_H)
                    + APEX_PNL_SEC_GAP;

        int px = InpPanelX;
        int py = InpPanelY;
        int pw = InpPanelWidth;

        //--- Main background
        cr("BG", px, py, pw, m_panel_h, InpPanelBG, InpPanelBorder, BORDER_FLAT);

        //--- Header bar
        cr("HDR_BG", px, py, pw, APEX_PNL_HDR_H, APEX_PNL_COLOR_HDR_BG);
        // Make header clickable for minimize/maximize
        ObjectSetInteger(m_chart, O("HDR_BG"), OBJPROP_SELECTABLE, true);
        cl("HDR_TITLE", px + APEX_PNL_PAD_X, py + 5, "APEX SCALPER", InpBullColor, APEX_PNL_FONT_LG);
        cl("HDR_SYM",   px + 100,             py + 5, " ",            InpNeutralColor, APEX_PNL_FONT_MD);
        cl("HDR_REG",   px + pw - 90,          py + 6, " ",            InpNeutralColor, APEX_PNL_FONT_SM);

        //--- ── SIGNALS section ──────────────────────────────────────
        int sy = section_y(0);
        cr("SIG_HDR",     px,                          sy, pw, APEX_PNL_SEC_H, APEX_PNL_COLOR_SEC_BG);
        cl("SIG_HDR_TXT", px + APEX_PNL_PAD_X,        sy + 3, "SIGNALS",    APEX_PNL_COLOR_WARNING, APEX_PNL_FONT_SM);
        cl("SIG_COL_SC",  px + APEX_PNL_COL_SCORE,    sy + 3, "SCORE",      APEX_PNL_COLOR_STALE,   APEX_PNL_FONT_SM);
        cl("SIG_COL_ST",  px + APEX_PNL_COL_STAT,     sy + 3, "STATUS/AGE", APEX_PNL_COLOR_STALE,   APEX_PNL_FONT_SM);

        for(int i = 0; i < m_sig_rows; i++)
        {
            string si  = SI(i);
            int    ry  = sig_row_y(i);
            color  rbg = (i % 2 == 0) ? InpPanelBG : APEX_PNL_COLOR_ROW_ALT;
            int    bmy = ry + (APEX_PNL_ROW_H - APEX_PNL_BAR_H) / 2;  // bar mid-y

            cr("SR_BG_"    + si, px,                            ry,  pw,               APEX_PNL_ROW_H, rbg);
            cr("SR_BARBG_" + si, px + APEX_PNL_COL_BAR,        bmy, APEX_PNL_BAR_W,   APEX_PNL_BAR_H, APEX_PNL_COLOR_DARK);
            // Center divider: 1px wide line at bar midpoint
            cr("SR_BCTR_"  + si, px + APEX_PNL_COL_BAR + APEX_PNL_BAR_W/2 - 1, bmy, 1, APEX_PNL_BAR_H, APEX_PNL_COLOR_CTR_LINE);
            // Score bar fill (initially 0-width)
            cr("SR_BAR_"   + si, px + APEX_PNL_COL_BAR + APEX_PNL_BAR_W/2, bmy, 0, APEX_PNL_BAR_H, InpNeutralColor);
            cl("SR_NAME_"  + si, px + APEX_PNL_COL_NAME,  ry + 4, " ",     InpNeutralColor, APEX_PNL_FONT_SM);
            cl("SR_SCORE_" + si, px + APEX_PNL_COL_SCORE, ry + 4, "+0.00", APEX_PNL_COLOR_STALE, APEX_PNL_FONT_SM);
            cl("SR_STAT_"  + si, px + APEX_PNL_COL_STAT,  ry + 4, "—",     APEX_PNL_COLOR_STALE, APEX_PNL_FONT_SM);
        }

        m_leds.Initialize(m_chart, m_sig_rows);
        m_leds.CreateObjects(px, sig_row_y(0), APEX_PNL_ROW_H);

        //--- ── COMPOSITE section ────────────────────────────────────
        int cy = section_y(1);
        cr("CMP_HDR",     px,                   cy, pw, APEX_PNL_SEC_H, APEX_PNL_COLOR_SEC_BG);
        cl("CMP_HDR_TXT", px + APEX_PNL_PAD_X, cy + 3, "COMPOSITE", APEX_PNL_COLOR_WARNING, APEX_PNL_FONT_SM);
        int cr1 = cy + APEX_PNL_SEC_H;
        cl("CMP_SCORE",  px + APEX_PNL_PAD_X, cr1 + 2,  "+0.00",     InpNeutralColor, APEX_PNL_FONT_XL);
        cl("CMP_DIR",    px + 55,              cr1 + 2,  "→",         InpNeutralColor, APEX_PNL_FONT_LG);
        cl("CMP_AGR",    px + 80,              cr1 + 5,  "0/8 agree", InpNeutralColor, APEX_PNL_FONT_SM);
        cl("CMP_CONF",   px + pw - 70,         cr1 + 5,  " ",         APEX_PNL_COLOR_WARNING, APEX_PNL_FONT_SM);
        int cr2 = cr1 + APEX_PNL_ROW_H;
        cl("CMP_GATE",   px + APEX_PNL_PAD_X, cr2 + 4,  "GATED",     InpBearColor, APEX_PNL_FONT_MD);
        cl("CMP_CONF2",  px + 60,              cr2 + 4,  " ",         APEX_PNL_COLOR_STALE, APEX_PNL_FONT_SM);
        int cr3 = cr2 + APEX_PNL_ROW_H;
        cl("CMP_TRADES", px + APEX_PNL_PAD_X, cr3 + 4,  "Trades: 0", APEX_PNL_COLOR_STALE, APEX_PNL_FONT_SM);
        cl("CMP_WINRT",  px + 100,             cr3 + 4,  "Win: —",    APEX_PNL_COLOR_STALE, APEX_PNL_FONT_SM);

        //--- ── RISK section ─────────────────────────────────────────
        int ry = section_y(2);
        cr("RSK_HDR",     px,                   ry, pw, APEX_PNL_SEC_H, APEX_PNL_COLOR_SEC_BG);
        cl("RSK_HDR_TXT", px + APEX_PNL_PAD_X, ry + 3, "RISK", APEX_PNL_COLOR_WARNING, APEX_PNL_FONT_SM);
        int rr1 = ry + APEX_PNL_SEC_H;
        cl("RSK_PNL",  px + APEX_PNL_PAD_X, rr1 + 4, "Daily P&L: --",   InpNeutralColor, APEX_PNL_FONT_SM);
        cl("RSK_DD",   px + 150,             rr1 + 4, "DD: --",           InpNeutralColor, APEX_PNL_FONT_SM);
        int rr2 = rr1 + APEX_PNL_ROW_H;
        cl("RSK_KS",   px + APEX_PNL_PAD_X, rr2 + 4, "Kill switch: OFF", InpBullColor,    APEX_PNL_FONT_SM);
        cl("RSK_POS",  px + 150,             rr2 + 4, "Pos: 0",           InpNeutralColor, APEX_PNL_FONT_SM);

        //--- ── SESSION / FILTERS section ────────────────────────────
        int fy = section_y(3);
        cr("FLT_HDR",     px,                   fy, pw, APEX_PNL_SEC_H, APEX_PNL_COLOR_SEC_BG);
        cl("FLT_HDR_TXT", px + APEX_PNL_PAD_X, fy + 3, "SESSION / FILTERS", APEX_PNL_COLOR_WARNING, APEX_PNL_FONT_SM);
        int fr1 = fy + APEX_PNL_SEC_H;
        cl("FLT_SESS",  px + APEX_PNL_PAD_X, fr1 + 4, "Session: --",       InpNeutralColor, APEX_PNL_FONT_SM);
        cl("FLT_SPR",   px + 140,             fr1 + 4, "Spread: --",        InpNeutralColor, APEX_PNL_FONT_SM);
        int fr2 = fr1 + APEX_PNL_ROW_H;
        cl("FLT_NEWS",  px + APEX_PNL_PAD_X, fr2 + 4, "News: OK",          InpBullColor,    APEX_PNL_FONT_SM);
        cl("FLT_REGM",  px + 100,             fr2 + 4, "Regime: --",        InpNeutralColor, APEX_PNL_FONT_SM);

        ChartRedraw(m_chart);
        m_initialized = true;
        return true;
    }

    //+----------------------------------------------------------------+
    //| Update all label/rect values from current global state.        |
    //| Must never call ObjectCreate.                                  |
    //+----------------------------------------------------------------+
    void Redraw()
    {
        if(!m_initialized || !InpShowDashboard || m_minimized) return;

        //--- Header: symbol + timeframe
        ul("HDR_SYM", StringFormat("%s %s", Symbol(), EnumToString(InpTimeframe)), InpNeutralColor);
        ul("HDR_REG",  RegimeToString(g_CurrentRegime),
           ApexScoreColor(g_CurrentRegime == REGIME_TRENDING_BULL ? 1 :
                          g_CurrentRegime == REGIME_TRENDING_BEAR ? -1 : 0));

        //--- Signal matrix
        CompositeResult comp = g_LastComposite;
        int n = MathMin(comp.component_count, m_sig_rows);
        for(int i = 0; i < n; i++)
        {
            SignalResult s = comp.components[i];
            string si  = SI(i);
            long   age = (s.generated_at > 0) ? (long)(TimeCurrent() - s.generated_at) : 999;
            bool stale = (!s.is_valid || age > 10);

            // Name (trim to 11 chars for column width)
            string nm_txt = s.signal_name;
            if(StringLen(nm_txt) > 11) nm_txt = StringSubstr(nm_txt, 0, 11);
            ul("SR_NAME_" + si, nm_txt, stale ? APEX_PNL_COLOR_STALE : InpNeutralColor);

            // Score bar fill
            update_bar(i, s.score, stale ? 0 : s.direction);

            // Score number
            ul("SR_SCORE_" + si, StringFormat("%+.2f", s.score),
               stale ? APEX_PNL_COLOR_STALE : ApexScoreColor(s.direction));

            // Status / age
            string stat_txt;
            color  stat_clr;
            if(!s.is_valid)
                { stat_txt = "NO DATA";              stat_clr = APEX_PNL_COLOR_STALE; }
            else if(age > 10)
                { stat_txt = StringFormat("STALE%ds", age);  stat_clr = APEX_PNL_COLOR_WARNING; }
            else
                { stat_txt = StringFormat("LIVE %ds", age);  stat_clr = InpBullColor; }
            ul("SR_STAT_" + si, stat_txt, stat_clr);

            m_leds.Update(i, s.direction, s.is_valid, age > 10);
        }
        // Clear unused rows
        for(int i = n; i < m_sig_rows; i++)
        {
            string si = SI(i);
            ul("SR_NAME_"  + si, " ", InpNeutralColor);
            ul("SR_SCORE_" + si, " ", APEX_PNL_COLOR_STALE);
            ul("SR_STAT_"  + si, " ", APEX_PNL_COLOR_STALE);
            update_bar(i, 0.0, 0);
            m_leds.Update(i, 0, false, true);
        }

        //--- Composite block
        color sc = ApexScoreColor(comp.direction);
        ul("CMP_SCORE", StringFormat("%+.2f", comp.score), sc);
        ul("CMP_DIR",   comp.direction > 0 ? "↑" : comp.direction < 0 ? "↓" : "→", sc);
        ul("CMP_AGR",   StringFormat("%d/%d agree", comp.signals_agree, n), InpNeutralColor);
        ul("CMP_CONF",  comp.conflict_flag ? "CONFLICT" : " ", APEX_PNL_COLOR_WARNING);

        if(comp.trade_allowed)
            ul("CMP_GATE", "READY", InpBullColor);
        else
            ul("CMP_GATE", "GATED", InpBearColor);

        // Second line: confidence % and signal counts
        ul("CMP_CONF2",
           StringFormat("conf %.0f%%  +%d/-%d", comp.confidence * 100.0,
                        comp.signals_agree, comp.signals_conflict),
           APEX_PNL_COLOR_STALE);

        ul("CMP_TRADES", StringFormat("Trades: %d", g_TotalTrades), APEX_PNL_COLOR_STALE);
        double win_rate = (g_TotalTrades > 0)
                          ? (double)g_WinningTrades / g_TotalTrades * 100.0 : 0.0;
        ul("CMP_WINRT",  StringFormat("Win: %.0f%%", win_rate),
           win_rate >= 50.0 ? InpBullColor : (g_TotalTrades > 0 ? InpBearColor : APEX_PNL_COLOR_STALE));

        //--- Risk block
        color pnl_clr = (g_DailyPnL >= 0.0) ? InpBullColor : InpBearColor;
        ul("RSK_PNL", StringFormat("Daily P&L: %+.2f", g_DailyPnL), pnl_clr);

        double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
        double dd_pct  = (g_PeakEquity > 1e-10)
                         ? MathMax(0.0, (g_PeakEquity - equity) / g_PeakEquity * 100.0) : 0.0;
        color dd_clr   = (dd_pct < 2.0) ? InpNeutralColor
                       : (dd_pct < 5.0) ? APEX_PNL_COLOR_WARNING
                       : InpBearColor;
        ul("RSK_DD",  StringFormat("DD: %.1f%%", dd_pct), dd_clr);
        ul("RSK_KS",  g_KillSwitch ? "Kill switch: ON!" : "Kill switch: OFF",
                      g_KillSwitch ? InpBearColor : InpBullColor);

        int open_pos = 0;
        for(int i = PositionsTotal() - 1; i >= 0; i--)
            if(PositionGetSymbol(i) == Symbol() &&
               PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                open_pos++;
        ul("RSK_POS", StringFormat("Pos: %d/%d", open_pos, InpMaxOpenPositions),
           open_pos >= InpMaxOpenPositions ? APEX_PNL_COLOR_WARNING : InpNeutralColor);

        //--- Session / filter block
        ul("FLT_SESS", "Session: " + SessionToString(g_CurrentSession), InpNeutralColor);
        color spr_clr = (g_CurrentSpread <= InpMaxSpreadPoints && InpMaxSpreadPoints > 0)
                        ? InpBullColor : InpBearColor;
        ul("FLT_SPR",  StringFormat("Spread: %.1f", g_CurrentSpread), spr_clr);
        ul("FLT_NEWS", g_NewsBlackout ? "News: BLOCK" : "News: OK",
           g_NewsBlackout ? InpBearColor : InpBullColor);
        ul("FLT_REGM", "Regime: " + RegimeToString(g_CurrentRegime), InpNeutralColor);

        ChartRedraw(m_chart);
    }

    //+----------------------------------------------------------------+
    //| Handle panel header click to toggle minimize/maximize.         |
    //+----------------------------------------------------------------+
    void OnChartEvent(const int id, const long &lparam,
                      const double &dparam, const string &sparam)
    {
        if(!m_initialized || !InpShowDashboard) return;
        if(id == CHARTEVENT_OBJECT_CLICK && sparam == O("HDR_BG"))
        {
            m_minimized = !m_minimized;
            apply_visibility(!m_minimized);
            ObjectSetInteger(m_chart, O("BG"), OBJPROP_YSIZE,
                             m_minimized ? APEX_PNL_HDR_H : m_panel_h);
            ChartRedraw(m_chart);
        }
    }

    //+----------------------------------------------------------------+
    //| Delete all APEX_D_ chart objects.                              |
    //+----------------------------------------------------------------+
    void Deinitialize()
    {
        if(!m_initialized) return;
        for(int i = ObjectsTotal(m_chart, -1, -1) - 1; i >= 0; i--)
        {
            string nm = ObjectName(m_chart, i, -1, -1);
            if(StringFind(nm, "APEX_D_") == 0)
                ObjectDelete(m_chart, nm);
        }
        m_leds.Deinitialize();
        m_initialized = false;
    }
};
