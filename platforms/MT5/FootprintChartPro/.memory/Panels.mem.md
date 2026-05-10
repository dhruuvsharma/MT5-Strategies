# Memory: Panels.mqh

## Purpose
All 11 panel rendering functions plus helper renderers for the FootprintChartPro canvas.

## Exports (public functions)
- RenderDeltaCellsFootprint() — main footprint panel with delta cells, POC/VAH/VAL lines, cumDelta line
- RenderSingleBar(barX, chartY, chartH, highPrice, lowPrice, priceRange, &bar) — single bar with cells
- DrawPriceAxis(x, chartY, chartH, highPrice, lowPrice) — left price axis
- RenderCumulativeDeltaLine(x, y, w, h, startIdx, count) — cumDelta line below footprint
- RenderSummaryTable() — vol/buy/sell/delta/POC/cumDelta for current bar
- RenderDOMPanel() — depth of market with bid/ask bars
- RenderVolumeProfilePanel() — horizontal histogram with POC/VAH/VAL
- RenderTimeAndSalesPanel() — streaming tape with bar totals
- RenderSignalMeterGauge() — analog dial from signal meter value
- RenderChartAnalystPanel() — 9-section analyst report
- RenderRSIPanel() — RSI(14) line chart
- RenderMACDPanel() — MACD histogram
- RenderSupplyDemandZones() — overlay on main footprint
- RenderEconomicCalendarPanel() — upcoming events table
- RenderMiniSessionChart() — M1 session candles

## Dependencies
- Imports from: Config.mqh, Market.mqh, Signal.mqh, Render.mqh
- Imported by: FootprintChartPro.mq5

## Last Modified
- Date: 2026-04-14
- Change: Initial creation with all 11 panels plus summary table.
