//+------------------------------------------------------------------+
//|                                                      Market.mqh |
//|                                        DeltaFadeEA — Dhruv Sharma |
//+------------------------------------------------------------------+
#ifndef MARKET_MQH
#define MARKET_MQH

#include "Config.mqh"

//--- Per-candle data arrays (size = WindowSize)
double volumeDelta[];
double tickDelta[];
double ticksPerSecond[];
double volumeWeightedPrices[];
double typicalPrices[];

//--- Cumulative deltas across the window
double cumulativeVolumeDelta = 0;
double cumulativeTickDelta   = 0;

//--- Tick analysis window (size = AnalysisWindowSize)
double   tickAnalysisData[];
datetime tickAnalysisTimes[];
int      tickAnalysisCount = 0;

//--- Volume analysis window (size = AnalysisWindowSize)
double   volumeAnalysisData[];
datetime volumeAnalysisTimes[];
int      volumeAnalysisCount = 0;

//--- Tick-rate tracking
long   totalTicksInWindow    = 0;
double averageTicksPerSecond = 0;

//--- Trend EMA
int    emaHandle = INVALID_HANDLE;
double emaValue  = 0;

//+------------------------------------------------------------------+
//| Allocate and zero all market arrays                              |
//+------------------------------------------------------------------+
void MarketInit()
{
    // Create EMA indicator handle
    if(TrendEMAPeriod > 0)
    {
        emaHandle = iMA(_Symbol, _Period, TrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
        if(emaHandle == INVALID_HANDLE)
            Print("[", EA_NAME, "] Warning: Failed to create EMA handle");
    }

    ArrayResize(volumeDelta,          WindowSize);
    ArrayResize(tickDelta,            WindowSize);
    ArrayResize(ticksPerSecond,       WindowSize);
    ArrayResize(volumeWeightedPrices, WindowSize);
    ArrayResize(typicalPrices,        WindowSize);

    ArrayInitialize(volumeDelta,          0);
    ArrayInitialize(tickDelta,            0);
    ArrayInitialize(ticksPerSecond,       0);
    ArrayInitialize(volumeWeightedPrices, 0);
    ArrayInitialize(typicalPrices,        0);

    ArrayResize(tickAnalysisData,    AnalysisWindowSize);
    ArrayResize(tickAnalysisTimes,   AnalysisWindowSize);
    ArrayResize(volumeAnalysisData,  AnalysisWindowSize);
    ArrayResize(volumeAnalysisTimes, AnalysisWindowSize);

    ArrayInitialize(tickAnalysisData,   0);
    ArrayInitialize(volumeAnalysisData, 0);
}

//+------------------------------------------------------------------+
//| Seed analysis windows from historical bars                       |
//+------------------------------------------------------------------+
void InitializeAnalysisWindows()
{
    MqlRates rates[];
    int copied = CopyRates(_Symbol, _Period, 1, AnalysisWindowSize * 2, rates);

    if(copied <= 0)
    {
        Print("[", EA_NAME, "] Warning: Could not load historical data for analysis windows");
        return;
    }

    int count = MathMin(copied, AnalysisWindowSize);

    tickAnalysisCount   = count;
    volumeAnalysisCount = count;

    for(int i = 0; i < count; i++)
    {
        int idx = MathMin(i, copied - 1);
        double delta = CandleDelta(rates[idx]);

        tickAnalysisData[i]    = delta;
        tickAnalysisTimes[i]   = rates[idx].time;
        volumeAnalysisData[i]  = delta;
        volumeAnalysisTimes[i] = rates[idx].time;
    }

    Print("[", EA_NAME, "] Analysis windows initialised — ",
          count, "/", AnalysisWindowSize, " candles");
}

//+------------------------------------------------------------------+
//| Return signed tick_volume based on candle direction               |
//+------------------------------------------------------------------+
double CandleDelta(const MqlRates &bar)
{
    if(bar.close > bar.open)  return  (double)bar.tick_volume;
    if(bar.close < bar.open)  return -(double)bar.tick_volume;
    return 0;
}

//+------------------------------------------------------------------+
//| Full recalculation of deltas for the entire window               |
//+------------------------------------------------------------------+
void CalculateDeltas()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, WindowSize, rates) < WindowSize) return;

    cumulativeVolumeDelta = 0;
    cumulativeTickDelta   = 0;

    for(int i = 0; i < WindowSize; i++)
    {
        int bar = WindowSize - 1 - i;

        volumeDelta[i] = CandleDelta(rates[bar]);

        double range = rates[bar].high - rates[bar].low;
        if(range > 0)
        {
            double ratio = (rates[bar].close - rates[bar].open) / range;
            tickDelta[i] = rates[bar].tick_volume * ratio;
        }
        else
        {
            tickDelta[i] = 0;
        }

        cumulativeVolumeDelta += volumeDelta[i];
        cumulativeTickDelta   += tickDelta[i];
    }
}

