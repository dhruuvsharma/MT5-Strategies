# Memory: DeltaFadeEA.cs

## Purpose
Single-file cAlgo cBot port of MT5 DeltaFadeEA v3.00 — fades cumulative delta extremes using dynamic Median+MAD thresholds, with optional EMA trend filter, VWP-slope confirmation, daily cap, cooldown, and trailing stop. No visual layer.

## Public surface
- `class DeltaFadeEA : Robot`
- `[Parameter]` properties: `EnableTrading`, `TradeLabel`, `WindowSize`, `AnalysisWindowSize`, `TrendEMAPeriod`, `TrendFollowing`, `ThresholdMultiplier`, `RequireBothDeltas`, `RequireSlopeConfirmation`, `MaxTradesPerDay`, `MinBarsBetweenTrades`, `LotSize`, `RiskPercent`, `StopLossPoints`, `TakeProfitPoints`, `RiskRewardRatio`, `MaxSpread`, `TrailingStart`, `EnableTimeFilter`, `StartHour`, `EndHour`
- `OnStart() / OnBar() / OnTick() / OnStop()` lifecycle overrides

## Internal layout (regions)
- Config / Constants
- State buffers + FIFO lists + dynamic thresholds + trade-mgmt counters
- Lifecycle (init + seed analysis windows + per-bar pipeline)
- Market layer — delta buffers, VWP, slope, FIFO push, Median + MAD
- Signal layer — threshold calc & clamping, signal evaluation, daily/cooldown gates
- Risk layer — units sizing (fixed or risk-%), TP-from-RR, points→pips
- Trade layer — entries, position queries, trailing stop
- Utils — session filter, evaluate/execute dispatch

## Dependencies
- cAlgo.API, cAlgo.API.Indicators, cAlgo.API.Internals
- System, System.Collections.Generic, System.Linq

## Key decisions
- 2026-05-10 — Single-file C# port (vs MT5's 7 files). Visual layer dropped.
- 2026-05-10 — `OnTick` reserved for trailing stop only; all heavy work happens in `OnBar`. Avoids per-tick recomputation that MT5 used (intra-bar UpdateCurrentCandleDelta) for visual reasons.
- 2026-05-10 — Risk-based sizing simplified to `riskAmt / (StopLossPoints × TickValue)` — matches MT5's algebra after substituting `tickVal = SymbolInfoDouble(SYMBOL_TRADE_TICK_VALUE)` and `_Point = SymbolInfoDouble(SYMBOL_POINT)`.
- 2026-05-10 — FIFO analysis windows use `List<double>.Insert(0, …)` — O(n) but `AnalysisWindowSize=50` makes this trivial; preserves "newest at index 0" semantic from MT5.

## Known issues / TODOs
- [ ] Visualization layer (rectangles, footprint line, HUD) not ported
- [ ] First-compile and tester run pending
- [ ] Validate spread/tick-value units per broker

## Last Modified
- Date: 2026-05-10
- Change: Initial port from MT5 DeltaFadeEA v3.00 — signal layer faithful, visual layer omitted
