//+------------------------------------------------------------------+
//| NewsFilter.mqh — APEX_SCALPER                                    |
//| Blackout window around high-impact news events.                 |
//| Uses MT5 Economic Calendar API (CalendarValueHistory).          |
//| Updates g_NewsBlackout in State.mqh.                           |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"

#define NEWS_CHECK_INTERVAL_SECS 60    // re-check calendar every 60s

class CNewsFilter
{
private:
    datetime m_last_check;         // last time we polled the calendar

    // Scan the economic calendar for high-impact events within the blackout window
    bool scan_calendar() const
    {
        if(!InpEnableNewsFilter) return false;

        datetime now   = TimeCurrent();
        datetime from  = now - InpNewsMinutesBefore * 60;
        datetime to    = now + InpNewsMinutesAfter   * 60;

        MqlCalendarValue values[];
        // Get all calendar values in window (all countries)
        if(CalendarValueHistory(values, from, to) <= 0) return false;

        for(int i = 0; i < ArraySize(values); i++)
        {
            MqlCalendarEvent event;
            if(!CalendarEventById(values[i].event_id, event)) continue;

            // Only block on HIGH impact events
            if(event.importance == CALENDAR_IMPORTANCE_HIGH)
                return true;
        }
        return false;
    }

public:
    bool Initialize()
    {
        m_last_check    = 0;
        g_NewsBlackout  = false;
        return true;
    }

    // Call every tick; throttles calendar API to CHECK_INTERVAL_SECS
    void OnTick()
    {
        if(!InpEnableNewsFilter)
        {
            g_NewsBlackout = false;
            return;
        }

        datetime now = TimeCurrent();
        if(now - m_last_check < NEWS_CHECK_INTERVAL_SECS) return;
        m_last_check   = now;
        g_NewsBlackout = scan_calendar();
    }

    // Returns true if it is safe to trade (no high-impact news in the blackout window)
    bool IsAllowed() const { return !g_NewsBlackout; }

    // Returns true if we are currently in a news blackout
    bool IsBlackout() const { return g_NewsBlackout; }
};
