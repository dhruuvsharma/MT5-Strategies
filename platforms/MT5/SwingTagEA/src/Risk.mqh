//+------------------------------------------------------------------+
//| Risk.mqh — SwingTagEA                                           |
//| SL/TP calculation from Config inputs. No trade calls.           |
//+------------------------------------------------------------------+
#ifndef SWINGTAGEA_RISK_MQH
#define SWINGTAGEA_RISK_MQH

#include "Config.mqh"

//+------------------------------------------------------------------+
//| Calculates stop loss price for the given order type and entry.   |
//+------------------------------------------------------------------+
double CalcStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   if(orderType == ORDER_TYPE_BUY_LIMIT)
      return entryPrice - InpSLPoints * _Point;
   return entryPrice + InpSLPoints * _Point;
}

//+------------------------------------------------------------------+
//| Calculates take profit price for the given order type and entry. |
//+------------------------------------------------------------------+
double CalcTakeProfit(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   if(orderType == ORDER_TYPE_BUY_LIMIT)
      return entryPrice + InpTPPoints * _Point;
   return entryPrice - InpTPPoints * _Point;
}

#endif // SWINGTAGEA_RISK_MQH
