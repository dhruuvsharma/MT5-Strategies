//+------------------------------------------------------------------+
//| DeltaSignal.mqh — APEX_SCALPER                                   |
//| Three sub-components:                                            |
//|   A. Cumulative delta Z-score (weight 0.4)                      |
//|   B. Delta acceleration (weight 0.3)                            |
//|   C. Delta divergence (weight 0.3)                              |
//+------------------------------------------------------------------+

#include "SignalBase.mqh"
#include "../Core/Inputs.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Data/WindowManager.mqh"

class CDeltaSignal : public CSignalBase
{
private:
    CWindowManager *m_wm;

    // Sub-component A: Z-score of current candle's tick_delta vs window
    double calc_delta_zscore(const ApexCandle &window[], int n,
                             double &conf_out) const
    {
        if(n < 3) { conf_out = 0.0; return 0.0; }
        double deltas[];
        ArrayResize(deltas, n);
        for(int i = 0; i < n; i++) deltas[i] = (double)window[i].tick_delta;
        double mean = RollingMean(deltas, n);
        double sd   = RollingStdDev(deltas, n, mean);
        double z    = ZScore(deltas[0], mean, sd);
        conf_out    = Clamp(MathAbs(z) / (InpDeltaZScoreThreshold * 2.0), 0.0, 1.0);
        return ScoreFromZScore(z, InpDeltaZScoreThreshold);
    }

    // Sub-component B: delta acceleration (delta[0] - delta[period])
    double calc_acceleration(const ApexCandle &window[], int n,
                             double &conf_out) const
    {
        int period = InpDeltaAccelPeriod;
        if(n <= period) { conf_out = 0.0; return 0.0; }
        double accels[];
        int accel_n = n - period;
        ArrayResize(accels, accel_n);
        for(int i = 0; i < accel_n; i++)
            accels[i] = (double)(window[i].tick_delta - window[i + period].tick_delta);
        double mean = RollingMean(accels, accel_n);
        double sd   = RollingStdDev(accels, accel_n, mean);
        double z    = ZScore(accels[0], mean, sd);
        conf_out    = Clamp(MathAbs(z) / (InpDeltaZScoreThreshold * 2.0), 0.0, 1.0);
        return ScoreFromZScore(z, InpDeltaZScoreThreshold);
    }

    // Sub-component C: delta divergence
    double calc_divergence(const ApexCandle &window[], int n,
                           double base_conf, double &conf_out) const
    {
        if(n < 4) { conf_out = base_conf; return 0.0; }
        conf_out = base_conf;

        // Find window high/low (look at the oldest InpWindowSize bars)
        double win_high = window[0].high, win_low = window[0].low;
        for(int i = 1; i < n; i++)
        {
            if(window[i].high > win_high) win_high = window[i].high;
            if(window[i].low  < win_low)  win_low  = window[i].low;
        }
        double cur_high = window[0].high;
        double cur_low  = window[0].low;

        // Cumulative delta of last 3 completed candles
        long recent_delta = window[0].tick_delta + window[1].tick_delta + window[2].tick_delta;

        double score = 0.0;
        // Bearish divergence: price at window high but delta turning negative
        if(MathAbs(cur_high - win_high) < SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 2.0
           && recent_delta < 0)
            score = -2.0;
        // Bullish divergence: price at window low but delta turning positive
        else if(MathAbs(cur_low - win_low) < SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 2.0
                && recent_delta > 0)
            score = 2.0;

        // Reduce confidence if delta efficiency is too low
        if(window[0].delta_efficiency < InpDeltaEfficiencyMin)
            conf_out = MathMax(0.0, conf_out - 0.4);

        return score;
    }

public:
    bool Initialize(CWindowManager *wm)
    {
        if(wm == NULL) return false;
        m_wm = wm;
        return true;
    }

    virtual SignalResult Calculate() override
    {
        SignalResult r;
        if(!IsReady()) { invalid_result(r, Name(), "window not ready"); return r; }

        ApexCandle window[];
        int n = m_wm.GetWindow(window);
        if(n < InpDeltaAccelPeriod + 1)
        { invalid_result(r, Name(), "insufficient candles"); return r; }

        double conf_a = 0.0, conf_b = 0.0, conf_c = 0.0;
        double score_a = calc_delta_zscore(window, n, conf_a);
        double score_b = calc_acceleration(window, n, conf_b);
        double score_c = calc_divergence(window, n, (conf_a + conf_b) * 0.5, conf_c);

        double final_score = score_a * 0.4 + score_b * 0.3 + score_c * 0.3;
        double final_conf  = conf_a  * 0.4 + conf_b  * 0.3 + conf_c  * 0.3;

        string note = StringFormat("A:%.2f B:%.2f C:%.2f eff:%.2f",
                                   score_a, score_b, score_c,
                                   window[0].delta_efficiency);
        make_result(r, Name(), final_score, final_conf, note);
        return r;
    }

    virtual string  Name()    override { return "DELTA";        }
    virtual double  Weight()  override { return InpWeightDelta; }
    virtual bool    IsReady() override { return m_wm != NULL && m_wm.WindowCount() >= InpWindowSize; }
};
