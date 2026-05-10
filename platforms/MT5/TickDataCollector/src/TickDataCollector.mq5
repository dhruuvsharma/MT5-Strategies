//+------------------------------------------------------------------+
//|                                          TickDataCollector.mq5  |
//|                                                    Dhruv Sharma  |
//|                    www.linkedin.com/in/dhruvsharminfo           |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      "www.linkedin.com/in/dhruvsharminfo"
#property version   "2.00"
#property strict

#include "Config.mqh"

int      g_file       = INVALID_HANDLE;
datetime g_candleTime  = 0;
datetime g_candleStart = 0;
double   g_cOpen       = 0;
double   g_cHigh       = 0;
double   g_cLow        = 0;
int      g_upTicks     = 0;
int      g_downTicks   = 0;
double   g_upVol       = 0;
double   g_downVol     = 0;
double   g_lastPrice   = 0;
long     g_tickCount   = 0;
int      g_cumDelta    = 0;

//+------------------------------------------------------------------+
int OnInit()
{
    if(InpCandleMinutes <= 0)
    {
        Print("[TickDataCollector] Invalid CandleMinutes: ", InpCandleMinutes);
        return INIT_PARAMETERS_INCORRECT;
    }

    string filename = BuildFilename();

    if(InpAppendMode)
    {
        g_file = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
        if(g_file != INVALID_HANDLE)
            FileSeek(g_file, 0, SEEK_END);
        else
        {
            g_file = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
            if(g_file != INVALID_HANDLE) WriteHeader();
        }
    }
    else
    {
        g_file = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
        if(g_file != INVALID_HANDLE) WriteHeader();
    }

    if(g_file == INVALID_HANDLE)
    {
        Print("[TickDataCollector] Cannot open '", filename, "': ", GetLastError());
        return INIT_FAILED;
    }

    Print("[TickDataCollector] Started | File: ",
          TerminalInfoString(TERMINAL_COMMONDATA_PATH), "\\Files\\", filename,
          " | CandleWindow: ", InpCandleMinutes, "min");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(g_file == INVALID_HANDLE) return;
    FileFlush(g_file);
    FileClose(g_file);
    Print("[TickDataCollector] Stopped | Ticks written: ", g_tickCount);
}

//+------------------------------------------------------------------+
void OnTick()
{
    MqlTick tick;
    if(!SymbolInfoTick(_Symbol, tick)) return;

    double   price        = (tick.last > 0) ? tick.last : (tick.bid + tick.ask) * 0.5;
    datetime tickTime     = tick.time;
    datetime newCandleTime = (tickTime / (InpCandleMinutes * 60)) * (InpCandleMinutes * 60);

    if(newCandleTime != g_candleTime)
    {
        g_candleTime  = newCandleTime;
        g_candleStart = tickTime;
        g_cOpen = g_cHigh = g_cLow = price;
        g_upTicks = g_downTicks = 0;
        g_upVol   = g_downVol   = 0;
        g_lastPrice = 0;
    }

    if(InpPriceChangeOnly && price == g_lastPrice && g_lastPrice > 0) return;

    string dir = "NEUTRAL";
    if(g_lastPrice > 0)
    {
        if(price > g_lastPrice)      { g_upTicks++;   g_upVol   += tick.volume; dir = "UP";   g_cumDelta++; }
        else if(price < g_lastPrice) { g_downTicks++; g_downVol += tick.volume; dir = "DOWN"; g_cumDelta--; }
    }

    if(price > g_cHigh) g_cHigh = price;
    if(price < g_cLow || g_cLow == 0) g_cLow = price;

    g_lastPrice = price;

    string session = GetSession(tickTime);
    if(InpSessionFilter != "ALL" && InpSessionFilter != session) return;

    int    cDelta  = g_upTicks - g_downTicks;
    double cvDelta = g_upVol - g_downVol;
    int    elapsed = (int)(tickTime - g_candleStart);
    double tps     = (elapsed > 0) ? (double)(g_upTicks + g_downTicks) / elapsed : 0.0;
    double spread  = (tick.ask - tick.bid) / _Point;
    int    ms      = (int)(tick.time_msc % 1000);

    string row =
        TimeToString(tickTime, TIME_DATE|TIME_SECONDS) + "," +
        IntegerToString(ms)                             + "," +
        DoubleToString(price,    _Digits)               + "," +
        DoubleToString(tick.bid, _Digits)               + "," +
        DoubleToString(tick.ask, _Digits)               + "," +
        DoubleToString(spread,   1)                     + "," +
        IntegerToString((long)tick.volume)              + "," +
        dir                                             + "," +
        DoubleToString(g_cOpen, _Digits)                + "," +
        DoubleToString(g_cHigh, _Digits)                + "," +
        DoubleToString(g_cLow,  _Digits)                + "," +
        IntegerToString(cDelta)                         + "," +
        DoubleToString(cvDelta, 2)                      + "," +
        DoubleToString(tps,     2)                      + "," +
        IntegerToString(g_cumDelta)                     + "," +
        session + "\r\n";

    FileWriteString(g_file, row);
    g_tickCount++;

    if(g_tickCount % InpFlushEveryN == 0) FileFlush(g_file);
}

//+------------------------------------------------------------------+
void WriteHeader()
{
    FileWriteString(g_file,
        "DateTime,Ms,Price,Bid,Ask,SpreadPts,Volume,Direction,"
        "CandleOpen,CandleHigh,CandleLow,CandleDelta,CandleVolDelta,"
        "TicksPerSec,CumDelta,Session\r\n");
}

//+------------------------------------------------------------------+
string BuildFilename()
{
    if(StringLen(InpCSVFileName) > 0) return InpCSVFileName;

    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    return StringFormat("%s_ticks_%04d%02d%02d.csv",
        _Symbol, dt.year, dt.mon, dt.day);
}

//+------------------------------------------------------------------+
string GetSession(datetime t)
{
    MqlDateTime dt;
    TimeToStruct(t, dt);
    int h = dt.hour;
    if(h >= 23 || h < 8) return "Asian";
    if(h < 13)            return "London";
    if(h < 16)            return "London-NewYork";
    if(h < 22)            return "NewYork";
    return "OffHours";
}
