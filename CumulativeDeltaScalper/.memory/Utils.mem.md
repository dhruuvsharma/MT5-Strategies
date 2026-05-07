# Memory: Utils.mqh

## Purpose
Daily statistics (history + open positions), 9-line dashboard with session/ADX/dynamic-spread surface, sliding-window rect, per-candle delta labels, footprint cells.

## Exports (public functions)
- GetDailyStats(double &todayPnL, int &todayTrades) — sums today's exit deals AND counts still-open positions opened today (fixes v1 count drift)
- CheckLastTradeLoss() — scans history for most recent loss, updates g_lastLossTime
- ResetDailyCounters() — daily roll, syncs from history
- CreateLabel / InitDashboard / UpdateDashboard / RemoveDashboard
- DrawSlidingWindow / DisplayCandleDeltas / DisplayFootprint / BuildBarFootprint / GetCellBgColor / GetCellTxColor / RemoveWindowObjects

## Dashboard layout (9 lines)
0. title
1. cumdelta + window-fill
2. livedelta + up/down
3. **session**: name + W/L (NEW v2)
4. trades: D x/MAX  S x/MAX (refactored to show session count too)
5. pnl
6. spread: current + rolling avg (NEW: avg)
7. **adx**: current + threshold (NEW v2)
8. status

## Dependencies
- Imports from: Trade.mqh (→ Risk → Signal → Market → Config)
- Imported by: CumulativeDeltaScalper.mq5

## Key Decisions
- 2026-05-08 — v2.0: GetDailyStats now also walks PositionsTotal() to include still-open positions opened today, eliminating the v1 race where the count would dip while a trade was open.
- Dashboard extended to 9 labels; SessionName/GetADX/GetAvgSpread surfaced via the Risk/Market chain.

## Last Modified
- Date: 2026-05-08
- Change: v2 — GetDailyStats fix + dashboard extension (session, ADX, avg spread).
