# ApexScalper (cTrader) — File Registry

> Per-file `.mem.md`s are intentionally NOT created (matches MT5 sibling convention). This table is the authoritative file registry.

## Files

| File | Layer | Status | Purpose |
|------|-------|--------|---------|
| `src/ApexScalper.cs` | Robot | WIRED | Lifecycle, signal collection, composite eval, dispatch |
| `src/Signals/SignalBase.cs` | Signals | DONE | `ISignal` interface + `SignalBase` abstract |
| `src/Signals/DeltaSignal.cs` | Signals | STUB | Z-scored cumulative delta + divergence |
| `src/Signals/VPINSignal.cs` | Signals | STUB | Volume-bucketed flow toxicity |
| `src/Signals/OBIShallowSignal.cs` | Signals | STUB | Top-3 OBI + spoof detection |
| `src/Signals/OBIDeepSignal.cs` | Signals | STUB | Top-10 OBI exp-weighted |
| `src/Signals/FootprintSignal.cs` | Signals | STUB | Stacked imbalance |
| `src/Signals/AbsorptionSignal.cs` | Signals | STUB | Volume / range Z-score |
| `src/Signals/TapeSpeedSignal.cs` | Signals | STUB | Trade-rate Z-score |
| `src/Signals/HVPSlopeSignal.cs` | Signals | STUB | Weighted lin-reg through HVP nodes |
| `src/Engine/ScoringEngine.cs` | Engine | DONE | Weighted composite + agree-count |
| `src/Engine/ConflictFilter.cs` | Engine | DONE | Top-2 disagree near threshold |
| `src/Engine/RegimeClassifier.cs` | Engine | STUB | ADX+BB+VPOC → multiplier |
| `src/Risk/RiskManager.cs` | Risk | PARTIAL | Spread gate only; rest TBD |
| `src/Execution/TradeManager.cs` | Execution | STUB | OpenPosition is no-op |

## Last Modified

- 2026-05-10 — Initial scaffold created (Dhruv Sharma + Claude port).

## Session Log

| Session | Date | What was done |
|---------|------|---------------|
| 1 | 2026-05-10 | Project scaffold + 8 signal stubs + scoring engine + conflict filter + spread-only risk + stub trade manager |
