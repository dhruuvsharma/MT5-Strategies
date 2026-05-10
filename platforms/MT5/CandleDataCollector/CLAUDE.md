# CandleDataCollector — EA Instructions

## Purpose
Data collection utility — builds tick-aggregated candles and writes them to CSV for Python backtesting.
No trade execution. Single-layer design (no Signal/Risk/Trade separation needed).

## Files
| File | Role |
|------|------|
| src/Config.mqh | All inputs |
| src/CandleDataCollector.mq5 | OnInit/OnTick/OnDeinit + helpers |

## CSV Output Schema
`DateTime, Open, High, Low, Close, TickDelta, VolumeDelta, Volume, VWAP, Range, TickCount, TicksPerSec, CumDelta, Session`

- **TickDelta**: upTicks − downTicks within candle
- **VolumeDelta**: upVolume − downVolume within candle
- **VWAP**: volume-weighted average price for the candle
- **Range**: High − Low in price units
- **CumDelta**: cumulative TickDelta across all candles (resets on EA restart)
- **Session**: Asian | London | London-NewYork | NewYork | OffHours (UTC)

## Key Behaviours
- First tick of each candle sets Open; direction tracking begins from the second tick
- Candle is written when the FIRST tick of the next candle arrives (not time-based)
- `InpWriteLastCandle = true` flushes the incomplete candle on deinit
- Append mode: opens with FILE_READ|FILE_WRITE and seeks to EOF; skips header rewrite
- Price: uses `tick.last` if > 0, else `(bid+ask)/2` — compatible with both FX and futures
- Output goes to MT5 Common Data folder (`FILE_COMMON` flag)
