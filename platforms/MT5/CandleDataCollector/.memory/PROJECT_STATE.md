# Project State: CandleDataCollector

## Status
Active — v2.00 refactored 2026-05-06

## What It Does
Attaches to any chart, builds custom-timeframe candles from live ticks, writes one CSV row per completed candle. Designed to feed a Python backtester.

## Last Change (2026-05-06)
Full rewrite from scratch. Original was a single monolithic UTF-16 file with several bugs. Moved to src/ subfolder, split Config.mqh out, rewrote with proper MQL5 patterns.

**Bugs fixed in rewrite:**
- FinalizeAndWriteCandle used the NEW candle's tick for bid/ask (now bid/ask removed from candle row — not meaningful at candle level)
- tick.last == 0 on FX not handled (now uses mid-price fallback)
- Duplicate Print logic (removed)
- No validation on CandleMinutes input (added INIT_PARAMETERS_INCORRECT guard)
- FILE_CSV append mode unreliable (switched to FILE_TXT + FileWriteString)

**New features added:**
- Auto-filename: SYMBOL_Nmin_YYYYMMDD.csv when InpCSVFileName is blank
- Append mode: opens with FILE_READ|FILE_WRITE, seeks to EOF, skips header rewrite
- VWAP per candle (volume-weighted average price)
- Range column (High − Low in price units)
- TickCount column (ticks per candle)
- CumDelta column (cumulative tick delta across all candles)
- InpWriteLastCandle: flush incomplete candle on shutdown
- InpSessionFilter: write only during specific session
- InpPrintEachCandle: optional terminal echo
- InpFlushEveryN: configurable disk flush frequency
- "OffHours" session label for 22:00–22:59 UTC (previously fell through to "Asian")

## Architecture Notes
- Single file + Config.mqh (no Signal/Risk/Trade — not a trading EA)
- g_cumDelta accumulates across all candles; resets only on EA restart
- First tick of each candle sets Open but direction is neutral (g_lastPrice = price in StartCandle)
- Candle is written when the next candle's first tick arrives, NOT on a timer
