# Memory: DeltaFadeEA.mq5

## Purpose
Core EA orchestration — OnInit, OnDeinit, OnTick, OnChartEvent. No raw logic, only function calls.

## Exports
- OnInit() → int — calls MarketInit, TradeInit, UpdateEMA, init logs mode/params
- OnDeinit(reason) — calls MarketDeinit() to release EMA handle
- OnTick() — new bar detection → ProcessNewBar or ProcessSameBar
- ProcessNewBar() — OnNewBarSignal cooldown, full recalc, thresholds, signals, trades
- ProcessSameBar() — intra-bar updates (live/visual only), no trading
- RedrawVisuals() — refresh all chart objects
- EvaluateAndExecute() — check signals, display, execute trades
- OnChartEvent(id, lparam, dparam, sparam)

## Dependencies
- Imports from: Config.mqh, Market.mqh, Signal.mqh, Risk.mqh, Trade.mqh, Utils.mqh
- Imported by: (none — this is the entry point)

## Key Decisions
- 2026-04-11 — v3.00: Renamed OnNewBar→ProcessNewBar, OnSameBar→ProcessSameBar. Removed intra-bar trading (ProcessSameBar no longer calls EvaluateAndExecute). Added UpdateEMA() and MarketDeinit() calls. OnInit logs mode (TrendPullback/Contrarian) and new params.

## Last Modified
- Date: 2026-04-11
- Change: v3.00 — trend-following mode orchestration, new-bar-only trading
