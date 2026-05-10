# Memory: TickDataCollector.mq5

## Purpose
Writes every tick as a CSV row with running candle-window statistics for tick-resolution backtesting.

## Exports (functions)
- OnInit() → int — opens/creates CSV file, writes header, validates inputs
- OnTick() → void — resets candle window on boundary, classifies direction, writes row
- OnDeinit() → void — flushes and closes file
- WriteHeader() → void — writes 16-column header
- BuildFilename() → string — returns InpCSVFileName or auto-generated name
- GetSession(t) → string — maps UTC hour to session label

## Dependencies
- Imports from: Config.mqh
- Imported by: none (top-level EA)

## Key Decisions
- 2026-05-06 — g_lastPrice resets to 0 on each new candle window; first tick of window is NEUTRAL
- 2026-05-06 — CumDelta updates before session filter check so it tracks all market activity, not just written rows
- 2026-05-06 — g_cLow guarded: `price < g_cLow || g_cLow == 0` prevents 0-init corruption
- 2026-05-06 — Uses FILE_TXT + FileWriteString for reliable append; avoids FILE_CSV seek issues
- 2026-05-06 — Price uses tick.last when > 0, else (bid+ask)/2 for FX compatibility

## Known Issues / TODOs
- [ ] g_cumDelta uses int — can overflow on very long sessions; unlikely in practice
- [ ] Ms column will always be 0 if broker does not provide sub-second timestamps (tick.time_msc == tick.time * 1000)

## Last Modified
- Date: 2026-05-06
- Change: v2.00 full rewrite — renamed from DataCollector.mq5; added Ms, SpreadPts, CandleVolDelta, CumDelta, InpPriceChangeOnly, append mode, auto-filename, FX price fallback
