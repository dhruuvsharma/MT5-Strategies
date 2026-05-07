//+------------------------------------------------------------------+
//| Trade.mqh — Order placement, fast exits, breakeven                |
//+------------------------------------------------------------------+
#ifndef TRADE_MQH
#define TRADE_MQH

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include "Risk.mqh"

CTrade        g_trade;
CPositionInfo g_posInfo;

//+------------------------------------------------------------------+
//| One-shot init                                                     |
//+------------------------------------------------------------------+
void TradeInit()
{
   g_trade.SetExpertMagicNumber(MagicNumber);
   g_trade.SetDeviationInPoints(Slippage);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
}

//+------------------------------------------------------------------+
//| Do we already have a position on this symbol+magic?              |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_posInfo.SelectByIndex(i))
      {
         if(g_posInfo.Symbol() == _Symbol && g_posInfo.Magic() == MagicNumber)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Open a market order in the given direction with risk-based lots  |
//+------------------------------------------------------------------+
bool OpenTrade(int direction)
{
   double slDist = CalcSLDistance();
   double tpDist = CalcTPDistance();
   if(slDist <= 0 || tpDist <= 0)
   {
      Print(EA_PREFIX, "Invalid SL/TP. SL=", slDist, " TP=", tpDist);
      return false;
   }

   double lots = CalcLotSize();
   if(lots <= 0)
   {
      Print(EA_PREFIX, "Lot size = 0. Skipping.");
      return false;
   }

   bool   ok    = false;
   double price = 0.0, sl = 0.0, tp = 0.0;

   if(direction > 0)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = NormalizeDouble(price - slDist, _Digits);
      tp = NormalizeDouble(price + tpDist, _Digits);
      ok = g_trade.Buy(lots, _Symbol, 0.0, sl, tp, EAComment);
   }
   else if(direction < 0)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = NormalizeDouble(price + slDist, _Digits);
      tp = NormalizeDouble(price - tpDist, _Digits);
      ok = g_trade.Sell(lots, _Symbol, 0.0, sl, tp, EAComment);
   }
   else return false;

   if(ok)
   {
      g_breakevenApplied   = false;
      g_lastTradeTime      = TimeCurrent();
      g_openTradeTime      = TimeCurrent();
      g_openTradeDirection = direction;
      g_sessionTradeCount++;
#ifndef BACKTEST_MODE
      Print(EA_PREFIX, (direction > 0 ? "BUY" : "SELL"),
            " opened. Lots=", lots, " SL=", sl, " TP=", tp,
            " Session=", SessionName(g_currentSession));
#endif
   }
#ifndef BACKTEST_MODE
   else
      Print(EA_PREFIX, "Open failed. Dir=", direction, " Error=", GetLastError());
#endif

   return ok;
}

//+------------------------------------------------------------------+
//| Close our matching position by ticket                             |
//+------------------------------------------------------------------+
void CloseOurPosition(string reason)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_posInfo.SelectByIndex(i)) continue;
      if(g_posInfo.Symbol() != _Symbol || g_posInfo.Magic() != MagicNumber) continue;

      if(g_trade.PositionClose(g_posInfo.Ticket()))
      {
#ifndef BACKTEST_MODE
         Print(EA_PREFIX, "Position closed. Reason=", reason);
#endif
         g_openTradeDirection = 0;
         g_openTradeTime      = 0;
      }
#ifndef BACKTEST_MODE
      else
         Print(EA_PREFIX, "Close failed. Error=", GetLastError());
#endif
      return;
   }
}

//+------------------------------------------------------------------+
//| Move SL to entry + buffer once profit threshold is hit            |
//+------------------------------------------------------------------+
void ApplyBreakeven()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_posInfo.SelectByIndex(i)) continue;
      if(g_posInfo.Symbol() != _Symbol || g_posInfo.Magic() != MagicNumber) continue;

      double openPrice = g_posInfo.PriceOpen();
      double currentSL = g_posInfo.StopLoss();
      double tp        = g_posInfo.TakeProfit();
      double beBuffer  = BE_BUFFER_PIPS * g_pipSize;

      if(g_posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double profitPips = (bid - openPrice) / g_pipSize;
         if(profitPips < BreakevenPips) return;
         double newSL = NormalizeDouble(openPrice + beBuffer, _Digits);
         if(newSL > currentSL && g_trade.PositionModify(g_posInfo.Ticket(), newSL, tp))
         {
            g_breakevenApplied = true;
#ifndef BACKTEST_MODE
            Print(EA_PREFIX, "BE applied. SL=", newSL);
#endif
         }
      }
      else if(g_posInfo.PositionType() == POSITION_TYPE_SELL)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profitPips = (openPrice - ask) / g_pipSize;
         if(profitPips < BreakevenPips) return;
         double newSL = NormalizeDouble(openPrice - beBuffer, _Digits);
         if((currentSL == 0.0 || newSL < currentSL) && g_trade.PositionModify(g_posInfo.Ticket(), newSL, tp))
         {
            g_breakevenApplied = true;
#ifndef BACKTEST_MODE
            Print(EA_PREFIX, "BE applied. SL=", newSL);
#endif
         }
      }
      return;
   }
}

//+------------------------------------------------------------------+
//| Time exit: close at market if neither TP/SL hit by deadline       |
//+------------------------------------------------------------------+
bool _TryTimeExit()
{
   if(MaxTradeSeconds <= 0 || g_openTradeTime <= 0) return false;
   if(TimeCurrent() < g_openTradeTime + MaxTradeSeconds) return false;
   CloseOurPosition("TIME_EXIT");
   return true;
}

//+------------------------------------------------------------------+
//| Adverse delta: close when cumDelta crosses against position       |
//+------------------------------------------------------------------+
bool _TryAdverseExit()
{
   if(!AdverseDeltaExit || g_openTradeTime <= 0 || g_openTradeDirection == 0)
      return false;
   if(TimeCurrent() - g_openTradeTime < AdverseDeltaCooldown) return false;

   int cum = CalculateCumDelta();
   bool adverse = (g_openTradeDirection > 0 && cum < -DeltaThreshold) ||
                  (g_openTradeDirection < 0 && cum >  DeltaThreshold);
   if(!adverse) return false;
   CloseOurPosition("ADVERSE_DELTA");
   return true;
}

//+------------------------------------------------------------------+
//| Manage open trade: time exit → adverse exit → breakeven           |
//+------------------------------------------------------------------+
void ManageOpenTrade()
{
   if(!HasOpenPosition())
   {
      if(g_openTradeDirection != 0)
      {
         g_openTradeDirection = 0;
         g_openTradeTime      = 0;
      }
      return;
   }
   if(_TryTimeExit())    return;
   if(_TryAdverseExit()) return;
   if(UseBreakeven && !g_breakevenApplied)
      ApplyBreakeven();
}

#endif
