# Memory: CandleDataCollector.mq5

## Purpose
Builds tick-aggregated candles and writes one CSV row per completed candle.

## Exports (functions)
- OnInit() → int — opens/creates CSV file, writes header, validates inputs
- OnTick() → void — routes tick to StartCandle / UpdateCandle / FlushCandle
- OnDeinit() → void — optionally flushes last candle, closes file
- StartCandle(cTime, tTime, tick, price) → void — resets all candle state
- UpdateCandle(tick, price) → void — updates OHLC, delta counters, VWAP numerator
- FlushCandle() → void — computes derived metrics, writes CSV row, bumps g_cumDelta
- WriteHeader() → void — writes 14-column header to file
- BuildFilename() → string — returns InpCSVFileName or auto-generated name
- GetSession(t) → string — maps UTC hour to session label

## Dependencies
- Imports from: Config.mqh
- Imported by: none (top-level EA)

## Key Decisions
- 2026-05-06 — Uses FILE_TXT + FileWriteString instead of FILE_CSV for reliable append mode
- 2026-05-06 — Price uses tick.last when > 0, else (bid+ask)/2 for FX compatibility
- 2026-05-06 — First tick of candle sets Open; stored in StartCandle with tickCount=1 and lastPrice=price, so its direction is always NEUTRAL
- 2026-05-06 — g_cumDelta accumulates TickDelta per candle; resets only on EA restart

## Known Issues / TODOs
- [ ] g_cumDelta uses int — could overflow after ~2 billion net ticks; unlikely in practice

## Last Modified
- Date: 2026-05-06
- Change: v2.00 full rewrite — bug fixes + VWAP, Range, TickCount, CumDelta, append mode, auto-filename, session filter
