//+------------------------------------------------------------------+
//|                                              GoldenLadder EA.mq5 |
//|                                                     Dhruv Sharma |
//|  Consolidated from: GoldenLadder EA, GoldenLadderAdvanceEA,      |
//|                     StatArbX, StatArbX_Valid_March, XAUUSD HFT.  |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      ""
#property version   "2.00"

#include <Trade\Trade.mqh>
CTrade trade;

// === Lot sizing ===
input bool    UseDynamicLot         = true;     // Enable dynamic lot sizing
input double  AccountSizeForBaseLot = 100.0;    // Account balance per base lot
input double  BaseLot               = 0.01;     // Base lot size

// === Order ladder ===
input int     OrderCount            = 1;        // Number of orders per direction
input double  StepDistance          = 0.05;     // Distance between orders
input double  EntryDistance         = 0.20;     // Initial entry distance
input double  TakeProfit            = 0.40;     // Take profit distance (price units)

// === SL mode === (was: GoldenLadderAdvance / StatArbX add prev-candle SL)
enum ENUM_SL_MODE { SL_NONE, SL_BAR_OPEN, SL_PREV_CANDLE_HL };
input ENUM_SL_MODE SLMode           = SL_BAR_OPEN; // SL anchor

// === Time window ===
input int     StartHour             = 13;       // Start hour (0-23)
input int     StartMinute           = 0;        // Start minute (0-59)
input int     EndHour               = 16;       // End hour (0-23)
input int     EndMinute             = 0;        // End minute (0-59)
input bool    UseServerTime         = true;     // Use server time (else local)

// === Misc ===
input ulong   MagicNumber           = 12345;    // EA Magic Number (0 = no filter)

// === Position management === (from GoldenLadderAdvance)
input bool    UseTPHitWatchdog      = false;    // Force-close-all when any pos hits TP

// === Time-bomb === (from StatArbX_Valid_March)
input bool    UseExpiration         = false;    // Enable hard expiration date
input datetime ExpirationDate       = D'2026.12.31 23:59:59'; // EA stops after this

// === Globals ===
datetime lastBarTime;
bool     tpTriggered = false;

//+------------------------------------------------------------------+
int OnInit()
{
   lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   trade.SetExpertMagicNumber(MagicNumber);

   if(UseExpiration && TimeCurrent() >= ExpirationDate)
   {
      Alert("[GoldenLadder] EA has expired. Contact developer.");
      return INIT_FAILED;
   }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(UseExpiration && TimeCurrent() >= ExpirationDate)
   {
      CloseAllPositions();
      DeleteAllOrders();
      Comment("[GoldenLadder] EA expired. Stopped.");
      return;
   }

   if(UseTPHitWatchdog && !tpTriggered && CheckForTPHit())
   {
      CloseAllPositions();
      DeleteAllOrders();
      tpTriggered = true;
   }

   datetime currentTime[1];
   CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, currentTime);

   if(currentTime[0] != lastBarTime)
   {
      lastBarTime  = currentTime[0];
      tpTriggered  = false;

      if(IsTradingTime())
      {
         CloseAllPositions();
         DeleteAllOrders();
         PlacePendingOrders();
      }
   }
}

//+------------------------------------------------------------------+
bool IsTradingTime()
{
   datetime now = UseServerTime ? TimeCurrent() : TimeLocal();
   MqlDateTime t;
   TimeToStruct(now, t);

   int cur   = t.hour * 60 + t.min;
   int start = StartHour * 60 + StartMinute;
   int end   = EndHour   * 60 + EndMinute;

   if(start < end)
      return (cur >= start && cur < end);
   return (cur >= start || cur < end);
}

//+------------------------------------------------------------------+
double CalculateLotSize()
{
   if(!UseDynamicLot) return BaseLot;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double lot     = (balance / AccountSizeForBaseLot) * BaseLot;

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathRound(lot / lotStep) * lotStep;
   lot = fmax(lot, minLot);
   lot = fmin(lot, maxLot);
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && (MagicNumber == 0 || PositionGetInteger(POSITION_MAGIC) == MagicNumber))
         trade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+
void DeleteAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && (MagicNumber == 0 || OrderGetInteger(ORDER_MAGIC) == MagicNumber))
         trade.OrderDelete(ticket);
   }
}

//+------------------------------------------------------------------+
bool CheckForTPHit()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(MagicNumber != 0 && PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      double tp = PositionGetDouble(POSITION_TP);
      if(tp <= 0) continue;

      ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double price = pt == POSITION_TYPE_BUY
                     ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                     : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if((pt == POSITION_TYPE_BUY  && price >= tp) ||
         (pt == POSITION_TYPE_SELL && price <= tp))
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void PlacePendingOrders()
{
   MqlRates curr[1], prev[1];
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, curr) < 1) return;
   if(SLMode == SL_PREV_CANDLE_HL && CopyRates(_Symbol, PERIOD_CURRENT, 1, 1, prev) < 1) return;

   double openPrice = curr[0].open;
   double lotSize   = CalculateLotSize();
   int    digits    = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   for(int i = 0; i < OrderCount; i++)
   {
      double buyEntry  = NormalizeDouble(openPrice + EntryDistance + (i * StepDistance), digits);
      double sellEntry = NormalizeDouble(openPrice - EntryDistance - (i * StepDistance), digits);
      double tpBuy     = NormalizeDouble(buyEntry  + TakeProfit, digits);
      double tpSell    = NormalizeDouble(sellEntry - TakeProfit, digits);

      double slBuy  = 0, slSell = 0;
      if(SLMode == SL_BAR_OPEN)
      {
         slBuy  = openPrice;
         slSell = openPrice;
      }
      else if(SLMode == SL_PREV_CANDLE_HL)
      {
         slBuy  = prev[0].low;
         slSell = prev[0].high;
      }

      trade.OrderOpen(_Symbol, ORDER_TYPE_BUY_STOP,  lotSize, 0, buyEntry,  slBuy,  tpBuy,  ORDER_TIME_GTC, 0, "BuyStop Order");
      trade.OrderOpen(_Symbol, ORDER_TYPE_SELL_STOP, lotSize, 0, sellEntry, slSell, tpSell, ORDER_TIME_GTC, 0, "SellStop Order");
   }
}
//+------------------------------------------------------------------+
