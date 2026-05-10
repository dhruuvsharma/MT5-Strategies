//+------------------------------------------------------------------+
//|                                                       Utils.mqh |
//|                                        DeltaFadeEA — Dhruv Sharma |
//+------------------------------------------------------------------+
#ifndef UTILS_MQH
#define UTILS_MQH

#include "Config.mqh"
#include "Market.mqh"
#include "Signal.mqh"

//+------------------------------------------------------------------+
//| Chart helpers                                                    |
//+------------------------------------------------------------------+
double ChartPriceMin(int subWin = 0)
{
    double v = 0;
    ChartGetDouble(0, CHART_PRICE_MIN, subWin, v);
    return v;
}

double ChartPriceMax(int subWin = 0)
{
    double v = 0;
    ChartGetDouble(0, CHART_PRICE_MAX, subWin, v);
    return v;
}

//+------------------------------------------------------------------+
//| Session filter: StartHour–EndHour, Mon–Fri only                  |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
    if(!EnableTimeFilter) return true;

    MqlDateTime t;
    TimeToStruct(TimeCurrent(), t);

    // Weekends always blocked
    if(t.day_of_week == 0 || t.day_of_week == 6) return false;

    // Hour range check
    if(StartHour <= EndHour)
        return (t.hour >= StartHour && t.hour < EndHour);
    else
        return (t.hour >= StartHour || t.hour < EndHour);
}

//+------------------------------------------------------------------+
//| Ticks-per-second activity colour                                 |
//+------------------------------------------------------------------+
color GetTicksPerSecColor(double tps)
{
    if(tps > 5.0) return clrLime;
    if(tps > 2.0) return clrYellow;
    if(tps > 0.5) return clrOrange;
    return clrGray;
}

//+------------------------------------------------------------------+
//| Rectangle colour from cumulative deltas                          |
//+------------------------------------------------------------------+
color GetRectangleColor()
{
    if(cumulativeTickDelta > 0 && cumulativeVolumeDelta > 0) return clrGreen;
    if(cumulativeTickDelta < 0 && cumulativeVolumeDelta < 0) return clrRed;
    return clrYellow;
}

//+------------------------------------------------------------------+
//| Volume-footprint line colour from slope                          |
//+------------------------------------------------------------------+
color CalculateLineColor()
{
    if(WindowSize < 2) return clrYellow;
    double s = volumeWeightedPrices[WindowSize - 1];
    double e = volumeWeightedPrices[0];
    if(e > s) return UP_TREND_COLOR;
    if(e < s) return DOWN_TREND_COLOR;
    return clrYellow;
}

//+------------------------------------------------------------------+
//| Point colour based on local trend                                |
//+------------------------------------------------------------------+
color GetPointColor(int idx)
{
    if(idx == 0 || idx == WindowSize - 1) return clrWhite;
    if(idx > 0 && idx < WindowSize - 1)
    {
        if(volumeWeightedPrices[idx] > volumeWeightedPrices[idx - 1]) return UP_TREND_COLOR;
        if(volumeWeightedPrices[idx] < volumeWeightedPrices[idx - 1]) return DOWN_TREND_COLOR;
    }
    return clrYellow;
}

