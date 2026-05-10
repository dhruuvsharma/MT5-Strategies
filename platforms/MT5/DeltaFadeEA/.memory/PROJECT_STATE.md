# Project State — DeltaFadeEA

## Status: Active

## Last Updated: 2026-04-11

## Recent Changes
- 2026-04-11 — v3.00: Trend-following pullback mode for XAUUSD
  - Added EMA trend filter (TrendEMAPeriod=50) in Market.mqh with iMA handle
  - Dual-mode signal: TrendFollowing=true buys pullbacks in uptrend / sells bounces in downtrend; false = original contrarian fade
  - Trade management: MaxTradesPerDay (5), MinBarsBetweenTrades (10) bar-based cooldown replaces old MIN_TRADE_DELAY seconds throttle
  - Trading restricted to new bars only (ProcessSameBar no longer executes trades)
  - Tuned defaults for XAUUSD: SL 500pts ($5), RR 0.6 (TP 300pts/$3), ThresholdMultiplier 2.0, RequireBothDeltas=true, RequireSlopeConfirmation=true
  - Trade.mqh now imports Signal.mqh, calls OnTradeExecuted() for cooldown tracking
  - MarketDeinit() added for proper EMA handle cleanup

- 2026-04-06 — v2.10: Input cleanup for XAUUSD 1M/3M/5M
  - Removed 50+ useless inputs: 24 hour bools, 7 day bools, all visual colour/size inputs
  - Merged window sizes and multipliers into single inputs
  - Config now has ~20 inputs (was 60+)

## Known Issues / TODOs
- [ ] Analysis window O(n*m) lookup in DrawThresholdWindows could be optimised with index mapping
- [ ] Consider adding max-positions-per-symbol limit
- [ ] Backtest v3.00 on XAUUSD M1/M5 to validate trend-following vs contrarian performance
