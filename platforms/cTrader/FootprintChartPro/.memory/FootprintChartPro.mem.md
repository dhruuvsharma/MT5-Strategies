# Memory: FootprintChartPro.cs

## Purpose
cAlgo `[Indicator]` providing a minimal viable delta-cell footprint on the chart overlay. SCAFFOLD only — none of the 11 MT5 panels are ported.

## Public surface
- `class FootprintChartPro : Indicator`
- `[Parameter]` properties: `BlockPips`, `MaxBarsBack`, `CellWidthSeconds`, `ShowLiveBar`, colour hex strings
- `Initialize()` / `Calculate(int index)` overrides

## Internal layout
- `BucketStats` struct (BuyCount, SellCount)
- `_barBuckets` — Dictionary<DateTime, Dictionary<int, BucketStats>> keyed by bar open time + price-bucket index
- `_lastBid` for uptick/downtick classification
- `PriceToBucket`, `RenderBar`, `RemoveBarObjects` helpers

## Dependencies
- cAlgo.API, cAlgo.API.Internals
- System, System.Collections.Generic, System.Linq

## Key decisions
- 2026-05-10 — Visualization-only scaffold. No trades; classified `[Indicator]`, not `[Robot]`.
- 2026-05-10 — `Calculate(int)` used as the per-tick hook (cAlgo Indicators get called on every tick when `IsOverlay = true`).
- 2026-05-10 — Volume classification is uptick/downtick — count-only (no real volume in cAlgo per tick).
- 2026-05-10 — POC = bucket with highest (Buy+Sell) total per bar.

## Known issues / TODOs
- [ ] Performance untested with many cells × many bars
- [ ] No 11-panel suite
- [ ] No themes
- [ ] No imbalance detection logic

## Last Modified
- Date: 2026-05-10
- Change: Initial WIP scaffold — minimal viable footprint
