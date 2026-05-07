# Project State — CumulativeDeltaScalper

## Current Status
- **Phase**: v2.0 — Sniper-mode redesign
- **Date**: 2026-05-08
- **Version**: 2.0

## What Changed
- 2026-05-08 — **Backtest-mode EA** added: `CumulativeDeltaScalperBT.mq5`. Defines `#define BACKTEST_MODE` before including Utils.mqh, which causes:
  - All UI functions (dashboard, sliding-window rect, footprint cells, candle-delta labels) to compile to empty stubs
  - All per-tick `Print()` calls in Market/Signal/Trade/Risk/main to compile out
  - `CheckLastTradeLoss` skipped in OnTick (OnTradeTransaction is authoritative); `GetDailyStats` moved off the tick path into OnTradeTransaction
  - Same signal/risk/trade logic — produces identical trades on identical data
  - Compile and select this EA for Strategy Tester optimization sweeps
- 2026-05-08 — **v2.0 Sniper redesign** (full restructure across all 6 source files):
  - **Sessions**: 3 GMT-toggleable sessions (Asia / London / NY) + OverlapOnly preset (London/NY 12:30–16:00). Each session has minute-precision start/end. Default: OverlapOnly=true. ENUM_SESSION_ID introduced.
  - **5-confirmation sniper gate** (Signal.mqh): crossover trigger + N-of-5 supporting filters (momentum alignment, HTF EMA bid-vs, EMA slope, ADX trending, dynamic spread). MinConfirmations input (0..5, default 5 strict).
  - **Risk-based sizing** (Risk.mqh): RiskPercentPerTrade default 1%, MaxLotSize hard cap, falls back to FixedLotSize if UseRiskBasedSizing=false. Replaces v1 fixed `LotSize`.
  - **Fast exits** (Trade.mqh): MaxTradeSeconds time-out, AdverseDeltaExit on cumDelta flip, retained breakeven (now opt-in via UseBreakeven, default off).
  - **Tight TP/SL defaults**: TP 0.4×ATR, SL 0.8×ATR (R:R 0.5 — designed for high win rate).
  - **Trade caps**: MaxTradesPerSession=2, MaxDailyTrades=3, MinSecondsBetweenTrades=900s. StopAfterFirstWin/Loss default true (sniper discipline).
  - **OnTradeTransaction** added to main EA — single source of truth for session W/L tracking.
  - **Dashboard** extended from 7 → 9 lines (session, ADX, rolling-avg spread).
- 2026-05-08 — Tier 1 bug fixes bundled into v2:
  - Pip math now broker-aware (CalcPipSize in MarketInit, g_pipSize used everywhere)
  - GetDailyStats counts both closed deals and open positions today (fixes v1 count drift)
  - Removed `#property strict` (MQL4-only)
  - Added EnsureMinStopDistance to prevent broker rejection when ATR shrinks
  - CTrade.Buy/Sell now passes 0.0 price (broker resolves at send-time)
  - Removed redundant `g_dailyTradeCount++` in OpenTrade

- 2026-04-14 — UI v5: proper footprint cells (stacked colored rectangles per price level)
- 2026-04-13 — sliding window rect, per-candle delta labels, ShowUI toggle
- 2026-04-11 — initial build from spec

## Architecture (v2)
| File | Layer | Responsibility |
|------|-------|----------------|
| src/Config.mqh   | Config | Inputs (sessions, sniper filters, risk, fast-exit), constants, ENUM_SESSION_ID, all globals |
| src/Market.mqh   | Market | ATR/EMA/ADX handles, pip size, tick delta, spread ring buffer, indicator readers |
| src/Signal.mqh   | Signal | DeltaCrossover trigger + 5 confirmation checks + CheckSniperSignal |
| src/Risk.mqh     | Risk   | Session detection (GMT-based, 4 modes), risk-based lots, stops-level guard, 6-part CheckGuards |
| src/Trade.mqh    | Trade  | OpenTrade (risk lots), ManageOpenTrade (time / adverse / BE), CloseOurPosition |
| src/Utils.mqh    | Utils  | GetDailyStats (deals + open positions), 9-line dashboard, sliding-window UI, footprint cells |
| src/CumulativeDeltaScalper.mq5 | Core | OnInit / OnDeinit / OnTick / OnTradeTransaction (live) |
| src/CumulativeDeltaScalperBT.mq5 | Core | Same logic, defines BACKTEST_MODE → strips UI + per-tick Prints |
| SETTINGS.md | Doc | Per-input reference + XAUUSD M1/M3/M5 presets + sweep ranges |

## Open Items
- [ ] Backtest v2 on EURUSD M1/M3/M5 across each session toggle (Overlap, London, NY individually)
- [ ] Tune ADXThreshold (default 18) per session — overlap may need higher
- [ ] Validate on broker without TICK_FLAG_BUY/SELL support — current impl uses bid-flip (broker-dependent)
- [ ] Forward-test risk-based sizing with realistic balance to confirm lot calculation
- [ ] Add CSV signal/trade logger (deferred from v2 scope)
- [ ] Consider replacing bid-flip aggressor with TICK_FLAG_BUY/SELL classification (Tier 2 from review)

## Archive
_(no archived entries yet)_
