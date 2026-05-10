//+------------------------------------------------------------------+
//| ConflictFilter.mqh — APEX_SCALPER                                |
//| Detects high-weight signal conflicts (delta vs VPIN).           |
//| Sets trade_allowed=false if conflict found near threshold.      |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"

//+------------------------------------------------------------------+
//| CConflictFilter                                                  |
//+------------------------------------------------------------------+
class CConflictFilter
{
private:
    // Find a signal result by name in the components array
    bool find_signal(const CompositeResult &cr, const string &name,
                     SignalResult &out) const
    {
        for(int i = 0; i < cr.component_count; i++)
        {
            if(cr.components[i].signal_name == name)
            {
                out = cr.components[i];
                return true;
            }
        }
        return false;
    }

public:
    // Evaluate the composite result in-place; sets conflict_flag and trade_allowed
    void Evaluate(CompositeResult &cr)
    {
        cr.conflict_flag = false;

        if(!InpEnableConflictFilter)
        {
            cr.trade_allowed = (cr.signals_agree >= InpMinSignalsAgree);
            return;
        }

        // Check primary conflict: Delta vs VPIN
        SignalResult delta_r, vpin_r;
        bool has_delta = find_signal(cr, "DELTA", delta_r);
        bool has_vpin  = find_signal(cr, "VPIN",  vpin_r);

        if(has_delta && has_vpin &&
           delta_r.is_valid && vpin_r.is_valid &&
           MathAbs(delta_r.score) > 0.5 &&
           MathAbs(vpin_r.score)  > 0.5 &&
           delta_r.direction != vpin_r.direction &&
           delta_r.direction != 0 && vpin_r.direction != 0)
        {
            // Conflict present: only block trade if composite score is close to threshold
            double abs_score = MathAbs(cr.score);
            if(abs_score < InpCompositeThreshold + InpConflictScoreBand)
            {
                cr.conflict_flag = true;
                g_EventBus.Publish(EVENT_CONFLICT_DETECTED);
            }
        }

        // Signal agreement check (always applied regardless of conflict)
        bool agreement_ok = (cr.signals_agree >= InpMinSignalsAgree);

        cr.trade_allowed = agreement_ok && !cr.conflict_flag;
    }
};
