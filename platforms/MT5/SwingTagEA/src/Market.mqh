//+------------------------------------------------------------------+
//| Market.mqh — SwingTagEA                                         |
//| Price data retrieval. No signal logic, no trade logic.          |
//+------------------------------------------------------------------+
#ifndef SWINGTAGEA_MARKET_MQH
#define SWINGTAGEA_MARKET_MQH

#include "Config.mqh"

//--- Holds the three-bar window used by the strategy.
//    Naming convention: old = bar[3], mid = bar[2], new_ = bar[1]
//    (bar[0] is the live/incomplete bar and is never used)
struct CandleData
{
   double   highOld,  highMid,  highNew;
   double   lowOld,   lowMid,   lowNew;
   datetime timeOld,  timeMid,  timeNew;
};

//+------------------------------------------------------------------+
//| Fills data with bars [3], [2], [1] for the current symbol/period.|
//| Returns false when there are not enough bars.                    |
//+------------------------------------------------------------------+
bool GetCandleData(CandleData &data)
{
   if(Bars(_Symbol, _Period) < MIN_BARS_REQUIRED)
      return false;

   data.highOld = iHigh(_Symbol, _Period, 3);
   data.highMid = iHigh(_Symbol, _Period, 2);
   data.highNew = iHigh(_Symbol, _Period, 1);

   data.lowOld  = iLow(_Symbol, _Period, 3);
   data.lowMid  = iLow(_Symbol, _Period, 2);
   data.lowNew  = iLow(_Symbol, _Period, 1);

   data.timeOld = iTime(_Symbol, _Period, 3);
   data.timeMid = iTime(_Symbol, _Period, 2);
   data.timeNew = iTime(_Symbol, _Period, 1);

   return true;
}

#endif // SWINGTAGEA_MARKET_MQH
