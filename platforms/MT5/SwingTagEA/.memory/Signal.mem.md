# Memory: Signal.mqh

## Purpose
Detects 3-bar swing pivot structures and returns the signal type and entry price. No trade calls, no drawing.

## Exports (public symbols)
- `IsMidHighAboveOld(const CandleData &) → bool` — true when midHigh > oldHigh
- `IsMidLowAboveOld(const CandleData &) → bool` — true when midLow > oldLow
- `DetectBearishPivot(const CandleData &) → bool` — both mid extremes above old → swing high
- `DetectBullishPivot(const CandleData &) → bool` — both mid extremes below old → swing low
- `GetSignal(const CandleData &, ENUM_ORDER_TYPE &, double &) → bool` — fills signal type and entry; false = no signal (mixed bar)

## Dependencies
- Imports from: Config.mqh, Market.mqh
- Imported by: SwingTagEA.mq5

## Key Decisions
- 2026-04-05 — `IsAboveLine` math bug preserved: original function always simplified to `testPrice > endPrice` due to slope × full_span cancellation. Implemented as direct comparison to preserve the exact strategy edge. See code comment in Signal.mqh for full explanation.
- 2026-04-05 — Bar[1] (new) does NOT affect signal — only mid vs old comparison determines entry. Bar[1] is used only for drawing.

## Known Issues / TODOs
- [ ] True trend-line interpolation (fixing the IsAboveLine bug) is a potential variant to back-test separately — do NOT apply to main file without explicit user approval

## Last Modified
- Date: 2026-04-05
- Change: Created from original IsAboveLine / OnTick signal logic during v2.0.0 refactor
