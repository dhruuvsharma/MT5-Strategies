//+------------------------------------------------------------------+
//| AbsorptionSignal.mqh — APEX_SCALPER                              |
//| Absorption score = volume / price range per candle.             |
//| High absorption at HVP/key level → strong signal.              |
//| High absorption away from key level → weak signal (max ±1.0). |
//+------------------------------------------------------------------+

#include "SignalBase.mqh"
#include "../Core/Inputs.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Data/WindowManager.mqh"

class CAbsorptionSignal : public CSignalBase
{
private:
    CWindowManager *m_wm;
    double          m_point;

    // Raw absorption score for one candle
    double absorption(const ApexCandle &c) const
    {
        double range = MathMax(c.high - c.low, m_point * 0.1);
        return (double)c.volume / range;
    }

    // Is `price` within `buffer_points` of any HVP?
    bool near_hvp(double price, double buffer_pts) const
    {
        CVolumeProfile *vp = m_wm.GetVolumeProfile();
        if(vp == NULL) return false;
        VPNode hvps[];
        int n = vp.GetHVPs(hvps);
        double buffer = buffer_pts * m_point;
        for(int i = 0; i < n; i++)
            if(MathAbs(hvps[i].price - price) <= buffer) return true;
        return false;
    }

public:
    bool Initialize(CWindowManager *wm)
    {
        if(wm == NULL) return false;
        m_wm   = wm;
        m_point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        if(m_point <= 0.0) m_point = 0.00001;
        return true;
    }

    virtual SignalResult Calculate() override
    {
        SignalResult r;
        if(!IsReady()) { invalid_result(r, Name(), "window not ready"); return r; }

        ApexCandle window[];
        int n = m_wm.GetWindow(window);
        int lb = MathMin(InpAbsorptionLookback, n);
        if(lb == 0) { invalid_result(r, Name(), "no candles"); return r; }

        // Gather absorption scores for qualifying candles in the full window
        double abs_scores[];
        ArrayResize(abs_scores, n);
        int abs_n = 0;
        for(int i = 0; i < n; i++)
            if(window[i].volume >= (long)InpAbsorptionMinVolume)
                abs_scores[abs_n++] = absorption(window[i]);

        if(abs_n < 2) { invalid_result(r, Name(), "insufficient volume candles"); return r; }

        double mean = RollingMean(abs_scores, abs_n);
        double sd   = RollingStdDev(abs_scores, abs_n, mean);

        // Evaluate the lookback window for high-absorption events
        double best_score = 0.0;
        double best_conf  = 0.0;
        double key_buf    = InpSLBufferPoints * 2.0;

        for(int i = 0; i < lb; i++)
        {
            if(window[i].volume < (long)InpAbsorptionMinVolume) continue;

            double abs_z = ZScore(absorption(window[i]), mean, sd);
            if(abs_z < 1.0) continue;  // not a notable absorption candle

            // Determine if at a key level
            double mid_price  = (window[i].high + window[i].low) * 0.5;
            bool   at_key     = near_hvp(mid_price, key_buf);
            double max_score  = at_key ? 3.0 : 1.0;

            double scaled = Clamp(abs_z / (InpDeltaZScoreThreshold) * max_score,
                                  0.0, max_score);
            double conf   = Clamp(abs_z / (InpDeltaZScoreThreshold * 2.0), 0.0, 1.0);

            // Direction: high absorption at resistance = bearish, at support = bullish
            // Proxy: if close near low of the absorption candle → bearish absorption
            double close_pct = (window[i].close - window[i].low)
                               / MathMax(window[i].high - window[i].low, m_point);
            double dir_score = (close_pct < 0.4) ? -scaled : scaled;

            if(MathAbs(dir_score) > MathAbs(best_score))
            {
                best_score = dir_score;
                best_conf  = conf;
            }
        }

        if(best_score == 0.0) { make_result(r, Name(), 0.0, 0.0, "no absorption event"); return r; }

        string note = StringFormat("abs_score:%.2f conf:%.2f mean_abs:%.1f",
                                   best_score, best_conf, mean);
        make_result(r, Name(), best_score, best_conf, note);
        return r;
    }

    virtual string  Name()    override { return "ABSORPTION";        }
    virtual double  Weight()  override { return InpWeightAbsorption; }
    virtual bool    IsReady() override { return m_wm != NULL && m_wm.WindowCount() >= InpWindowSize; }
};
