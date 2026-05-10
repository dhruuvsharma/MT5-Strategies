# FootprintChartPro (cTrader) — Project State

## Current Status
- **Version:** 0.10 (WIP SCAFFOLD)
- **Type:** cAlgo Indicator (not Robot) — `IsOverlay = true`
- **Source of truth:** `platforms/MT5/FootprintChartPro/` for math/theming
- **Built/tested:** code review only

## What's Done (2026-05-10)
- Single-file Indicator class
- Per-tick bid bucketing into N-pip price levels per bar (`Calculate(index)` is the per-tick hook in cAlgo Indicators)
- Per-bar render: delta cells via `Chart.DrawRectangle` + `Chart.DrawText`
- POC highlighting (highest-volume bucket per bar)
- Cleanup of objects when bars age out beyond `MaxBarsBack`

## What's NOT Done
- All 11 MT5 panels (DOM, Volume Profile, Time & Sales, Signal Meter, Chart Analyst, RSI, MACD, S&D Zones, Calendar, Mini Session Chart, plus one)
- 16 theme presets
- 3-tier imbalance detection
- Volume inference engine
- DOM streaming via `Symbol.MarketDepth.Updated`

## Architecture
- Single Indicator class. No subclasses or partner files.
- State: `Dictionary<DateTime, Dictionary<int, BucketStats>>` keyed by bar open time, then by price-bucket index.
- `Calculate(index)` runs per tick on the live bar; we update the bucket for the current bid and re-render that bar's cells.

## TODOs
- [ ] First-run validation in cTrader
- [ ] Confirm `Chart.DrawRectangle` performance with many cells (consider throttling render to once per second)
- [ ] If panels are wanted: split into per-panel Indicators (cAlgo can only produce one panel per Indicator)
- [ ] Theme support: a base class with `ColorScheme` enum + per-color resolver
