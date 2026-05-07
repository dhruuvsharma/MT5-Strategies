# Memory: Market.mqh

## Purpose
Indicator handles (ATR/EMA/ADX), tick-level delta processing, candle detection, rolling spread sampling, and broker-aware pip size.

## Exports (public functions)
- CalcPipSize() → double — 10×Point on 3/5-digit, else 1×Point
- MarketInit() → bool — creates ATR/EMA/ADX handles, inits delta + spread ring buffers, sets g_pipSize
- MarketDeinit() → void — releases all 3 handles
- IsNewCandle() → bool
- ProcessTick() → void — increments uptick/downtick on bid flip
- FinalizeCandle() → void — pushes delta to circular buffer + samples spread
- GetATR() → double
- GetHTFEma() → double — EMA(50) on M15
- GetEMASlopeDir() → int — +1 rising / -1 falling / 0 flat over EMASlopeBars
- GetADX() → double — ADX(14) main line on M15
- GetSpreadPoints() → int
- GetAvgSpread() → double — rolling avg from g_spreadHistory (0 until bootstrap)
- GetOrderedDeltas(int &deltas[]) → int — oldest→newest

## Dependencies
- Imports from: Config.mqh
- Imported by: Signal.mqh

## Key Decisions
- 2026-05-08 — v2.0: added ADX handle + GetADX, GetEMASlopeDir, spread ring buffer + GetAvgSpread, broker-aware CalcPipSize. Spread sampled once per bar (in FinalizeCandle).

## Last Modified
- Date: 2026-05-08
- Change: v2 — ADX/EMA-slope/rolling-spread infrastructure for the sniper confirmation stack.
