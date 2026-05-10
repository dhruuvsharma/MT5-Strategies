# TickDataCollector (cTrader) — Strategy-Specific Claude Instructions

> Also follow `/CLAUDE.md` and the MT5 sibling at `platforms/MT5/TickDataCollector/CLAUDE.md`.

## Purpose
Tick-resolution data collection. Writes one CSV row per tick with running candle-window OHLC + delta context, plus cumulative delta. No trade execution.

## CSV Schema (MUST match MT5 sibling exactly)
`DateTime, Ms, Price, Bid, Ask, SpreadPts, Volume, Direction, CandleOpen, CandleHigh, CandleLow, CandleDelta, CandleVolDelta, TicksPerSec, CumDelta, Session`

## Caveats vs MT5

- **`Ms` is from `DateTime.Millisecond` of `Server.Time`.** This depends on cTrader's internal tick timestamping; if the broker only times ticks to whole seconds, `Ms` will always be 0.
- **`Volume = 1` per tick** — cTrader doesn't expose per-tick volume. Same caveat as CandleDataCollector.
- **`SpreadPts = Symbol.Spread / Symbol.TickSize`** — convert from cAlgo's price-unit spread to MT5's point semantics.
- **`Direction = NEUTRAL` on the first tick of a candle** (matches MT5 — `g_lastPrice` starts at 0 and the first tick can't compute a direction).

## Hard Constraints

- `AccessRights = AccessRights.FileSystem` — required.
- `CultureInfo.InvariantCulture` everywhere — needed for dot-decimal CSV across non-English locales.
- `_cumDelta` updates **even when the row is filtered out by SessionFilter** (parity with MT5).
- `PriceChangeOnly = true` skips same-price ticks **before** updating `_lastPrice` writes — same as MT5.
