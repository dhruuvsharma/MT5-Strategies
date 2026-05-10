# Memory: Utils.mqh

## Purpose
Trading hours filter and all chart drawing helpers (trend lines, triangles, object deletion).

## Exports (public symbols)
- `IsWithinTradingHours() → bool` — compares broker time against InpTradingStart/EndTime
- `DeleteChartObjects(string prefix) → void` — deletes all chart objects whose name starts with prefix
- `CreateTrendLine(name, t1, p1, t2, p2, color) → void` — draws a single non-ray trend line segment
- `DrawTriangle(prefix, t1,p1, t2,p2, t3,p3, color) → void` — draws three segments forming a closed triangle
- `UpdateDrawings(const CandleData &, bool highGreen, bool lowGreen, datetime) → void` — clears and redraws both high and low triangles for the current bar

## Dependencies
- Imports from: Config.mqh, Market.mqh
- Imported by: SwingTagEA.mq5

## Key Decisions
- 2026-04-05 — Renamed DeleteObjects → DeleteChartObjects to avoid conflict with MQL5 built-in naming style
- 2026-04-05 — Removed redundant `if(!UseTradingHours) return true` from IsWithinTradingHours — the OnTick caller already gates the call; the inner bypass was dead code
- 2026-04-05 — UpdateDrawings takes CandleData struct instead of 14 individual parameters — matches Market.mqh refactor

## Known Issues / TODOs
- [ ] None

## Last Modified
- Date: 2026-04-05
- Change: Created from original drawing/utility functions during v2.0.0 refactor
