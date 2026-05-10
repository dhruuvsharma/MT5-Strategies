//+------------------------------------------------------------------+
//| HVPRenderer.mqh — APEX_SCALPER                                   |
//| Draws HVP horizontal lines on the chart, colored by volume      |
//| intensity. Draws a linear regression trend line through HVP    |
//| price nodes. Updates on each bar close.                         |
//| Guard: only active when InpShowHVPLines == true.                |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"
#include "../Data/WindowManager.mqh"
#include "PanelTheme.mqh"

//--- Maximum HVP lines drawn on the chart
#define APEX_HVP_MAX_LINES  20

class CHVPRenderer
{
private:
    CWindowManager *m_wm;
    long            m_chart;
    bool            m_initialized;
    int             m_active_lines;  // how many lines are currently visible

    //--- Object name helpers
    string hvp_nm(int i)   const { return StringFormat("APEX_HVP_L%d", i); }
    string poc_nm()        const { return "APEX_HVP_POC"; }
    string reg_nm()        const { return "APEX_HVP_REG"; }
    string va_hi_nm()      const { return "APEX_HVP_VAH"; }
    string va_lo_nm()      const { return "APEX_HVP_VAL"; }

    //--- Interpolate a color between two endpoints (0.0 = c1, 1.0 = c2)
    color interpolate_color(color c1, color c2, double t)
    {
        t = MathMax(0.0, MathMin(1.0, t));
        int r = (int)((double)(c1 & 0xFF)         * (1.0 - t) + (double)(c2 & 0xFF)         * t);
        int g = (int)((double)((c1 >> 8)  & 0xFF) * (1.0 - t) + (double)((c2 >> 8)  & 0xFF) * t);
        int b = (int)((double)((c1 >> 16) & 0xFF) * (1.0 - t) + (double)((c2 >> 16) & 0xFF) * t);
        return (color)(r | (g << 8) | (b << 16));
    }

