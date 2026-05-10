# Memory: Config.mqh

## Purpose
Defines all user-facing `input` parameters and compile-time `#define` constants for SwingTagEA. Contains zero logic.

## Exports (public symbols)
- `InpLots` (double) — trade volume in lots
- `InpSLPoints` (int) — stop loss distance in points
- `InpTPPoints` (int) — take profit distance in points
- `InpMagicNumber` (ulong) — EA instance identifier
- `InpOrderManagement` (bool) — enables position/order deduplication
- `InpUseTradingHours` (bool) — enables the session time filter
- `InpTradingStartTime` (string) — session start "HH:MM"
- `InpTradingEndTime` (string) — session end "HH:MM"
- `EA_NAME` (#define) — "SwingTagEA"
- `EA_PREFIX` (#define) — "[SwingTagEA] " used in all Print calls
- `MIN_BARS_REQUIRED` (#define) — 4
- `HIGH_LINE_PREFIX` (#define) — "HighLine"
- `LOW_LINE_PREFIX` (#define) — "LowLine"
- `LINE_WIDTH` (#define) — 2
- `ORDER_DEVIATION` (#define) — 5 (slippage points for CTrade)

## Dependencies
- Imports from: none
- Imported by: Market.mqh, Signal.mqh, Risk.mqh, Trade.mqh, Utils.mqh, SwingTagEA.mq5

## Key Decisions
- 2026-04-05 — All magic numbers extracted from original monolithic file; no inline numbers anywhere in codebase

## Known Issues / TODOs
- [ ] May need `InpOrderFilling` input for brokers that require non-FOK fill modes

## Last Modified
- Date: 2026-04-05
- Change: Created from original monolithic file during v2.0.0 refactor
