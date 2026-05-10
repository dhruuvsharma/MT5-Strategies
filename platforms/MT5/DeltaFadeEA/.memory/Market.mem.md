# Memory: Market.mqh

## Purpose
Price data collection, delta calculations, volume footprint, ticks-per-second, analysis windows, statistical functions (median, MAD), and EMA trend indicator.

## Exports (public functions / arrays)
- MarketInit() — allocate arrays + create EMA indicator handle
- MarketDeinit() — release EMA handle
- InitializeAnalysisWindows() — seed from historical bars
- CandleDelta(MqlRates&) → double — signed tick_volume
- CalculateDeltas() / UpdateCurrentCandleDelta()
- CalculateVolumeFootprint() / UpdateCurrentVolumeFootprint()
- CalculateTicksPerSecond() / UpdateCurrentTicksPerSecond()
- UpdateTickAnalysisWindow(double) / UpdateVolumeAnalysisWindow(double)
- GetVolumeLineSlope() → int (+1/-1/0)
- UpdateEMA() — read EMA buffer into emaValue
- GetTrendDirection() → int (+1 bullish, -1 bearish, 0 disabled/flat)
- CalculateMedian(double&[], int) → double
- CalculateMAD(double&[], double, int) → double
- GetCurrentSpread() → double
- Arrays: volumeDelta[], tickDelta[], ticksPerSecond[], volumeWeightedPrices[], typicalPrices[]
- Globals: cumulativeVolumeDelta, cumulativeTickDelta, averageTicksPerSecond, emaHandle, emaValue

## Dependencies
- Imports from: Config.mqh
- Imported by: Signal.mqh, Utils.mqh, DeltaFadeEA.mq5

## Key Decisions
- 2026-04-11 — v3.00: Added iMA handle for EMA trend filter, UpdateEMA(), GetTrendDirection(), MarketDeinit()

## Last Modified
- Date: 2026-04-11
- Change: v3.00 — EMA trend indicator integration
