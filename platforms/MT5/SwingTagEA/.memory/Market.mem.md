# Memory: Market.mqh

## Purpose
Defines the `CandleData` struct and `GetCandleData()` — the single entry point for all price data in the EA.

## Exports (public symbols)
- `struct CandleData` — holds highs, lows, and open times for bars [3], [2], [1]
  - Fields: `highOld/Mid/New`, `lowOld/Mid/New`, `timeOld/Mid/New`
  - old = bar[3], mid = bar[2], new = bar[1]
- `GetCandleData(CandleData &data) → bool` — fills struct; returns false if fewer than MIN_BARS_REQUIRED bars exist

## Dependencies
- Imports from: Config.mqh
- Imported by: Signal.mqh, Utils.mqh, SwingTagEA.mq5

## Key Decisions
- 2026-04-05 — Replaced 12-parameter out-variable function signature with a single struct for readability and maintainability
- 2026-04-05 — Bar naming: old/mid/new instead of H1/H2/H3 (original naming was confusing — H1 mapped to bar[3], not bar[1])

## Known Issues / TODOs
- [ ] None

## Last Modified
- Date: 2026-04-05
- Change: Created from original GetCandleData() during v2.0.0 refactor
