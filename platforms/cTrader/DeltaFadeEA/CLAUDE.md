# DeltaFadeEA (cTrader) — Strategy-Specific Claude Instructions

> Also follow `/CLAUDE.md` and the MT5 sibling at `platforms/MT5/DeltaFadeEA/CLAUDE.md` (logic parity is mandatory).

## Parity Rule

This is a **port** of the MT5 DeltaFadeEA v3.00. The signal pipeline (Median+MAD threshold, dual-delta requirement, VWP slope confirmation, EMA trend filter, day/cooldown caps) must remain identical. Differences from MT5:

- **No visualization layer.** All `Draw*` / `Display*` from MT5 `Utils.mqh` is **omitted** in the cTrader port. If you re-implement, do it as separate methods that don't run during optimization. Use `Chart.DrawTrendLine`, `Chart.DrawText`, `Chart.DrawStaticText` for HUD.
- **Hour filter is range-only**, weekend-blocked. The MT5 EA mentions "24 separate bool inputs for tester compatibility" but only exposes `StartHour`/`EndHour` in `Config.mqh`; we mirror that.

## API Translation Notes

| MT5 concept | cAlgo equivalent in this port |
|-------------|--------------------------------|
| `iMA(_Symbol, _Period, period, 0, MODE_EMA, PRICE_CLOSE)` | `Indicators.ExponentialMovingAverage(Bars.ClosePrices, period)` |
| `CopyRates(_Symbol, _Period, 0, N, rates)` | `Bars.OpenPrices/HighPrices/LowPrices/ClosePrices/TickVolumes.Last(i)` |
| `tick_volume` | `Bars.TickVolumes.Last(i)` |
| `SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point` | `Symbol.Spread` (already in price units) |
| `AccountInfoDouble(ACCOUNT_BALANCE)` | `Account.Balance` |
| `SYMBOL_TRADE_TICK_VALUE` | `Symbol.TickValue` |
| Magic number filter | `Label == TradeLabel` filter on `Positions` |

## Bar / Index Convention

Both EAs use the same convention: **index 0 = newest bar (live), increasing index = older**. cAlgo's `Bars.<series>.Last(i)` matches this directly. The analysis FIFO list also has newest at index 0 (front).

## Hard Constraints (carried from MT5)

- Threshold clamping: buy threshold stays ≥ 0, sell threshold stays ≤ 0 (sign-aware).
- `MIN_MAD_VALUE = 10.0` — prevents division-by-tiny when the analysis data has very low spread.
- `MIN_ABSOLUTE_THRESHOLD = 80.0` — pushes threshold off zero in flat markets.
- `MAD_SCALE_FACTOR = 1.4826` — converts MAD to a normal-equivalent stddev. **Don't change.**
- VWP weights `0.4 / 0.4 / 0.2` (close / typical / open) — these are part of the strategy's edge; do not tune without explicit user request.

## What's NOT yet ported

- All visual artifacts: SlidingWindow rectangle, VolumeFootprint trend line + arrow points, per-bar V/T/Ts text labels, Tick & Volume threshold-window rectangles, threshold HUD, time-filter status label.
- These live in MT5's `Utils.mqh`. Reimplementing in cAlgo would use `Chart.DrawTrendLine`, `Chart.DrawText`, `Chart.DrawStaticText`. Filed as gap in the README.
