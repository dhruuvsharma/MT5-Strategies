# ApexScalper (cTrader) — WIP Scaffold

> ⚠️ **Status: Work-In-Progress scaffold.** This cBot is a structural skeleton. All 8 order-flow signals return 0.0 — **no trades will be placed** until the signals are implemented. Do not run on a live account expecting it to trade.

cTrader / cAlgo port of [ApexScalper-MT5](../../MT5/ApexScalper) — microstructure scalper that combines 8 weighted order-flow signals into a composite scoring engine.

## What's Implemented

✅ Project structure mirroring MT5 architecture (Signals / Engine / Risk / Execution)
✅ `ISignal` interface + `SignalBase` abstract class
✅ All 8 signal classes with documented TODOs pointing at the MT5 reference
✅ `ScoringEngine` — weighted composite, freshness-aware re-normalisation
✅ `ConflictFilter` — top-2 weight disagreement near threshold
✅ `RiskManager.AllowEntry` — spread gate (only)
✅ Robot orchestration that wires it all together

## What's NOT Implemented

❌ Actual signal math for any of the 8 signals (all return 0.0)
❌ Volume profile / HVP node detection
❌ Footprint builder (per-candle bid/ask volume cells)
❌ Market depth subscription handling
❌ Regime classifier (ADX+BB+VPOC)
❌ Daily loss / peak equity / position cap risk gates
❌ Trade execution (`TradeManager.OpenPosition` is a no-op stub)
❌ SL/TP anchoring to HVP nodes
❌ Live dashboard panel
❌ CSV logging

## Why a Scaffold?

The MT5 ApexScalper is ~40 modules across 9 folders, built over 13 sessions. Faithfully porting all the signal math, regime classifier, HVP/footprint builders, and execution logic is a multi-day project — not a single-session item. Producing this scaffold gives you:

1. **A compilable cTrader project** with the right structure
2. **Clear TODOs** in every signal class pointing to the MT5 reference math
3. **Working composite + conflict-filter scaffolding** so when signals come online you can test them in isolation against the same composite logic

## Recommended Implementation Order

1. **DeltaSignal** — simplest; reuse logic from `CumulativeDeltaScalper.cs` (cTrader)
2. **TapeSpeedSignal** — independent, just tick-rate Z-score
3. **AbsorptionSignal** — uses Bars data only
4. **VPINSignal** — needs trade classification
5. **OBIShallowSignal / OBIDeepSignal** — both need `Symbol.MarketDepth` subscription
6. **FootprintSignal** — needs per-tick price-bucketing
7. **HVPSlopeSignal** — needs full VolumeProfile builder
8. **RegimeClassifier** — depends on having a few signals working to validate

## Install

1. Open cTrader → **Automate** → New cBot → name it `ApexScalper`.
2. Copy ALL `.cs` files from `src/` (and subdirectories) into the cTrader project. cAlgo compiles all `.cs` files in the project together.
3. Build (F6). The scaffold should compile cleanly.
4. Drop on a chart. The cBot logs `"SCAFFOLD initialised"` and runs without placing trades.

## Author

**Dhruv Sharma** · [linkedin.com/in/dhruvsharmainfo](https://www.linkedin.com/in/dhruvsharmainfo)
