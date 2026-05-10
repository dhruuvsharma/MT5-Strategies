# Memory: Trade.mqh

## Purpose
Order execution via CTrade, trailing stop management, position queries.

## Exports
- TradeInit() — set magic, slippage, fill type on CTrade
- EnterLong() / EnterShort() — market order with SL/TP, calls OnTradeExecuted()
- ManagePositions() — loop all EA positions for trailing
- ApplyTrailingStop(ticket) — move SL toward profit, preserves TP
- HasLongPosition() / HasShortPosition() → bool

## Dependencies
- Imports from: Config.mqh, Risk.mqh, Signal.mqh, <Trade\Trade.mqh>, <Trade\PositionInfo.mqh>
- Imported by: DeltaFadeEA.mq5

## Key Decisions
- 2026-04-06 — Replaced raw MqlTradeRequest/OrderSend with CTrade class
- 2026-04-06 — PositionModify preserves TP on SL modification
- 2026-04-11 — v3.00: Removed IsTradeTime() / lastTradeTime / MIN_TRADE_DELAY throttle. Now calls OnTradeExecuted() from Signal.mqh for bar-based cooldown tracking. Added Signal.mqh import.

## Last Modified
- Date: 2026-04-11
- Change: v3.00 — replaced time-based throttle with Signal.mqh trade management
