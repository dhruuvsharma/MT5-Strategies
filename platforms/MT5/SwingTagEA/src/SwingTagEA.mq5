//+------------------------------------------------------------------+
//|                                               SwingTagEA.mq5    |
//|                                                   Dhruv Sharma   |
//|                         www.linkedin.com/in/dhruvsharmainfo     |
//+------------------------------------------------------------------+
//| Strategy: Identifies 3-bar swing pivots (mid bar structurally    |
//| higher or lower than the oldest of the 3 bars) and places a     |
//| limit order to fade the extreme at the mid bar's high or low.   |
//| Designed for DAX (GER40) — see README.md for full details.      |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      "www.linkedin.com/in/dhruvsharmainfo"
#property version   "2.00"

#include "Config.mqh"
#include "Market.mqh"
#include "Signal.mqh"
#include "Risk.mqh"
#include "Trade.mqh"
#include "Utils.mqh"

datetime g_lastProcessedTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   g_lastProcessedTime = 0;
   InitTradeObjects();
   Print(EA_PREFIX, "Initialised on ", _Symbol, " ", EnumToString(_Period));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteChartObjects(HIGH_LINE_PREFIX);
   DeleteChartObjects(LOW_LINE_PREFIX);
   Print(EA_PREFIX, "Deinitialised reason=", reason);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(InpUseTradingHours && !IsWithinTradingHours()) return;

   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == g_lastProcessedTime) return;
   g_lastProcessedTime = currentBarTime;

   CandleData data;
   if(!GetCandleData(data)) return;

   bool highGreen = IsMidHighAboveOld(data);
   bool lowGreen  = IsMidLowAboveOld(data);

   UpdateDrawings(data, highGreen, lowGreen, currentBarTime);

   ENUM_ORDER_TYPE signalType;
   double          entryPrice;
   if(GetSignal(data, signalType, entryPrice))
      ProcessSignal(signalType, entryPrice);
}
