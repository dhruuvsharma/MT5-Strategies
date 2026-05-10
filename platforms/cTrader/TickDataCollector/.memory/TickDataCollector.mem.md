# Memory: TickDataCollector.cs

## Purpose
Single-file cAlgo cBot port of MT5 TickDataCollector — per-tick CSV writer with running candle-window context. No trading.

## Public surface
- `class TickDataCollector : Robot`
- `[Parameter]` properties: `CSVFileName`, `OutputFolder`, `AppendMode`, `CandleMinutes`, `SessionFilter`, `PriceChangeOnly`, `FlushEveryN`
- `OnStart() / OnTick() / OnStop()` overrides

## Dependencies
- cAlgo.API, cAlgo.API.Internals
- System, System.IO

## Key decisions
- 2026-05-10 — Per-tick volume = 1 (cAlgo limitation).
- 2026-05-10 — `_cumDelta` updates regardless of SessionFilter (MT5 parity).
- 2026-05-10 — Spread points = `Symbol.Spread / Symbol.TickSize`, rounded to one decimal.
- 2026-05-10 — Default output to `MyDocuments\cAlgoData\`.

## Known issues / TODOs
- [ ] Per-tick volume = 1 (limitation, not bug)
- [ ] Verify spread-point conversion vs MT5 on same broker

## Last Modified
- Date: 2026-05-10
- Change: Initial port from MT5 TickDataCollector v2.00
