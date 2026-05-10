# Memory: Config.mqh

## Purpose
All user-configurable inputs for TickDataCollector.

## Exports (inputs)
- InpCSVFileName (string) — output filename; blank triggers auto-name SYMBOL_ticks_YYYYMMDD.csv
- InpAppendMode (bool) — append to existing file vs overwrite
- InpCandleMinutes (int) — candle window for running delta/OHLC context; validated > 0 in OnInit
- InpSessionFilter (string) — write filter: ALL | Asian | London | London-NewYork | NewYork
- InpPriceChangeOnly (bool) — skip ticks where price did not change
- InpFlushEveryN (int) — flush to disk every N ticks (default 500)

## Dependencies
- Imports from: none
- Imported by: TickDataCollector.mq5

## Last Modified
- Date: 2026-05-06
- Change: Created in v2.00 refactor
