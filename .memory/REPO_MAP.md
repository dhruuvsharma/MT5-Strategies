# Repo Map

## Last Updated
2026-05-15

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
- 2026-05-15 — Imported legacy EAs under `platforms/MT5/Drafts/`. Deduplicated 4 families into single main versions; broken WIP `FSX-Delta` discarded after grafting its working session-rectangle code into `FrameAlgo`. None of the drafts are decoupled yet — they are raw `.mq5` files awaiting evaluation before porting into the layered `platforms/MT5/<StrategyName>/` layout.

## Drafts Inventory (`platforms/MT5/Drafts/`)

Legacy EAs and indicators imported as-is. **Not** decoupled into Config/Market/Signal/Risk/Trade/Utils layers.

| Family | Main file | Description |
|--------|-----------|-------------|
| Ladder | `GoldenLadder EA.mq5` (v2.00) | Pending stop-order ladder around bar open in a time window. Absorbed: `GoldenLadderAdvanceEA` (TP-hit watchdog), `StatArbX` (UseServerTime + prev-candle ref), `StatArbX_Valid_March` (expiration time-bomb), `XAUUSD HFT`. Toggle features via inputs. |
| TV Bridge | `DaxAlgo - TradingViewBridge.mq5` (v2.00, UTF-16, 62KB) | Full-feature CSV-bridge with risk management, breakeven, daily P&L caps, news filter, dynamic lot. Absorbed: `bridge debug script`, `DaxAlgo - TradingViewMT5Bridge`, `SimpleTradingViewBridge`, `DaxAlgo - TradingViewToMT5Bridge`. |
| 3-bar pattern | `DaxAlgo - FrameAlgo.mq5` | 3-candle C1/C2/C3 pattern → SmartLimit / DirectExecute, RectHL or unit SL, fixed-step trailing, session rectangles (Asia/London/NY/Pacific), per-bar tick-delta in trade comments + chart label. Absorbed: `DaxAlgo-StratRec`. Discarded: broken `DaxAlgo - FSX-Delta` (after grafting its session-draw body in). |
| RSI Envelope | `Envelope Oscillator.mq5` (v2.00) | RSI crossover entry/exit with symbol-aware SL/TP validation (SYMBOL_TRADE_STOPS_LEVEL), retry-on-error, post-fill stop verification. Absorbed: `LSF-X-Engine`. |
| Triangle + SuperTrend | `TrianglePatternForceCloseNextSignal.mq5` | Parallel implementation: 3-bar triangle + SuperTrend + RSI confluence filter. Kept separate from FrameAlgo. |
| Renko | `DaxAlgo - RenkoPAT.mq5` | Consecutive-brick entry/exit, per-hour toggles, brick-trail SL. |
| Renko display | `DaxAlgo - RenkoDisplay.mq5`, `renko2.mq5` (Guilherme Santos, third-party) | Visualization only. |
| Adaptive RSI | `DaxAlgoRSI.mq5` | ARSI with manual SMA/EMA/SMMA calculation. |
| NW envelope EA | `DaxAlgoNDE_MFT.mq5`, `DaxAlgo.mq5` | Nadaraya-Watson envelope strategy + base chart-styling EA. |
| NW indicator | `Nadaraya Watson Envelope.mq5` | Gaussian kernel + MAE bands. |
| SuperTrend | `SuperTrendEA.mq5` | SuperTrend + EMA + ADX filters. |
| SpeedBased | `SpeedBasedEA.mq5` | Price-speed + LSF slope + Kalman + MTF confirmation dashboard. |
| Trend indicator | `TrendIndicator.mq5` | ATR breakout (buggy — calls iMA inside OnCalculate loop). |
| StratTagger src | `DaxAlgo - StratTagger.mq5` | Source of `platforms/MT5/SwingTagEA/`. |
| SlidingWindow src | `DaxAlgo - SlidingWindow.mq5` (UTF-16) | Source of `platforms/MT5/DeltaFadeEA/`. |

### Excluded from repo (kept locally only)
- `TrendEA(DeepSeek).mq5` — broken (unbalanced `)` on line 82, won't compile).
- `DaxAlgo - AdvanceRecStrat.mq5` — empty OnInit/OnTick scaffold.
- `MachineIDGenerator.mq5`, `LicenceGenerator.mq5`, `LicenceValidator.mq5` — license-flow utilities, intentionally not published.
- All `*.ex5` compiled binaries (gitignored repo-wide).
- Third-party paid binaries with no source (`LuxAlgo - *.ex5`, `Trend Catcher with Alert MT5.ex5`, `Range Breakout EA.ex5`, `DaxAlgoHFT/Prime/Wave.ex5`).

### Known issues in committed Drafts
- 3 files are UTF-16 with BOM (`DaxAlgo - SlidingWindow.mq5`, `DaxAlgo - TradingViewBridge.mq5`, `renko2.mq5`). Compile fine but awkward to diff.
