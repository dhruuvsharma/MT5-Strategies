# CandleDataCollector (cTrader) — Project State

## Current Status
- **Version:** 1.00 (initial port)
- **Source of truth:** `platforms/MT5/CandleDataCollector/`
- **Built/tested:** code review only

## What Changed Recently
- 2026-05-10 — Initial port. Single-file cBot, FileSystem access rights, default output to `MyDocuments\cAlgoData`. CSV schema matches MT5 sibling exactly.

## Architecture
Single class `CandleDataCollector : Robot`. Sections:
- Parameters (file/folder/append/candle TF/session filter/flush)
- Lifecycle (`OnStart` opens file, `OnTick` aggregates, `OnStop` flushes last candle)
- Helpers: `TruncateToCandle`, `StartCandle`, `UpdateCandle`, `FlushCandle`, `WriteHeader`, `BuildFilename`, `GetSession`

## Known Limitations
- Per-tick volume is hard-coded to 1.0 (cTrader doesn't expose tick volumes per OnTick call). Matches MT5 Forex; underestimates futures volume.
- `Server.Time` assumed to be UTC for session-bucketing. Verify on broker.

## TODOs
- [ ] First-run validation: write a few minutes of data, compare CSV to MT5 output for the same window
- [ ] Add `OnBar` flush as a backup in case `OnTick` doesn't fire on a quiet symbol
