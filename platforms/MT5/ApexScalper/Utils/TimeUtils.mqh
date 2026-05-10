//+------------------------------------------------------------------+
//| TimeUtils.mqh — APEX_SCALPER                                     |
//| Session time checks and bar index helpers.                       |
//| Never hardcodes GMT offset — uses TimeCurrent()/TimeGMT() diff. |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| ParseTimeString — parses "HH:MM" into seconds since midnight    |
//| Returns -1 on parse failure                                      |
//+------------------------------------------------------------------+
int ParseTimeString(const string &time_str)
{
    string parts[];
    int count = StringSplit(time_str, ':', parts);
    if(count != 2) return -1;
    int h = (int)StringToInteger(parts[0]);
    int m = (int)StringToInteger(parts[1]);
    if(h < 0 || h > 23 || m < 0 || m > 59) return -1;
    return h * 3600 + m * 60;
}

//+------------------------------------------------------------------+
//| SecondsIntoDay — seconds elapsed since midnight of a datetime   |
//+------------------------------------------------------------------+
int SecondsIntoDay(datetime t)
{
    MqlDateTime dt;
    TimeToStruct(t, dt);
    return dt.hour * 3600 + dt.min * 60 + dt.sec;
}

//+------------------------------------------------------------------+
//| IsInTimeRange — true if `now_secs` falls within [start, end)   |
//| Handles overnight ranges (start > end) correctly                |
//+------------------------------------------------------------------+
bool IsInTimeRange(int now_secs, int start_secs, int end_secs)
{
    if(start_secs < end_secs)
        return now_secs >= start_secs && now_secs < end_secs;
    // Overnight range (e.g. 22:00 – 02:00)
    return now_secs >= start_secs || now_secs < end_secs;
}

//+------------------------------------------------------------------+
//| ClassifySession — determines the active trading session         |
//| Uses server time; session strings come from Inputs.mqh          |
//+------------------------------------------------------------------+
TradingSession ClassifySession(datetime server_time,
                               const string &asian_start,  const string &asian_end,
                               const string &london_start, const string &london_end,
                               const string &ny_start,     const string &ny_end)
{
    int now     = SecondsIntoDay(server_time);
    int as      = ParseTimeString(asian_start);
    int ae      = ParseTimeString(asian_end);
    int ls      = ParseTimeString(london_start);
    int le      = ParseTimeString(london_end);
    int ns      = ParseTimeString(ny_start);
    int ne      = ParseTimeString(ny_end);

    bool in_london = (ls >= 0 && le >= 0) && IsInTimeRange(now, ls, le);
    bool in_ny     = (ns >= 0 && ne >= 0) && IsInTimeRange(now, ns, ne);
    bool in_asian  = (as >= 0 && ae >= 0) && IsInTimeRange(now, as, ae);

    if(in_london && in_ny)  return SESSION_LONDON_NY_OVERLAP;
    if(in_london)           return SESSION_LONDON;
    if(in_ny)               return SESSION_NEW_YORK;
    if(in_asian)            return SESSION_ASIAN;
    return SESSION_OFF;
}

//+------------------------------------------------------------------+
//| SessionToString — human-readable session name for dashboard     |
//+------------------------------------------------------------------+
string SessionToString(TradingSession session)
{
    switch(session)
    {
        case SESSION_ASIAN:            return "ASIAN";
        case SESSION_LONDON:           return "LONDON";
        case SESSION_NEW_YORK:         return "NEW YORK";
        case SESSION_LONDON_NY_OVERLAP: return "LDN/NY";
        default:                       return "OFF";
    }
}

//+------------------------------------------------------------------+
//| RegimeToString — human-readable regime name for dashboard       |
//+------------------------------------------------------------------+
string RegimeToString(ApexRegime regime)
{
    switch(regime)
    {
        case REGIME_TRENDING_BULL:  return "BULL TREND";
        case REGIME_TRENDING_BEAR:  return "BEAR TREND";
        case REGIME_RANGING:        return "RANGING";
        case REGIME_HIGH_VOLATILITY: return "HIGH VOL";
        default:                    return "UNDEFINED";
    }
}

//+------------------------------------------------------------------+
//| IsNewBar — true if the current bar open time differs from last  |
//| Caller must pass last_bar_time by reference to track state      |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES tf, datetime &last_bar_time)
{
    datetime current = iTime(Symbol(), tf, 0);
    if(current != last_bar_time)
    {
        last_bar_time = current;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| MillisecondsSince — ms elapsed since a stored GetTickCount()    |
//+------------------------------------------------------------------+
int MillisecondsSince(uint start_tick_count)
{
    return (int)(GetTickCount() - start_tick_count);
}

//+------------------------------------------------------------------+
//| IsSameDay — true if two datetimes share the same calendar day   |
//+------------------------------------------------------------------+
bool IsSameDay(datetime a, datetime b)
{
    MqlDateTime da, db;
    TimeToStruct(a, da);
    TimeToStruct(b, db);
    return da.year == db.year && da.mon == db.mon && da.day == db.day;
}

//+------------------------------------------------------------------+
//| GMTOffset — server time minus GMT time in seconds               |
//+------------------------------------------------------------------+
int GMTOffset()
{
    return (int)(TimeCurrent() - TimeGMT());
}

//+------------------------------------------------------------------+
//| UNIT TEST — call from OnInit in debug builds                    |
//+------------------------------------------------------------------+
bool TimeUtils_RunTests()
{
    bool ok = true;

    // ParseTimeString
    if(ParseTimeString("08:30") != 8 * 3600 + 30 * 60) { Print("FAIL ParseTime 08:30"); ok = false; }
    if(ParseTimeString("00:00") != 0)                   { Print("FAIL ParseTime 00:00"); ok = false; }
    if(ParseTimeString("23:59") != 23*3600+59*60)       { Print("FAIL ParseTime 23:59"); ok = false; }
    if(ParseTimeString("bad")   != -1)                  { Print("FAIL ParseTime bad");   ok = false; }

    // IsInTimeRange — normal
    if(!IsInTimeRange(10 * 3600, 8 * 3600, 17 * 3600))  { Print("FAIL InRange normal"); ok = false; }
    if( IsInTimeRange(18 * 3600, 8 * 3600, 17 * 3600))  { Print("FAIL OutRange normal"); ok = false; }

    // IsInTimeRange — overnight (22:00 – 02:00)
    if(!IsInTimeRange(23 * 3600, 22 * 3600, 2 * 3600))  { Print("FAIL InRange overnight A"); ok = false; }
    if(!IsInTimeRange(1  * 3600, 22 * 3600, 2 * 3600))  { Print("FAIL InRange overnight B"); ok = false; }
    if( IsInTimeRange(12 * 3600, 22 * 3600, 2 * 3600))  { Print("FAIL OutRange overnight"); ok = false; }

    if(ok) Print("TimeUtils: all tests PASSED");
    return ok;
}
