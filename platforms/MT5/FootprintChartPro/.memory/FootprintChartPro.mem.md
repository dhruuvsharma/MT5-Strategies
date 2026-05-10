# Memory: FootprintChartPro.mq5

## Purpose
Main EA entry point. Orchestrates initialization, tick processing, timer-based canvas refresh, DOM event handling, and clean shutdown.

## Exports (public functions — MQL5 event handlers)
- OnInit() → int — theme, canvas, indicators, DOM, arrays, historical data, VP, S&D, calendar, session chart, analyst report, timer
- OnDeinit(reason) — timer kill, DOM cleanup, indicator release, canvas destroy
- OnTick() — delegates to ProcessTick()
- OnTimer() — periodic analyst/calendar refresh, VP recalc, session chart update, RefreshAllPanels()
- OnBookEvent(symbol) — MarketBookGet → UpdateDOMData
- RefreshAllPanels() — clears canvas, renders all 12 panels (incl. S&D overlay), flushes

## Dependencies
- Imports from: Config.mqh, Market.mqh, Signal.mqh, Render.mqh, Panels.mqh
- Imported by: none (top-level EA file)

## Last Modified
- Date: 2026-04-14
- Change: Initial creation with full orchestration.