//+------------------------------------------------------------------+
//| Draw / update sliding window rectangle                           |
//+------------------------------------------------------------------+
void DrawRectangle()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, WindowSize, rates) < WindowSize) return;

    datetime startTime = rates[WindowSize - 1].time;
    datetime endTime   = rates[0].time;

    double hi = rates[0].high, lo = rates[0].low;
    for(int i = 1; i < WindowSize; i++)
    {
        hi = MathMax(hi, rates[i].high);
        lo = MathMin(lo, rates[i].low);
    }
    double rng = hi - lo;
    hi += rng * 0.1;
    lo -= rng * 0.1;

    color clr = GetRectangleColor();

    if(ObjectFind(0, "SlidingWindow_Rect") < 0)
    {
        if(ObjectCreate(0, "SlidingWindow_Rect", OBJ_RECTANGLE, 0, startTime, lo, endTime, hi))
        {
            ObjectSetInteger(0, "SlidingWindow_Rect", OBJPROP_COLOR, clr);
            ObjectSetInteger(0, "SlidingWindow_Rect", OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, "SlidingWindow_Rect", OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, "SlidingWindow_Rect", OBJPROP_BACK, true);
            ObjectSetInteger(0, "SlidingWindow_Rect", OBJPROP_FILL, false);
            ObjectSetInteger(0, "SlidingWindow_Rect", OBJPROP_SELECTABLE, false);
        }
    }
    else
    {
        ObjectSetInteger(0, "SlidingWindow_Rect", OBJPROP_TIME,  0, startTime);
        ObjectSetDouble (0, "SlidingWindow_Rect", OBJPROP_PRICE, 0, lo);
        ObjectSetInteger(0, "SlidingWindow_Rect", OBJPROP_TIME,  1, endTime);
        ObjectSetDouble (0, "SlidingWindow_Rect", OBJPROP_PRICE, 1, hi);
        ObjectSetInteger(0, "SlidingWindow_Rect", OBJPROP_COLOR, clr);
    }
}

//+------------------------------------------------------------------+
//| Draw volume footprint trend line                                 |
//+------------------------------------------------------------------+
void DrawVolumeFootprintLine()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, WindowSize, rates) < WindowSize) return;

    ObjectDelete(0, "VolumeFootprint_Line");

    if(ObjectCreate(0, "VolumeFootprint_Line", OBJ_TREND, 0, 0, 0))
    {
        color lc = CalculateLineColor();
        ObjectSetInteger(0, "VolumeFootprint_Line", OBJPROP_COLOR, lc);
        ObjectSetInteger(0, "VolumeFootprint_Line", OBJPROP_WIDTH, FOOTPRINT_LINE_WIDTH);
        ObjectSetInteger(0, "VolumeFootprint_Line", OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, "VolumeFootprint_Line", OBJPROP_RAY, false);
        ObjectSetInteger(0, "VolumeFootprint_Line", OBJPROP_BACK, true);
        ObjectSetInteger(0, "VolumeFootprint_Line", OBJPROP_SELECTABLE, false);

        ObjectSetInteger(0, "VolumeFootprint_Line", OBJPROP_TIME,  0, rates[WindowSize - 1].time);
        ObjectSetDouble (0, "VolumeFootprint_Line", OBJPROP_PRICE, 0, volumeWeightedPrices[WindowSize - 1]);
        ObjectSetInteger(0, "VolumeFootprint_Line", OBJPROP_TIME,  1, rates[0].time);
        ObjectSetDouble (0, "VolumeFootprint_Line", OBJPROP_PRICE, 1, volumeWeightedPrices[0]);
    }

    DrawVolumeFootprintPoints(rates);
}

//+------------------------------------------------------------------+
void DrawVolumeFootprintPoints(MqlRates &rates[])
{
    for(int i = 0; i < WindowSize; i++)
    {
        string name = "VolumeFootprint_Point_" + IntegerToString(i);
        ObjectDelete(0, name);

        int bar = WindowSize - 1 - i;
        if(ObjectCreate(0, name, OBJ_ARROW_RIGHT_PRICE, 0, rates[bar].time, volumeWeightedPrices[i]))
        {
            ObjectSetInteger(0, name, OBJPROP_COLOR, GetPointColor(i));
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        }
    }
}

