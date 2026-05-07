# CumulativeDeltaScalper — Settings Reference & XAUUSD Presets

> v2.0 sniper mode. All inputs live in `src/Config.mqh`. Tables below assume the live EA (`CumulativeDeltaScalper.mq5`) — the BT EA (`CumulativeDeltaScalperBT.mq5`) reads the same inputs.

---

## 1. Strategy in one paragraph

Every tick: increment uptick/downtick counters from bid flips. On each new candle, push the candle's net delta (uptick − downtick) into a sliding window of `WindowSize` candles. The **trigger** is `cumulative_window_delta` crossing ±`DeltaThreshold`. The trigger fires only if the **5-confirmation gate** passes (momentum continuity, HTF EMA position, EMA slope, ADX trending, dynamic spread). Position is sized by `RiskPercentPerTrade` of balance, SL/TP by ATR multipliers. Position closes on TP, SL, time-out, adverse-delta flip, or breakeven. Hard caps on per-session and per-day trades, plus inter-trade cooldown.

---

## 2. Input reference (every input)

### 2.1 Delta Settings

| Input | Type | Default | What it does |
|---|---|---|---|
| `WindowSize` | int | 10 | Number of completed candles whose deltas are summed into `cumDelta`. Larger → smoother, slower signals. Smaller → twitchier, more frequent triggers. |
| `DeltaThreshold` | int | 300 | Crossover trigger level. Trigger fires when `cumDelta` crosses ±this. Must scale with broker tick rate and timeframe. |

### 2.2 Sessions (GMT)

| Input | Type | Default | What it does |
|---|---|---|---|
| `UseSessionFilter` | bool | true | Master switch. If false, all session checks bypassed. |
| `OverlapOnly` | bool | true | If true, only the London/NY overlap window is active (highest liquidity). The 3 individual session toggles are ignored. |
| `OverlapStart/EndHour/Min` | int | 12:30–16:00 | Defines the overlap window. |
| `UseAsiaSession` + hours/mins | bool/int | false, 00:00–07:00 | Tokyo/Sydney session. Quietest for most pairs. |
| `UseLondonSession` + hours/mins | bool/int | true, 07:00–12:00 | London session. |
| `UseNewYorkSession` + hours/mins | bool/int | true, 12:30–17:00 | NY session. |

### 2.3 Sniper Filters (the confirmation stack)

| Input | Type | Default | What it does |
|---|---|---|---|
| `MinConfirmations` | int 0–5 | 5 | Number of supporting confirmations required (out of 5). Crossover trigger is always required and not counted here. 5 = strict (all must pass). 0 = fire on crossover alone. |
| `EMASlopeBars` | int | 3 | Number of M15 bars over which EMA slope is measured. Higher = smoother slope, less noise. |
| `ADXThreshold` | double | 18.0 | Minimum M15 ADX(14) for "trending" regime. Below this, signal is rejected. |
| `SpreadAvgMultiplier` | double | 1.5 | Reject if current spread > rolling-avg × this. Filters news widening. |
| `SpreadHistorySize` | int | 30 | Number of bars sampled into the rolling spread average. |

### 2.4 Trade Settings

| Input | Type | Default | What it does |
|---|---|---|---|
| `UseRiskBasedSizing` | bool | true | If true, lots = (balance × RiskPercent / 100) / SL$loss. If false, `FixedLotSize` is used. |
| `RiskPercentPerTrade` | double | 1.0 | % of account balance lost if SL hits. **The lever to "size up".** |
| `FixedLotSize` | double | 0.01 | Fallback lot size when risk-based sizing is off. |
| `MaxLotSize` | double | 5.0 | Hard cap on calculated lots — fat-finger / runaway-balance protection. |
| `TP_Multiplier` | double | 0.4 | TP distance = ATR × this. Sniper default = tight, easy to hit. |
| `SL_Multiplier` | double | 0.8 | SL distance = ATR × this. |
| `UseBreakeven` | bool | false | If true, moves SL to entry+buffer once `BreakevenPips` profit reached. |
| `BreakevenPips` | double | 1.5 | Profit threshold (in pips) for breakeven. Pip is auto-derived from broker digits. |
| `MaxSpreadPoints` | int | 15 | Hard cap on spread (points). Always blocks regardless of dynamic check. |
| `Slippage` | int | 3 | CTrade deviation in points. Raise on volatile instruments. |

