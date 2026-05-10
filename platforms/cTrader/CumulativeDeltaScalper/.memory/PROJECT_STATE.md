# CumulativeDeltaScalper (cTrader) — Project State

## Current Status
- **Version:** 1.00 (initial port from MT5 v2.00)
- **Source of truth:** `platforms/MT5/CumulativeDeltaScalper/` for signal logic
- **Built/tested:** code review only — needs first compile + side-by-side run vs MT5

## What Changed Recently
- 2026-05-10 — Initial cTrader port. Single-file cBot with all 5 sniper confirmations, GMT session logic, risk-based sizing, ATR-anchored SL/TP, fast exits (time-out / adverse-delta), optional breakeven, daily and per-session caps with cooldowns.
- 2026-05-10 — HTF (M15) EMA + ADX wired via `MarketData.GetBars(TimeFrame.Minute15)`. HTF EMA slope reads `_htfEma.Result[last] vs Result[last - slopeBars]`.
- 2026-05-10 — Position close handling via `Positions.Closed` event hook (replaces MT5's `OnTradeTransaction`).
- 2026-05-10 — Visualization layer (dashboard, sliding-window rectangle, footprint heatmap, per-candle delta labels) NOT ported. Documented in README.

## Open TODOs
- [ ] First-compile + cTrader Tester run vs MT5 on EURUSD M1
- [ ] Verify `Server.Time.ToUniversalTime()` returns true GMT for the broker
- [ ] Validate risk-based sizing on first trade — log shows `units` and the implied loss at SL; should equal `RiskPercentPerTrade % of balance`
- [ ] Optional: add a minimal status `Chart.DrawStaticText` for "ACTIVE / SESSION CLOSED / SPREAD HIGH"
- [ ] Optional: re-implement the dashboard panel under a `ShowUI` parameter

## Architecture
Single class `CumulativeDeltaScalper : Robot`. Logical regions:
- **Config** — parameters grouped (Delta, Sessions, Sniper, Trade, Fast Exit, Filters, Risk, Identity)
- **Constants** — pip buffer, indicator periods (ATR/EMA/ADX)
- **Indicators** — `_atr`, `_htfEma`, `_htfDms` (DirectionalMovementSystem for ADX)
- **State** — tick counters, circular delta buffer, spread history, daily/session counters, open-trade tracking
- **Lifecycle** — `OnStart` (init+validate+wire `Positions.Closed`), `OnTick` (delta+manage+signal), `OnBar` (finalize candle), `OnStop` (unwire event)
- **Tick/Candle** — `ProcessTickDelta`, `FinalizeCandle`, `CalculateCumDelta`, `GetOrderedDeltas`
- **Signal** — `DeltaCrossover`, 5 confirmation methods, `CheckSniperSignal`
- **Sessions** — `MinutesSinceMidnightGmt`, `InRange`, `GetCurrentSessionId`, `UpdateSessionState`, `CheckAllGuards`
- **Risk** — `CalcSLDistancePrice`, `CalcTPDistancePrice`, `CalcLotsToUnits`, `SpreadInPoints`, `AvgSpreadPoints`
- **Trade** — `HasOpenPosition`, `OpenTrade`, `ManageOpenTrade`, `ClosePos`, `TryBreakeven`
- **Daily/History** — `ResetDailyCounters`, `SyncDailyStatsFromHistory`, `OnOurPositionClosed`

## Hard Constraints (carried from MT5)
- Buffer must be filled before first crossover (`_bufferFilled == WindowSize`)
- `_prevCumDelta` updates every tick crossover-check call
- Adverse-delta exit cooldown is from open time, not last bar close
- Breakeven is one-shot per trade
- Session reset clears wins/losses; daily reset clears daily counters and re-syncs from History
- All `Positions` and `History` filtering is by `Label == TradeLabel` (no magic number in cAlgo)
