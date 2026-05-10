# CandleDataCollector (cTrader)

cTrader / cAlgo port of [CandleDataCollector-MT5](../../MT5/CandleDataCollector).

Builds tick-aggregated candles (OHLC + TickDelta + VolumeDelta + VWAP + Range + CumDelta) and writes one CSV row per candle. **No trade execution.** Designed for Python backtesting workflows.

## CSV Schema

```
DateTime, Open, High, Low, Close, TickDelta, VolumeDelta, Volume,
VWAP, Range, TickCount, TicksPerSec, CumDelta, Session
```

(Identical to MT5 sibling — Python loaders work for both.)

## Volume Note

cTrader's tick API does not expose per-tick volume. Each tick is counted as **1 unit** for the `Volume` / `VolumeDelta` / `VWAP` columns. For Forex this matches MT5's behaviour exactly. For futures or exchange-feed symbols, MT5 may report real volume; this cTrader port will not.

## Parameter Mapping (MT5 → cTrader)

| MT5 input | cTrader Parameter | Default |
|-----------|-------------------|---------|
| `InpCSVFileName` | `Output Filename (blank = auto)` | "" |
| (n/a — MT5 uses Common Data) | `Output Folder` | "" → `MyDocuments\cAlgoData` |
| `InpAppendMode` | `Append Mode` | false |
| `InpCandleMinutes` | `Candle Minutes` | 1 |
| `InpSessionFilter` | `Session Filter` | "ALL" |
| `InpWriteLastCandle` | `Write Last Candle on Stop` | true |
| `InpPrintEachCandle` | `Print Each Candle` | false |
| `InpFlushEveryN` | `Flush Every N Candles` | 10 |

## Install

1. Open cTrader → **Automate** → New cBot → name it `CandleDataCollector`.
2. Replace generated source with `src/CandleDataCollector.cs`.
3. Build (F6). The cBot needs `AccessRights = FileSystem` (already set in the source).
4. Drop on a chart, set parameters, **Start**.
5. CSV appears in `MyDocuments\cAlgoData\` (or the path you configured).

## Status

Active port. Schema matches MT5 sibling. Volume per-tick = 1 unit (documented limitation).

## Author

**Dhruv Sharma** · [linkedin.com/in/dhruvsharmainfo](https://www.linkedin.com/in/dhruvsharmainfo)
