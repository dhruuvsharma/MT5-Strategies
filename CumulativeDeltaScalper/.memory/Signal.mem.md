# Memory: Signal.mqh

## Purpose
Cumulative delta calculation, threshold-crossover trigger, and 5-confirmation sniper gate.

## Exports (public functions)
- CalculateCumDelta() → int — sums sliding-window buffer
- DeltaCrossover() → int — 1/-1/0 (trigger only; was CheckSignal in v1)
- CheckMomentumAlignment(int signal) → bool — last 3 candle deltas all share signal sign
- CheckHTFEMA(int signal) → bool — bid on correct side of M15 EMA(50); returns true if UseHTFFilter is off
- CheckEMASlope(int signal) → bool — EMA slope direction matches signal
- CheckADXTrending() → bool — ADX ≥ ADXThreshold
- CheckSpreadDynamic() → bool — spread ≤ rolling avg × multiplier (and ≤ MaxSpreadPoints hard cap)
- CheckSniperSignal() → int — runs DeltaCrossover, then counts the 5 confirmations; returns direction only if ≥ MinConfirmations pass

## Dependencies
- Imports from: Market.mqh
- Imported by: Risk.mqh

## Key Decisions
- 2026-05-08 — v2.0: replaced single-condition CheckSignal with 5-confirmation stack. Crossover is always required; MinConfirmations is the count of supporting filters that must pass (default 5/5 = strict).

## Last Modified
- Date: 2026-05-08
- Change: v2 — confirmation-stack signal gate; PassesHTFFilter rolled into CheckHTFEMA.
