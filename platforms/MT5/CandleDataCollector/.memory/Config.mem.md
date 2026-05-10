# Memory: Config.mqh

## Purpose
All user-configurable inputs for CandleDataCollector.

## Exports (inputs)
- InpCSVFileName (string) — output filename; blank triggers auto-name SYMBOL_Nmin_YYYYMMDD.csv
- InpAppendMode (bool) — append to existing file vs overwrite
- InpCandleMinutes (int) — candle timeframe in minutes; validated > 0 in OnInit
- InpSessionFilter (string) — write filter: ALL | Asian | London | London-NewYork | NewYork
- InpWriteLastCandle (bool) — flush incomplete candle on EA shutdown
- InpPrintEachCandle (bool) — echo each closed candle to terminal
- InpFlushEveryN (int) — flush to disk every N candles

## Dependencies
- Imports from: none
- Imported by: CandleDataCollector.mq5

## Last Modified
- Date: 2026-05-06
- Change: Created in v2.00 refactor; extracted from monolithic file
