# DeltaFadeEA (cTrader) — Project State

## Current Status
- **Version:** 1.00 (initial port from MT5 v3.00)
- **Source of truth:** `platforms/MT5/DeltaFadeEA/` for signal logic
- **Built/tested:** code review only — needs first compile + side-by-side run vs MT5

## What Changed Recently
- 2026-05-10 — Initial cTrader port. Single-file cBot. Faithful port of: signed tick/volume delta calc, VWP weighted line + slope, sliding analysis FIFO, Median+MAD threshold calc with sign-aware bounds clamping, EMA trend filter, dual-delta requirement, slope confirmation, daily cap, cooldown, trailing stop.
- 2026-05-10 — Visual / chart-drawing layer **not** ported (rectangles, footprint trend line, threshold HUDs, per-bar delta labels). Documented as known gap in README.

## Open TODOs
- [ ] First-run validation in cTrader Tester vs MT5 baseline
- [ ] Optional: re-implement minimal HUD (threshold values + delta sums) using `Chart.DrawStaticText`
- [ ] Confirm `Symbol.TickValue` semantics for the broker's XAUUSD — should be value of 1 point per 1 unit in account currency
- [ ] Validate `Symbol.Spread` units (cAlgo docs: price units, but some adapters report pips — check first run)

## Architecture
Single class `DeltaFadeEA : Robot`. Logical layers as comment-region blocks:
- **Config** — `[Parameter]` properties (full mapping from MT5 inputs)
- **Constants** — VWP weights, threshold-bounds multipliers, MAD scale factor, base thresholds
- **State** — delta buffers, FIFO analysis lists, threshold doubles, trade-mgmt counters, EMA reference
- **Lifecycle** — `OnStart` (init+seed), `OnBar` (new-bar pipeline), `OnTick` (trailing only), `OnStop`
- **Market** — `CalculateDeltas`, `CalculateVolumeFootprint`, `GetVolumeLineSlope`, FIFO push, Median + MAD
- **Signal** — `RecalcDynamicThresholds`, `CalcThresholds` + `ClampThreshold`, `IsTradeAllowedByLimits`, `GetTrendDirection`, `CheckTradingSignals`, `UpdateDailyTradeCount`
- **Risk** — `CalculatePositionUnits` (fixed or risk-%), `GetTpPoints` (RR fallback), `PointsToPips`
- **Trade** — `HasPosition`, `EnterLong`, `EnterShort`, `ManagePositions`, `ApplyTrailingStop`, `SafeModify`
- **Utils** — `IsTradingAllowed` (session filter), `EvaluateAndExecute`

## Hard Constraints (carried from MT5)
- Bar index 0 = newest (live, `Bars.Last(0)`); buffers store newest at index 0.
- Threshold sign-aware clamping must not flip signs.
- VWP weights 0.4/0.4/0.2 — frozen.
- MAD scale factor 1.4826 — frozen.
- Min absolute threshold 80, min MAD 10 — frozen.
- TrendFollowing semantics: in trend-pullback mode, BUY only on uptrend+oversold+red-slope; SELL only on downtrend+overbought+green-slope. **No** entries against the trend.
