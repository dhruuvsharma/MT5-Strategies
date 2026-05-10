# Memory: Config.mqh

## Purpose
All input parameters, constants, and #defines for DeltaFadeEA.

## Exports (public inputs / defines)
- EA_NAME ("DeltaFadeEA"), EA_VERSION ("3.00")
- MagicNumber (input, default 12345), EnableTrading
- WindowSize (20), AnalysisWindowSize (50)
- TrendEMAPeriod (50, 0=disabled), TrendFollowing (true=pullback, false=contrarian)
- ThresholdMultiplier (2.0), RequireBothDeltas (true), RequireSlopeConfirmation (true)
- MaxTradesPerDay (5, 0=unlimited), MinBarsBetweenTrades (10)
- LotSize (0.01), RiskPercent (2.0), StopLossPoints (500), TakeProfitPoints (0), RiskRewardRatio (0.6)
- MaxSpread (30), Slippage (10), TrailingStart (200)
- EnableTimeFilter (true), StartHour (8), EndHour (17)
- Visual #defines: TEXT_SIZE, colors, FOOTPRINT_LINE_WIDTH
- VWP weights: 0.4/0.4/0.2
- Threshold bounds: MIN/MAX_MULT, MIN_ABSOLUTE_THRESHOLD
- Statistical: MIN_MAD_VALUE, MAD_SCALE_FACTOR

## Dependencies
- Imports from: (none)
- Imported by: Market.mqh, Signal.mqh, Risk.mqh, Trade.mqh, Utils.mqh, DeltaFadeEA.mq5

## Key Decisions
- 2026-04-06 — v2.10: Reduced 60+ inputs to 16 for XAUUSD focus
- 2026-04-11 — v3.00: Added TrendEMAPeriod, TrendFollowing, MaxTradesPerDay, MinBarsBetweenTrades. Removed MIN_TRADE_DELAY. Tuned defaults for XAUUSD (SL 500, RR 0.6, ThresholdMultiplier 2.0, RequireBothDeltas=true, SlopeConfirm=true)

## Last Modified
- Date: 2026-04-11
- Change: v3.00 — added trend filter + trade management inputs, tuned XAUUSD defaults
