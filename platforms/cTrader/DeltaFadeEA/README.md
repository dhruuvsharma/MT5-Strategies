# DeltaFadeEA (cTrader)

cTrader / cAlgo port of [DeltaFadeEA-MT5](../../MT5/DeltaFadeEA) (v3.00).

Contrarian / trend-pullback scalper that fades cumulative tick & volume delta extremes using **dynamic Median + MAD thresholds** over a rolling analysis window. Confirms with VWP-slope direction; optional EMA trend filter; daily trade cap, bar cooldown, and trailing stop.

Designed for **XAUUSD** by default but the `StopLossPoints` / `MaxSpread` / `TrailingStart` parameters are calibrated in symbol points and translate cleanly to other instruments.

## Logic in One Glance

1. Each bar close: recompute cumulative tick & volume delta over the last `WindowSize` bars.
2. Push the just-closed bar's deltas into the analysis FIFO (`AnalysisWindowSize`).
3. Recompute thresholds: `median ± multiplier × MAD`, clamped to `[base × 0.3, base × 3.0]`.
4. Spread filter, daily cap, cooldown gate.
5. Combine signals:
   - **Trend-pullback mode** (`TrendFollowing=true` + EMA): uptrend + delta oversold + red slope → BUY; mirror for SELL.
   - **Contrarian mode** (no trend filter or trend=0): delta overbought + green slope → SELL; oversold + red slope → BUY.

## Parameter Mapping (MT5 → cTrader)

| MT5 input | cTrader Parameter | Default |
|-----------|-------------------|---------|
| `MagicNumber` | `Order Label` (string) | "DeltaFadeEA" |
| `EnableTrading` | `Enable Trading` | true |
| `WindowSize` | `Window Size (bars)` | 20 |
| `AnalysisWindowSize` | `Analysis Window Size (bars)` | 50 |
| `TrendEMAPeriod` | `Trend EMA Period (0=off)` | 50 |
| `TrendFollowing` | `Trend Following (else Contrarian)` | true |
| `ThresholdMultiplier` | `Threshold Multiplier (MAD)` | 2.0 |
| `RequireBothDeltas` | `Require BOTH deltas` | true |
| `RequireSlopeConfirmation` | `Require VWP Slope Confirmation` | true |
| `MaxTradesPerDay` | `Max Trades / Day` | 5 |
| `MinBarsBetweenTrades` | `Min Bars Between Trades` | 10 |
| `LotSize` | `Lot Size (0=risk-based)` | 0.01 |
| `RiskPercent` | `Risk % per Trade` | 2.0 |
| `StopLossPoints` | `Stop Loss (Points)` | 500 |
| `TakeProfitPoints` | `Take Profit (Points, 0=use RR)` | 0 |
| `RiskRewardRatio` | `Risk:Reward Ratio (TP)` | 0.6 |
| `MaxSpread` | `Max Spread (Points)` | 30 |
| `Slippage` | (auto via cAlgo) | — |
| `TrailingStart` | `Trailing Start (Points)` | 200 |
| `EnableTimeFilter` | `Enable Time Filter` | true |
| `StartHour` | `Session Start Hour` | 8 |
| `EndHour` | `Session End Hour` | 17 |

## API Differences vs MT5

- **`OnBar()` for new-bar work; `OnTick()` for trailing stop only** — replaces MT5's manually-tracked `lastBarTime`.
- **No magic number** — direction/symbol/owner filtering goes through `Label == TradeLabel`.
- **SL/TP in pips** — `PlaceMarketOrder` takes `stopLossPips`/`takeProfitPips` doubles. Conversion: `pips = points × Symbol.TickSize / Symbol.PipSize`.
- **Spread is in price units** — `Symbol.Spread`, no `_Point` multiplier needed.
- **Risk-based lot sizing** simplified: `volumeInUnits = riskAmount / (StopLossPoints × Symbol.TickValue)`.

## Known Gaps

The MT5 EA includes a heavy visual layer (sliding-window rectangle, VWP trend line + arrow points, per-bar delta text labels, threshold-window rectangles, top-right HUD with threshold values, time-filter status label). **None of this is ported.** It is signal-irrelevant; reimplementing on `Chart.DrawTrendLine` / `DrawText` is straightforward but not done yet.

## Install

1. Open cTrader → **Automate** → New cBot → name it `DeltaFadeEA`.
2. Replace generated source with `src/DeltaFadeEA.cs`.
3. Build (F6), drop on a chart (XAUUSD or your preferred symbol), set parameters, Start.

## Status

Active port. Logic parity confirmed by code review. Recommended pre-live: side-by-side run of MT5 and cTrader instances on the same symbol/timeframe, comparing entry timestamps and direction over a representative session.

## Author

**Dhruv Sharma** · [linkedin.com/in/dhruvsharmainfo](https://www.linkedin.com/in/dhruvsharmainfo)
