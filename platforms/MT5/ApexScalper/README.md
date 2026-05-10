# APEX — Microstructure Scalping EA for MT5

> A fully automated Expert Advisor for MetaTrader 5 that combines 8 order flow and microstructure signals into a weighted composite scoring engine. Designed for intraday scalping on liquid FX and futures instruments during high-volume sessions.

---

## Overview

APEX does not use conventional lagging indicators. Every signal is derived from live order flow, tick-level volume analysis, footprint data, and order book microstructure. The scoring engine requires a minimum number of independent signals to agree before any position is opened — reducing false positives and avoiding single-signal traps common in retail EAs.

The EA was designed from the ground up with production constraints in mind: no magic numbers, no unbounded memory, symbol/timeframe agnostic, live dashboard on chart, full CSV logging, and a regime-adaptive weight system that adjusts signal importance based on the current market environment.

---

## Signal Architecture

All signals score on a continuous scale from **-3.0 (maximum bearish conviction)** to **+3.0 (maximum bullish conviction)**. A weighted composite score is computed on every tick. A trade is only triggered when:

- The absolute composite score exceeds the configured threshold
- A minimum number of signals agree in direction (default: 4 of 8)
- The two highest-weight signals (Delta and VPIN) do not conflict
- All risk, session, spread, and regime filters pass

| Signal | Weight | Method |
|--------|--------|--------|
| Cumulative Tick Delta | 20% | Z-scored delta with acceleration and divergence detection |
| VPIN (Flow Toxicity) | 20% | Volume-bucketed directional imbalance across rolling buckets |
| Order Book Imbalance (Shallow) | 15% | Weighted OBI across top 3 levels with spoof detection |
| Footprint Stacked Imbalance | 15% | Consecutive zero-bid / zero-ask rows in footprint candles |
| Absorption Score | 10% | Volume per unit price range at key levels |
| Order Book Imbalance (Deep) | 10% | Exponentially weighted OBI across top 10 levels |
| Tape Speed | 5% | Trade arrival rate Z-score with directional fraction filter |
| HVP Regression Slope | 5% | Weighted linear regression through high-volume pocket nodes |

---

## Key Features

**Signal Engine**
- VPIN computed via volume-bucketed flow classification (not time-based)
- OBI computed at two depths with exponential level weighting and spoofing detection
- Footprint stacked imbalance detection with configurable minimum consecutive rows
- Delta divergence detection: price high/low vs cumulative delta disagreement
- Delta efficiency filtering: ignores high delta on balanced two-sided flow
- VPOC migration tracking across window for trend confirmation
- Tape speed directional fraction: distinguishes institutional algo activity from retail flow

**Composite Engine**
- Per-signal TTL decay: stale signals are excluded from composite, not zeroed
- Conflict filter: blocks trades when top-weighted signals disagree near the threshold
- Confirmation gate: final multi-condition check before any execution call
- Regime-adaptive weights: multipliers applied dynamically without changing stored inputs

**Regime Classifier**
- Higher-timeframe ADX + Bollinger Band width + VPOC stability
- Four states: Trending Bull, Trending Bear, Ranging, High Volatility
- Trending regime: boosts delta and HVP slope weights
- Ranging regime: boosts OBI and absorption weights
- High volatility regime: halves all weights (natural threshold gate)

**Execution**
- Stop loss placed behind nearest HVP or stacked imbalance level with configurable buffer
- Take profit at opposing HVP level with optional trailing activation after first TP hit
- Dynamic lot sizing: `(balance × risk%) / (SL_points × tick_value)`
- Single retry on requote with refreshed price

**Risk**
- Daily loss circuit breaker (% of balance)
- Peak equity drawdown circuit breaker
- Max open positions cap
- Minimum bars cooldown between trades
- Session filter: independently toggle Asian, London, New York, Overlap
- Spread filter: hard max spread gate before any entry

**UI**
- Full chart dashboard: signal matrix with score bars, composite block, regime, risk status
- Optional footprint overlay on current candle
- Optional HVP horizontal lines with regression line
- Optional order book depth visualization
- Panel minimize/maximize on header click
- Zero flickering: all chart objects reused and updated in-place

