//+------------------------------------------------------------------+
//| FootprintRenderer.mqh — APEX_SCALPER                             |
//| Draws the live footprint candle on the chart as text labels at  |
//| each price level, positioned at the right edge of the current  |
//| bar. Stacked imbalance zones are shown as background rectangles.|
//| Guard: only active when InpShowFootprint == true.               |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"
#include "../Data/WindowManager.mqh"
#include "PanelTheme.mqh"

//--- Max price rows shown (centred on current mid price)
#define APEX_FP_MAX_ROWS  24

class CFootprintRenderer
{
private:
    CWindowManager *m_wm;
    long            m_chart;
    bool            m_initialized;
    double          m_tick_size;
    datetime        m_last_bar_time;   // detect bar close for stacked-zone refresh

    //--- Object name helpers
    string row_nm(int i) const { return StringFormat("APEX_FP_R%d", i); }
    string zon_nm(int i) const { return StringFormat("APEX_FP_Z%d", i); }  // i=0 bull, i=1 bear

    //--- Create a time/price anchored text label
    void create_row_label(int i)
    {
        string nm = row_nm(i);
        ObjectDelete(m_chart, nm);
        if(!ObjectCreate(m_chart, nm, OBJ_TEXT, 0, 0, 0)) return;
        ObjectSetString (m_chart, nm, OBJPROP_TEXT,      "");
        ObjectSetInteger(m_chart, nm, OBJPROP_COLOR,     InpNeutralColor);
        ObjectSetInteger(m_chart, nm, OBJPROP_FONTSIZE,  APEX_PNL_FONT_SM);
        ObjectSetString (m_chart, nm, OBJPROP_FONT,      APEX_PNL_FONT);
        ObjectSetInteger(m_chart, nm, OBJPROP_ANCHOR,    ANCHOR_LEFT);
        ObjectSetInteger(m_chart, nm, OBJPROP_SELECTABLE,false);
        ObjectSetInteger(m_chart, nm, OBJPROP_HIDDEN,    true);
        ObjectSetInteger(m_chart, nm, OBJPROP_BACK,      false);
    }

