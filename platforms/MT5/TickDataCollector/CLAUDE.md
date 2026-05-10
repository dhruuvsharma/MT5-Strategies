# TickDataCollector — EA Instructions

## Purpose
Data collection utility — writes every tick as a CSV row with running candle-window context for Python backtesting.
No trade execution. Single-layer design.

## Files
| File | Role |
|------|------|
| src/Config.mqh | All inputs |
| src/TickDataCollector.mq5 | OnInit/OnTick/OnDeinit + helpers |

## CSV Output Schema
`DateTime, Ms, Price, Bid, Ask, SpreadPts, Volume, Direction, CandleOpen, CandleHigh, CandleLow, CandleDelta, CandleVolDelta, TicksPerSec, CumDelta, Session`

- **Ms**: millisecond component of tick.time_msc (0–999)
- **SpreadPts**: (ask − bid) / _Point
- **Direction**: UP | DOWN | NEUTRAL (relative to previous price-changing tick)
- **CandleOpen/High/Low**: running OHLC for the current InpCandleMinutes window
- **CandleDelta**: upTicks − downTicks within current candle window (resets each window)
- **CandleVolDelta**: upVolume − downVolume within current candle window
- **CumDelta**: cumulative direction count from EA start (never resets; updated even for filtered ticks)
- **Session**: Asian | London | London-NewYork | NewYork | OffHours (UTC)

## Key Behaviours
- `InpPriceChangeOnly = true` suppresses same-price ticks to reduce file size
- Session filter skips writes but still updates CumDelta and g_lastPrice
- Price: uses `tick.last` if > 0, else `(bid+ask)/2` — works for FX and futures
- Flush every `InpFlushEveryN` ticks (default 500); safe to increase for high-frequency symbols
- Output goes to MT5 Common Data folder (`FILE_COMMON` flag)
