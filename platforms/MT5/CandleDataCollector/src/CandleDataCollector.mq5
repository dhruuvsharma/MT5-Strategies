//+------------------------------------------------------------------+
//|                                        CandleDataCollector.mq5  |
//|                                                    Dhruv Sharma  |
//|                    www.linkedin.com/in/dhruvsharminfo           |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      "www.linkedin.com/in/dhruvsharminfo"
#property version   "2.00"
#property strict

#include "Config.mqh"

int      g_file        = INVALID_HANDLE;
datetime g_candleTime  = 0;
datetime g_candleStart = 0;
double   g_open        = 0;
double   g_high        = 0;
double   g_low         = 0;
double   g_close       = 0;
int      g_upTicks     = 0;
int      g_downTicks   = 0;
double   g_upVol       = 0;
double   g_downVol     = 0;
double   g_totalVol    = 0;
double   g_vwapNumer   = 0;
double   g_lastPrice   = 0;
long     g_tickCount   = 0;
long     g_candleCount = 0;
int      g_cumDelta    = 0;

//+------------------------------------------------------------------+
int OnInit()
{
    if(InpCandleMinutes <= 0)
    {
        Print("[CandleDataCollector] Invalid CandleMinutes: ", InpCandleMinutes);
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
        Print("[CandleDataCollector] Cannot open '", filename, "': ", GetLastError());
        return INIT_FAILED;
    }

    Print("[CandleDataCollector] Started | File: ",
          TerminalInfoString(TERMINAL_COMMONDATA_PATH), "\\Files\\", filename,
          " | TF: ", InpCandleMinutes, "min");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(g_file == INVALID_HANDLE) return;

    if(InpWriteLastCandle && g_candleTime != 0 && g_tickCount > 0)
        FlushCandle();

    FileFlush(g_file);
    FileClose(g_file);
    Print("[CandleDataCollector] Stopped | Candles written: ", g_candleCount);
}

//+------------------------------------------------------------------+
void OnTick()
{
    MqlTick tick;
    if(!SymbolInfoTick(_Symbol, tick)) return;

    double   price        = (tick.last > 0) ? tick.last : (tick.bid + tick.ask) * 0.5;
    datetime tickTime     = tick.time;
    datetime newCandleTime = (tickTime / (InpCandleMinutes * 60)) * (InpCandleMinutes * 60);

    if(g_candleTime == 0)
    {
        StartCandle(newCandleTime, tickTime, tick, price);
        return;
    }

    if(newCandleTime != g_candleTime)
    {
        FlushCandle();
        StartCandle(newCandleTime, tickTime, tick, price);
        return;
    }

    UpdateCandle(tick, price);
}

//+------------------------------------------------------------------+
void StartCandle(datetime cTime, datetime tTime, const MqlTick &tick, double price)
{
    g_candleTime  = cTime;
    g_candleStart = tTime;
    g_open = g_high = g_low = g_close = price;
    g_upTicks = g_downTicks = 0;
    g_upVol   = g_downVol   = 0;
    g_totalVol  = tick.volume;
    g_vwapNumer = price * tick.volume;
    g_tickCount = 1;
    g_lastPrice = price;
}

//+------------------------------------------------------------------+
void UpdateCandle(const MqlTick &tick, double price)
{
    if(price > g_high) g_high = price;
    if(price < g_low)  g_low  = price;

    if(price > g_lastPrice)      { g_upTicks++;   g_upVol   += tick.volume; }
    else if(price < g_lastPrice) { g_downTicks++; g_downVol += tick.volume; }

    g_totalVol  += tick.volume;
    g_vwapNumer += price * tick.volume;
    g_tickCount++;
    g_close     = price;
    g_lastPrice = price;
}

//+------------------------------------------------------------------+
void FlushCandle()
{
    string session = GetSession(g_candleTime);
    if(InpSessionFilter != "ALL" && InpSessionFilter != session) return;

    int    tDelta = g_upTicks - g_downTicks;
    double vDelta = g_upVol - g_downVol;
    double vwap   = (g_totalVol > 0) ? g_vwapNumer / g_totalVol : g_close;
    double range  = g_high - g_low;

    int    elapsed = (int)(TimeCurrent() - g_candleStart);
    double tps     = (elapsed > 0) ? (double)g_tickCount / elapsed : 0.0;

    g_cumDelta += tDelta;

    string row =
        TimeToString(g_candleTime, TIME_DATE|TIME_MINUTES)  + "," +
        DoubleToString(g_open,  _Digits) + "," +
        DoubleToString(g_high,  _Digits) + "," +
        DoubleToString(g_low,   _Digits) + "," +
        DoubleToString(g_close, _Digits) + "," +
        IntegerToString(tDelta)          + "," +
        DoubleToString(vDelta,     2)    + "," +
        DoubleToString(g_totalVol, 2)    + "," +
        DoubleToString(vwap,  _Digits)   + "," +
        DoubleToString(range, _Digits)   + "," +
        IntegerToString((int)g_tickCount)+ "," +
        DoubleToString(tps,        2)    + "," +
        IntegerToString(g_cumDelta)      + "," +
        session + "\r\n";

    FileWriteString(g_file, row);

    g_candleCount++;
    if(g_candleCount % InpFlushEveryN == 0) FileFlush(g_file);

    if(InpPrintEachCandle)
        Print("[CandleDataCollector] ", TimeToString(g_candleTime),
              " O:", g_open, " H:", g_high, " L:", g_low, " C:", g_close,
              " Delta:", tDelta, " VDelta:", DoubleToString(vDelta, 2));
}

//+------------------------------------------------------------------+
void WriteHeader()
{
    FileWriteString(g_file,
        "DateTime,Open,High,Low,Close,"
        "TickDelta,VolumeDelta,Volume,VWAP,Range,"
        "TickCount,TicksPerSec,CumDelta,Session\r\n");
}

//+------------------------------------------------------------------+
string BuildFilename()
{
    if(StringLen(InpCSVFileName) > 0) return InpCSVFileName;

    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    return StringFormat("%s_%dmin_%04d%02d%02d.csv",
        _Symbol, InpCandleMinutes, dt.year, dt.mon, dt.day);
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
