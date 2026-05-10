//+------------------------------------------------------------------+
//| Utils.mqh — SwingTagEA                                          |
//| Chart drawing helpers and trading hours check.                  |
//+------------------------------------------------------------------+
#ifndef SWINGTAGEA_UTILS_MQH
#define SWINGTAGEA_UTILS_MQH

#include "Config.mqh"
#include "Market.mqh"

//+------------------------------------------------------------------+
//| Returns true when broker time falls within the configured        |
//| trading session window. Both endpoints are inclusive.            |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   MqlDateTime dtNow;
   TimeCurrent(dtNow);

   string startParts[], endParts[];
   if(StringSplit(InpTradingStartTime, ':', startParts) != 2) return false;
   if(StringSplit(InpTradingEndTime,   ':', endParts)   != 2) return false;

   int startSec = (int)StringToInteger(startParts[0]) * 3600
                + (int)StringToInteger(startParts[1]) * 60;
   int endSec   = (int)StringToInteger(endParts[0])   * 3600
                + (int)StringToInteger(endParts[1])   * 60;
   int nowSec   = dtNow.hour * 3600 + dtNow.min * 60 + dtNow.sec;

   return (nowSec >= startSec) && (nowSec <= endSec);
}

//+------------------------------------------------------------------+
//| Deletes all chart objects whose name starts with prefix.         |
//+------------------------------------------------------------------+
void DeleteChartObjects(string prefix)
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Draws a single trend-line segment between two price/time points. |
//+------------------------------------------------------------------+
void CreateTrendLine(string name, datetime t1, double p1,
                     datetime t2, double p2, color clr)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      LINE_WIDTH);
   ObjectSetInteger(0, name, OBJPROP_RAY,        false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK,       true);
}

//+------------------------------------------------------------------+
//| Draws a closed triangle using three trend-line segments.         |
//+------------------------------------------------------------------+
void DrawTriangle(string prefix,
                  datetime t1, double p1,
                  datetime t2, double p2,
                  datetime t3, double p3,
                  color clr)
{
   CreateTrendLine(prefix + "_1", t1, p1, t2, p2, clr);
   CreateTrendLine(prefix + "_2", t2, p2, t3, p3, clr);
   CreateTrendLine(prefix + "_3", t3, p3, t1, p1, clr);
}

//+------------------------------------------------------------------+
//| Redraws both the high and low triangles for the current bar.     |
//| highGreen / lowGreen control the colour of each triangle.        |
//+------------------------------------------------------------------+
void UpdateDrawings(const CandleData &data,
                    bool highGreen, bool lowGreen,
                    datetime currentBarTime)
{
   DeleteChartObjects(HIGH_LINE_PREFIX);
   DeleteChartObjects(LOW_LINE_PREFIX);

   string highName = HIGH_LINE_PREFIX + "_" + TimeToString(currentBarTime);
   string lowName  = LOW_LINE_PREFIX  + "_" + TimeToString(currentBarTime);

   color highColor = highGreen ? clrLimeGreen : clrIndianRed;
   color lowColor  = lowGreen  ? clrLimeGreen : clrIndianRed;

   DrawTriangle(highName,
                data.timeOld, data.highOld,
                data.timeMid, data.highMid,
                data.timeNew, data.highNew,
                highColor);

   DrawTriangle(lowName,
                data.timeOld, data.lowOld,
                data.timeMid, data.lowMid,
                data.timeNew, data.lowNew,
                lowColor);
}

#endif // SWINGTAGEA_UTILS_MQH
