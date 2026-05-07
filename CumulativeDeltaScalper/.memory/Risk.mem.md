# Memory: Risk.mqh

## Purpose
Session detection (3 toggles + overlap), risk-based lot sizing, ATR stop distances with broker stops-level guard, and the master CheckGuards orchestrator.

## Exports (public functions)
- GetCurrentSessionID() → ENUM_SESSION_ID — Asia/London/NY/Overlap or NONE based on GMT minute and toggles
- SessionName(ENUM_SESSION_ID) → string
- UpdateSessionState() → void — resets session counters when active session changes
- IsInSession() → bool — wrapper, honors UseSessionFilter
- EnsureMinStopDistance(double dist) → double — clamps to broker SYMBOL_TRADE_STOPS_LEVEL × buffer
- CalcSLDistance() / CalcTPDistance() → double — ATR × multiplier, with stops-level guard
- CalcLotSize() → double — risk-based via balance × Risk% / (slDist/tickSize × tickValue), clamped to broker min/max/step and MaxLotSize; falls back to FixedLotSize if UseRiskBasedSizing=false
- CheckGuards(string &reason) → bool — composes _GuardSession / _GuardSpreadHardCap / _GuardCounts / _GuardLossLimit / _GuardCooldowns / _GuardVolatility

## Dependencies
- Imports from: Signal.mqh (→ Market.mqh → Config.mqh)
- Imported by: Trade.mqh

## Key Decisions
- 2026-05-08 — v2.0: replaced hardcoded London-OR-NY session with 3 independent GMT toggles + OverlapOnly preset; sessions support per-session start/end minute precision (NY is 12:30, not 13:00).
- Risk-based sizing made default (UseRiskBasedSizing=true). MaxLotSize is a hard safety cap independent of broker max.
- CheckGuards split into 6 sub-helpers (each <40 lines) per repo convention.
- Stops-level guard prevents broker rejection when ATR shrinks below SYMBOL_TRADE_STOPS_LEVEL.

## Last Modified
- Date: 2026-05-08
- Change: v2 — session selector, risk-based lots, stops-level guard, guard split.
