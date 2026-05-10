# Project State: TickDataCollector

## Status
Active — v2.00 refactored 2026-05-06

## What It Does
Attaches to any chart, writes every tick as a CSV row with running candle-window statistics. Designed for tick-resolution analysis in a Python backtester.

## Last Change (2026-05-06)
Full rewrite from scratch. Original `DataCollector.mq5` had critical bugs and missing features. Renamed to `TickDataCollector.mq5`. Moved to src/ subfolder, split Config.mqh out.

**Bugs fixed in rewrite:**
- Used `tick.last` only — writes 0 for all FX symbols. Now uses `(bid+ask)/2` fallback
- No upVolume/downVolume tracking — CandleVolDelta was always 0 (now tracked)
- `ticksPerSecond = tickCount` when elapsed==0 was misleading (now returns 0.0)
- FILE_CSV append mode unreliable (switched to FILE_TXT + FileWriteString)
- No input validation on CandleMinutes

**New features added:**
- Ms column: millisecond component from tick.time_msc (0–999)
- SpreadPts column: (ask − bid) / _Point per tick
- CandleOpen/High/Low: running OHLC context for the candle window
- CandleVolDelta: running volume delta within candle window
- CumDelta: cumulative direction count from EA start (persists across candle windows)
- InpPriceChangeOnly: skip same-price ticks to reduce file size
- InpSessionFilter: write only during specific session
- Auto-filename: SYMBOL_ticks_YYYYMMDD.csv when InpCSVFileName is blank
- Append mode
- OffHours session label

## Architecture Notes
- Single file + Config.mqh
- CumDelta updates even for filtered ticks (session filter / price-change filter) so the running total is market-accurate
- g_lastPrice resets to 0 on each new candle window so first tick of new window is always NEUTRAL
- g_cLow guarded against 0-init: `if(price < g_cLow || g_cLow == 0)`
- Flush every InpFlushEveryN ticks (default 500); increase for quiet symbols, decrease for high-frequency