//+------------------------------------------------------------------+
//| Display per-candle delta labels                                  |
//+------------------------------------------------------------------+
void DisplayDeltas()
{
    ObjectsDeleteAll(0, "Delta_");
    ObjectsDeleteAll(0, "Cumulative_");
    ObjectsDeleteAll(0, "TicksPerSecond_");

    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, WindowSize, rates) < WindowSize) return;

    double chartRange = ChartPriceMax() - ChartPriceMin();

    for(int i = 0; i < WindowSize; i++)
    {
        int bar = WindowSize - 1 - i;
        double above   = rates[bar].high + chartRange * 0.02;
        double below   = rates[bar].low  - chartRange * 0.02;
        double belowTp = below - chartRange * 0.02;

        // Volume delta — above candle
        string vn = "Delta_Vol_" + IntegerToString(i);
        if(ObjectCreate(0, vn, OBJ_TEXT, 0, rates[bar].time, above))
        {
            ObjectSetString (0, vn, OBJPROP_TEXT, "V:" + DoubleToString(volumeDelta[i], 0));
            ObjectSetInteger(0, vn, OBJPROP_COLOR, (volumeDelta[i] >= 0) ? clrGreen : clrRed);
            ObjectSetInteger(0, vn, OBJPROP_FONTSIZE, TEXT_SIZE);
            ObjectSetInteger(0, vn, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, vn, OBJPROP_BACK, false);
        }

        // Tick delta — below candle
        string tn = "Delta_Tick_" + IntegerToString(i);
        if(ObjectCreate(0, tn, OBJ_TEXT, 0, rates[bar].time, below))
        {
            ObjectSetString (0, tn, OBJPROP_TEXT, "T:" + DoubleToString(tickDelta[i], 0));
            ObjectSetInteger(0, tn, OBJPROP_COLOR, (tickDelta[i] >= 0) ? clrGreen : clrRed);
            ObjectSetInteger(0, tn, OBJPROP_FONTSIZE, TEXT_SIZE);
            ObjectSetInteger(0, tn, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, tn, OBJPROP_BACK, false);
        }

        // Ticks/sec — below tick delta
        string ts = "TicksPerSecond_" + IntegerToString(i);
        if(ObjectCreate(0, ts, OBJ_TEXT, 0, rates[bar].time, belowTp))
        {
            ObjectSetString (0, ts, OBJPROP_TEXT, "Ts:" + DoubleToString(ticksPerSecond[i], 1));
            ObjectSetInteger(0, ts, OBJPROP_COLOR, GetTicksPerSecColor(ticksPerSecond[i]));
            ObjectSetInteger(0, ts, OBJPROP_FONTSIZE, TEXT_SIZE - 1);
            ObjectSetInteger(0, ts, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, ts, OBJPROP_BACK, false);
        }
    }

    DisplayCumulativeValues(rates);
    DisplayAverageTicksPerSecond(rates);
}

//+------------------------------------------------------------------+
//| Cumulative sums below the rectangle                              |
//+------------------------------------------------------------------+
void DisplayCumulativeValues(MqlRates &rates[])
{
    double hi = rates[0].high, lo = rates[0].low;
    for(int i = 1; i < WindowSize; i++)
    {
        hi = MathMax(hi, rates[i].high);
        lo = MathMin(lo, rates[i].low);
    }
    double rng = hi - lo;
    lo -= rng * 0.1;
    double bottom = lo - rng * 0.15;

    datetime st = rates[WindowSize - 1].time;
    datetime en = rates[0].time;

    string cn = "Cumulative_Tick";
    if(ObjectCreate(0, cn, OBJ_TEXT, 0, st + (en - st) / 10, bottom))
    {
        ObjectSetString (0, cn, OBJPROP_TEXT, StringFormat("\x03A3T: %.0f (Th: %.0f/%.0f)",
            cumulativeTickDelta, dynamicTickBuyThreshold, dynamicTickSellThreshold));
        ObjectSetInteger(0, cn, OBJPROP_COLOR, (cumulativeTickDelta >= 0) ? clrGreen : clrRed);
        ObjectSetInteger(0, cn, OBJPROP_FONTSIZE, TEXT_SIZE + 1);
        ObjectSetInteger(0, cn, OBJPROP_ANCHOR, ANCHOR_UPPER);
        ObjectSetInteger(0, cn, OBJPROP_BACK, false);
    }

    string vn = "Cumulative_Vol";
    if(ObjectCreate(0, vn, OBJ_TEXT, 0, st + (datetime)((en - st) * 0.9), bottom))
    {
        ObjectSetString (0, vn, OBJPROP_TEXT, StringFormat("\x03A3V: %.0f (Th: %.0f/%.0f)",
            cumulativeVolumeDelta, dynamicVolumeBuyThreshold, dynamicVolumeSellThreshold));
        ObjectSetInteger(0, vn, OBJPROP_COLOR, (cumulativeVolumeDelta >= 0) ? clrGreen : clrRed);
        ObjectSetInteger(0, vn, OBJPROP_FONTSIZE, TEXT_SIZE + 1);
        ObjectSetInteger(0, vn, OBJPROP_ANCHOR, ANCHOR_UPPER);
        ObjectSetInteger(0, vn, OBJPROP_BACK, false);
    }
}

