# Memory: CumulativeDeltaScalper.mq5

## Purpose
Entry-point EA — OnInit/OnDeinit/OnTick orchestration plus OnTradeTransaction for trade-close detection. No raw logic; only function calls.

## Exports
- OnInit() → int — validates inputs (WindowSize, DeltaThreshold, multipliers, RiskPercentPerTrade or FixedLotSize, MinConfirmations 0..5), inits market/trade/dashboard
- OnDeinit(int reason) → void
- OnTick() → void — order: ResetDailyCounters → UpdateSessionState → GetDailyStats → CheckLastTradeLoss → ProcessTick → IsNewCandle/FinalizeCandle → if open: ManageOpenTrade else: CheckGuards → CheckSniperSignal → OpenTrade
- OnTradeTransaction(...) → void — on DEAL_ADD for our magic+symbol, when entry is OUT: increments g_sessionWins or g_sessionLosses by deal profit, updates g_lastLossTime, clears open-trade tracking

## Dependencies
- Imports from: Utils.mqh (chains all layers)
- Imported by: none (entry point)

## Key Decisions
- 2026-05-08 — v2.0: removed `#property strict` (MQL4-only); version bumped to 2.00. Added OnTradeTransaction event handler — single source of truth for session W/L tracking. CheckLastTradeLoss kept in OnTick as a safety net for EA restart.

## Last Modified
- Date: 2026-05-08
- Change: v2 — sniper-mode orchestration, OnTradeTransaction handler, validation updated for new inputs.
