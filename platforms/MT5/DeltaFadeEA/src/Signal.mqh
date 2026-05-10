//+------------------------------------------------------------------+
//|                                                      Signal.mqh |
//|                                        DeltaFadeEA — Dhruv Sharma |
//+------------------------------------------------------------------+
#ifndef SIGNAL_MQH
#define SIGNAL_MQH

#include "Config.mqh"
#include "Market.mqh"

//--- Dynamic thresholds (recalculated each bar)
double dynamicTickBuyThreshold      =  1000;
double dynamicTickSellThreshold     = -1000;
double dynamicVolumeBuyThreshold    =  800;
double dynamicVolumeSellThreshold   = -800;

//--- Base thresholds for multiplier bounds
double baseTickBuyThreshold         =  1000;
double baseTickSellThreshold        = -1000;
double baseVolumeBuyThreshold       =  800;
double baseVolumeSellThreshold      = -800;

//--- Signal state
bool signalLong  = false;
bool signalShort = false;

//--- Trade management tracking
int      tradesToday       = 0;
datetime lastTradeDay      = 0;
int      barsSinceLastTrade = 999;

//+------------------------------------------------------------------+
//| Reset daily trade counter at day change                          |
//+------------------------------------------------------------------+
void UpdateDailyTradeCount()
{
    MqlDateTime t;
    TimeToStruct(TimeCurrent(), t);
    datetime today = StringToTime(IntegerToString(t.year) + "." +
                                  IntegerToString(t.mon) + "." +
                                  IntegerToString(t.day));
    if(today != lastTradeDay)
    {
        tradesToday  = 0;
        lastTradeDay = today;
    }
}

//+------------------------------------------------------------------+
//| Record that a trade was taken                                    |
//+------------------------------------------------------------------+
void OnTradeExecuted()
{
    tradesToday++;
    barsSinceLastTrade = 0;
}

//+------------------------------------------------------------------+
//| Increment bar counter (call on each new bar)                     |
//+------------------------------------------------------------------+
void OnNewBarSignal()
{
    barsSinceLastTrade++;
}

//+------------------------------------------------------------------+
//| Can we trade right now? (daily limit + cooldown)                 |
//+------------------------------------------------------------------+
bool IsTradeAllowedByLimits()
{
    if(MaxTradesPerDay > 0 && tradesToday >= MaxTradesPerDay)
        return false;
    if(barsSinceLastTrade < MinBarsBetweenTrades)
        return false;
    return true;
}

//+------------------------------------------------------------------+
//| Clamp threshold within bounds, sign-aware                        |
//+------------------------------------------------------------------+
double ApplyThresholdBounds(double raw, double base, bool isBuy)
{
    if(isBuy)
    {
        if(raw < 0) raw = MathAbs(raw);
        return MathMin(MathMax(raw, base * THRESHOLD_MIN_MULT), base * THRESHOLD_MAX_MULT);
    }
    else
    {
        if(raw > 0) raw = -raw;
        return MathMax(MathMin(raw, base * THRESHOLD_MIN_MULT), base * THRESHOLD_MAX_MULT);
    }
}

//+------------------------------------------------------------------+
//| Calculate dynamic thresholds from analysis window data           |
//+------------------------------------------------------------------+
void CalculateThresholdsFromData(double &data[], int count,
                                  double baseBuy, double baseSell,
                                  double &outBuy, double &outSell)
{
    if(count < 10)
    {
        outBuy  = baseBuy;
        outSell = baseSell;
        return;
    }

    double temp[];
    ArrayResize(temp, count);
    for(int i = 0; i < count; i++)
        temp[i] = data[i];

    double med = CalculateMedian(temp, count);
    double mad = MathMax(CalculateMAD(temp, med, count), MIN_MAD_VALUE);

    double rawBuy  = med + ThresholdMultiplier * mad;
    double rawSell = med - ThresholdMultiplier * mad;

    if(MathAbs(rawBuy)  < MIN_ABSOLUTE_THRESHOLD)
        rawBuy  = (rawBuy  >= 0) ?  MIN_ABSOLUTE_THRESHOLD : -MIN_ABSOLUTE_THRESHOLD;
    if(MathAbs(rawSell) < MIN_ABSOLUTE_THRESHOLD)
        rawSell = (rawSell >= 0) ?  MIN_ABSOLUTE_THRESHOLD : -MIN_ABSOLUTE_THRESHOLD;

    outBuy  = ApplyThresholdBounds(rawBuy,  baseBuy,  true);
    outSell = ApplyThresholdBounds(rawSell, baseSell, false);
}