    //--- MQL5 color channels: stored as 0x00BBGGRR
    color hvp_volume_color(double vol_fraction)
    {
        // Low volume: dim InpNeutralColor → High volume: bright InpBullColor
        return interpolate_color(APEX_PNL_COLOR_STALE, InpBullColor, vol_fraction);
    }

public:
    bool Initialize()
    {
        m_initialized = false;
        m_wm          = NULL;
        m_active_lines = 0;

        if(!InpShowHVPLines) { m_initialized = true; return true; }

        m_chart = ChartID();

        // Pre-create HVP horizontal lines (initially hidden)
        for(int i = 0; i < APEX_HVP_MAX_LINES; i++)
        {
            string nm = hvp_nm(i);
            ObjectDelete(m_chart, nm);
            if(!ObjectCreate(m_chart, nm, OBJ_HLINE, 0, 0, 0.0)) continue;
            ObjectSetInteger(m_chart, nm, OBJPROP_COLOR,      APEX_PNL_COLOR_STALE);
            ObjectSetInteger(m_chart, nm, OBJPROP_STYLE,      STYLE_DOT);
            ObjectSetInteger(m_chart, nm, OBJPROP_WIDTH,      1);
            ObjectSetInteger(m_chart, nm, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(m_chart, nm, OBJPROP_HIDDEN,     true);
            ObjectSetInteger(m_chart, nm, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        }

        // POC line (solid, bright)
        {
            string nm = poc_nm();
            ObjectDelete(m_chart, nm);
            if(ObjectCreate(m_chart, nm, OBJ_HLINE, 0, 0, 0.0))
            {
                ObjectSetInteger(m_chart, nm, OBJPROP_COLOR,      APEX_PNL_COLOR_WARNING);
                ObjectSetInteger(m_chart, nm, OBJPROP_STYLE,      STYLE_SOLID);
                ObjectSetInteger(m_chart, nm, OBJPROP_WIDTH,      1);
                ObjectSetInteger(m_chart, nm, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(m_chart, nm, OBJPROP_HIDDEN,     true);
                ObjectSetInteger(m_chart, nm, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
            }
        }

        // Value area high/low lines (dashed)
        for(int j = 0; j < 2; j++)
        {
            string nm = (j == 0) ? va_hi_nm() : va_lo_nm();
            ObjectDelete(m_chart, nm);
            if(ObjectCreate(m_chart, nm, OBJ_HLINE, 0, 0, 0.0))
            {
                ObjectSetInteger(m_chart, nm, OBJPROP_COLOR,      InpNeutralColor);
                ObjectSetInteger(m_chart, nm, OBJPROP_STYLE,      STYLE_DASH);
                ObjectSetInteger(m_chart, nm, OBJPROP_WIDTH,      1);
                ObjectSetInteger(m_chart, nm, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(m_chart, nm, OBJPROP_HIDDEN,     true);
                ObjectSetInteger(m_chart, nm, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
            }
        }

        // Regression trend line through HVP nodes
        {
            string nm = reg_nm();
            ObjectDelete(m_chart, nm);
            if(ObjectCreate(m_chart, nm, OBJ_TREND, 0, 0, 0.0, 0, 0.0))
            {
                ObjectSetInteger(m_chart, nm, OBJPROP_COLOR,      APEX_PNL_COLOR_WARNING);
                ObjectSetInteger(m_chart, nm, OBJPROP_STYLE,      STYLE_DASHDOT);
                ObjectSetInteger(m_chart, nm, OBJPROP_WIDTH,      2);
                ObjectSetInteger(m_chart, nm, OBJPROP_RAY_RIGHT,  false);
                ObjectSetInteger(m_chart, nm, OBJPROP_RAY_LEFT,   false);
                ObjectSetInteger(m_chart, nm, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(m_chart, nm, OBJPROP_HIDDEN,     true);
                ObjectSetInteger(m_chart, nm, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
            }
        }

        m_initialized = true;
        return true;
    }

    void SetWindowManager(CWindowManager *wm) { m_wm = wm; }

    //--- Call on each bar close (via OnTick bar-change detection or EVENT_NEW_BAR).
    void OnBarClose()
    {
        if(!m_initialized || !InpShowHVPLines || m_wm == NULL) return;

        CVolumeProfile *vp = m_wm.GetVolumeProfile();
        if(vp == NULL || !vp.IsReady()) return;

        //--- HVP lines
        VPNode hvps[];
        int n = vp.GetHVPs(hvps);
        n = MathMin(n, APEX_HVP_MAX_LINES);

        // Find max HVP volume for normalising color intensity
        long max_vol = 1;
        for(int i = 0; i < n; i++)
            if(hvps[i].volume > max_vol) max_vol = hvps[i].volume;

        for(int i = 0; i < n; i++)
        {
            string nm    = hvp_nm(i);
            double frac  = (double)hvps[i].volume / (double)max_vol;
            color  clr   = hvp_volume_color(frac);
            ObjectSetDouble (m_chart, nm, OBJPROP_PRICE, hvps[i].price);
            ObjectSetInteger(m_chart, nm, OBJPROP_COLOR, clr);
            ObjectSetInteger(m_chart, nm, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        }
        // Hide unused slots
        for(int i = n; i < m_active_lines; i++)
            ObjectSetInteger(m_chart, hvp_nm(i), OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        m_active_lines = n;

        //--- POC line
        VPNode poc = vp.GetPOC();
        if(poc.price > 0.0)
        {
            ObjectSetDouble (m_chart, poc_nm(), OBJPROP_PRICE, poc.price);
            ObjectSetInteger(m_chart, poc_nm(), OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        }

        //--- Value area lines
        double va_h = vp.GetValueAreaHigh();
        double va_l = vp.GetValueAreaLow();
        if(va_h > 0.0 && va_l > 0.0)
        {
            ObjectSetDouble (m_chart, va_hi_nm(), OBJPROP_PRICE, va_h);
            ObjectSetDouble (m_chart, va_lo_nm(), OBJPROP_PRICE, va_l);
            ObjectSetInteger(m_chart, va_hi_nm(), OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            ObjectSetInteger(m_chart, va_lo_nm(), OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        }

        //--- Regression trend line through HVP prices
        if(n >= 2)
            update_regression_line(hvps, n);
        else
            ObjectSetInteger(m_chart, reg_nm(), OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);

        ChartRedraw(m_chart);
    }

private:
    //--- Linear regression of HVP prices (Y) vs node index (X).
    //    Maps X=0 → window_start_time, X=n-1 → current time.
    void update_regression_line(const VPNode &hvps[], int n)
    {
        // Compute weighted regression: weight = hvp volume (higher vol = more influence)
        double sum_w  = 0.0, sum_wx = 0.0, sum_wy  = 0.0;
        double sum_wxx = 0.0, sum_wxy = 0.0;
        for(int i = 0; i < n; i++)
        {
            double w = (double)hvps[i].volume;
            double x = (double)i;
            double y = hvps[i].price;
            sum_w   += w;
            sum_wx  += w * x;
            sum_wy  += w * y;
            sum_wxx += w * x * x;
            sum_wxy += w * x * y;
        }
        double denom = sum_w * sum_wxx - sum_wx * sum_wx;
        if(MathAbs(denom) < 1e-20) return;
        double slope     = (sum_w * sum_wxy - sum_wx * sum_wy) / denom;
        double intercept = (sum_wy - slope * sum_wx) / sum_w;

        double y_start = intercept;
        double y_end   = intercept + slope * (n - 1);

        // Time span: oldest bar in window → current projected bar end
        ApexCandle oldest = m_wm.GetCandle(m_wm.WindowCount() - 1);
        datetime   t_start = (oldest.open_time > 0) ? oldest.open_time
                             : iTime(Symbol(), InpTimeframe, m_wm.WindowCount() - 1);
        datetime   t_end   = iTime(Symbol(), InpTimeframe, 0) + PeriodSeconds(InpTimeframe);

        ObjectSetInteger(m_chart, reg_nm(), OBJPROP_TIME,  0, t_start);
        ObjectSetDouble (m_chart, reg_nm(), OBJPROP_PRICE, 0, y_start);
        ObjectSetInteger(m_chart, reg_nm(), OBJPROP_TIME,  1, t_end);
        ObjectSetDouble (m_chart, reg_nm(), OBJPROP_PRICE, 1, y_end);
        ObjectSetInteger(m_chart, reg_nm(), OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    }

public:
    void Deinitialize()
    {
        if(!m_initialized) return;
        for(int i = 0; i < APEX_HVP_MAX_LINES; i++) ObjectDelete(m_chart, hvp_nm(i));
        ObjectDelete(m_chart, poc_nm());
        ObjectDelete(m_chart, va_hi_nm());
        ObjectDelete(m_chart, va_lo_nm());
        ObjectDelete(m_chart, reg_nm());
        m_initialized = false;
    }
};
