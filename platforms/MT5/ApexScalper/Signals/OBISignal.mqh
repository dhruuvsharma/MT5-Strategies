//+------------------------------------------------------------------+
//| OBISignal.mqh — APEX_SCALPER                                     |
//| Two components exposed separately to ScoringEngine:            |
//|   CalculateShallow() — uses obi_l3, weight InpWeightOBI        |
//|   CalculateDeep()    — uses weighted_obi, weight InpWeightOBIDeep|
//+------------------------------------------------------------------+

#include "SignalBase.mqh"
#include "../Core/Inputs.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Data/OrderBookSnapshot.mqh"

class COBISignal : public CSignalBase
{
private:
    COrderBookSnapshot *m_ob;

public:
    bool Initialize(COrderBookSnapshot *ob)
    {
        if(ob == NULL) return false;
        m_ob = ob;
        return true;
    }

    // Shallow OBI: uses obi_l3, OBI momentum, spoof reduction
    SignalResult CalculateShallow()
    {
        SignalResult r;
        if((bool)MQLInfoInteger(MQL_TESTER)) { invalid_result(r, "OBI_SHALLOW", "TESTER: N/A"); return r; }
        if(!IsReady()) { invalid_result(r, "OBI_SHALLOW", "no snapshot data"); return r; }

        OrderBookSnapshot snap = m_ob.GetLatestSnapshot();
        double obi      = snap.obi_l3;
        double momentum = m_ob.ComputeOBIMomentum(InpOBIMomentumPeriod);
        double score    = Clamp(obi * 3.0, APEX_SCORE_MIN, APEX_SCORE_MAX);
        double conf     = MathAbs(obi);  // raw OBI as proxy for confidence

        // Scale by momentum direction
        if((momentum > 0 && score > 0) || (momentum < 0 && score < 0))
            score = Clamp(score * 1.0 + MathSign(score) * 0.5,
                          APEX_SCORE_MIN, APEX_SCORE_MAX);

        // Spoof penalty: reduce confidence if large level may be spoofed
        if(snap.spoof_suspected) conf = MathMax(0.0, conf - 0.5);

        string note = StringFormat("OBI_L3:%.3f mom:%.4f spoof:%s",
                                   obi, momentum, snap.spoof_suspected ? "Y" : "N");
        make_result(r, "OBI_SHALLOW", score, conf, note);
        return r;
    }

    // Deep OBI: uses weighted_obi across InpOBILevelsDeep levels
    SignalResult CalculateDeep()
    {
        SignalResult r;
        if((bool)MQLInfoInteger(MQL_TESTER)) { invalid_result(r, "OBI_DEEP", "TESTER: N/A"); return r; }
        if(!IsReady()) { invalid_result(r, "OBI_DEEP", "no snapshot data"); return r; }

        OrderBookSnapshot snap = m_ob.GetLatestSnapshot();
        double wobi  = snap.weighted_obi;
        double score = Clamp(wobi * 3.0, APEX_SCORE_MIN, APEX_SCORE_MAX);
        double conf  = MathAbs(wobi);

        string note = StringFormat("WOBI:%.3f bid_tot:%.0f ask_tot:%.0f",
                                   wobi, snap.total_bid_vol, snap.total_ask_vol);
        make_result(r, "OBI_DEEP", score, conf, note);
        return r;
    }

    // Default Calculate() returns shallow result (satisfies interface)
    virtual SignalResult Calculate() override { return CalculateShallow(); }

    virtual string  Name()    override { return "OBI";        }
    virtual double  Weight()  override { return InpWeightOBI; }
    virtual bool    IsReady() override { return m_ob != NULL && m_ob.IsReady(); }

private:
    double MathSign(double v) const { return (v > 0) ? 1.0 : (v < 0) ? -1.0 : 0.0; }
};