### 2.5 Fast Exit

| Input | Type | Default | What it does |
|---|---|---|---|
| `MaxTradeSeconds` | int | 90 | Close at market if neither TP/SL hits within this many seconds. 0 = disabled. |
| `AdverseDeltaExit` | bool | true | Close immediately if cumDelta crosses against the position. |
| `AdverseDeltaCooldown` | int | 5 | Seconds after entry before adverse-delta exit can fire. Prevents premature close on entry-tick noise. |

### 2.6 Filters

| Input | Type | Default | What it does |
|---|---|---|---|
| `UseHTFFilter` | bool | true | M15 EMA(50) bid-side check. Confirmation 2 of the stack. |
| `MinATR` | double | 0.00030 | Reject signal if ATR is below this (market too flat). **EURUSD-scaled — must be retuned for gold/indices.** |
| `MaxATR` | double | 0.00200 | Reject signal if ATR is above this (market too wild). Same caveat. |

### 2.7 Risk Management

| Input | Type | Default | What it does |
|---|---|---|---|
| `MaxTradesPerSession` | int | 2 | Hard cap per session (Asia/London/NY/Overlap each tracked independently). |
| `MaxDailyTrades` | int | 3 | Hard cap across the entire trading day. |
| `MaxDailyLossPercent` | double | 2.0 | If today's PnL drops below −(balance × this/100), trading halts for the rest of the day. |
| `MinSecondsBetweenTrades` | int | 900 | Floor between any two entries (any direction, win or loss). |
| `LossCooldownMinutes` | int | 15 | Extra cooldown after a losing trade. |
| `StopAfterFirstWin` | bool | true | After the first win in a session, no more entries. |
| `StopAfterFirstLoss` | bool | true | After the first loss in a session, no more entries. With both true, max 1 trade per session. |

### 2.8 Display & Identity

| Input | Type | Default | What it does |
|---|---|---|---|
| `ShowUI` | bool | true | Toggle dashboard, sliding-window rect, candle deltas, footprint cells. Set false in backtest (or use the BT EA). |
| `FootprintBlockPips` | double | 1.0 | Price-bucket size for footprint cells (in pips). |
| `MagicNumber` | int | 20250411 | EA identification. **Use a different magic per symbol** if running multi-pair on the same account. |
| `EAComment` | string | "CDScalper" | Trade comment. |

---

## 3. XAUUSD presets

> **Critical**: confirm your broker's gold digit count first — open the symbol spec in MT5 (right-click XAUUSD in Market Watch → Specification). Most brokers use **3 digits** (Point = 0.001, 1 pip = 0.01); some use 2 digits (Point = 0.01, 1 pip = 0.10). The presets below assume **3-digit XAUUSD**. If your broker is 2-digit, divide all `*Points`, `BreakevenPips`, and `DeltaThreshold` values by 10.

### 3.1 Common across M1 / M3 / M5

