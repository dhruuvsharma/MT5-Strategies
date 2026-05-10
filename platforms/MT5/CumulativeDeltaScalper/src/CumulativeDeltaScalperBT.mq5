//+------------------------------------------------------------------+
//| CumulativeDeltaScalperBT.mq5                                      |
//| Backtest-mode entry point — same logic, no UI, no per-tick Prints |
//| Strips dashboard / footprint / sliding-window rendering and all   |
//| per-tick Print calls so optimization sweeps run faster.           |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property version   "2.00"
#property description "CDScalper v2 — BACKTEST BUILD (UI stripped, no per-tick logs)"

//--- Compile-time switch: causes all Utils UI funcs to be no-op stubs
//--- and all per-tick Prints in Market/Signal/Trade/Risk to compile out.
//--- Defined BEFORE any include so the flag propagates through the chain.
#define BACKTEST_MODE

#include "Utils.mqh"

//+------------------------------------------------------------------+
//| OnInit — same validation as live EA                               |
//+------------------------------------------------------------------+
int OnInit()
{
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

   if(!MarketInit())
      return INIT_FAILED;

   TradeInit();

   g_lastTradeDay     = 0;
   g_lastLossTime     = 0;
   g_breakevenApplied = false;

   //--- No InitDashboard call — UI stripped via BACKTEST_MODE
   Print(EA_PREFIX, "[BT] Initialized. Window=", WindowSize,
         " Threshold=", DeltaThreshold, " MinConf=", MinConfirmations,
         " Magic=", MagicNumber);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   MarketDeinit();
   //--- No RemoveDashboard call needed (no objects were created)
}

//+------------------------------------------------------------------+
//| OnTick — identical orchestration to live EA, minus dashboard      |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- BT: CheckLastTradeLoss skipped — OnTradeTransaction is authoritative
   ResetDailyCounters();
   UpdateSessionState();
   ProcessTick();
   if(IsNewCandle())
      FinalizeCandle();

   if(HasOpenPosition())
   {
      ManageOpenTrade();
      return;
   }

   string guardReason;
   if(!CheckGuards(guardReason)) return;

   int signal = CheckSniperSignal();
   if(signal == 0) return;

   OpenTrade(signal);
}

//+------------------------------------------------------------------+
//| Trade-close detection: session W/L tracking + last-loss timer     |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != MagicNumber) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;

   //--- BT: refresh daily PnL+count here instead of every tick
   GetDailyStats(g_dailyPnL, g_dailyTradeCount);

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
}
//+------------------------------------------------------------------+
