//+------------------------------------------------------------------+
//| HVPSignal.mqh — APEX_SCALPER                                     |
//| Weighted linear regression through HVP nodes across the window. |
//| Score = f(slope); Confidence = R².                              |
//| Recency weight = 1.0 / (bars_since_peak + 1).                  |
//+------------------------------------------------------------------+

#include "SignalBase.mqh"
#include "../Core/Inputs.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Data/WindowManager.mqh"

class CHVPSignal : public CSignalBase
{
private:
    CWindowManager *m_wm;

    // Find the bar index (0=newest) at which each HVP price had its peak volume
    int find_peak_bar(double hvp_price, const FootprintCandle &fps[], int n) const
    {
        double tick_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
        if(tick_size <= 0.0) tick_size = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        double tol = tick_size * InpFootprintTickSize * 0.5;

        long   best_vol  = 0;
        int    best_bar  = 0;
        for(int b = 0; b < n; b++)
        {
            for(int r = 0; r < fps[b].row_count; r++)
            {
                if(MathAbs(fps[b].rows[r].price - hvp_price) < tol)
                {
                    long vol = fps[b].rows[r].bid_vol + fps[b].rows[r].ask_vol;
                    if(vol > best_vol) { best_vol = vol; best_bar = b; }
                    break;
                }
            }
        }
        return best_bar;  // 0 = most recent bar
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

        CVolumeProfile *vp = m_wm.GetVolumeProfile();
        if(vp == NULL || !vp.IsReady())
        { invalid_result(r, Name(), "VP not ready"); return r; }

        VPNode hvps[];
        int nhvp = vp.GetHVPs(hvps);
        if(nhvp < InpHVPMinNodes)
        {
            invalid_result(r, Name(), StringFormat("need %d HVPs, have %d", InpHVPMinNodes, nhvp));
            return r;
        }

        FootprintCandle fps[];
        int nfp = m_wm.GetFootprints(fps);

        // Build regression arrays: X = bar_index (0=oldest), Y = price, W = vol*recency
        double xs[], ys[], ws[];
        ArrayResize(xs, nhvp);
        ArrayResize(ys, nhvp);
        ArrayResize(ws, nhvp);

        for(int i = 0; i < nhvp; i++)
        {
            int bar_from_newest = find_peak_bar(hvps[i].price, fps, nfp);
            int bar_index       = nfp - 1 - bar_from_newest;  // 0=oldest
            double recency_w    = 1.0 / (bar_from_newest + 1.0);

            xs[i] = (double)bar_index;
            ys[i] = hvps[i].price;
            ws[i] = (double)hvps[i].volume * recency_w;
        }

        double slope = LinearRegressionSlopeWeighted(xs, ys, ws, nhvp);
        double r2    = LinearRegressionR2(xs, ys, nhvp);

        double score = 0.0;
        if(MathAbs(slope) >= InpHVPSlopeThreshold)
            score = Clamp(slope / (InpHVPSlopeThreshold * 2.0) * 3.0,
                          APEX_SCORE_MIN, APEX_SCORE_MAX);
        // Confidence = R²
        double conf = Clamp(r2, 0.0, 1.0);
        // Scale score by R²
        score *= conf;

        string note = StringFormat("slope:%.5f R2:%.3f nodes:%d", slope, r2, nhvp);
        make_result(r, Name(), score, conf, note);
        return r;
    }

    virtual string  Name()    override { return "HVP";        }
    virtual double  Weight()  override { return InpWeightHVP; }
    virtual bool    IsReady() override { return m_wm != NULL && m_wm.IsWindowReady(); }
};
