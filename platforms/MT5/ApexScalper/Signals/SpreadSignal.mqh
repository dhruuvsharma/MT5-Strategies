//+------------------------------------------------------------------+
//| SpreadSignal.mqh — APEX_SCALPER                                  |
//| Supporting signal (not in core 8 weighted composite).          |
//| Tracks spread dynamics vs rolling mean across OB snapshots.    |
//| Widening with direction = informed flow.                        |
//| Widening without direction = MM pulling liquidity (flag only). |
//+------------------------------------------------------------------+

#include "SignalBase.mqh"
#include "../Core/Inputs.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Data/OrderBookSnapshot.mqh"

class CSpreadSignal : public CSignalBase
{
private:
    COrderBookSnapshot *m_ob;
    bool                m_widening_alert;  // set if spread widens without direction

public:
    bool Initialize(COrderBookSnapshot *ob)
    {
        if(ob == NULL) return false;
        m_ob             = ob;
        m_widening_alert = false;
        return true;
    }

    // True if last Calculate() detected spread widening without directional move
    bool IsWideningAlert() const { return m_widening_alert; }

    virtual SignalResult Calculate() override
    {
        SignalResult r;
        m_widening_alert = false;
        if(!IsReady()) { invalid_result(r, Name(), "no snapshot history"); return r; }

        int n_hist = MathMin(InpSpreadRollingPeriod, m_ob.SnapshotCount());
        OrderBookSnapshot snaps[];
        int n = m_ob.GetSnapshotHistory(n_hist, snaps);
        if(n < 3) { invalid_result(r, Name(), "insufficient snapshots"); return r; }

        // Rolling mean and std dev of spread
        double spreads[];
        ArrayResize(spreads, n);
        for(int i = 0; i < n; i++) spreads[i] = snaps[i].spread;
        double mean = RollingMean(spreads, n);
        double sd   = RollingStdDev(spreads, n, mean);
        double cur  = snaps[0].spread;

        // OBI as directional proxy
        double obi_momentum = m_ob.ComputeOBIMomentum(5);
        bool   directional  = MathAbs(obi_momentum) > 0.001;

        double score = 0.0;
        double conf  = 0.3;

        if(cur > mean * InpSpreadWideningFactor)
        {
            // Spread widening
            if(directional)
            {
                // Informed flow in direction of OBI momentum
                score = (obi_momentum > 0) ? 1.5 : -1.5;
                conf  = 0.6;
            }
            else
            {
                // MM pulling liquidity — uncertainty, set alert flag
                m_widening_alert = true;
                score = 0.0;
                conf  = 0.1;
            }
        }
        else if(cur < mean * 0.8 && directional)
        {
            // Spread compressing during directional move → fade signal
            score = (obi_momentum > 0) ? -1.0 : 1.0;
            conf  = 0.4;
        }

        string note = StringFormat("spread:%.1f mean:%.1f factor:%.1f dir:%s alert:%s",
                                   cur, mean, cur / MathMax(mean, 0.001),
                                   directional ? "Y" : "N",
                                   m_widening_alert ? "Y" : "N");
        make_result(r, Name(), score, conf, note);
        return r;
    }

    virtual string  Name()    override { return "SPREAD";  }
    virtual double  Weight()  override { return 0.0;       }  // supporting signal, not in core 8
    virtual bool    IsReady() override
    {
        return m_ob != NULL && m_ob.IsReady() && m_ob.SnapshotCount() >= 3;
    }
};
