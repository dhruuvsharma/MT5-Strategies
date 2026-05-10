# ApexScalper (cTrader) — Project State

## Current Status
- **Version:** 0.10 (WIP SCAFFOLD)
- **Source of truth:** `platforms/MT5/ApexScalper/` for signal math
- **Built/tested:** scaffold compiles (assumed); no signals implemented; no trades

## What's Done (2026-05-10)
- Project skeleton matching MT5 architecture under `src/Signals`, `src/Engine`, `src/Risk`, `src/Execution`
- `ISignal` interface + `SignalBase` abstract base
- All 8 signal classes present as STUBS (`Score = 0.0`)
- `ScoringEngine` with freshness-aware weighted composite
- `ConflictFilter` with top-2 disagreement check
- `RegimeClassifier` (passthrough)
- `RiskManager` (spread gate only)
- `TradeManager.OpenPosition` (logged stub, no trade placed)
- Documentation: README.md (status + impl order), CLAUDE.md (per-folder guide)

## What's NOT Done
- 8 signal Evaluate() implementations
- VolumeProfile builder
- FootprintBuilder
- MarketDepth subscription wrapper
- Full RegimeClassifier
- Daily loss / position cap / cooldown / session gates
- HVP-anchored SL/TP
- Dashboard panel
- CSV logging

## Recommended Next Steps
1. Port DeltaSignal first (simplest, reuse CumulativeDeltaScalper.cs delta logic)
2. Port TapeSpeed second (just tick-rate)
3. Build a VolumeProfile helper (`Data/VolumeProfile.cs`) before tackling HVPSlope/Absorption
4. Wire MarketDepth subscription before OBI signals
5. Stand up basic risk gates (daily loss, position cap) before flipping `OpenPosition` from stub

## Architecture Notes
- Each signal is a class implementing `ISignal`. `Update()` mutates `Score` and `IsFresh`.
- `ScoringEngine` re-normalises across fresh signals only.
- TTL semantics: signals mark `IsFresh = false` when their underlying data is too old; ScoringEngine drops them, doesn't zero-score them.
- Same `[-3.0, +3.0]` score range as MT5.

## Files
- src/ApexScalper.cs — Robot
- src/Signals/{SignalBase, Delta, VPIN, OBIShallow, OBIDeep, Footprint, Absorption, TapeSpeed, HVPSlope}.cs
- src/Engine/{ScoringEngine, ConflictFilter, RegimeClassifier}.cs
- src/Risk/RiskManager.cs
- src/Execution/TradeManager.cs

## Hard Constraints (carried from MT5)
- Score range `[-3.0, +3.0]` per signal
- Composite is weighted mean over fresh signals (not over all)
- Top-2 conflict block applies near threshold (1.3× band)
- Min agreeing signals default 4-of-8
- Magic-number → `Label` (string) — single value `TradeLabel`
