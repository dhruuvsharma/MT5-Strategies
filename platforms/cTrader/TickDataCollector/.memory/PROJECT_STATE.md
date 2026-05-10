# TickDataCollector (cTrader) — Project State

## Current Status
- **Version:** 1.00 (initial port)
- **Source of truth:** `platforms/MT5/TickDataCollector/`
- **Built/tested:** code review only

## What Changed Recently
- 2026-05-10 — Initial port. Single-file cBot, FileSystem access. Schema matches MT5 sibling.

## Architecture
Single class `TickDataCollector : Robot`. Sections:
- Parameters
- Lifecycle (`OnStart` opens file, `OnTick` writes row, `OnStop` flushes)
- Helpers: `TruncateToCandle`, `WriteHeader`, `BuildFilename`, `GetSession`

## Known Limitations
- Per-tick volume hard-coded to 1 (cAlgo doesn't expose it).
- Millisecond field depends on broker tick timestamping; may be 0.
- `Server.Time` assumed UTC for session-bucketing.

## TODOs
- [ ] First-run validation: write a few minutes, compare to MT5 same-window output
- [ ] Verify `Symbol.Spread / Symbol.TickSize` produces same point counts as MT5's `(ask-bid)/_Point`
