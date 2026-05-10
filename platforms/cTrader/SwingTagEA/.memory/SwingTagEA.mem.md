# Memory: SwingTagEA.cs

## Purpose
Single-file cAlgo cBot port of MT5 SwingTagEA — 3-bar swing pivot fade with limit orders, DAX-focused, session-gated.

## Exports (public surface)
- `class SwingTagEA : Robot` — the cBot itself
- `[Parameter]` properties: `Lots`, `SLPoints`, `TPPoints`, `OrderManagement`, `UseTradingHours`, `TradingStartTime`, `TradingEndTime`, `TradeLabel`
- `OnStart() / OnBar() / OnStop()` — lifecycle overrides

## Internal layers (within the file)
- `CandleData` struct — three-bar window (old/mid/new)
- `GetCandleData()` → CandleData — reads `Bars.HighPrices/LowPrices/OpenTimes` Last(1..3)
- `IsMidHighAboveOld / IsMidLowAboveOld / DetectBullishPivot / DetectBearishPivot / GetSignal` — pure signal logic
- `PointsToPips(int)` → double — converts MT5 points distance to cAlgo pips
- `HasActivePosition / DeletePendingOrdersByType / SendPendingLimitOrder / ProcessSignal` — trade ops via cAlgo Positions/PendingOrders
- `IsWithinTradingHours / TryParseHHMM` — session gate
- `DeleteChartObjects / CreateTrendLine / DrawTriangle / UpdateDrawings` — chart drawing via `Chart.DrawTrendLine`

## Dependencies
- cAlgo.API, cAlgo.API.Internals (cTrader Automate API)
- System, System.Linq

## Imported by
- (none — top-level cBot)

## Key Decisions
- 2026-05-10 — Single-file layout (vs MT5's 7 files). Reasoning: cBots cannot reference external files trivially, and the logic is small enough that comment regions adequately separate concerns.
- 2026-05-10 — `OnBar()` instead of `OnTick()` — natural fit for new-bar-only strategy. MT5's `_lastProcessedBarTime` guard retained as defence against duplicate invocations.
- 2026-05-10 — SL/TP conversion via `Symbol.TickSize / Symbol.PipSize` ratio — preserves the MT5 "points" semantic while using cAlgo's pip-based API.
- 2026-05-10 — Magic number → `TradeLabel` (string). cAlgo doesn't expose a numeric magic; Label filter is the canonical pattern.

## Known Issues / TODOs
- [ ] First-run validation in cTrader Tester against MT5 baseline
- [ ] Confirm broker `PipSize` for DAX (typically 1.0 or 0.1)

## Last Modified
- Date: 2026-05-10
- Change: Initial port from MT5 SwingTagEA v2.00.