**Logging**
- Per-trade CSV with full signal context at entry
- Optional per-tick signal log
- Per-session summary statistics

---

## File Structure

```
Experts/ApexScalper/
├── ApexScalper.mq5
├── MEMORY.md
├── INSTRUCTIONS.md
│
├── Core/
│   ├── Defines.mqh          Enums, structs, constants
│   ├── Inputs.mqh           All input parameters
│   ├── State.mqh            Global state variables
│   └── EventBus.mqh         Inter-module pub/sub
│
├── Utils/
│   ├── RingBuffer.mqh       Generic fixed-size ring buffer
│   ├── MathUtils.mqh        Z-score, regression, normalization
│   ├── TimeUtils.mqh        Session time helpers
│   └── StringUtils.mqh      Panel/log formatting
│
├── Data/
│   ├── TickCollector.mqh    Tick classification and aggregation
│   ├── CandleBuilder.mqh    Enriched candle construction from ticks
│   ├── FootprintBuilder.mqh Per-candle bid/ask volume at price
│   ├── OrderBookSnapshot.mqh OB depth capture and OBI calculation
│   ├── VolumeProfile.mqh    Rolling window volume-at-price profile
│   └── WindowManager.mqh   Sliding window coordinator
│
├── Signals/
│   ├── SignalBase.mqh
│   ├── DeltaSignal.mqh
│   ├── VPINSignal.mqh
│   ├── OBISignal.mqh
│   ├── FootprintSignal.mqh
│   ├── AbsorptionSignal.mqh
│   ├── HVPSignal.mqh
│   ├── TapeSpeedSignal.mqh
│   ├── VPOCSignal.mqh
│   └── SpreadSignal.mqh
│
├── Engine/
│   ├── ScoringEngine.mqh
│   ├── ConflictFilter.mqh
│   ├── SignalDecayManager.mqh
│   ├── RegimeClassifier.mqh
│   └── ConfirmationGate.mqh
│
├── Execution/
│   ├── TradeManager.mqh
│   ├── StopLossEngine.mqh
│   ├── TakeProfitEngine.mqh
│   └── PositionTracker.mqh
│
├── Risk/
│   ├── RiskManager.mqh
│   ├── SessionFilter.mqh
│   ├── SpreadFilter.mqh
│   └── NewsFilter.mqh
│
├── UI/
│   ├── DashboardPanel.mqh
│   ├── FootprintRenderer.mqh
│   ├── HVPRenderer.mqh
│   ├── OBRenderer.mqh
│   ├── SignalLEDs.mqh
│   └── PanelTheme.mqh
│
└── Logging/
    ├── TradeLogger.mqh
    ├── SignalLogger.mqh
    └── SessionLogger.mqh
```

---

## Core Math

**Order Book Imbalance**
```
OBI(n) = [Σ bid_vol(i) − Σ ask_vol(i)] / [Σ bid_vol(i) + Σ ask_vol(i)]   for i = 1..n
```

**Weighted OBI**
```
w(i) = decay^(i−1)
Weighted_OBI = [Σ w(i)·bid_vol(i) − Σ w(i)·ask_vol(i)] / Σ w(i)·(bid_vol(i) + ask_vol(i))
```

**VPIN**
```
buy_fraction(b) = buy_vol(b) / total_vol(b)
VPIN = (1/L) · Σ |buy_fraction(b) − 0.5| · 2   for last L buckets
```

**Delta Efficiency**
```
ΔE = |tick_delta| / volume     [0, 1]
High ΔE (>0.3) = aggressive directional flow
Low ΔE (<0.1) = balanced two-sided flow
```

**Absorption Score**
```
A = volume / max(high − low, min_range)
High A at a key level = absorption (price rejection likely)
```

**Weighted HVP Regression Slope**
```
weight(i) = hvp_volume(i) / (bars_since_peak(i) + 1)
slope = (S_w·S_wxy − S_wx·S_wy) / (S_w·S_wxx − S_wx²)
```

**Dynamic Lot Sizing**
```
lot = (balance · risk%) / (SL_points · tick_value_per_lot)
```

---

## Requirements

