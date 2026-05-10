//+------------------------------------------------------------------+
//| SignalDecayManager.mqh — APEX_SCALPER                            |
//| Tracks generated_at timestamps per signal name.                 |
//| IsValid() returns false when age_ms exceeds the signal's TTL.  |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"

#define DECAY_MANAGER_MAX_SIGNALS 12

//+------------------------------------------------------------------+
//| CSignalDecayManager                                              |
//+------------------------------------------------------------------+
class CSignalDecayManager
{
private:
    string   m_names[DECAY_MANAGER_MAX_SIGNALS];
    datetime m_generated_at[DECAY_MANAGER_MAX_SIGNALS];
    int      m_ttl_ms[DECAY_MANAGER_MAX_SIGNALS];       // TTL in milliseconds
    int      m_count;

    // Return the TTL (ms) for a given signal name from input parameters
    int ttl_for(const string &name) const
    {
        if(name == "DELTA")      return InpTTL_Delta;
        if(name == "VPIN")       return InpTTL_VPIN;
        if(name == "OBI_SHALLOW") return InpTTL_OBI;
        if(name == "OBI_DEEP")   return InpTTL_OBI;
        if(name == "FOOTPRINT")  return InpTTL_Footprint;
        if(name == "ABSORPTION") return InpTTL_Absorption;
        if(name == "HVP")        return InpTTL_HVP;
        if(name == "TAPE_SPEED") return InpTTL_TapeSpeed;
        if(name == "VPOC")       return InpTTL_VPOC;
        if(name == "SPREAD")     return InpTTL_VPOC;   // no dedicated param; reuse VPOC
        return 5000;  // default 5s for unknown signals
    }

    // Find the slot index for a signal name; returns -1 if not registered
    int find_slot(const string &name) const
    {
        for(int i = 0; i < m_count; i++)
            if(m_names[i] == name) return i;
        return -1;
    }

    // Find or create a slot for a signal name
    int get_or_create_slot(const string &name)
    {
        int idx = find_slot(name);
        if(idx >= 0) return idx;
        if(m_count >= DECAY_MANAGER_MAX_SIGNALS) return -1;
        m_names[m_count]        = name;
        m_generated_at[m_count] = 0;
        m_ttl_ms[m_count]       = ttl_for(name);
        return m_count++;
    }

public:
    bool Initialize()
    {
        m_count = 0;
        return true;
    }

    // Register or refresh a signal's timestamp from a SignalResult
    void Update(const SignalResult &r)
    {
        if(!r.is_valid) return;
        int idx = get_or_create_slot(r.signal_name);
        if(idx < 0) return;
        m_generated_at[idx] = r.generated_at;
        m_ttl_ms[idx]       = ttl_for(r.signal_name);
    }

    // Returns true if the named signal's age is within its TTL
    bool IsValid(const string &name) const
    {
        int idx = find_slot(name);
        if(idx < 0) return false;
        int age_ms = (int)((TimeCurrent() - m_generated_at[idx]) * 1000);
        return age_ms < m_ttl_ms[idx];
    }

    // Returns age in milliseconds for a named signal (0 if not registered)
    int GetAgeMS(const string &name) const
    {
        int idx = find_slot(name);
        if(idx < 0) return 999999;
        return (int)((TimeCurrent() - m_generated_at[idx]) * 1000);
    }

    // Returns the configured TTL in ms for a named signal
    int GetTTL(const string &name) const
    {
        int idx = find_slot(name);
        if(idx < 0) return ttl_for(name);
        return m_ttl_ms[idx];
    }
};
