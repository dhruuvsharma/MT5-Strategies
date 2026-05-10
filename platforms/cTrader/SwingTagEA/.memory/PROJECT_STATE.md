# SwingTagEA (cTrader) — Project State

## Current Status
- **Version:** 1.00 (initial cTrader port)
- **Source of truth:** `platforms/MT5/SwingTagEA/` (parity reference)
- **Built/tested:** code-review only — needs first compile + tester run in cTrader

## What Changed Recently
- 2026-05-10 — Initial port from MT5. Single-file cBot with logical layers as comment regions. Bar indexing mapped 1:1 (`Last(1)` ≡ MT5 `bar[1]`). SL/TP converted from MT5 points to cAlgo pips via `Symbol.TickSize / Symbol.PipSize` ratio.

## Open TODOs
- [ ] First compile + tester run in cTrader (visual verify entries match MT5 sibling on same DAX session)
- [ ] Confirm `Symbol.PipSize` for the broker's DAX symbol — note in README if non-standard
- [ ] Add `.algo` packaging if user wants distributable bundle (currently raw `.cs` only)

## Architecture
Single class `SwingTagEA : Robot`. Logical layers are kept as comment-region blocks inside the file:
- Config — `[Parameter]` properties
- Market — `CandleData` struct + `GetCandleData()`
- Signal — pivot detection (preserves MT5's `IsAboveLine` quirk)
- Risk — `PointsToPips()` for SL/TP conversion
- Trade — `HasActivePosition`, `DeletePendingOrdersByType`, `SendPendingLimitOrder`, `ProcessSignal`
- Utils — `IsWithinTradingHours`, chart-drawing helpers

## Hard Constraints (carried from MT5)
- IsAboveLine quirk preserved verbatim — no "fix"
- Bar mapping: `old=Last(3) mid=Last(2) new=Last(1)` — never read live bar
- Mixed signal (highGreen != lowGreen) → no trade, no log
- All chart objects under prefix are deleted before each redraw