- MetaTrader 5 (build 3000+)
- MQL5 compiler (included with MT5)
- Broker with full depth of market (DOM) / Level 2 access for order book signals
- Tick data (not modeled) for backtesting — use `Every tick based on real ticks` in Strategy Tester
- Recommended instruments: EURUSD, GBPUSD, NQ1!, ES1!, or any highly liquid market
- Recommended sessions: London, New York, or London/NY overlap

---

## Installation

1. Clone or download the repository
2. Copy the `ApexScalper/` folder to `[MT5 Data Folder]/MQL5/Experts/`
3. Open MetaEditor and compile `ApexScalper.mq5`
4. Attach the EA to a chart with the target symbol and timeframe (M1 recommended)
5. Enable **Algo Trading** and **Allow DLL imports** in MT5 settings
6. Ensure **Market Depth** (DOM) is subscribed for the symbol

---

## Configuration

All parameters are exposed as MT5 inputs. Key parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpWindowSize` | 20 | Sliding window size in candles |
| `InpCompositeThreshold` | 1.80 | Minimum composite score to trigger a trade |
| `InpMinSignalsAgree` | 4 | Minimum signals that must align |
| `InpRiskPercent` | 0.5 | Risk per trade as % of account balance |
| `InpMaxDailyLossPercent` | 2.0 | Daily loss circuit breaker |
| `InpMaxSpreadPoints` | 8.0 | Maximum spread in points to allow entry |
| `InpSLBehindHVP` | true | Place SL behind nearest high-volume pocket |
| `InpTPAtOppositeHVP` | true | Target opposing HVP for take profit |
| `InpVPINBucketVolume` | 5000 | Volume per VPIN classification bucket |

Signal weights must sum to 1.0. If they do not, the EA normalizes them automatically at startup and logs a warning.

---

## Backtesting

1. Open Strategy Tester in MT5
2. Select `ApexScalper` as the Expert
3. Set **Modelling** to `Every tick based on real ticks`
4. Load at least 3 months of tick history for the target symbol
5. Run on M1 timeframe
6. Review `[MT5 Data Folder]/MQL5/Files/ApexScalper/Logs/` for trade and signal CSV output

> **Note:** Order book signals (`OBISignal`) cannot be replayed from historical tick data and will return neutral scores (0.0) in backtesting. This means live performance of OBI-driven signals cannot be verified from backtest alone.

---

## Limitations

- **Order book data is not available in MT5 backtesting.** OBI signals are live-only. Backtest results understate the full signal engine.
- **Broker dependency.** Tick delta accuracy depends on the broker's tick feed granularity. ECN/STP brokers with aggregated liquidity provide higher-quality tick classification than dealing desk brokers.
- **Not a black box.** The EA requires active monitoring. Threshold tuning per instrument and session is expected and recommended.
- **Not financial advice.** This is an open-source research project for educational and portfolio purposes.

---

## Project Structure Principles

- No file exceeds 600 lines — logic is split into focused modules
- No magic numbers — all numeric literals are named constants or input parameters
- No dynamic array growth — all data stores use fixed-capacity ring buffers
- No chart object recreation inside `OnTick` — all objects created once, updated in-place
- Modules communicate through `State.mqh` and `EventBus.mqh` only — no direct cross-module includes outside of owned dependencies

---

## Roadmap

- [ ] Machine learning layer: train a lightweight classifier on the 8 signal scores using logged trade outcomes to auto-tune weights per instrument
- [ ] Multi-symbol runner: scan multiple instruments and route to highest-scoring setup
- [ ] Greeks-aware mode for options market making context (NQ/ES)
- [ ] Web dashboard: stream signal state and trade log to a local browser via WebSocket
- [ ] Backtest OBI simulation using synthetic order book reconstruction from tick data

---

## License

MIT License. See `LICENSE` for details.

---

## Author

Built as part of a quantitative trading research portfolio. Signal design and architecture are original. VPIN methodology is inspired by Easley, López de Prado, and O'Hara (2012).

> *Easley, D., López de Prado, M. M., & O'Hara, M. (2012). Flow Toxicity and Liquidity in a High-Frequency World. The Review of Financial Studies, 25(5), 1457–1493.*