//+------------------------------------------------------------------+
//| Average ticks/sec label below cumulatives                        |
//+------------------------------------------------------------------+
void DisplayAverageTicksPerSecond(MqlRates &rates[])
{
    double hi = rates[0].high, lo = rates[0].low;
    for(int i = 1; i < WindowSize; i++)
    {
        hi = MathMax(hi, rates[i].high);
        lo = MathMin(lo, rates[i].low);
    }
    double rng = hi - lo;
    lo -= rng * 0.1;
    double bottom = lo - rng * 0.25;

    datetime st  = rates[WindowSize - 1].time;
    datetime en  = rates[0].time;
    datetime mid = st + (en - st) / 2;

    string name = "AvgTicksPerSec";
    ObjectDelete(0, name);
    if(ObjectCreate(0, name, OBJ_TEXT, 0, mid, bottom))
    {
        ObjectSetString (0, name, OBJPROP_TEXT, "Avg Ts: " + DoubleToString(averageTicksPerSecond, 2) + "/s");
        ObjectSetInteger(0, name, OBJPROP_COLOR, GetTicksPerSecColor(averageTicksPerSecond));
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, TEXT_SIZE + 1);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
    }
}

//+------------------------------------------------------------------+
//| Signal arrow on chart                                            |
//+------------------------------------------------------------------+
void DisplaySignal(string signal, color clr)
{
    string name = "Current_Signal";
    ObjectDelete(0, name);

    if(ObjectCreate(0, name, OBJ_TEXT, 0, TimeCurrent(), SymbolInfoDouble(_Symbol, SYMBOL_BID)))
    {
        string txt = signal + StringFormat("\nTick: %.0f/%.0f | Vol: %.0f/%.0f",
            dynamicTickBuyThreshold, dynamicTickSellThreshold,
            dynamicVolumeBuyThreshold, dynamicVolumeSellThreshold);
        ObjectSetString (0, name, OBJPROP_TEXT, txt);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, TEXT_SIZE + 2);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
    }
}

//+------------------------------------------------------------------+
//| Time-filter status labels                                        |
//+------------------------------------------------------------------+
void DisplayTimeFilterStatus()
{
    string sn = "TimeFilter_Status";
    ObjectDelete(0, sn);

    bool ok = IsTradingAllowed();
    if(ObjectCreate(0, sn, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, sn, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, sn, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, sn, OBJPROP_YDISTANCE, 20);
        ObjectSetString (0, sn, OBJPROP_TEXT, "Trading: " + (ok ? "ALLOWED" : "BLOCKED"));
        ObjectSetInteger(0, sn, OBJPROP_COLOR, ok ? clrLime : clrRed);
        ObjectSetInteger(0, sn, OBJPROP_FONTSIZE, TEXT_SIZE);
        ObjectSetInteger(0, sn, OBJPROP_BACK, false);
    }

    if(EnableTimeFilter)
    {
        string sesName = "TimeFilter_Session";
        ObjectDelete(0, sesName);

        MqlDateTime t;
        TimeToStruct(TimeCurrent(), t);
        string days[7] = {"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"};

        if(ObjectCreate(0, sesName, OBJ_LABEL, 0, 0, 0))
        {
            ObjectSetInteger(0, sesName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, sesName, OBJPROP_XDISTANCE, 10);
            ObjectSetInteger(0, sesName, OBJPROP_YDISTANCE, 40);
            ObjectSetString (0, sesName, OBJPROP_TEXT, days[t.day_of_week] + " " +
                             StringFormat("%02d:%02d", t.hour, t.min));
            ObjectSetInteger(0, sesName, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, sesName, OBJPROP_FONTSIZE, TEXT_SIZE);
            ObjectSetInteger(0, sesName, OBJPROP_BACK, false);
        }
    }
}

