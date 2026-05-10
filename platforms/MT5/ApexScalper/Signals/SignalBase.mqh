//+------------------------------------------------------------------+
//| SignalBase.mqh — APEX_SCALPER                                    |
//| Abstract base class for all signal modules.                     |
//| All signals return SignalResult with score [-3, +3].            |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| CSignalBase — abstract interface every signal must implement    |
//+------------------------------------------------------------------+
class CSignalBase
{
public:
    // Compute and return the signal result; call every tick or bar
    virtual SignalResult Calculate() = 0;

    // Human-readable signal name (used in logs and dashboard)
    virtual string       Name()      = 0;

    // Configured weight for this signal in the composite score
    virtual double       Weight()    = 0;

    // True once enough data exists to produce a valid signal
    virtual bool         IsReady()   = 0;

protected:
    // Helper: populate out as an invalid result with a reason note
    void invalid_result(SignalResult &out, const string name, const string note) const
    {
        ZeroMemory(out);
        out.signal_name  = name;
        out.is_valid     = false;
        out.generated_at = TimeCurrent();
        out.debug_note   = note;
    }

    // Helper: populate out as a valid result
    void make_result(SignalResult &out, const string name, double score,
                     double confidence, const string note = "") const
    {
        out.signal_name  = name;
        out.score        = Clamp(score, APEX_SCORE_MIN, APEX_SCORE_MAX);
        out.confidence   = Clamp(confidence, 0.0, 1.0);
        out.direction    = (out.score > 0.05) ? 1 : (out.score < -0.05) ? -1 : 0;
        out.is_valid     = true;
        out.generated_at = TimeCurrent();
        out.debug_note   = note;
    }
};
