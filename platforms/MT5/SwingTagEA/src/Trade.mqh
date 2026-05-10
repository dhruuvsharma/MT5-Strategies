//+------------------------------------------------------------------+
//| Trade.mqh — SwingTagEA                                          |
//| Order placement, deletion, position checks via CTrade.          |
//+------------------------------------------------------------------+
#ifndef SWINGTAGEA_TRADE_MQH
#define SWINGTAGEA_TRADE_MQH

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include "Config.mqh"
#include "Risk.mqh"

CTrade        g_trade;
CPositionInfo g_position;
COrderInfo    g_order;

//+------------------------------------------------------------------+
//| Must be called once from OnInit before any trade operations.     |
//+------------------------------------------------------------------+
void InitTradeObjects()
{
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(ORDER_DEVIATION);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
}

//+------------------------------------------------------------------+
//| Returns true if an open position matching our magic + symbol     |
//| already exists in the same direction as orderType.              |
//+------------------------------------------------------------------+
bool HasActivePosition(ENUM_ORDER_TYPE orderType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_position.SelectByIndex(i))             continue;
      if(g_position.Magic()  != (long)InpMagicNumber) continue;
      if(g_position.Symbol() != _Symbol)           continue;

      ENUM_POSITION_TYPE posType = g_position.PositionType();
      if(orderType == ORDER_TYPE_BUY_LIMIT  && posType == POSITION_TYPE_BUY)  return true;
      if(orderType == ORDER_TYPE_SELL_LIMIT && posType == POSITION_TYPE_SELL) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Cancels all pending orders matching our magic + symbol + type.   |
//+------------------------------------------------------------------+
void DeletePendingOrdersByType(ENUM_ORDER_TYPE orderType)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!g_order.SelectByIndex(i))               continue;
      if(g_order.Magic()     != (long)InpMagicNumber) continue;
      if(g_order.Symbol()    != _Symbol)           continue;
      if(g_order.OrderType() != orderType)         continue;

      ResetLastError();
      if(!g_trade.OrderDelete(g_order.Ticket()))
         Print(EA_PREFIX, "OrderDelete failed ticket=", g_order.Ticket(),
               " err=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Places a pending limit order at the given price with SL/TP.      |
//| Returns true on success.                                         |
//+------------------------------------------------------------------+
bool SendPendingOrder(ENUM_ORDER_TYPE orderType, double price, double sl, double tp)
{
   double normPrice = NormalizeDouble(price, _Digits);
   double normSL    = NormalizeDouble(sl,    _Digits);
   double normTP    = NormalizeDouble(tp,    _Digits);
   double normLots  = NormalizeDouble(InpLots, 2);

   ResetLastError();
   bool ok = g_trade.OrderOpen(_Symbol, orderType, normLots, 0,
                               normPrice, normSL, normTP,
                               ORDER_TIME_GTC, 0, EA_NAME);
   if(!ok)
      Print(EA_PREFIX, "OrderOpen failed type=", EnumToString(orderType),
            " price=", normPrice, " err=", GetLastError());
   return ok;
}

//+------------------------------------------------------------------+
//| Full signal processing: checks state, cleans stale orders,       |
//| calculates SL/TP, and fires the pending order.                   |
//+------------------------------------------------------------------+
void ProcessSignal(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   if(InpOrderManagement)
   {
      if(HasActivePosition(orderType))
      {
         Print(EA_PREFIX, "Active position exists — skipping signal");
         return;
      }
      DeletePendingOrdersByType(orderType);
   }

   double sl = CalcStopLoss(orderType, entryPrice);
   double tp = CalcTakeProfit(orderType, entryPrice);
   SendPendingOrder(orderType, entryPrice, sl, tp);
}

#endif // SWINGTAGEA_TRADE_MQH
