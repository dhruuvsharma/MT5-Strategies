//+------------------------------------------------------------------+
//| ScoringEngine.mqh — APEX_SCALPER                                 |
//| Weighted composite score from all active signal results.        |
//| Applies regime weight multipliers, TTL validation, normalization.|
//| Calls ConflictFilter to set trade_allowed.                      |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"
#include "SignalDecayManager.mqh"
#include "ConflictFilter.mqh"

#define APEX_WEIGHT_COUNT 8

//+------------------------------------------------------------------+
//| CScoringEngine                                                   |
//+------------------------------------------------------------------+
class CScoringEngine
{
private:
    CSignalDecayManager *m_decay;
    CConflictFilter     *m_conflict;

    // Normalized base weights (set in Initialize(), possibly auto-corrected)
    double m_weights[APEX_WEIGHT_COUNT];

    // Apply regime multipliers to a base weight for a given signal name
    double regime_adjusted_weight(const string &name, double base_w) const
    {
        double mult = 1.0;
        switch(g_CurrentRegime)
        {
            case REGIME_TRENDING_BULL:
            case REGIME_TRENDING_BEAR:
                if(name == "DELTA")      mult = 1.3;
                if(name == "HVP")        mult = 1.2;
                if(name == "OBI_DEEP")   mult = 0.8;
                break;
            case REGIME_RANGING:
                if(name == "OBI_SHALLOW") mult = 1.3;
                if(name == "ABSORPTION")  mult = 1.3;
                if(name == "DELTA")       mult = 0.7;
                break;
            case REGIME_HIGH_VOLATILITY:
                mult = 0.5;  // all signals halved → hard to pass threshold
                break;
            default: break;
        }
        return base_w * mult;
    }

    // Look up the base weight for a signal name
    double base_weight_for(const string &name) const
    {
        if(name == "DELTA")       return m_weights[0];
        if(name == "VPIN")        return m_weights[1];
        if(name == "OBI_SHALLOW") return m_weights[2];
        if(name == "OBI_DEEP")    return m_weights[3];
        if(name == "FOOTPRINT")   return m_weights[4];
        if(name == "HVP")         return m_weights[5];
        if(name == "ABSORPTION")  return m_weights[6];
        if(name == "TAPE_SPEED")  return m_weights[7];
        return 0.0;
    }

public:
    // Initialize with references to decay manager and conflict filter
    bool Initialize(CSignalDecayManager *decay, CConflictFilter *conflict)
    {
        if(decay == NULL || conflict == NULL) return false;
        m_decay    = decay;
        m_conflict = conflict;

        // Load base weights from input parameters
        double raw[] = {
            InpWeightDelta, InpWeightVPIN, InpWeightOBI, InpWeightOBIDeep,
            InpWeightFootprint, InpWeightHVP, InpWeightAbsorption, InpWeightTapeSpeed
        };
        double sum = 0.0;
        for(int i = 0; i < APEX_WEIGHT_COUNT; i++) sum += raw[i];

        if(MathAbs(sum - 1.0) > 0.001)
        {
            PrintFormat("APEX ScoringEngine: weights sum=%.4f, auto-normalizing", sum);
            if(sum < 1e-10) sum = 1.0;
        }
        for(int i = 0; i < APEX_WEIGHT_COUNT; i++)
            m_weights[i] = raw[i] / sum;

        return true;
    }

    // Compute composite result from array of signal results
    CompositeResult Calculate(const SignalResult &signals[], int count)
    {
        CompositeResult cr;
        ZeroMemory(cr);
        cr.timestamp       = TimeCurrent();
        cr.component_count = 0;

        double weighted_sum  = 0.0;
        double active_weight = 0.0;
        int    agree         = 0;
        int    conflict_cnt  = 0;

        // Pass 1: validate TTL, collect active signals
        for(int i = 0; i < count && i < APEX_MAX_SIGNAL_COUNT; i++)
        {
            SignalResult r = signals[i];

            // Refresh decay manager
            m_decay.Update(r);

            // TTL check overrides is_valid
            if(r.is_valid && !m_decay.IsValid(r.signal_name))
                r.is_valid = false;

            cr.components[cr.component_count++] = r;
            if(!r.is_valid) continue;

            double bw      = base_weight_for(r.signal_name);
            double adj_w   = regime_adjusted_weight(r.signal_name, bw);
            double contrib = r.score * adj_w * r.confidence;
            weighted_sum  += contrib;
            active_weight += adj_w;
        }

        // Pass 2: normalize composite score by active weight sum
        if(active_weight > 1e-10)
            cr.score = weighted_sum / active_weight;
        else
            cr.score = 0.0;

        cr.direction    = (cr.score >  0.05) ?  1 :
                          (cr.score < -0.05) ? -1 : 0;

        // Pass 3: count direction agreement (for active signals with |score| > 0.5)
        for(int i = 0; i < cr.component_count; i++)
        {
            if(!cr.components[i].is_valid || MathAbs(cr.components[i].score) < 0.5) continue;
            if(cr.components[i].direction == cr.direction)    agree++;
            else if(cr.components[i].direction != 0)          conflict_cnt++;
        }
        cr.signals_agree    = agree;
        cr.signals_conflict = conflict_cnt;
        cr.confidence       = Clamp(active_weight, 0.0, 1.0);

        // Pass 4: conflict filter sets trade_allowed and conflict_flag
        m_conflict.Evaluate(cr);

        // Update global state
        g_LastComposite = cr;

        return cr;
    }
};
