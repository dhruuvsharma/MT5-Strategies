# Repo Map

## Last Updated
2026-05-08

## EAs Index
| Folder | Strategy Summary | Status | Files |
|--------|-----------------|--------|-------|
| SwingTagEA | 3-bar swing pivot fade — SELL LIMIT at mid-bar high when both extremes peak above oldest bar; BUY LIMIT at mid-bar low when both extremes trough below. DAX-focused, 13:00–16:00 session, fixed lots, symmetric SL/TP. | Active | Config.mqh, Market.mqh, Signal.mqh, Risk.mqh, Trade.mqh, Utils.mqh, SwingTagEA.mq5 |
| DeltaFadeEA | Contrarian scalper — fades cumulative tick/volume delta extremes using dynamic Median+MAD thresholds over rolling analysis windows, confirmed by volume-weighted price line slope. Day/hour time filter, trailing stop. | Active | Config.mqh, Market.mqh, Signal.mqh, Risk.mqh, Trade.mqh, Utils.mqh, DeltaFadeEA.mq5 |
| CumulativeDeltaScalper | **v2 Sniper-mode** — N-candle delta sliding window with crossover trigger + 5-confirmation gate (momentum, HTF EMA, EMA slope, ADX, dynamic spread). Session-aware (Asia/London/NY/Overlap toggles, GMT minute-precision). Risk-based lot sizing. Fast exits: time-out, adverse-delta flip, optional breakeven. Tight TP (0.4×ATR) / SL (0.8×ATR) for high-win-rate scalping. Per-session and daily trade caps. Has a BT-mode entry point (BACKTEST_MODE define) that strips UI + per-tick Prints for faster optimization sweeps. EURUSD M1/M3/M5. | Active | Config.mqh, Market.mqh, Signal.mqh, Risk.mqh, Trade.mqh, Utils.mqh, CumulativeDeltaScalper.mq5, CumulativeDeltaScalperBT.mq5 |
| FootprintChartPro | Professional order flow visualization — canvas-based delta cells footprint with 11 analysis panels (DOM, Volume Profile, Time & Sales, Signal Meter, Chart Analyst, RSI, MACD, S&D Zones, Calendar, Mini Session Chart). 16 themes, volume inference engine, 3-tier imbalance detection. Visualization only, no trading. | Active | Config.mqh, Market.mqh, Signal.mqh, Render.mqh, Panels.mqh, FootprintChartPro.mq5 |
| ApexScalper | Microstructure scalper — weighted composite of 8 order flow signals (Cumulative Delta 20%, VPIN 20%, shallow OBI 15%, footprint stacked imbalance 15%, absorption 10%, deep OBI 10%, tape speed 5%, HVP slope 5%). Regime-adaptive weights via ADX+BB width+VPOC stability classifier (Trending Bull/Bear, Ranging, High Vol). Conflict filter on top-weighted signals, SL/TP anchored to HVP nodes. Liquid FX/futures, intraday. | Active | ApexScalper.mq5 + ~40 .mqh modules across Core/, Utils/, Data/, Signals/, Engine/, Execution/, Risk/, UI/, Logging/ |

| CandleDataCollector | Data collection utility — builds tick-aggregated candles (OHLC + TickDelta + VolumeDelta + VWAP + Range + CumDelta) and writes one CSV row per candle. For Python backtesting. No trade execution. | Active | src/Config.mqh, src/CandleDataCollector.mq5 |
| TickDataCollector | Data collection utility — writes every tick as a CSV row with ms timestamp, spread, running candle-window OHLC/delta context, and cumulative delta. For tick-resolution Python backtesting. No trade execution. | Active | src/Config.mqh, src/TickDataCollector.mq5 |

## Notes
- Each EA lives in its own folder with a src/ and .memory/ subfolder (ApexScalper uses its own multi-folder layout — Core/Data/Signals/Engine/Execution/Risk/UI/Logging/Utils — not src/)
- Every source file has a corresponding .mem.md in .memory/ (pending for ApexScalper modules)
- Original file: "DaxAlgo - StratTagger.mq5" → renamed and moved to SwingTagEA/src/SwingTagEA.mq5
- Original file: "SlidingWindow.mq5" (UTF-16, 2160 lines) → decoupled and renamed to DeltaFadeEA/src/DeltaFadeEA.mq5
- ApexScalper imported 2026-04-29 from external repo (github.com/dhruuvsharma/mt5-microstructure-scalper); folder renamed from `mt5-microstructure-scalper` to match EA name
