//+------------------------------------------------------------------+
//| Signal.mqh — SwingTagEA                                         |
//| Three-bar swing pivot detection. No trade logic, no drawing.    |
//+------------------------------------------------------------------+
#ifndef SWINGTAGEA_SIGNAL_MQH
#define SWINGTAGEA_SIGNAL_MQH

#include "Config.mqh"
#include "Market.mqh"

//--- NOTE (preserved bug):
//    The original IsAboveLine() contained a math error: the slope was
//    multiplied by the full time span, so linePrice always reduced to
//    endPrice regardless of the test bar's timestamp. The effective
//    logic was therefore a simple "testPrice > endPrice" comparison.
//    This behavior is preserved exactly to maintain the original edge.
//    See Known Issues in Signal.mem.md for full analysis.

//+------------------------------------------------------------------+
//| Returns true when the mid bar's HIGH is above the old bar's HIGH.|
//+------------------------------------------------------------------+
bool IsMidHighAboveOld(const CandleData &data)
{
   return data.highMid > data.highOld;
}

//+------------------------------------------------------------------+
//| Returns true when the mid bar's LOW is above the old bar's LOW.  |
//+------------------------------------------------------------------+
bool IsMidLowAboveOld(const CandleData &data)
{
   return data.lowMid > data.lowOld;
}

//+------------------------------------------------------------------+
//| Detects a bearish pivot: mid bar is structurally HIGHER than old |
//| bar (both high and low above). Signal: SELL LIMIT at mid high.   |
//+------------------------------------------------------------------+
bool DetectBearishPivot(const CandleData &data)
{
   return IsMidHighAboveOld(data) && IsMidLowAboveOld(data);
}

//+------------------------------------------------------------------+
//| Detects a bullish pivot: mid bar is structurally LOWER than old  |
//| bar (both high and low below). Signal: BUY LIMIT at mid low.     |
//+------------------------------------------------------------------+
bool DetectBullishPivot(const CandleData &data)
{
   return !IsMidHighAboveOld(data) && !IsMidLowAboveOld(data);
}

//+------------------------------------------------------------------+
//| Evaluates both pivot types and returns signal if found.          |
//| Returns false when no actionable signal is present (mixed bars). |
//+------------------------------------------------------------------+
bool GetSignal(const CandleData &data, ENUM_ORDER_TYPE &signalType, double &entryPrice)
{
   if(DetectBearishPivot(data))
   {
      signalType = ORDER_TYPE_SELL_LIMIT;
      entryPrice = data.highMid;
      return true;
   }
   if(DetectBullishPivot(data))
   {
      signalType = ORDER_TYPE_BUY_LIMIT;
      entryPrice = data.lowMid;
      return true;
   }
   return false;
}

#endif // SWINGTAGEA_SIGNAL_MQH