//+------------------------------------------------------------------+
//| Real-time update of the current (index-0) candle delta           |
//+------------------------------------------------------------------+
void UpdateCurrentCandleDelta()
{
    MqlRates cur[];
    if(CopyRates(_Symbol, _Period, 0, 1, cur) <= 0) return;

    volumeDelta[0] = CandleDelta(cur[0]);

    double range = cur[0].high - cur[0].low;
    if(range > 0)
    {
        double ratio = (cur[0].close - cur[0].open) / range;
        tickDelta[0] = cur[0].tick_volume * ratio;
    }
    else
    {
        tickDelta[0] = 0;
    }

    cumulativeVolumeDelta = 0;
    cumulativeTickDelta   = 0;
    for(int i = 0; i < WindowSize; i++)
    {
        cumulativeVolumeDelta += volumeDelta[i];
        cumulativeTickDelta   += tickDelta[i];
    }
}

//+------------------------------------------------------------------+
//| Volume footprint — full window                                   |
//+------------------------------------------------------------------+
void CalculateVolumeFootprint()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, WindowSize, rates) < WindowSize) return;

    for(int i = 0; i < WindowSize; i++)
    {
        int bar = WindowSize - 1 - i;
        typicalPrices[i] = (rates[bar].high + rates[bar].low + rates[bar].close) / 3.0;

        if(rates[bar].tick_volume > 0)
            volumeWeightedPrices[i] = rates[bar].close  * VWP_CLOSE_WEIGHT
                                    + typicalPrices[i]   * VWP_TYPICAL_WEIGHT
                                    + rates[bar].open    * VWP_OPEN_WEIGHT;
        else
            volumeWeightedPrices[i] = typicalPrices[i];
    }
}

//+------------------------------------------------------------------+
//| Volume footprint — current candle only                           |
//+------------------------------------------------------------------+
void UpdateCurrentVolumeFootprint()
{
    MqlRates cur[];
    if(CopyRates(_Symbol, _Period, 0, 1, cur) <= 0) return;

    typicalPrices[0] = (cur[0].high + cur[0].low + cur[0].close) / 3.0;

    if(cur[0].tick_volume > 0)
        volumeWeightedPrices[0] = cur[0].close     * VWP_CLOSE_WEIGHT
                                + typicalPrices[0]  * VWP_TYPICAL_WEIGHT
                                + cur[0].open       * VWP_OPEN_WEIGHT;
    else
        volumeWeightedPrices[0] = typicalPrices[0];
}

//+------------------------------------------------------------------+
//| Ticks-per-second — full window                                   |
//+------------------------------------------------------------------+
void CalculateTicksPerSecond()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, WindowSize, rates) < WindowSize) return;

    totalTicksInWindow = 0;
    double totalSeconds = 0;

    for(int i = 0; i < WindowSize; i++)
    {
        int bar = WindowSize - 1 - i;
        double dur = (i == 0)
            ? MathMax((double)(TimeCurrent() - rates[bar].time), (double)PeriodSeconds())
            : (double)PeriodSeconds();

        if(dur > 0)
        {
            ticksPerSecond[i]    = rates[bar].tick_volume / dur;
            totalTicksInWindow  += rates[bar].tick_volume;
            totalSeconds        += dur;
        }
        else
        {
            ticksPerSecond[i] = 0;
        }
    }

    averageTicksPerSecond = (totalSeconds > 0) ? totalTicksInWindow / totalSeconds : 0;
}

