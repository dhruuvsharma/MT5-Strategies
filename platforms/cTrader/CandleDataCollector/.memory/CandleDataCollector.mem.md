# Memory: CandleDataCollector.cs

## Purpose
Single-file cAlgo cBot port of MT5 CandleDataCollector — aggregates ticks into N-minute candles, writes per-candle CSV with delta/VWAP/cumulative-delta columns. No trading.

## Public surface
- `class CandleDataCollector : Robot`
- `[Parameter]` properties: `CSVFileName`, `OutputFolder`, `AppendMode`, `CandleMinutes`, `SessionFilter`, `WriteLastCandle`, `PrintEachCandle`, `FlushEveryN`
- `OnStart() / OnTick() / OnStop()` overrides

## Dependencies
- cAlgo.API, cAlgo.API.Internals
- System, System.IO

## Key decisions
- 2026-05-10 — Per-tick volume hard-coded to 1 (cAlgo doesn't expose it).
- 2026-05-10 — `CultureInfo.InvariantCulture` on every numeric ToString to guarantee dot-decimal CSV.
- 2026-05-10 — Default output to `MyDocuments\cAlgoData\` (cross-OS friendly via SpecialFolder).
- 2026-05-10 — `[Robot(AccessRights = AccessRights.FileSystem)]` — required for StreamWriter.

## Known issues / TODOs
- [ ] Per-tick volume = 1 (limitation, not bug)
- [ ] Verify `Server.Time` UTC assumption on first run

## Last Modified
- Date: 2026-05-10
- Change: Initial port from MT5 CandleDataCollector v2.00
