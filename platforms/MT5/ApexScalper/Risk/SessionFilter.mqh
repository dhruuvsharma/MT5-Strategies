//+------------------------------------------------------------------+
//| SessionFilter.mqh — APEX_SCALPER                                 |
//| Gates trading to allowed sessions using TimeUtils.              |
//| Updates g_CurrentSession in State.mqh each tick.               |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"
#include "../Utils/TimeUtils.mqh"

class CSessionFilter
{
public:
    bool Initialize() { return true; }

    // Call every tick to keep g_CurrentSession current
    void OnTick()
    {
        g_CurrentSession = ClassifySession(TimeCurrent(),
                                           InpAsianStart,  InpAsianEnd,
                                           InpLondonStart, InpLondonEnd,
                                           InpNewYorkStart, InpNewYorkEnd);
    }

    // Returns true if trading is permitted in the current session
    bool IsAllowed() const
    {
        switch(g_CurrentSession)
        {
            case SESSION_ASIAN:             return InpTradeAsian;
            case SESSION_LONDON:            return InpTradeLondon;
            case SESSION_NEW_YORK:          return InpTradeNewYork;
            case SESSION_LONDON_NY_OVERLAP: return InpTradeLondonNY;
            default:                        return false;
        }
    }

    // Human-readable current session name (for dashboard)
    string GetSessionName() const { return SessionToString(g_CurrentSession); }
};
