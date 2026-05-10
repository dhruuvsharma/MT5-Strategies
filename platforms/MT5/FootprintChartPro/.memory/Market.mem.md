# Memory: Market.mqh

## Purpose
Tick processing engine, DOM data management, historical footprint bar loading, volume inference, S&D zone detection, volume profile calculation, economic calendar, mini session chart.

## Exports (public functions)
- InitIndicators() → bool — creates all indicator handles
- ReleaseIndicators() — releases all indicator handles
- GetIndicatorValue(handle, buffer, shift) → double
- GetIndicatorValues(handle, buffer, shift, count, &vals[]) → int
- InferVolume(tick, prevBid) → long — volume inference engine
- ClassifyTick(tick, prevBid) → int — 1=buy, -1=sell, 0=neutral
- GetPriceBucket(price) → double — floor to bucket
- ProcessTickIntoBar(&bar, tick, direction, volume) — adds tick to bar levels
- AddTickToTimeAndSales(tick, direction, volume)
- CalculateTSBarTotals() — sums buy/sell for current bar
- CalculateBarPOC(&bar) — finds POC level
- DetectImbalances(&bar) — 3-tier diagonal imbalance detection
- LoadHistoricalFootprintData() — CopyTicksRange for all visible bars
- ProcessTick() — main tick handler (called from OnTick)
- OnNewBar() — locks prev bar, creates new bar
- UpdateDOMData(&book[]) — processes MarketBook data
- InitializeDOMPanel() → bool — MarketBookAdd
- CleanupDOMPanel() — MarketBookRelease
- CalculateVolumeProfile() — aggregates levels, calls CalculateProfilePOCVA
- DetectSupplyDemandZones() — swing detection with volume filter
- FetchEconomicCalendar() — MQL5 Calendar API
- UpdateMiniSessionChart() — M1 candles for session window

## Dependencies
- Imports from: Config.mqh
- Imported by: Signal.mqh, Panels.mqh, FootprintChartPro.mq5

## Last Modified
- Date: 2026-04-14
- Change: Initial creation with full tick processing, volume inference, DOM, VP, S&D, calendar, session chart.