//+------------------------------------------------------------------+
void CalculateDynamicTickThresholds()
{
    CalculateThresholdsFromData(tickAnalysisData, tickAnalysisCount,
        baseTickBuyThreshold, baseTickSellThreshold,
        dynamicTickBuyThreshold, dynamicTickSellThreshold);
}

//+------------------------------------------------------------------+
void CalculateDynamicVolumeThresholds()
{
    CalculateThresholdsFromData(volumeAnalysisData, volumeAnalysisCount,
        baseVolumeBuyThreshold, baseVolumeSellThreshold,
        dynamicVolumeBuyThreshold, dynamicVolumeSellThreshold);
}

//+------------------------------------------------------------------+
//| Core signal logic — trend-following pullback OR contrarian       |
//+------------------------------------------------------------------+
void CheckTradingSignals()
{
    signalLong  = false;
    signalShort = false;

    // Spread filter
    if(GetCurrentSpread() > MaxSpread * _Point)
        return;

    // Trade limits
    UpdateDailyTradeCount();
    if(!IsTradeAllowedByLimits())
        return;

    // Delta extremes
    bool tickOverbought  = (cumulativeTickDelta   > dynamicTickBuyThreshold);
    bool tickOversold    = (cumulativeTickDelta   < dynamicTickSellThreshold);
    bool volOverbought   = (cumulativeVolumeDelta > dynamicVolumeBuyThreshold);
    bool volOversold     = (cumulativeVolumeDelta < dynamicVolumeSellThreshold);

    // Combine deltas
    bool deltaOverbought, deltaOversold;
    if(RequireBothDeltas)
    {
        deltaOverbought = tickOverbought && volOverbought;
        deltaOversold   = tickOversold   && volOversold;
    }
    else
    {
        deltaOverbought = tickOverbought || volOverbought;
        deltaOversold   = tickOversold   || volOversold;
    }

    // VWP slope
    int slope = GetVolumeLineSlope();
    bool slopeUp   = !RequireSlopeConfirmation || (slope == 1);
    bool slopeDown = !RequireSlopeConfirmation || (slope == -1);

    // Trend direction from EMA
    int trend = GetTrendDirection();

    if(TrendFollowing && trend != 0)
    {
        //--------------------------------------------------------------
        // TREND-FOLLOWING PULLBACK MODE
        // Uptrend + delta oversold (pullback) → BUY the dip
        // Downtrend + delta overbought (bounce) → SELL the rally
        //--------------------------------------------------------------
        if(trend == 1 && deltaOversold && slopeDown)
        {
            signalLong = true;
            Print("[", EA_NAME, "] LONG — uptrend pullback detected (EMA trend + delta oversold + red slope)");
        }
        else if(trend == -1 && deltaOverbought && slopeUp)
        {
            signalShort = true;
            Print("[", EA_NAME, "] SHORT — downtrend bounce detected (EMA trend + delta overbought + green slope)");
        }
    }
    else
    {
        //--------------------------------------------------------------
        // CONTRARIAN MODE (original logic, no trend filter)
        //--------------------------------------------------------------
        if(deltaOverbought && slopeUp)
        {
            signalShort = true;
            Print("[", EA_NAME, "] SHORT — contrarian fade (delta overbought)");
        }
        else if(deltaOversold && slopeDown)
        {
            signalLong = true;
            Print("[", EA_NAME, "] LONG — contrarian fade (delta oversold)");
        }
    }
}

#endif
