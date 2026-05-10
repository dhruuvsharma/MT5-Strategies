# Memory: Utils.mqh

## Purpose
Time filter, all chart drawing/display functions, chart helpers, and object cleanup.

## Exports
- ChartPriceMin/ChartPriceMax(subWin) → double
- IsTradingAllowed() → bool — day + hour filter
- GetTicksPerSecColor(tps) → color
- GetRectangleColor() → color
- CalculateLineColor() → color
- GetPointColor(idx) → color
- DrawRectangle() — sliding window rectangle
- DrawVolumeFootprintLine() / DrawVolumeFootprintPoints()
- DisplayDeltas() — per-candle labels
- DisplayCumulativeValues(rates) / DisplayAverageTicksPerSecond(rates)
- DisplaySignal(signal, clr) — signal arrow on chart
- DisplayTimeFilterStatus() — trading status labels
- DisplayDynamicThresholds() — HUD in top-right
- DrawThresholdWindows() / UpdateThresholdWindows() — analysis window rectangles
- DisplayWindowStatistics() — median/MAD stats
- CleanupObjects() — remove all chart objects on deinit

## Dependencies
- Imports from: Config.mqh, Market.mqh, Signal.mqh
- Imported by: DeltaFadeEA.mq5

## Last Modified
- Date: 2026-04-06
- Change: Initial creation from SlidingWindow.mq5 decoupling
