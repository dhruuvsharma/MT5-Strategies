//+------------------------------------------------------------------+
//| SignalLEDs.mqh — APEX_SCALPER                                    |
//| Small 8×8 colored indicator rectangles, one per signal row.    |
//| Green = bullish, red = bearish, grey = neutral/stale/no-data.  |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "PanelTheme.mqh"

class CSignalLEDs
{
private:
    long m_chart;
    int  m_count;

    // Object name for LED at index i
    string led_nm(int i) const { return StringFormat("APEX_D_LED_%d", i); }

public:
    bool Initialize(long chart_id, int count)
    {
        m_chart = chart_id;
        m_count = MathMin(count, APEX_MAX_SIGNAL_COUNT);
        return true;
    }

    //--- Create LED rectangle objects positioned in the signal matrix.
    //    panel_x    : left edge of the panel in pixels
    //    first_row_y: Y of the first signal row
    //    row_h      : row height in pixels
    void CreateObjects(int panel_x, int first_row_y, int row_h)
    {
        for(int i = 0; i < m_count; i++)
        {
            string nm = led_nm(i);
            ObjectDelete(m_chart, nm);
            if(!ObjectCreate(m_chart, nm, OBJ_RECTANGLE_LABEL, 0, 0, 0)) continue;
            int y = first_row_y + i * row_h + (row_h - 8) / 2;
            ObjectSetInteger(m_chart, nm, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
            ObjectSetInteger(m_chart, nm, OBJPROP_XDISTANCE,   panel_x + APEX_PNL_COL_LED);
            ObjectSetInteger(m_chart, nm, OBJPROP_YDISTANCE,   y);
            ObjectSetInteger(m_chart, nm, OBJPROP_XSIZE,       8);
            ObjectSetInteger(m_chart, nm, OBJPROP_YSIZE,       8);
            ObjectSetInteger(m_chart, nm, OBJPROP_BGCOLOR,     APEX_PNL_COLOR_STALE);
            ObjectSetInteger(m_chart, nm, OBJPROP_BORDER_TYPE, BORDER_FLAT);
            ObjectSetInteger(m_chart, nm, OBJPROP_SELECTABLE,  false);
            ObjectSetInteger(m_chart, nm, OBJPROP_HIDDEN,      true);
        }
    }

    //--- Update LED color for signal at index.
    //    direction: +1 bull, -1 bear, 0 neutral
    //    is_valid : false = no data
    //    is_stale : age > threshold
    void Update(int index, int direction, bool is_valid, bool is_stale)
    {
        if(index < 0 || index >= m_count) return;
        color clr;
        if(!is_valid)           clr = APEX_PNL_COLOR_STALE;
        else if(is_stale)       clr = APEX_PNL_COLOR_WARNING;
        else if(direction > 0)  clr = InpBullColor;
        else if(direction < 0)  clr = InpBearColor;
        else                    clr = InpNeutralColor;
        ObjectSetInteger(m_chart, led_nm(index), OBJPROP_BGCOLOR, clr);
    }

    //--- Show or hide all LEDs (used when panel is minimized).
    void SetAllVisible(bool visible)
    {
        long tf = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
        for(int i = 0; i < m_count; i++)
            ObjectSetInteger(m_chart, led_nm(i), OBJPROP_TIMEFRAMES, tf);
    }

    //--- Delete all LED objects.
    void Deinitialize()
    {
        for(int i = 0; i < m_count; i++)
            ObjectDelete(m_chart, led_nm(i));
        m_count = 0;
    }
};
