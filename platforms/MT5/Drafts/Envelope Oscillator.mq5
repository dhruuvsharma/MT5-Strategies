//+------------------------------------------------------------------+
//|                                          Envelope Oscillator.mq5 |
//|                                                     Dhruv Sharma |
//|     Consolidated from: Envelope Oscillator, LSF-X-Engine.        |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      "www.linkedin.com/in/dhruvsharmainfo"
#property version   "2.00"

#include <Trade\Trade.mqh>

input group "RSI Parameters"
input int    rsiPeriod   = 14;      // RSI Period
input double overbought  = 70.0;    // Overbought Level
input double oversold    = 30.0;    // Oversold Level

input group "Trade Settings"
input double lotSize     = 0.1;     // Trade Volume
input int    stopLoss    = 200;     // SL (points)
input int    takeProfit  = 400;     // TP (points)
input ulong  magicNumber = 12345;   // Magic Number

input group "Execution Robustness"
input bool   ValidateStopsAgainstSymbol = true; // Reject orders below SYMBOL_TRADE_STOPS_LEVEL
input int    OrderRetryAttempts         = 3;    // Retry attempts on transient failures
input int    OrderRetryDelayMs          = 500;  // Delay between retries (ms)

CTrade trade;
int    rsiHandle;
double rsiBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(magicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);

   rsiHandle = iRSI(_Symbol, _Period, rsiPeriod, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE)
   {
      Print("[EnvelopeOsc] Failed to create RSI indicator");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(rsiBuffer, true);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
}

//+------------------------------------------------------------------+
void OnTick()
{
   static datetime previousBar = 0;
   datetime currentBar = iTime(_Symbol, _Period, 0);
   if(previousBar == currentBar) return;
   previousBar = currentBar;

   if(CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) < 3)
   {
      Print("[EnvelopeOsc] Failed to copy RSI buffer");
      return;
   }
   CheckForSignals(rsiBuffer[0], rsiBuffer[1]);
}

//+------------------------------------------------------------------+
void CheckForSignals(double currentRSI, double previousRSI)
{
   if(currentRSI > oversold && previousRSI <= oversold)
   {
      if(CloseAllPositions()) ExecuteTrade(ORDER_TYPE_BUY);
   }
   else if(currentRSI < overbought && previousRSI >= overbought)
   {
      if(CloseAllPositions()) ExecuteTrade(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| Execute trade with retry + symbol-aware stop validation          |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
   MqlTick lastTick;
   if(!SymbolInfoTick(_Symbol, lastTick))
   {
      Print("[EnvelopeOsc] Failed to get tick data");
      return;
   }

   for(int attempt = 1; attempt <= OrderRetryAttempts; attempt++)
   {
      double price = orderType == ORDER_TYPE_BUY ? lastTick.ask : lastTick.bid;
      double sl    = orderType == ORDER_TYPE_BUY ? price - stopLoss   * _Point : price + stopLoss   * _Point;
      double tp    = orderType == ORDER_TYPE_BUY ? price + takeProfit * _Point : price - takeProfit * _Point;

      if(ValidateStopsAgainstSymbol && !ValidateStopLevels(orderType, price, sl, tp))
      {
         Print("[EnvelopeOsc] Stops too close to market (broker SYMBOL_TRADE_STOPS_LEVEL).");
         return;
      }

      bool ok = orderType == ORDER_TYPE_BUY
                ? trade.Buy(lotSize,  _Symbol, price, sl, tp)
                : trade.Sell(lotSize, _Symbol, price, sl, tp);

      if(ok) { VerifyStops(trade.ResultOrder(), sl, tp); return; }

      HandleTradeError(trade.ResultRetcode());
      SymbolInfoTick(_Symbol, lastTick); // refresh
      Sleep(OrderRetryDelayMs);
   }
}

//+------------------------------------------------------------------+
bool ValidateStopLevels(ENUM_ORDER_TYPE type, double price, double sl, double tp)
{
   double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(minDist <= 0) return true;

   if(type == ORDER_TYPE_BUY)
      return (price - sl) >= minDist && (tp - price) >= minDist;
   return (sl - price) >= minDist && (price - tp) >= minDist;
}

//+------------------------------------------------------------------+
void HandleTradeError(int retcode)
{
   switch(retcode)
   {
      case 10018: Print("[EnvelopeOsc] Requote, retrying..."); break;
      case 4756:  Print("[EnvelopeOsc] Market closed - check trading hours"); break;
      default:    Print("[EnvelopeOsc] Trade error: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
void VerifyStops(ulong ticket, double wantSL, double wantTP)
{
   if(!PositionSelectByTicket(ticket)) return;
   double curSL = PositionGetDouble(POSITION_SL);
   double curTP = PositionGetDouble(POSITION_TP);
   if(curSL == 0.0 || curTP == 0.0 || curSL != wantSL || curTP != wantTP)
   {
      Print("[EnvelopeOsc] SL/TP not applied as expected. Retrying...");
      trade.PositionModify(ticket, wantSL, wantTP);
   }
}

//+------------------------------------------------------------------+
bool CloseAllPositions()
{
   bool allClosed = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)   != _Symbol)      continue;
      if(PositionGetInteger(POSITION_MAGIC)   != (long)magicNumber) continue;

      bool closed = false;
      for(int attempt = 1; attempt <= OrderRetryAttempts; attempt++)
      {
         if(trade.PositionClose(ticket)) { closed = true; break; }
         Print("[EnvelopeOsc] Close error: ", trade.ResultRetcodeDescription());
         Sleep(OrderRetryDelayMs);
      }
      if(!closed) allClosed = false;
   }
   return allClosed;
}
//+------------------------------------------------------------------+
