//+------------------------------------------------------------------+
//| CumulativeDeltaScalper.mq5                                        |
//| Expert Advisor: CumulativeDeltaScalper                            |
//| Version: 1.0                                                      |
//| Description: Scalps EURUSD on short timeframes using cumulative   |
//|   tick-level delta in a sliding window. Enters when delta crosses |
//|   a threshold, filtered by 15M EMA trend and session/risk guards. |
//| Author: Dhruv Sharma                                              |
//| Date: 2025-04-11                                                  |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      ""
#property version   "2.00"
#property description "Cumulative Delta Scalper v2 — sniper sessions, risk-based sizing, fast exits"

//--- Include all layers
#include "Utils.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Validate inputs
   if(WindowSize < 2)
   {
      Print(EA_PREFIX, "WindowSize must be >= 2"); return INIT_PARAMETERS_INCORRECT;
   }
   if(DeltaThreshold <= 0)
   {
      Print(EA_PREFIX, "DeltaThreshold must be > 0"); return INIT_PARAMETERS_INCORRECT;
   }
   if(SL_Multiplier <= 0 || TP_Multiplier <= 0)
   {
      Print(EA_PREFIX, "SL/TP multipliers must be > 0"); return INIT_PARAMETERS_INCORRECT;
   }
   if(UseRiskBasedSizing)
   {
      if(RiskPercentPerTrade <= 0 || RiskPercentPerTrade > 50.0)
      {
         Print(EA_PREFIX, "RiskPercentPerTrade must be in (0, 50]"); return INIT_PARAMETERS_INCORRECT;
      }
      if(MaxLotSize <= 0)
      {
         Print(EA_PREFIX, "MaxLotSize must be > 0"); return INIT_PARAMETERS_INCORRECT;
      }
   }
   else if(FixedLotSize <= 0)
   {
      Print(EA_PREFIX, "FixedLotSize must be > 0 when UseRiskBasedSizing=false"); return INIT_PARAMETERS_INCORRECT;
   }
   if(MinConfirmations < 0 || MinConfirmations > 5)
   {
      Print(EA_PREFIX, "MinConfirmations must be 0..5"); return INIT_PARAMETERS_INCORRECT;
   }

   //--- Initialize market data and indicator handles
   if(!MarketInit())
      return INIT_FAILED;

   //--- Initialize trade object
   TradeInit();

   //--- Initialize daily counters
   g_lastTradeDay = 0; // Force reset on first tick
   g_lastLossTime = 0;
   g_breakevenApplied = false;

   //--- Initialize dashboard
   InitDashboard();

   Print(EA_PREFIX, "Initialized. Window=", WindowSize,
         " Threshold=", DeltaThreshold, " Magic=", MagicNumber);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   MarketDeinit();
   RemoveDashboard();
   Print(EA_PREFIX, "Deinitialized. Reason=", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Daily / session bookkeeping
   ResetDailyCounters();
   UpdateSessionState();
   GetDailyStats(g_dailyPnL, g_dailyTradeCount);
   CheckLastTradeLoss();

   //--- Tick + candle pipeline
   ProcessTick();
   if(IsNewCandle())
      FinalizeCandle();

   //--- Manage open position (time exit, adverse-delta exit, breakeven)
   if(HasOpenPosition())
   {
      ManageOpenTrade();
      UpdateDashboard("ACTIVE (in trade)");
      return;
   }

   //--- Guards (session, counts, cooldowns, volatility, hard spread cap)
   string guardReason;
   bool guardsOK = CheckGuards(guardReason);
   UpdateDashboard(guardReason);
   if(!guardsOK) return;

   //--- Sniper signal (crossover + N-of-5 confirmations)
   int signal = CheckSniperSignal();
   if(signal == 0) return;

   OpenTrade(signal);
}

//+------------------------------------------------------------------+
//| Trade-close detection: update session W/L + last-loss timer       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != MagicNumber) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;

   int entry = (int)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) return;

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   if(profit > 0.0)      g_sessionWins++;
   else if(profit < 0.0)
   {
      g_sessionLosses++;
      g_lastLossTime = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   }

   g_openTradeDirection = 0;
   g_openTradeTime      = 0;

#ifndef BACKTEST_MODE
   Print(EA_PREFIX, "Exit deal #", trans.deal, " profit=", profit,
         " session W/L=", g_sessionWins, "/", g_sessionLosses);
#endif
}
//+------------------------------------------------------------------+