//+------------------------------------------------------------------+
//| Dynamic threshold HUD (top-right corner)                         |
//+------------------------------------------------------------------+
void DisplayDynamicThresholds()
{
    string name = "DynamicThresholds_Display";
    ObjectDelete(0, name);

    string txt = StringFormat(
        "DYNAMIC THRESHOLDS (Mult: %.2f)\n"
        "Tick: %.0f / %.0f\n"
        "Vol:  %.0f / %.0f\n"
        "Data: T[%d/%d] V[%d/%d]",
        ThresholdMultiplier,
        dynamicTickBuyThreshold, dynamicTickSellThreshold,
        dynamicVolumeBuyThreshold, dynamicVolumeSellThreshold,
        tickAnalysisCount, AnalysisWindowSize,
        volumeAnalysisCount, AnalysisWindowSize);

    if(ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 60);
        ObjectSetString (0, name, OBJPROP_TEXT, txt);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrCyan);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, TEXT_SIZE);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
    }
}

//+------------------------------------------------------------------+
//| Draw tick + volume analysis window rectangles on chart           |
//+------------------------------------------------------------------+
void DrawThresholdWindows()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, AnalysisWindowSize, rates) <= 0) return;

    // --- Tick analysis window ---
    if(tickAnalysisCount > 0)
    {
        datetime tStart = tickAnalysisTimes[tickAnalysisCount - 1];
        datetime tEnd   = tickAnalysisTimes[0];
        double   tHi = -DBL_MAX, tLo = DBL_MAX;

        for(int i = 0; i < tickAnalysisCount; i++)
            for(int j = 0; j < ArraySize(rates); j++)
                if(rates[j].time == tickAnalysisTimes[i])
                {
                    tHi = MathMax(tHi, rates[j].high);
                    tLo = MathMin(tLo, rates[j].low);
                    break;
                }

        if(tHi > -DBL_MAX)
        {
            double rng = tHi - tLo;
            tHi += rng * 0.1;
            tLo -= rng * 0.1;

            ObjectDelete(0, "TickAnalysisWindow");
            if(ObjectCreate(0, "TickAnalysisWindow", OBJ_RECTANGLE, 0, tStart, tLo, tEnd, tHi))
            {
                ObjectSetInteger(0, "TickAnalysisWindow", OBJPROP_COLOR, TICK_WINDOW_COLOR);
                ObjectSetInteger(0, "TickAnalysisWindow", OBJPROP_STYLE, STYLE_SOLID);
                ObjectSetInteger(0, "TickAnalysisWindow", OBJPROP_WIDTH, THRESHOLD_WINDOW_WIDTH);
                ObjectSetInteger(0, "TickAnalysisWindow", OBJPROP_BACK, true);
                ObjectSetInteger(0, "TickAnalysisWindow", OBJPROP_FILL, false);
                ObjectSetInteger(0, "TickAnalysisWindow", OBJPROP_SELECTABLE, false);
            }

            string lbl = "TickWindowLabel";
            ObjectDelete(0, lbl);
            if(ObjectCreate(0, lbl, OBJ_TEXT, 0, tStart, tHi))
            {
                ObjectSetString (0, lbl, OBJPROP_TEXT, "Tick Analysis (" + string(tickAnalysisCount) + "/" + string(AnalysisWindowSize) + ")");
                ObjectSetInteger(0, lbl, OBJPROP_COLOR, TICK_WINDOW_COLOR);
                ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, TEXT_SIZE - 1);
                ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
                ObjectSetInteger(0, lbl, OBJPROP_BACK, false);
            }

            string thName = "TickThresholds_Display";
            ObjectDelete(0, thName);
            if(ObjectCreate(0, thName, OBJ_TEXT, 0, tStart + (tEnd - tStart) / 2, tLo - rng * 0.1))
            {
                ObjectSetString (0, thName, OBJPROP_TEXT, StringFormat("Tick Th: %.0f / %.0f", dynamicTickBuyThreshold, dynamicTickSellThreshold));
                ObjectSetInteger(0, thName, OBJPROP_COLOR, TICK_WINDOW_COLOR);
                ObjectSetInteger(0, thName, OBJPROP_FONTSIZE, TEXT_SIZE);
                ObjectSetInteger(0, thName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                ObjectSetInteger(0, thName, OBJPROP_BACK, false);
            }
        }
    }

    // --- Volume analysis window ---
    if(volumeAnalysisCount > 0)
    {
        datetime vStart = volumeAnalysisTimes[volumeAnalysisCount - 1];
        datetime vEnd   = volumeAnalysisTimes[0];
        double   vHi = -DBL_MAX, vLo = DBL_MAX;

        for(int i = 0; i < volumeAnalysisCount; i++)
            for(int j = 0; j < ArraySize(rates); j++)
                if(rates[j].time == volumeAnalysisTimes[i])
                {
                    vHi = MathMax(vHi, rates[j].high);
                    vLo = MathMin(vLo, rates[j].low);
                    break;
                }

        if(vHi > -DBL_MAX)
        {
            double rng = vHi - vLo;
            vHi += rng * 0.1;
            vLo -= rng * 0.1;

            ObjectDelete(0, "VolumeAnalysisWindow");
            if(ObjectCreate(0, "VolumeAnalysisWindow", OBJ_RECTANGLE, 0, vStart, vLo, vEnd, vHi))
            {
                ObjectSetInteger(0, "VolumeAnalysisWindow", OBJPROP_COLOR, VOLUME_WINDOW_COLOR);
                ObjectSetInteger(0, "VolumeAnalysisWindow", OBJPROP_STYLE, STYLE_SOLID);
                ObjectSetInteger(0, "VolumeAnalysisWindow", OBJPROP_WIDTH, THRESHOLD_WINDOW_WIDTH);
                ObjectSetInteger(0, "VolumeAnalysisWindow", OBJPROP_BACK, true);
                ObjectSetInteger(0, "VolumeAnalysisWindow", OBJPROP_FILL, false);
                ObjectSetInteger(0, "VolumeAnalysisWindow", OBJPROP_SELECTABLE, false);
            }

            string lbl = "VolumeWindowLabel";
            ObjectDelete(0, lbl);
            if(ObjectCreate(0, lbl, OBJ_TEXT, 0, vStart, vHi))
            {
                ObjectSetString (0, lbl, OBJPROP_TEXT, "Volume Analysis (" + string(volumeAnalysisCount) + "/" + string(AnalysisWindowSize) + ")");
                ObjectSetInteger(0, lbl, OBJPROP_COLOR, VOLUME_WINDOW_COLOR);
                ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, TEXT_SIZE - 1);
                ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
                ObjectSetInteger(0, lbl, OBJPROP_BACK, false);
            }

            string thName = "VolumeThresholds_Display";
            ObjectDelete(0, thName);
            if(ObjectCreate(0, thName, OBJ_TEXT, 0, vStart + (vEnd - vStart) / 2, vHi + rng * 0.1))
            {
                ObjectSetString (0, thName, OBJPROP_TEXT, StringFormat("Vol Th: %.0f / %.0f", dynamicVolumeBuyThreshold, dynamicVolumeSellThreshold));
                ObjectSetInteger(0, thName, OBJPROP_COLOR, VOLUME_WINDOW_COLOR);
                ObjectSetInteger(0, thName, OBJPROP_FONTSIZE, TEXT_SIZE);
                ObjectSetInteger(0, thName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                ObjectSetInteger(0, thName, OBJPROP_BACK, false);
            }
        }
    }

    DisplayWindowStatistics();
}

