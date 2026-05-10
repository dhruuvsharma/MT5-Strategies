# Memory: CumulativeDeltaScalper.cs

## Purpose
Single-file cAlgo cBot port of MT5 CumulativeDeltaScalper v2 (Sniper-mode). Tick-level delta accumulation, candle-window crossover trigger, 5-confirmation gate, ATR-anchored SL/TP, fast exits, session-aware caps & cooldowns. No visualization layer.

## Public surface
- `class CumulativeDeltaScalper : Robot`
- `enum SessionId { None, Asia, London, NewYork, Overlap }`
- ~50 `[Parameter]` properties grouped by purpose (Delta, Sessions, Sniper, Trade, Fast Exit, Filters, Risk, Identity)
- `OnStart() / OnTick() / OnBar() / OnStop()` lifecycle overrides
- `OnOurPositionClosed(PositionClosedEventArgs)` — `Positions.Closed` event handler

## Internal layout (regions)
- Config (~50 parameters)
- Constants (`Prefix`, `BreakevenBufferPips`, indicator periods)
- Indicator handles (`AverageTrueRange`, M15 `ExponentialMovingAverage`, M15 `DirectionalMovementSystem`)
- Tick/candle state (counters, circular `_deltaBuffer[]`, `_spreadHistory[]`)
- Daily / session tracking
- Lifecycle (init validates parameters, wires Positions.Closed)
- Tick / candle delta methods
- Signal layer — crossover, 5 confirmations, sniper aggregator
- Sessions / Guards (GMT minute math, range checks, master guard chain)
- Risk / Stop distances / Lot sizing
- Trade layer (open, manage, close, breakeven)
- Daily reset + history sync + position-close hook

## Dependencies
- cAlgo.API, cAlgo.API.Indicators, cAlgo.API.Internals
- System, System.Collections.Generic, System.Linq

## Key decisions
- 2026-05-10 — `OnTick` retains tick-level delta + management; `OnBar` only finalizes candle. Mirrors MT5's `IsNewCandle()` gate without manual time-tracking.
- 2026-05-10 — HTF (M15) data via `MarketData.GetBars(TimeFrame.Minute15)`; ADX via `DirectionalMovementSystem`'s `.ADX` series.
- 2026-05-10 — Server.Time is treated as broker time; `.ToUniversalTime()` derives GMT minutes for session math. Documented as a verify-on-first-run item.
- 2026-05-10 — Position close → session W/L tracking via `Positions.Closed` event (idiomatic cAlgo) instead of polling `OnTradeTransaction`.
- 2026-05-10 — `History.NetProfit` is used directly (already nets commission + swap), avoiding the MT5 three-field summation.
- 2026-05-10 — No `BACKTEST_MODE` ifdef — single code path. Logging is moderate; could be parameter-gated later.

## Known issues / TODOs
- [ ] No on-chart visualization (dashboard / sliding window / footprint)
- [ ] First compile + tester run pending
- [ ] Tick-delta uptick-rule (bid-flip) — verify cTrader's tick semantics match MT5 sufficiently for parity
- [ ] Verify `Symbol.Spread / Symbol.TickSize` rounding produces correct point counts vs MT5 `SYMBOL_SPREAD`

## Last Modified
- Date: 2026-05-10
- Change: Initial port of MT5 v2.00 — full signal pipeline + risk/exit logic, no visualization
