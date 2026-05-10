//+------------------------------------------------------------------+
//| VPOCSignal.mqh — APEX_SCALPER                                    |
//| VPOC migration direction and stability over lookback candles.  |
//| Stable VPOC (low std dev) → anchor level flag, score = 0.     |
//+------------------------------------------------------------------+

#include "SignalBase.mqh"
#include "../Core/Inputs.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Data/WindowManager.mqh"

class CVPOCSignal : public CSignalBase
{
private:
    CWindowManager *m_wm;
    bool            m_is_anchor;  // set true when VPOC is stable

public:
    bool Initialize(CWindowManager *wm)
    {
        if(wm == NULL) return false;
        m_wm       = wm;
        m_is_anchor = false;
        return true;
    }

    // True if the last Calculate() identified a stable VPOC anchor level
    bool IsAnchorLevel() const { return m_is_anchor; }

    virtual SignalResult Calculate() override
    {
        SignalResult r;
        m_is_anchor = false;
        if(!IsReady()) { invalid_result(r, Name(), "window not ready"); return r; }

        FootprintCandle fps[];
        int n = m_wm.GetFootprints(fps);
        int lb = MathMin(InpVPOCLookback, n);
        if(lb < 2) { invalid_result(r, Name(), "insufficient footprints"); return r; }

        // Gather per-candle POC prices
        double poc_prices[];
        ArrayResize(poc_prices, lb);
        for(int i = 0; i < lb; i++)
            poc_prices[i] = fps[i].poc_price;

        double tick_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
        if(tick_size <= 0.0) tick_size = SymbolInfoDouble(Symbol(), SYMBOL_POINT);

        // Standard deviation of POC prices
        double mean_poc = RollingMean(poc_prices, lb);
        double sd_poc   = RollingStdDev(poc_prices, lb, mean_poc);

        // Anchor: VPOC is returning to same level repeatedly
        if(sd_poc < tick_size * 1.0)
        {
            m_is_anchor = true;
            make_result(r, Name(), 0.0, 0.0, "VPOC anchor level — mean reversion zone");
            return r;
        }

        // Compute average displacement per candle in ticks
        // poc_prices[0] = newest, poc_prices[lb-1] = oldest
        // Positive displacement = POC moving up
        double total_disp = poc_prices[0] - poc_prices[lb - 1];
        double avg_disp_per_bar = total_disp / (lb - 1);
        double disp_ticks = avg_disp_per_bar / tick_size;

        double score = Clamp(disp_ticks / (InpVPOCMigrationTicks * 2.0) * 3.0,
                             APEX_SCORE_MIN, APEX_SCORE_MAX);
        double conf  = Clamp(MathAbs(disp_ticks) / (InpVPOCMigrationTicks * 2.0),
                             0.0, 1.0);

        string note = StringFormat("disp_ticks:%.1f sd:%.5f lb:%d",
                                   disp_ticks, sd_poc, lb);
        make_result(r, Name(), score, conf, note);
        return r;
    }

    virtual string  Name()    override { return "VPOC";        }
    virtual double  Weight()  override { return 0.0;           }  // informational; scored via VPIN/HVP; TP engine uses anchor flag
    virtual bool    IsReady() override
    {
        return m_wm != NULL && m_wm.IsWindowReady()
               && m_wm.WindowCount() >= InpVPOCLookback;
    }
};
