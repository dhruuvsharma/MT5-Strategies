# Memory: SwingTagEA.mq5

## Purpose
Core EA file — contains only OnInit, OnDeinit, and OnTick. Pure orchestration; zero business logic lives here.

## Exports (public symbols)
- `OnInit() → int` — calls InitTradeObjects(), resets bar-change guard, logs startup
- `OnDeinit(int reason) → void` — deletes all chart objects, logs shutdown
- `OnTick() → void` — gates by session time → bar-change guard → data fetch → drawing → signal → trade

## Dependencies
- Imports from: Config.mqh, Market.mqh, Signal.mqh, Risk.mqh, Trade.mqh, Utils.mqh
- Imported by: MetaTrader 5 runtime

## Key Decisions
- 2026-04-05 — `g_lastProcessedTime` global replaces original `lastProcessedTime` (added g_ prefix per MQL5 global naming convention)
- 2026-04-05 — `#property strict` removed — MQL4-only directive
- 2026-04-05 — version bumped to 2.00 for the refactored release
- 2026-04-05 — OnTick reads as plain English: each step is a named function call with no raw logic

## Known Issues / TODOs
- [ ] None

## Last Modified
- Date: 2026-04-05
- Change: Full rewrite from monolithic v1 to orchestration-only v2.00
