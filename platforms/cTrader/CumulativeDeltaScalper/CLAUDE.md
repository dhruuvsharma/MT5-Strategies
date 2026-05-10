# CumulativeDeltaScalper (cTrader) — Strategy-Specific Claude Instructions

> Also follow `/CLAUDE.md` and the MT5 sibling at `platforms/MT5/CumulativeDeltaScalper/CLAUDE.md`. Logic parity is mandatory.

## Parity Rule

This is a port of MT5 v2 Sniper-mode. The signal pipeline (tick uptick/downtick → per-candle delta → circular sliding window → cumulative-delta crossover → 5-confirmation gate) must match MT5 exactly. Differences from MT5:

- **Visualization is omitted.** No dashboard, sliding-window rectangle, per-candle delta labels, or footprint cells. (See README "Known gaps".)
- **No `BACKTEST_MODE` define-toggle** — cAlgo doesn't have preprocessor-style conditional compilation across two file variants. The single port emits `Print` per significant event; if you need a fast-tester variant, gate the prints behind a `[Parameter] bool VerboseLog`.

## API Translation Notes

| MT5 concept | cAlgo equivalent in this port |
|-------------|--------------------------------|
| `iATR(_Symbol, PERIOD_CURRENT, 14)` | `Indicators.AverageTrueRange(14, MovingAverageType.Simple)` |
| `iMA(_Symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE)` | `MarketData.GetBars(TimeFrame.Minute15)` + `Indicators.ExponentialMovingAverage(htfBars.ClosePrices, 50)` |
| `iADX(_Symbol, PERIOD_M15, 14)` | `Indicators.DirectionalMovementSystem(htfBars, 14)` (`.ADX` series) |
| `SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)` | `Symbol.Spread / Symbol.TickSize` (rounded) |
| `SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE / SIZE)` | `Symbol.TickValue` / `Symbol.TickSize` |
| `PositionsTotal()` + magic loop | `Positions.Where(p => p.Label == TradeLabel)` |
| `OnTradeTransaction → DEAL_ENTRY_OUT` | `Positions.Closed += OnOurPositionClosed` event |
| `HistorySelect + HistoryDealGet*` | `History` collection (already filtered by current account) |
| `TimeGMT()` | `Server.Time.ToUniversalTime()` |

## Bar/Index Conventions

- cAlgo's `Bars.Last(0)` = live (currently-forming) bar = MT5's `iTime(_Symbol, PERIOD_CURRENT, 0)`.
- The HTF EMA/ADX pull from a separate `MarketData.GetBars(TimeFrame.Minute15)` and use `.LastValue`.
- The delta circular buffer is unchanged: oldest at logical `start`, wraps via `bufferIndex`.

## Hard Constraints (carried from MT5)

- **Crossover requires `_bufferFilled == WindowSize`** — cold-start guards against premature signals.
- **`_prevCumDelta` is updated on every call to `DeltaCrossover()`**, not just when a crossover fires. Keeps the edge condition tight (one-shot crossing).
- **MinConfirmations gate is on the 5 supporting checks; the crossover itself is always required.**
- **Adverse-delta exit cooldown is `AdverseDeltaCooldown` seconds from open** — must not fire immediately on entry.
- **Breakeven is one-shot per trade** via `_breakevenApplied` flag.
- **Session change resets `_sessionTradeCount`/wins/losses** but not daily counters.
- **`StopAfterFirstWin` / `StopAfterFirstLoss` halt the *current session*, not the day.**
- **Tick-level delta is bid-flip based** (uptick = bid > prev_bid). Keep this — switching to ask-flip changes the edge.

## Known cAlgo-side differences

- cAlgo doesn't expose a numeric "stops level" the way MT5 does. The port relies on cAlgo's internal validation of SL/TP distances. If `ExecuteMarketOrder` returns a min-distance error, surface it via the `TradeResult.Error` log — don't paper over it.
- `Server.Time` is broker-server time; `.ToUniversalTime()` is used for GMT-based session windows. **Verify on first run** that the broker's server clock is UTC or GMT (most are).
- `History.NetProfit` already nets commission + swap; no need for the MT5-style `DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION` summation.

## What's NOT yet ported

- The on-chart dashboard (9 labels), sliding-window rectangle, per-bar delta text, and footprint heatmap (background+text cells per price level). All visualization-only.
- `BACKTEST_MODE` ifdef toggle — collapsed into a single non-ifdef path.
