//+------------------------------------------------------------------+
//| SpreadFilter.mqh — APEX_SCALPER                                  |
//| Blocks new entries when current spread exceeds InpMaxSpreadPoints|
//| Updates g_CurrentSpread in State.mqh each tick.                |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"

class CSpreadFilter
{
private:
    double m_point;

public:
    bool Initialize()
    {
        m_point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        if(m_point <= 0.0) m_point = 0.00001;

        // Startup spread check — warn if current spread already exceeds limit
        MqlTick tick;
        if(SymbolInfoTick(Symbol(), tick))
        {
            double cur_spr = (tick.ask - tick.bid) / m_point;
            if(cur_spr > InpMaxSpreadPoints)
                PrintFormat("APEX SpreadFilter WARNING: current spread %.1f pts exceeds limit %.1f pts — trades BLOCKED",
                            cur_spr, InpMaxSpreadPoints);
            else
                PrintFormat("APEX SpreadFilter: spread OK %.1f pts (limit %.1f pts)",
                            cur_spr, InpMaxSpreadPoints);
        }
        return true;
    }

    // Call every tick to keep g_CurrentSpread current
    void OnTick()
    {
        MqlTick tick;
        if(SymbolInfoTick(Symbol(), tick))
            g_CurrentSpread = (tick.ask - tick.bid) / m_point;
    }

    // Returns true if current spread is within the allowed maximum
    bool IsOK() const { return g_CurrentSpread <= InpMaxSpreadPoints; }

    // Returns current spread in points
    double GetSpreadPoints() const { return g_CurrentSpread; }
};