    //--- Create a background rectangle (used for stacked imbalance zones)
    void create_zone(int i)
    {
        string nm = zon_nm(i);
        ObjectDelete(m_chart, nm);
        if(!ObjectCreate(m_chart, nm, OBJ_RECTANGLE, 0, 0, 0.0, 0, 0.0)) return;
        ObjectSetInteger(m_chart, nm, OBJPROP_COLOR,      (i == 0) ? InpBullColor : InpBearColor);
        ObjectSetInteger(m_chart, nm, OBJPROP_STYLE,      STYLE_SOLID);
        ObjectSetInteger(m_chart, nm, OBJPROP_WIDTH,      1);
        ObjectSetInteger(m_chart, nm, OBJPROP_FILL,       true);
        ObjectSetInteger(m_chart, nm, OBJPROP_BACK,       true);   // behind candles
        ObjectSetInteger(m_chart, nm, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(m_chart, nm, OBJPROP_HIDDEN,     true);
        ObjectSetInteger(m_chart, nm, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);  // hidden until data
    }

    //--- Hide a zone object
    void hide_zone(int i)
    {
        ObjectSetInteger(m_chart, zon_nm(i), OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    }

    //--- Hide a row label
    void hide_row(int i)
    {
        ObjectSetString(m_chart, row_nm(i), OBJPROP_TEXT, "");
    }

public:
    bool Initialize()
    {
        m_initialized  = false;
        m_wm           = NULL;
        m_last_bar_time = 0;

        if(!InpShowFootprint) { m_initialized = true; return true; }

        m_chart     = ChartID();
        m_tick_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
        if(m_tick_size <= 0.0) m_tick_size = SymbolInfoDouble(Symbol(), SYMBOL_POINT);

        for(int i = 0; i < APEX_FP_MAX_ROWS; i++) create_row_label(i);
        create_zone(0);   // bull stacked imbalance zone (green)
        create_zone(1);   // bear stacked imbalance zone (red)

        m_initialized = true;
        return true;
    }

    void SetWindowManager(CWindowManager *wm) { m_wm = wm; }

    //--- Call every tick to refresh footprint overlay
    void OnTick()
    {
        if(!m_initialized || !InpShowFootprint || m_wm == NULL) return;

        FootprintCandle fp = m_wm.GetCurrentFootprint();
        if(fp.row_count == 0)
        {
            for(int i = 0; i < APEX_FP_MAX_ROWS; i++) hide_row(i);
            hide_zone(0); hide_zone(1);
            return;
        }

        // Right edge of current bar = projected close time
        datetime bar_open = m_wm.GetCurrentBarTime();
        if(bar_open == 0) bar_open = iTime(Symbol(), InpTimeframe, 0);
        datetime bar_right = bar_open + PeriodSeconds(InpTimeframe);

        // Current mid price for centering
        MqlTick tick;
        double  mid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        if(SymbolInfoTick(Symbol(), tick)) mid = (tick.ask + tick.bid) * 0.5;

        // Find the row index closest to mid price
        int center_idx = 0;
        double min_diff = 1e20;
        for(int i = 0; i < fp.row_count; i++)
        {
            double d = MathAbs(fp.rows[i].price - mid);
            if(d < min_diff) { min_diff = d; center_idx = i; }
        }

        int half  = APEX_FP_MAX_ROWS / 2;
        int start = MathMax(0, center_idx - half);
        int end   = MathMin(fp.row_count - 1, start + APEX_FP_MAX_ROWS - 1);
        // Adjust start if we hit the top boundary
        start = MathMax(0, end - APEX_FP_MAX_ROWS + 1);

        int label_idx = 0;
        for(int i = end; i >= start; i--, label_idx++)
        {
            if(label_idx >= APEX_FP_MAX_ROWS) break;
            string nm = row_nm(label_idx);

            // Build label text  e.g. "  123 | 456  " — wider side highlighted
            string bid_str = StringFormat("%5d", (int)fp.rows[i].bid_vol);
            string ask_str = StringFormat("%-5d", (int)fp.rows[i].ask_vol);
            string text    = bid_str + "|" + ask_str;

            // Color by imbalance
            color clr = InpNeutralColor;
            if(fp.rows[i].zero_ask)        clr = InpBullColor;
            else if(fp.rows[i].zero_bid)   clr = InpBearColor;
            else if(fp.rows[i].ask_imbalance) clr = InpBullColor;
            else if(fp.rows[i].bid_imbalance) clr = InpBearColor;

            // Update label position and content
            ObjectSetInteger(m_chart, nm, OBJPROP_TIME,  bar_right);
            ObjectSetDouble (m_chart, nm, OBJPROP_PRICE, fp.rows[i].price);
            ObjectSetString (m_chart, nm, OBJPROP_TEXT,  text);
            ObjectSetInteger(m_chart, nm, OBJPROP_COLOR, clr);
        }
        // Hide unused label slots
        for(; label_idx < APEX_FP_MAX_ROWS; label_idx++)
            hide_row(label_idx);

        // --- Stacked imbalance zones (update on bar change for perf)
        datetime cur_bar = iTime(Symbol(), InpTimeframe, 0);
        if(cur_bar != m_last_bar_time)
        {
            m_last_bar_time = cur_bar;
            update_stacked_zones(fp, bar_open, bar_right);
        }

        ChartRedraw(m_chart);
    }

private:
    void update_stacked_zones(const FootprintCandle &fp,
                               datetime bar_open, datetime bar_right)
    {
        // Bull zone: where ask_imbalance rows cluster (below POC)
        // Bear zone: where bid_imbalance rows cluster (above POC)
        // Find contiguous imbalance runs and show the most significant one per side

        double bull_lo = 0, bull_hi = 0;
        double bear_lo = 0, bear_hi = 0;
        int    bull_streak = 0, bear_streak = 0;

        for(int i = 0; i < fp.row_count; i++)
        {
            if(fp.rows[i].ask_imbalance || fp.rows[i].zero_bid)
            {
                if(bull_lo == 0.0) bull_lo = fp.rows[i].price;
                bull_hi     = fp.rows[i].price;
                bull_streak++;
            }
            if(fp.rows[i].bid_imbalance || fp.rows[i].zero_ask)
            {
                if(bear_lo == 0.0) bear_lo = fp.rows[i].price;
                bear_hi     = fp.rows[i].price;
                bear_streak++;
            }
        }

        int min_streak = (InpMinStackedRows > 0) ? InpMinStackedRows : 2;

        // Bull zone (green rectangle below price action)
        if(bull_streak >= min_streak && bull_lo > 0.0)
        {
            ObjectSetInteger(m_chart, zon_nm(0), OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            ObjectSetInteger(m_chart, zon_nm(0), OBJPROP_TIME,  0, bar_open);
            ObjectSetDouble (m_chart, zon_nm(0), OBJPROP_PRICE, 0, bull_lo - m_tick_size * 0.5);
            ObjectSetInteger(m_chart, zon_nm(0), OBJPROP_TIME,  1, bar_right);
            ObjectSetDouble (m_chart, zon_nm(0), OBJPROP_PRICE, 1, bull_hi + m_tick_size * 0.5);
        }
        else hide_zone(0);

        // Bear zone (red rectangle above price action)
        if(bear_streak >= min_streak && bear_lo > 0.0)
        {
            ObjectSetInteger(m_chart, zon_nm(1), OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            ObjectSetInteger(m_chart, zon_nm(1), OBJPROP_TIME,  0, bar_open);
            ObjectSetDouble (m_chart, zon_nm(1), OBJPROP_PRICE, 0, bear_lo - m_tick_size * 0.5);
            ObjectSetInteger(m_chart, zon_nm(1), OBJPROP_TIME,  1, bar_right);
            ObjectSetDouble (m_chart, zon_nm(1), OBJPROP_PRICE, 1, bear_hi + m_tick_size * 0.5);
        }
        else hide_zone(1);
    }

public:
    void Deinitialize()
    {
        if(!m_initialized) return;
        for(int i = 0; i < APEX_FP_MAX_ROWS; i++) ObjectDelete(m_chart, row_nm(i));
        ObjectDelete(m_chart, zon_nm(0));
        ObjectDelete(m_chart, zon_nm(1));
        m_initialized = false;
    }
};