//+------------------------------------------------------------------+
//| Ticks-per-second — current candle only                           |
//+------------------------------------------------------------------+
void UpdateCurrentTicksPerSecond()
{
    MqlRates cur[];
    if(CopyRates(_Symbol, _Period, 0, 1, cur) <= 0) return;

    double elapsed = MathMax((double)(TimeCurrent() - cur[0].time), 1.0);
    ticksPerSecond[0] = cur[0].tick_volume / elapsed;

    totalTicksInWindow = 0;
    double totalSeconds = 0;

    for(int i = 0; i < WindowSize; i++)
    {
        MqlRates r[];
        if(CopyRates(_Symbol, _Period, i, 1, r) > 0)
        {
            double dur = (i == 0) ? elapsed : (double)PeriodSeconds();
            if(dur > 0)
            {
                totalTicksInWindow += r[0].tick_volume;
                totalSeconds       += dur;
            }
        }
    }

    averageTicksPerSecond = (totalSeconds > 0) ? totalTicksInWindow / totalSeconds : 0;
}

//+------------------------------------------------------------------+
//| Push new value into tick analysis sliding window                 |
//+------------------------------------------------------------------+
void UpdateTickAnalysisWindow(double newTickDelta)
{
    if(tickAnalysisCount < AnalysisWindowSize)
        tickAnalysisCount++;

    for(int i = tickAnalysisCount - 1; i > 0; i--)
    {
        tickAnalysisData[i]  = tickAnalysisData[i - 1];
        tickAnalysisTimes[i] = tickAnalysisTimes[i - 1];
    }
    tickAnalysisData[0]  = newTickDelta;
    tickAnalysisTimes[0] = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Push new value into volume analysis sliding window               |
//+------------------------------------------------------------------+
void UpdateVolumeAnalysisWindow(double newVolumeDelta)
{
    if(volumeAnalysisCount < AnalysisWindowSize)
        volumeAnalysisCount++;

    for(int i = volumeAnalysisCount - 1; i > 0; i--)
    {
        volumeAnalysisData[i]  = volumeAnalysisData[i - 1];
        volumeAnalysisTimes[i] = volumeAnalysisTimes[i - 1];
    }
    volumeAnalysisData[0]  = newVolumeDelta;
    volumeAnalysisTimes[0] = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Volume footprint line slope: +1 up, -1 down, 0 flat             |
//+------------------------------------------------------------------+
int GetVolumeLineSlope()
{
    if(WindowSize < 2) return 0;
    double start = volumeWeightedPrices[WindowSize - 1];
    double end   = volumeWeightedPrices[0];
    if(end > start) return  1;
    if(end < start) return -1;
    return 0;
}

//+------------------------------------------------------------------+
//| Median of first `count` elements                                 |
//+------------------------------------------------------------------+
double CalculateMedian(double &data[], int count)
{
    if(count <= 0) return 0;

    double temp[];
    ArrayResize(temp, count);
    ArrayCopy(temp, data, 0, 0, count);
    ArraySort(temp);

    if(count % 2 == 0)
        return (temp[count / 2 - 1] + temp[count / 2]) / 2.0;
    return temp[count / 2];
}

//+------------------------------------------------------------------+
//| Median Absolute Deviation (scaled for normal distribution)       |
//+------------------------------------------------------------------+
double CalculateMAD(double &data[], double median, int count)
{
    if(count <= 0) return 0;

    double dev[];
    ArrayResize(dev, count);
    for(int i = 0; i < count; i++)
        dev[i] = MathAbs(data[i] - median);

    return CalculateMedian(dev, count) * MAD_SCALE_FACTOR;
}

//+------------------------------------------------------------------+
//| Current spread in price units                                    |
//+------------------------------------------------------------------+
double GetCurrentSpread()
{
    return SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
}

//+------------------------------------------------------------------+
//| Update EMA value from indicator buffer                           |
//+------------------------------------------------------------------+
void UpdateEMA()
{
    if(emaHandle == INVALID_HANDLE) return;

    double buf[1];
    if(CopyBuffer(emaHandle, 0, 0, 1, buf) == 1)
        emaValue = buf[0];
}

//+------------------------------------------------------------------+
//| Trend direction: +1 bullish, -1 bearish, 0 no trend/disabled    |
//+------------------------------------------------------------------+
int GetTrendDirection()
{
    if(TrendEMAPeriod <= 0 || emaHandle == INVALID_HANDLE)
        return 0;

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(bid > emaValue) return  1;  // Price above EMA = uptrend
    if(bid < emaValue) return -1;  // Price below EMA = downtrend
    return 0;
}

//+------------------------------------------------------------------+
//| Release indicator handle                                         |
//+------------------------------------------------------------------+
void MarketDeinit()
{
    if(emaHandle != INVALID_HANDLE)
        IndicatorRelease(emaHandle);
}

#endif