| Input | Value | Why |
|---|---|---|
| `UseSessionFilter` | true | Gold's edge concentrates in sessions, not 24h. |
| `OverlapOnly` | true | London/NY overlap is gold's prime liquidity window. |
| `OverlapStart/End` | 12:30 / 16:00 | Standard overlap. |
| `UseRiskBasedSizing` | true | Always. |
| `RiskPercentPerTrade` | 1.0 | Start at 1%; raise to 2–3% only after the strategy proves itself. |
| `MaxLotSize` | 1.0 | Gold notional is ~$200K per standard lot at $2000. Cap aggressively. |
| `Slippage` | 10 | Gold slips more than EURUSD. |
| `UseHTFFilter` | true | M15 EMA still meaningful on gold. |
| `MaxTradesPerSession` | 2 | Sniper budget. |
| `MaxDailyTrades` | 3 | Daily ceiling. |
| `MaxDailyLossPercent` | 2.0 | Hard daily loss circuit-breaker. |
| `MinSecondsBetweenTrades` | 900 | 15 min between entries. |
| `LossCooldownMinutes` | 15 | After a loss, wait. |
| `StopAfterFirstWin` | true | Lock the win, walk away. |
| `StopAfterFirstLoss` | true | No revenge trades. |
| `AdverseDeltaExit` | true | Don't pay full SL when delta flips. |
| `AdverseDeltaCooldown` | 5 | Standard. |
| `UseBreakeven` | false | TP is tight enough that BE rarely fires before TP anyway. |
| `MagicNumber` | 20260508 | Distinct from EURUSD instance. |
| `EAComment` | "CDS_XAU" | Identify in journal. |
| `ShowUI` | false (BT) / true (live) | |

### 3.2 M1 preset (most aggressive)

| Input | Default | M1 XAUUSD |
|---|---|---|
| `WindowSize` | 10 | **10** |
| `DeltaThreshold` | 300 | **300** |
| `TP_Multiplier` | 0.4 | **0.4** |
| `SL_Multiplier` | 0.8 | **0.9** |
| `MinATR` | 0.00030 | **0.30** (~$0.30) |
| `MaxATR` | 0.00200 | **4.00** (~$4) |
| `MaxSpreadPoints` | 15 | **50** (raw account) / **300** (standard) |
| `MinConfirmations` | 5 | **4** (M1 noise rejects too many at 5) |
| `ADXThreshold` | 18 | **20** |
| `EMASlopeBars` | 3 | **3** |
| `MaxTradeSeconds` | 90 | **120** (gold takes longer to develop) |
| `SpreadAvgMultiplier` | 1.5 | **1.5** |
| `SpreadHistorySize` | 30 | **30** |

### 3.3 M3 preset (balanced)

| Input | Default | M3 XAUUSD |
|---|---|---|
| `WindowSize` | 10 | **8** |
| `DeltaThreshold` | 300 | **600** |
| `TP_Multiplier` | 0.4 | **0.4** |
| `SL_Multiplier` | 0.8 | **0.8** |
| `MinATR` | 0.00030 | **0.80** |
| `MaxATR` | 0.00200 | **8.00** |
| `MaxSpreadPoints` | 15 | **50 / 300** |
| `MinConfirmations` | 5 | **5** (strict — M3 has time to wait for clean setups) |
| `ADXThreshold` | 18 | **20** |
| `EMASlopeBars` | 3 | **3** |
| `MaxTradeSeconds` | 90 | **240** |
| `SpreadAvgMultiplier` | 1.5 | **1.5** |
| `SpreadHistorySize` | 30 | **20** |

### 3.4 M5 preset (most selective)

| Input | Default | M5 XAUUSD |
|---|---|---|
| `WindowSize` | 10 | **6** |
| `DeltaThreshold` | 300 | **900** |
| `TP_Multiplier` | 0.4 | **0.35** |
| `SL_Multiplier` | 0.8 | **0.7** |
| `MinATR` | 0.00030 | **1.50** |
| `MaxATR` | 0.00200 | **12.00** |
| `MaxSpreadPoints` | 15 | **50 / 300** |
| `MinConfirmations` | 5 | **5** |
| `ADXThreshold` | 18 | **22** (M5 trend signal is more reliable; raise the bar) |
| `EMASlopeBars` | 3 | **2** (fewer M15 bars stays responsive on a slower TF) |
| `MaxTradeSeconds` | 90 | **360** |
| `SpreadAvgMultiplier` | 1.5 | **1.5** |
| `SpreadHistorySize` | 30 | **15** |

---

## 4. Optimization sweep ranges (for your 230-combo runs)

These are reasonable ranges for the **highest-impact** parameters. Don't sweep everything — sweep these 3–5 first, lock the winners, then sweep secondary ones.

