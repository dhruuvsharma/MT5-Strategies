# Memory: CumulativeDeltaScalperBT.mq5

## Purpose
Backtest-mode entry point. Same strategy logic as the live `CumulativeDeltaScalper.mq5`, but with all UI/dashboard rendering and per-tick `Print()` calls compiled out via `#define BACKTEST_MODE`. Designed to materially speed up MT5 Strategy Tester optimization sweeps.

## How it works
- Defines `BACKTEST_MODE` BEFORE `#include "Utils.mqh"`
- The chained .mqh files (Market/Signal/Trade/Risk/Utils) check `#ifdef BACKTEST_MODE` and:
  - Replace UI functions in Utils.mqh with empty no-op stubs (CreateLabel/InitDashboard/UpdateDashboard/DrawSlidingWindow/DisplayCandleDeltas/DisplayFootprint/BuildBarFootprint/RemoveDashboard/RemoveWindowObjects/GetCellBgColor/GetCellTxColor)
  - Compile out per-tick `Print()` calls in Market.FinalizeCandle, Signal.CheckSniperSignal, Trade.OpenTrade/CloseOurPosition/ApplyBreakeven, Risk.UpdateSessionState, and the main EA's OnTradeTransaction
- Skips `CheckLastTradeLoss` in OnTick (redundant — OnTradeTransaction is authoritative)
- Refreshes `g_dailyPnL` / `g_dailyTradeCount` inside OnTradeTransaction instead of every tick (eliminates per-tick HistorySelect)

## What is NOT changed
- All signal logic (DeltaCrossover + 5 confirmations) is identical
- All risk/lot calculations are identical
- All session detection / cooldowns / guards are identical
- Compiled binary produces the same trades as the live EA on the same data — only logging/UI differ

## When to use
- MT5 Strategy Tester optimization sweeps
- Any backtest where chart rendering is wasted work

## When NOT to use
- Live trading (no dashboard visibility)
- Forward-test on demo where you want to watch the EA work

## Dependencies
- Imports from: Utils.mqh (chains all layers)
- Imported by: none (entry point)

## Last Modified
- Date: 2026-05-08
- Change: Initial BT entry point.
