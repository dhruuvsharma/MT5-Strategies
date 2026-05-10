# TickDataCollector (cTrader)

cTrader / cAlgo port of [TickDataCollector-MT5](../../MT5/TickDataCollector).

Writes every tick as a CSV row with running candle-window OHLC/delta context, spread, and cumulative direction count. **No trade execution.** Designed for Python backtesting workflows that want tick-level granularity.

## CSV Schema

```
DateTime, Ms, Price, Bid, Ask, SpreadPts, Volume, Direction,
CandleOpen, CandleHigh, CandleLow, CandleDelta, CandleVolDelta,
TicksPerSec, CumDelta, Session
```

Matches MT5 sibling.

## Parameter Mapping (MT5 → cTrader)

| MT5 input | cTrader Parameter | Default |
|-----------|-------------------|---------|
| `InpCSVFileName` | `Output Filename (blank = auto)` | "" |
| (n/a — MT5 uses Common Data) | `Output Folder` | "" → `MyDocuments\cAlgoData` |
| `InpAppendMode` | `Append Mode` | false |
| `InpCandleMinutes` | `Candle Window Minutes` | 1 |
| `InpSessionFilter` | `Session Filter` | "ALL" |
| `InpPriceChangeOnly` | `Price-Change Only` | false |
| `InpFlushEveryN` | `Flush Every N Ticks` | 500 |

## Caveats

- **Per-tick volume = 1.** cTrader does not expose tick volumes, so this column is constant. Use the candle-aggregator (`CandleDataCollector`) instead if you need volume sums per period.
- **Millisecond accuracy** depends on broker tick timestamping. May be 0 for some brokers.
- **Spread** is `Symbol.Spread / Symbol.TickSize` rounded to one decimal — converts cAlgo's price-unit spread to MT5's "points".

## Install

1. Open cTrader → **Automate** → New cBot → name it `TickDataCollector`.
2. Replace generated source with `src/TickDataCollector.cs`.
3. Build (F6) — needs `AccessRights = FileSystem` (already set).
4. Drop on a chart, set parameters, **Start**.
5. CSV appears in `MyDocuments\cAlgoData\` (or your configured path).

## Status

Active port. Schema matches MT5 sibling. Volume per-tick = 1 (documented limitation).

## Author

**Dhruv Sharma** · [linkedin.com/in/dhruvsharmainfo](https://www.linkedin.com/in/dhruvsharmainfo)
