# CumulativeDeltaScalper (cTrader)

cTrader / cAlgo port of [CumulativeDeltaScalper-MT5](../../MT5/CumulativeDeltaScalper) — v2 Sniper-mode.

A tick-driven scalper for **EURUSD M1/M3/M5**. Sums tick-level uptick/downtick over a sliding window of N candles and triggers entries on cumulative-delta crossover of `±DeltaThreshold`, gated by a 5-confirmation stack:

1. **Momentum alignment** — last 3 candle deltas all share signal sign
2. **HTF EMA filter** — bid on correct side of M15 EMA(50)
3. **HTF EMA slope** — direction of M15 EMA matches signal
4. **ADX trending regime** — M15 ADX(14) ≥ threshold
5. **Spread sanity** — current spread within `SpreadAvgMultiplier × rolling-avg`, plus hard cap

Risk-based lot sizing, ATR-anchored SL/TP (default `0.4×ATR` TP / `0.8×ATR` SL → tight, high-WR), per-session and daily trade caps, fast exits (time-out, adverse-delta flip), optional breakeven, plus session/cooldown/loss-limit guards.

## Parameter Mapping (MT5 → cTrader)

All MT5 inputs are exposed as `[Parameter]` in C# with the same defaults. Highlights:

| MT5 input | cTrader Parameter | Default |
|-----------|-------------------|---------|
| `WindowSize` | `Window Size` | 10 |
| `DeltaThreshold` | `Delta Threshold` | 300 |
| `MinConfirmations` | `Min Confirmations (0..5)` | 5 |
| `EMASlopeBars` | `EMA Slope Bars` | 3 |
| `ADXThreshold` | `ADX Threshold` | 18.0 |
| `SpreadAvgMultiplier` | `Spread Avg Multiplier` | 1.5 |
| `SpreadHistorySize` | `Spread History Size` | 30 |
| `UseRiskBasedSizing` | `Use Risk-Based Sizing` | true |
| `RiskPercentPerTrade` | `Risk % per Trade` | 1.0 |
| `FixedLotSize` | `Fixed Lot Size` | 0.01 |
| `MaxLotSize` | `Max Lot Size (cap)` | 5.0 |
| `TP_Multiplier` | `TP Multiplier (×ATR)` | 0.4 |
| `SL_Multiplier` | `SL Multiplier (×ATR)` | 0.8 |
| `UseBreakeven` | `Use Breakeven` | false |
| `BreakevenPips` | `Breakeven Pips` | 1.5 |
| `MaxSpreadPoints` | `Max Spread (Points)` | 15 |
| `MaxTradeSeconds` | `Max Trade Seconds` | 90 |
| `AdverseDeltaExit` | `Adverse Delta Exit` | true |
| `AdverseDeltaCooldown` | `Adverse Delta Cooldown (s)` | 5 |
| `UseHTFFilter` | `Use HTF EMA Filter` | true |
| `MinATR` / `MaxATR` | `Min ATR` / `Max ATR` | 0.0003 / 0.002 |
| `MaxTradesPerSession` | `Max Trades / Session` | 2 |
| `MaxDailyTrades` | `Max Daily Trades` | 3 |
| `MaxDailyLossPercent` | `Max Daily Loss %` | 2.0 |
| `MinSecondsBetweenTrades` | `Min Sec Between Trades` | 900 |
| `LossCooldownMinutes` | `Loss Cooldown Min` | 15 |
| `StopAfterFirstWin` / `StopAfterFirstLoss` | `Stop After First Win/Loss` | true / true |
| All session start/end H/M | exposed individually under "Sessions" group | as MT5 |
| `MagicNumber` + `EAComment` | `Order Label` (string) | "CDScalper" |

## API Differences vs MT5

- **Tick delta in `OnTick()`** — same as MT5; cAlgo also fires `OnTick()` per tick with `Symbol.Bid` available.
- **Bar finalisation in `OnBar()`** instead of MT5's manual `IsNewCandle()` check.
- **HTF data** via `MarketData.GetBars(TimeFrame.Minute15)` rather than `iMA(_Symbol, PERIOD_M15, ...)`.
- **GMT** via `Server.Time.ToUniversalTime()` — verify your broker's clock if sessions look skewed.
- **Position close detection** via `Positions.Closed` event (replaces `OnTradeTransaction → DEAL_ENTRY_OUT`).
- **Daily PnL** sourced from `History` collection — `History[i].NetProfit` already nets commission/swap.
- **Magic number → `Label` string** — all queries on `Positions` and `History` filter by `Label == TradeLabel`.
- **No "stops level" buffer** — cAlgo enforces minimum SL/TP distance internally; if your broker rejects, raise `SL_Multiplier` slightly.

## Known Gaps

The MT5 EA includes a **9-line dashboard** (CumDelta, LiveDelta, Session W/L, Trades D/S, PnL, Spread+Avg, ADX, Status), a **sliding-window rectangle**, **per-candle delta labels** below bars, **live delta** under the active bar, **cumulative delta** Σ label below the window, and a **footprint heatmap** (delta cells stacked per price level over each bar). **None of this is ported.** The signal logic is fully functional without it.

If you want any of these later, build them under a separate `void DrawDashboard()` / `void DrawFootprint()` method and gate them on a `[Parameter] bool ShowUI = true`.

## Install

1. Open cTrader → **Automate** → New cBot → name it `CumulativeDeltaScalper`.
2. Replace generated source with `src/CumulativeDeltaScalper.cs`.
3. Build (F6), drop on a EURUSD M1/M3/M5 chart, set parameters, **Start**.

## Status

Active port. Logic parity confirmed by code review. **First-run validation strongly recommended** — run side-by-side with MT5 instance on the same symbol/timeframe and compare entries over a few overlap-sessions.

## Author

**Dhruv Sharma** · [linkedin.com/in/dhruvsharmainfo](https://www.linkedin.com/in/dhruvsharmainfo)
