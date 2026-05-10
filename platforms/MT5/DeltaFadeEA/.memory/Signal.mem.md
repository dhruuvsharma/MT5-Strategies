# Memory: Signal.mqh

## Purpose
Dynamic threshold calculation, trade management limits, and dual-mode signal generation (trend-following pullback OR contrarian fade).

## Exports
- dynamicTickBuyThreshold, dynamicTickSellThreshold
- dynamicVolumeBuyThreshold, dynamicVolumeSellThreshold
- signalLong, signalShort — current signal state
- tradesToday, barsSinceLastTrade — trade management state
- UpdateDailyTradeCount() — reset counter on day change
- OnTradeExecuted() — increment daily count, reset bar cooldown
- OnNewBarSignal() — increment bar cooldown counter
- IsTradeAllowedByLimits() → bool — checks MaxTradesPerDay + MinBarsBetweenTrades
- ApplyThresholdBounds(raw, base, isBuy) → double
- CalculateThresholdsFromData(...) — median+MAD threshold calc
- CalculateDynamicTickThresholds() / CalculateDynamicVolumeThresholds()
- CheckTradingSignals() — dual-mode: trend pullback (EMA+delta+slope) or contrarian fade

## Dependencies
- Imports from: Config.mqh, Market.mqh
- Imported by: Trade.mqh, Utils.mqh, DeltaFadeEA.mq5

## Key Decisions
- 2026-04-06 — Signal display moved to DeltaFadeEA.mq5 (EvaluateAndExecute)
- 2026-04-11 — v3.00: Added trade limits (MaxTradesPerDay, MinBarsBetweenTrades). Dual-mode signal: TrendFollowing uses EMA direction + delta pullback; contrarian mode preserved as fallback. Removed prevLong/prevShort statics.

## Last Modified
- Date: 2026-04-11
- Change: v3.00 — trend-following pullback mode, trade management limits