//+------------------------------------------------------------------+
//| Window statistics (median, MAD) in top-right corner              |
//+------------------------------------------------------------------+
void DisplayWindowStatistics()
{
    double tickMed = 0, tickMAD2 = 0;
    if(tickAnalysisCount > 0)
    {
        double tmp[];
        ArrayResize(tmp, tickAnalysisCount);
        ArrayCopy(tmp, tickAnalysisData, 0, 0, tickAnalysisCount);
        tickMed  = CalculateMedian(tmp, tickAnalysisCount);
        tickMAD2 = CalculateMAD(tmp, tickMed, tickAnalysisCount);
    }

    string tsn = "TickWindowStats";
    ObjectDelete(0, tsn);
    if(ObjectCreate(0, tsn, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, tsn, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, tsn, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, tsn, OBJPROP_YDISTANCE, 60);
        ObjectSetString (0, tsn, OBJPROP_TEXT, StringFormat("Tick Stats | Med: %.0f | MAD: %.0f | Mult: %.2f",
            tickMed, tickMAD2, ThresholdMultiplier));
        ObjectSetInteger(0, tsn, OBJPROP_COLOR, TICK_WINDOW_COLOR);
        ObjectSetInteger(0, tsn, OBJPROP_FONTSIZE, TEXT_SIZE - 1);
        ObjectSetInteger(0, tsn, OBJPROP_BACK, false);
    }

    double volMed = 0, volMAD2 = 0;
    if(volumeAnalysisCount > 0)
    {
        double tmp2[];
        ArrayResize(tmp2, volumeAnalysisCount);
        ArrayCopy(tmp2, volumeAnalysisData, 0, 0, volumeAnalysisCount);
        volMed  = CalculateMedian(tmp2, volumeAnalysisCount);
        volMAD2 = CalculateMAD(tmp2, volMed, volumeAnalysisCount);
    }

    string vsn = "VolumeWindowStats";
    ObjectDelete(0, vsn);
    if(ObjectCreate(0, vsn, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, vsn, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, vsn, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, vsn, OBJPROP_YDISTANCE, 80);
        ObjectSetString (0, vsn, OBJPROP_TEXT, StringFormat("Vol Stats | Med: %.0f | MAD: %.0f | Mult: %.2f",
            volMed, volMAD2, ThresholdMultiplier));
        ObjectSetInteger(0, vsn, OBJPROP_COLOR, VOLUME_WINDOW_COLOR);
        ObjectSetInteger(0, vsn, OBJPROP_FONTSIZE, TEXT_SIZE - 1);
        ObjectSetInteger(0, vsn, OBJPROP_BACK, false);
    }
}