### Primary (sweep first, biggest P&L impact)

| Input | Min | Max | Step | Why |
|---|---|---|---|---|
| `DeltaThreshold` | 200 | 800 | 50 (M1) / 100 (M3+) | Direct trigger sensitivity. |
| `MinConfirmations` | 3 | 5 | 1 | Selectivity vs frequency tradeoff. |
| `ADXThreshold` | 15 | 28 | 2 | Regime selectivity. |
| `SL_Multiplier` | 0.5 | 1.4 | 0.1 | Stop placement is half the edge. |
| `TP_Multiplier` | 0.25 | 0.8 | 0.05 | R:R lever. |

### Secondary (sweep after primaries lock)

| Input | Min | Max | Step | Why |
|---|---|---|---|---|
| `WindowSize` | 5 | 15 | 1 | Smoothing. |
| `MaxTradeSeconds` | 60 | 600 | 30 | Time-out aggressiveness. |
| `EMASlopeBars` | 2 | 5 | 1 | Trend confirmation responsiveness. |
| `MinATR` / `MaxATR` | (calibrate to instrument) | | | Volatility band. |

### Don't sweep — set per broker / risk policy

`UseSessionFilter`, `OverlapOnly`, session windows, `RiskPercentPerTrade`, `MaxLotSize`, `MaxSpreadPoints`, `Slippage`, `MaxDailyTrades`, `MaxTradesPerSession`, `MaxDailyLossPercent`, `MagicNumber`, `EAComment`, `ShowUI`, `UseRiskBasedSizing`, `StopAfterFirstWin/Loss`.

---

## 5. Key caveats specific to XAUUSD

1. **Bid-flip delta is broker-tick-rate-dependent.** Two brokers running side-by-side produce different `cumDelta` values for the same bar. `DeltaThreshold` must be tuned per-broker; values from one feed do not transfer.
2. **Gold has real volume on most brokers** (unlike retail FX). The current EA ignores `MqlTick.volume_real` and counts ticks only. A future v2.1 could weight by real volume, which is the single biggest signal-quality lever for XAUUSD specifically.
3. **News risk is amplified.** US data (CPI, FOMC, NFP) and any geopolitical event can move gold $20+ in seconds. The EA does not currently filter news — consider pausing entries ±15 min around scheduled high-impact events. The MQL5 calendar API can provide this; not implemented yet (Tier 2 todo).
4. **2-digit vs 3-digit pricing.** Some brokers quote XAUUSD with 2 digits (Point = 0.01, 1 pip = 0.10). All `*Points`, `BreakevenPips`, and `DeltaThreshold` values in the M1/M3/M5 tables assume 3-digit. Divide by 10 if 2-digit.
5. **Spread volatility around session boundaries.** Asian → London transition (around 07:00 GMT) often spikes spread for 1–2 minutes. `SpreadAvgMultiplier=1.5` should catch this. If you trade Asia or London open specifically (not just overlap), consider `SpreadAvgMultiplier=1.3`.
6. **ATR bands are gold-scale.** The default `MinATR=0.00030` / `MaxATR=0.00200` are EURUSD-price values — they will block 100% of XAUUSD trades. **You must override these** with the timeframe-specific values in §3 above.

---

## 6. Sanity checks before running

- [ ] Symbol on chart is XAUUSD (not gold CFD with different specs)
- [ ] Broker digit count matches the preset assumption (3-digit assumed)
- [ ] `MagicNumber` is unique vs any other EA on the account
- [ ] `MinATR` / `MaxATR` are gold-scale, not EURUSD-scale (the EURUSD defaults will block all trades)
- [ ] `MaxLotSize` is reasonable for account size (1.0 = ~$200K notional)
- [ ] If running on a brokered account, `MaxSpreadPoints` reflects that broker's typical raw spread
- [ ] Session window (`OverlapStart/End`) matches your broker server's GMT offset (most do; verify via `TimeGMT()` in journal)
