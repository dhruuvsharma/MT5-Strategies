# Memory: Trade.mqh

## Purpose
All order and position operations via CTrade/CPositionInfo/COrderInfo. The only file in the project that issues trade commands.

## Exports (public symbols)
- `g_trade` (CTrade) — global trade object; configured in InitTradeObjects()
- `g_position` (CPositionInfo) — global position info object
- `g_order` (COrderInfo) — global order info object
- `InitTradeObjects() → void` — call once from OnInit; sets magic, deviation, fill mode
- `HasActivePosition(ENUM_ORDER_TYPE) → bool` — checks for open position in same direction on same symbol
- `DeletePendingOrdersByType(ENUM_ORDER_TYPE) → void` — cancels stale pending orders of given type
- `SendPendingOrder(ENUM_ORDER_TYPE, price, sl, tp) → bool` — places limit order with normalised values
- `ProcessSignal(ENUM_ORDER_TYPE, double entryPrice) → void` — orchestrates management + order placement

## Dependencies
- Imports from: Config.mqh, Risk.mqh, <Trade\Trade.mqh>, <Trade\PositionInfo.mqh>, <Trade\OrderInfo.mqh>
- Imported by: SwingTagEA.mq5

## Key Decisions
- 2026-04-05 — Replaced raw OrderSend/MqlTradeRequest with CTrade — provides type validation, automatic error logging, and standard API
- 2026-04-05 — Symbol filter added to HasActivePosition and DeletePendingOrdersByType — original had no symbol check; bug on multi-chart setups
- 2026-04-05 — ResetLastError() called before every trade operation — original could read stale error codes
- 2026-04-05 — NormalizeDouble(InpLots, 2) added — original passed raw double volume which some brokers reject
- 2026-04-05 — ORDER_FILLING_FOK kept as default; documented as broker-dependent in CLAUDE.md

## Known Issues / TODOs
- [ ] ORDER_FILLING_FOK may need to be configurable input for broker compatibility
- [ ] ORDER_TIME_GTC may be capped by some brokers — may need ORDER_TIME_DAY fallback

## Last Modified
- Date: 2026-04-05
- Change: Created from original trade functions during v2.0.0 refactor; CTrade adopted, bugs fixed
