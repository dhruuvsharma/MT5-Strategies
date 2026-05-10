# Repo Map

## Last Updated
2026-05-10

## Layout
```
platforms/
├── MT5/        ← MQL5 EAs and indicators (canonical implementations)
└── cTrader/    ← cAlgo / C# ports of the MT5 strategies
```

## Strategies Index

| Strategy | Type | Instrument | MT5 | cTrader | Strategy Summary |
|----------|------|------------|:---:|:-------:|------------------|
| SwingTagEA | EA | DAX / GER40 | ✅ | ✅ | 3-bar swing pivot fade — SELL LIMIT at mid-bar high when both extremes peak above oldest bar; BUY LIMIT at mid-bar low when both extremes trough below. 13:00–16:00 session, fixed lots, symmetric SL/TP. |
| DeltaFadeEA | EA | DAX / GER40 | ✅ | ✅ | Contrarian scalper — fades cumulative tick/volume delta extremes using dynamic Median+MAD thresholds over rolling analysis windows, confirmed by volume-weighted price line slope. Day/hour time filter, trailing stop. |
| CumulativeDeltaScalper | EA | EURUSD M1/M3/M5 | ✅ | ✅ | **v2 Sniper-mode** — N-candle delta sliding window with crossover trigger + 5-confirmation gate (momentum, HTF EMA, EMA slope, ADX, dynamic spread). Session-aware (Asia/London/NY/Overlap, GMT minute-precision). Risk-based lot sizing. Fast exits: time-out, adverse-delta flip, optional breakeven. Tight TP (0.4×ATR) / SL (0.8×ATR). Per-session and daily trade caps. |
| FootprintChartPro | Indicator | Any | ✅ | ⚠️ WIP | Professional order flow visualization — canvas-based delta cells footprint with 11 analysis panels (DOM, Volume Profile, Time & Sales, Signal Meter, Chart Analyst, RSI, MACD, S&D Zones, Calendar, Mini Session Chart). 16 themes, volume inference engine, 3-tier imbalance detection. Visualization only, no trading. cTrader port is a scaffolded stub — full panel suite not yet implemented. |
| ApexScalper | EA | Liquid FX / index futures | ✅ | ⚠️ WIP | Microstructure scalper — weighted composite of 8 order flow signals (Cumulative Delta 20%, VPIN 20%, shallow OBI 15%, footprint stacked imbalance 15%, absorption 10%, deep OBI 10%, tape speed 5%, HVP slope 5%). Regime-adaptive weights via ADX+BB width+VPOC stability classifier. Conflict filter on top-weighted signals, SL/TP anchored to HVP nodes. cTrader port is a scaffolded stub — signal modules need individual ports. |
| CandleDataCollector | Utility | Any | ✅ | ✅ | Builds tick-aggregated candles (OHLC + TickDelta + VolumeDelta + VWAP + Range + CumDelta) and writes one CSV row per candle. For Python backtesting. No trade execution. |
| TickDataCollector | Utility | Any | ✅ | ✅ | Writes every tick as a CSV row with ms timestamp, spread, running candle-window OHLC/delta context, and cumulative delta. For tick-resolution Python backtesting. No trade execution. |

Legend: ✅ available · ⚠️ WIP / scaffolded stub · ❌ not ported

## File Inventory by Strategy (MT5)

| Folder | Files |
|--------|-------|
| `platforms/MT5/SwingTagEA/` | Config.mqh, Market.mqh, Signal.mqh, Risk.mqh, Trade.mqh, Utils.mqh, SwingTagEA.mq5 |
| `platforms/MT5/DeltaFadeEA/` | Config.mqh, Market.mqh, Signal.mqh, Risk.mqh, Trade.mqh, Utils.mqh, DeltaFadeEA.mq5 |
| `platforms/MT5/CumulativeDeltaScalper/` | Config.mqh, Market.mqh, Signal.mqh, Risk.mqh, Trade.mqh, Utils.mqh, CumulativeDeltaScalper.mq5, CumulativeDeltaScalperBT.mq5 |
| `platforms/MT5/FootprintChartPro/` | Config.mqh, Market.mqh, Signal.mqh, Render.mqh, Panels.mqh, FootprintChartPro.mq5 |
| `platforms/MT5/ApexScalper/` | ApexScalper.mq5 + ~40 .mqh modules across Core/, Utils/, Data/, Signals/, Engine/, Execution/, Risk/, UI/, Logging/ |
| `platforms/MT5/CandleDataCollector/` | src/Config.mqh, src/CandleDataCollector.mq5 |
| `platforms/MT5/TickDataCollector/` | src/Config.mqh, src/TickDataCollector.mq5 |

## File Inventory by Strategy (cTrader)

| Folder | Files |
|--------|-------|
| `platforms/cTrader/SwingTagEA/` | src/SwingTagEA.cs |
| `platforms/cTrader/DeltaFadeEA/` | src/DeltaFadeEA.cs |
| `platforms/cTrader/CumulativeDeltaScalper/` | src/CumulativeDeltaScalper.cs |
| `platforms/cTrader/FootprintChartPro/` | src/FootprintChartPro.cs (WIP — minimal viable footprint only) |
| `platforms/cTrader/ApexScalper/` | src/ApexScalper.cs + signal stubs (WIP) |
| `platforms/cTrader/CandleDataCollector/` | src/CandleDataCollector.cs |
| `platforms/cTrader/TickDataCollector/` | src/TickDataCollector.cs |

## Notes
- Each strategy folder has a `src/` and `.memory/` subfolder. ApexScalper-MT5 uses its own multi-folder layout (Core/Data/Signals/Engine/Execution/Risk/UI/Logging/Utils) — not src/.
- Every source file has a corresponding `.mem.md` in `.memory/` (pending for ApexScalper modules and cTrader WIP stubs).
- Original file: `DaxAlgo - StratTagger.mq5` → `platforms/MT5/SwingTagEA/src/SwingTagEA.mq5`
- Original file: `SlidingWindow.mq5` (UTF-16, 2160 lines) → decoupled into `platforms/MT5/DeltaFadeEA/`
- ApexScalper imported 2026-04-29 from external repo (`github.com/dhruuvsharma/mt5-microstructure-scalper`); folder renamed to `ApexScalper`.
- 2026-05-10 — Repository restructured under `platforms/MT5/` and `platforms/cTrader/`. cTrader ports added for the 5 small strategies; ApexScalper and FootprintChartPro scaffolded as WIP. Repo renamed to `Trading-Strategies`.