//+------------------------------------------------------------------+
//| Refresh threshold window display                                 |
//+------------------------------------------------------------------+
void UpdateThresholdWindows()
{
    ObjectDelete(0, "TickAnalysisWindow");
    ObjectDelete(0, "VolumeAnalysisWindow");
    ObjectDelete(0, "TickWindowLabel");
    ObjectDelete(0, "VolumeWindowLabel");
    ObjectDelete(0, "TickThresholds_Display");
    ObjectDelete(0, "VolumeThresholds_Display");
    ObjectDelete(0, "TickWindowStats");
    ObjectDelete(0, "VolumeWindowStats");

    DrawThresholdWindows();
}

//+------------------------------------------------------------------+
//| Clean up all chart objects on deinit                              |
//+------------------------------------------------------------------+
void CleanupObjects()
{
    ObjectsDeleteAll(0, "Delta_");
    ObjectsDeleteAll(0, "Cumulative_");
    ObjectsDeleteAll(0, "Signal_");
    ObjectsDeleteAll(0, "VolumeFootprint_");
    ObjectsDeleteAll(0, "TimeFilter_");
    ObjectsDeleteAll(0, "TicksPerSecond_");
    ObjectsDeleteAll(0, "AvgTicks");
    ObjectsDeleteAll(0, "Threshold_");
    ObjectsDeleteAll(0, "Window_");
    ObjectDelete(0, "SlidingWindow_Rect");
    ObjectDelete(0, "VolumeFootprint_Line");
    ObjectDelete(0, "TickAnalysisWindow");
    ObjectDelete(0, "VolumeAnalysisWindow");
    ObjectDelete(0, "TickWindowLabel");
    ObjectDelete(0, "VolumeWindowLabel");
    ObjectDelete(0, "TickThresholds_Display");
    ObjectDelete(0, "VolumeThresholds_Display");
    ObjectDelete(0, "TickWindowStats");
    ObjectDelete(0, "VolumeWindowStats");
    ObjectDelete(0, "Current_Signal");
    ObjectDelete(0, "DynamicThresholds_Display");
    ObjectDelete(0, "AvgTicksPerSec");
}

#endif
