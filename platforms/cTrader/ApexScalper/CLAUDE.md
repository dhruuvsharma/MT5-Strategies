# ApexScalper (cTrader) — Strategy-Specific Claude Instructions

> **STATUS: WIP scaffold.** This is a structural skeleton, not a production cBot. Signals all return 0.0 from `Evaluate()`. The Robot will compile, run, and place no trades.

> Also follow `/CLAUDE.md` and the MT5 sibling at `platforms/MT5/ApexScalper/CLAUDE.md`. The MT5 EA is the source of truth for all signal math.

## What's in the scaffold

```
src/
├── ApexScalper.cs           Robot — wires signals + engine + risk + trade
├── Signals/
│   ├── SignalBase.cs        ISignal interface + abstract base
│   ├── DeltaSignal.cs       cumulative delta — STUB
│   ├── VPINSignal.cs        flow toxicity — STUB
│   ├── OBIShallowSignal.cs  top-3 OBI — STUB (needs MarketDepth)
│   ├── OBIDeepSignal.cs     top-10 OBI — STUB (needs MarketDepth)
│   ├── FootprintSignal.cs   stacked imbalance — STUB
│   ├── AbsorptionSignal.cs  vol/range — STUB
│   ├── TapeSpeedSignal.cs   trade-rate Z-score — STUB
│   └── HVPSlopeSignal.cs    HVP regression slope — STUB
├── Engine/
│   ├── ScoringEngine.cs     weighted composite — IMPLEMENTED
│   ├── ConflictFilter.cs    top-2 disagree near threshold — IMPLEMENTED
│   └── RegimeClassifier.cs  ADX+BB+VPOC regime detection — STUB
├── Risk/
│   └── RiskManager.cs       spread gate IMPLEMENTED, rest STUB
└── Execution/
    └── TradeManager.cs      OpenPosition() STUB (no trades placed)
```

## To Complete the Port

1. **Each signal's `Update()` method** — the math is documented in the MT5 sibling's
   corresponding `.mqh` file in `platforms/MT5/ApexScalper/Signals/`.
2. **`RegimeClassifier.WeightMultiplier()`** — currently passthrough. Implement using
   M15 ADX + BB-width + VPOC stability per MT5 RegimeClassifier.mqh.
3. **`RiskManager`** — daily loss circuit breaker, peak equity drawdown, position cap,
   bar cooldown, session toggles. Mirror MT5 RiskManager + SessionFilter + SpreadFilter.
4. **`TradeManager.OpenPosition`** — anchor SL behind nearest HVP/imbalance level,
   TP at opposing HVP, trailing after first TP hit. Mirror MT5 TradeManager + StopLossEngine + TakeProfitEngine.
5. **VolumeProfile / FootprintBuilder** — needed by HVPSlope and Absorption signals.
   In MT5 these live in `Data/`; in cAlgo they need to be built from `Bars`+`MarketDepth`+`OnTick` since cAlgo has no direct CopyTicksRange equivalent.

## Hard Constraints

- The directory structure is **deliberate** — mirrors MT5 architecture (data → signal → scoring → confirmation → execution). Don't flatten or rename.
- All score arithmetic must respect the `[-3.0, +3.0]` convention.
- `IsFresh = false` excludes a signal from composite (TTL decay). Don't zero-score for "stale" — drop it from the weighted mean instead. (`ScoringEngine` re-normalizes correctly.)
- The conflict filter's "near threshold" band is `1.3 × threshold`. Don't change without testing.

## Why Not a Full Port?

The MT5 EA is ~40 modules, ~13 build sessions of work. Porting all signals correctly to cAlgo requires:
- A volume-profile builder (MT5's `Data/VolumeProfile.mqh`)
- A footprint builder (MT5's `Data/FootprintBuilder.mqh`)
- A market-depth subscription wrapper (cAlgo `Symbol.MarketDepth.Updated`)
- A tick collector (MT5's `Data/TickCollector.mqh`)

These are foundational and not trivial. The recommended next step is to port one signal end-to-end (DeltaSignal is simplest) and use it as the template for the remaining seven.
