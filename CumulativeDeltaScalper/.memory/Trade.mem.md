# Memory: Trade.mqh

## Purpose
Order placement (CTrade), three fast-exit mechanisms (time / adverse-delta / breakeven), and position-state tracking.

## Exports (public functions / objects)
- g_trade (CTrade), g_posInfo (CPositionInfo)
- TradeInit() → void — sets magic, slippage, fill type
- HasOpenPosition() → bool
- OpenTrade(int direction) → bool — uses risk-based lots, sets g_lastTradeTime / g_openTradeTime / g_openTradeDirection, increments g_sessionTradeCount on success
- CloseOurPosition(string reason) → void — close at market with audit log
- ApplyBreakeven() → void — moves SL to entry + BE_BUFFER_PIPS once profit ≥ BreakevenPips (uses g_pipSize, broker-aware)
- _TryTimeExit() / _TryAdverseExit() → bool — internal helpers
- ManageOpenTrade() → void — orchestrates time exit → adverse-delta exit → breakeven, in that order; clears tracking when no position

## Dependencies
- Imports from: Risk.mqh, <Trade/Trade.mqh>, <Trade/PositionInfo.mqh>
- Imported by: Utils.mqh

## Key Decisions
- 2026-05-08 — v2.0:
  - Removed `g_dailyTradeCount++` from OpenTrade (now sourced from GetDailyStats which counts both closed deals and open positions).
  - Pass 0.0 as price to CTrade.Buy/Sell so the broker resolves at send-time (avoids stale-price rejection).
  - Pip math now uses g_pipSize (computed in MarketInit) instead of hardcoded `10.0 * Point`.
  - Three exits in priority order: TIME_EXIT (deadline), ADVERSE_DELTA (cumDelta flips against position), then BE.
  - AdverseDeltaCooldown prevents premature exit on entry-tick noise.

## Last Modified
- Date: 2026-05-08
- Change: v2 — risk-based lots, time exit, adverse-delta exit, broker-aware pip math, removed daily-count double-increment.
