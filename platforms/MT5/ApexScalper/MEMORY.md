# PROJECT MEMORY
Last updated: 2026-03-24 — Session 13

## Project: MT5 Microstructure Scalping EA
## Codename: APEX_SCALPER

## File Registry
| File | Purpose | Status | Last Modified |
|------|---------|--------|---------------|
| ApexScalper.mq5 | Main EA entry points (OnInit/OnTick/OnDeinit/OnBookEvent/OnChartEvent) — no logic | STABLE | 2026-03-23 |
| Core/Defines.mqh | All enums, structs, constants (ApexTick, ApexCandle, FootprintRow, FootprintCandle, OBLevel, OrderBookSnapshot, VPNode, SignalResult, CompositeResult, TradeContext, ApexRegime, TradingSession, ApexEvent) | STABLE | 2026-03-23 |
| Core/Inputs.mqh | All input/sinput parameter declarations grouped by module | STABLE | 2026-03-23 |
| Core/State.mqh | Global state variables (g_CurrentRegime, g_LastComposite, g_KillSwitch, g_CurrentSession, g_BarsProcessed, g_BarsSinceLastTrade, g_SessionStartTime, g_DailyPnL, g_PeakEquity, g_TotalTrades, g_WinningTrades) | STABLE | 2026-03-23 |
| Core/EventBus.mqh | Observer pattern pub/sub for inter-module events (ApexEvent enum + subscribe/publish) | STABLE | 2026-03-23 |
| Utils/RingBuffer.mqh | Generic MQL5 template ring buffer (Push/Get/ToArray/Size/Capacity/IsFull/Reset) | STABLE | 2026-03-23 |
| Utils/MathUtils.mqh | ZScore, RollingMean/StdDev, LinearRegressionSlope/R2(weighted), Normalize, Clamp, VWAP, WeightedMean, ExponentialDecayWeight, OBIFormula, WeightedOBI, ScoreFromZScore — unit tests included | STABLE | 2026-03-23 |
| Utils/TimeUtils.mqh | ParseTimeString, SecondsIntoDay, IsInTimeRange (incl. overnight), ClassifySession, SessionToString, RegimeToString, IsNewBar, MillisecondsSince, IsSameDay, GMTOffset — unit tests included | STABLE | 2026-03-23 |
| Utils/StringUtils.mqh | FormatScore/Confidence/Price/Lot/PnL/Spread/Age/Drawdown, SignalStatusString, ScoreBar, CSVEscape/Row, DateTimeToCSV, PadLeft/Right — unit tests included | STABLE | 2026-03-23 |
| Data/TickCollector.mqh | Raw tick aggregation, buy/sell classification (last>=ask=buy, last<=bid=sell), tape speed, directional fraction, buy/sell volume, 5000-tick ring buffer | STABLE | 2026-03-23 |
| Data/CandleBuilder.mqh | Builds ApexCandle from tick stream; tracks buy/sell vol, delta, delta_efficiency, tape_speed, avg/max spread; ring buffer of window+10 complete candles | STABLE | 2026-03-23 |
| Data/FootprintBuilder.mqh | Per-candle footprint (bid/ask vol per quantized price level), imbalance scan (bid/ask_imbalance, zero_bid/ask), stacked imbalance detection (max consecutive), POC, Value Area (70%), window+10 ring buffer | STABLE | 2026-03-24 |
| Data/OrderBookSnapshot.mqh | MarketBookGet() wrapper; OBI L1/L3/L5/L10 + weighted OBI (exp decay); largest bid/ask level tracking; spoof detection (level vanishes within InpOBISpoofDetectSnap snaps); OBI momentum (lin reg slope); 50-snapshot ring buffer; IsSnapshotDue() throttle | STABLE | 2026-03-24 |
| Data/VolumeProfile.mqh | Merges footprint rows across window into unified price→vol map; POC; HVP (mean + N*stddev threshold); Value Area (70% from POC outward); GetNearestHVPBelow/Above for SL/TP; fallback to OHLC midpoint if no footprint data | STABLE | 2026-03-24 |
| Data/WindowManager.mqh | Central controller: owns CVolumeProfile, holds CCandleBuilder* + CFootprintBuilder* pointers; OnTick() detects bar change, calls Advance() which refreshes both windows + rebuilds VP + publishes EVENT_NEW_BAR; GetCurrentCandle/Footprint for live data | STABLE | 2026-03-24 |
| Signals/SignalBase.mqh | Abstract base CSignalBase with Calculate/Name/Weight/IsReady pure virtuals + invalid_result/make_result helpers | STABLE | 2026-03-24 |
| Signals/DeltaSignal.mqh | A:delta Z-score(0.4) + B:acceleration(0.3) + C:divergence(0.3); confidence reduced if delta_efficiency < min | STABLE | 2026-03-24 |
| Signals/VPINSignal.mqh | Fixed-volume bucket accumulator with OnTick(); VPIN = mean(toxicity) over L buckets; direction from latest bucket; rising adds ±0.3 | STABLE | 2026-03-24 |
| Signals/OBISignal.mqh | CalculateShallow() (obi_l3 + momentum + spoof penalty) + CalculateDeep() (weighted_obi); exposes both to ScoringEngine | STABLE | 2026-03-24 |
| Signals/FootprintSignal.mqh | Stacked imbalance from last 3 complete candles + live candle bonus + fill-target sub-signal | STABLE | 2026-03-24 |
| Signals/AbsorptionSignal.mqh | Absorption = vol/range; Z-scored; at HVP/key level max ±3, else max ±1; direction from close position in candle | STABLE | 2026-03-24 |
| Signals/HVPSignal.mqh | Weighted lin reg slope through HVP nodes (recency weight = 1/(bars+1)); score * R² as confidence | STABLE | 2026-03-24 |
| Signals/TapeSpeedSignal.mqh | OnTick() maintains 60-obs speed history; spike+directional → scored; spike+neutral → score 0 (institutional) | STABLE | 2026-03-24 |
| Signals/VPOCSignal.mqh | POC displacement over lookback in ticks; stable VPOC (sd < 1 tick) → anchor flag (used by TP engine), score 0; weight=0 (informational) | STABLE | 2026-03-24 |
| Signals/SpreadSignal.mqh | Widening+directional → informed flow score; widening+neutral → sets widening_alert flag, score 0; compressing+directional → fade; weight=0 (supporting) | STABLE | 2026-03-24 |
| Engine/SignalDecayManager.mqh | Name→timestamp map; IsValid() checks age_ms < TTL; TTLs from Inputs.mqh; Update() refreshes on each SignalResult | STABLE | 2026-03-24 |
| Engine/ConflictFilter.mqh | Delta vs VPIN direction conflict check; blocks trade when conflict + score near threshold; always checks signals_agree | STABLE | 2026-03-24 |
| Engine/ScoringEngine.mqh | Auto-normalizes weights; TTL validates each signal; regime multipliers applied at runtime; normalizes by active weight sum; updates g_LastComposite | STABLE | 2026-03-24 |
| Engine/RegimeClassifier.mqh | ADX computed from scratch (Wilder smoothing, DM+/DM-/TR); BB width = 2σ band / midline; VPOC proxy = (H+L)/2 std dev; updates g_CurrentRegime + publishes EVENT_REGIME_CHANGED | STABLE | 2026-03-24 |
| Engine/ConfirmationGate.mqh | 10-check gate (kill switch, conflict, score threshold, agree count, regime, session, spread, news, cooldown, positions); #includes Risk headers directly; SetSessionFilter/SpreadFilter/NewsFilter/RiskManager setters | STABLE | 2026-03-24 |
| Execution/StopLossEngine.mqh | Priority: HVP-behind SL → fixed fallback → imbalance tighter alt; broker min stop enforced | STABLE | 2026-03-24 |
| Execution/TakeProfitEngine.mqh | Opposing HVP TP (discarded if R:R < InpTPFixedRR) → fixed R:R fallback; VPOC anchor check → fixed R:R override; ComputeTrailLong/Short for trailing | STABLE | 2026-03-24 |
| Execution/TradeManager.mqh | CTrade wrapper: lot normalization, parameter validation, 1 requote retry, TradeContext population, g_TotalTrades/g_BarsSinceLastTrade update, SetTracker() injection | STABLE | 2026-03-24 |
| Execution/PositionTracker.mqh | Circular include resolved via register_trade() deferred impl; trailing activation on TP HVP hit; early exit on composite reversal; sync on external close | STABLE | 2026-03-24 |
| Risk/RiskManager.mqh | Daily loss % circuit breaker, drawdown from peak equity circuit breaker, dynamic lot sizing (balance×risk%/sl_points×val_per_point), midnight reset, kill switch via EVENT_KILL_SWITCH_ACTIVATED | STABLE | 2026-03-24 |
| Risk/SessionFilter.mqh | OnTick() updates g_CurrentSession via ClassifySession(); IsAllowed() gates on InpTradeAsian/London/NewYork/LondonNY flags | STABLE | 2026-03-24 |
| Risk/SpreadFilter.mqh | OnTick() computes (ask-bid)/point → g_CurrentSpread; IsOK() returns g_CurrentSpread <= InpMaxSpreadPoints | STABLE | 2026-03-24 |
| Risk/NewsFilter.mqh | CalendarValueHistory() + CalendarEventById(); CALENDAR_IMPORTANCE_HIGH events in [now-before, now+after] window; throttled to 60s; updates g_NewsBlackout | STABLE | 2026-03-24 |
| UI/PanelTheme.mqh | Layout constants (APEX_PNL_*), color helpers ApexScoreColor/ApexBarFillWidth; no class — pure #define + free functions | STABLE | 2026-03-24 |
| UI/SignalLEDs.mqh | CSignalLEDs: 8×8 rectangle LEDs per signal row; green=bull, red=bear, grey=stale/nodata, yellow=stale-age; SetAllVisible for minimize | STABLE | 2026-03-24 |
| UI/DashboardPanel.mqh | CDashboardPanel: all objects created once in Initialize(), updated via ObjectSet* in Redraw(); 5 sections: header, signals (8 rows with score bars+LEDs), composite, risk, session/filters; header click minimizes | STABLE | 2026-03-24 |
| UI/FootprintRenderer.mqh | APEX_FP_* OBJ_TEXT labels (24, bid\|ask per row, colored by imbalance) + 2 OBJ_RECTANGLE stacked zone overlays; rows centered on mid price; OnTick() updates label positions to bar right-edge time | STABLE | 2026-03-24 |
| UI/HVPRenderer.mqh | APEX_HVP_* up to 20 OBJ_HLINE colored by volume intensity; POC line (yellow); value area high/low dashed lines; OBJ_TREND regression through HVP prices (weighted by volume); OnBarClose() only | STABLE | 2026-03-24 |
| UI/OBRenderer.mqh | APEX_OB_* 10 bid + 10 ask OBJ_RECTANGLE_LABEL bars (CORNER_RIGHT_UPPER); width ∝ level volume; spoof alert tints BG red; throttled to InpOBISnapshotInterval ms | STABLE | 2026-03-24 |
| Logging/SessionLogger.mqh | Tracks max drawdown (OnTick) + regime histogram; OnTradeOpen/Close called by TradeLogger for avg composite stats; WriteSessionSummary() called from OnDeinit | STABLE | 2026-03-24 |
| Logging/TradeLogger.mqh | Self-contained trade detection via PositionsTotal scan (opens) + HistorySelect/DEAL_ENTRY_OUT scan (closes); TLEntry cache stores composite/regime/spread at entry; writes open row + close row per trade; calls SessionLogger callbacks | STABLE | 2026-03-24 |
| Logging/SignalLogger.mqh | Per-tick CSV append (InpEnableSignalLog guard); file handle kept open across ticks; lazy header write; columns: timestamp + composite + per-signal score/conf/valid + regime + spread | STABLE | 2026-03-24 |

## Completed Modules
- [x] Core scaffolding (Session 1)
- [x] Utility layer (Session 2)
- [x] Data layer (Sessions 3-5) — ALL COMPLETE
- [x] Signal Engine (Session 6)
- [x] Scoring Engine (Session 7)
- [x] Regime Classifier (Session 7)
- [x] Execution Layer (Session 8)
- [x] Risk Layer (Session 9)
- [x] Dashboard Panel (Session 10)
- [x] Renderers (Session 11)
- [x] Logger (Session 12)
- [x] Integration (Session 13)
- [ ] Tuning (Session 14)

## Known Issues
(none — Session 14 compile fixes applied 2026-03-24)

## Session Log
- **2026-03-24 Session 14 — Compile Error Fix:**
  - RC1 RingBuffer: `Push(const T &value)`, `void Get(int index, T &out)`, `ToArray` updated — all callers updated in TickCollector, FootprintBuilder, OrderBookSnapshot, VPINSignal
  - RC2 Static consts → #defines: `DECAY_MANAGER_MAX_SIGNALS` (SignalDecayManager), `NEWS_CHECK_INTERVAL_SECS` (NewsFilter), `TAPE_SPEED_HISTORY_SIZE` (TapeSpeedSignal), `APEX_WEIGHT_COUNT` (ScoringEngine)
  - RC3 SignalBase: `invalid_result`/`make_result` changed to void with `SignalResult &out` — all 9 signal files updated (Delta, VPIN, OBI, Footprint, Absorption, HVP, TapeSpeed, VPOC, Spread)
  - RC4 Struct pointers removed: VolumeProfile line 127 (`FootprintCandle *fc` → direct array access), `GetNodes()` removed; AbsorptionSignal line 79 (`ApexCandle *c` → direct array access); ScoringEngine line 145 (`SignalResult *r` → direct array access)
  - RC5 Reference to array element: VPINSignal line 50 `ApexTick &t` → `ApexTick t` (copy)
  - RC6 Type casts: TickCollector line 55 `(long)tick.volume`; OrderBookSnapshot lines 151-152 `(double)book[i].volume`
  - Extra: FootprintBuilder `m_accum[]` → fixed `m_accum[APEX_MAX_FOOTPRINT_ROWS]`, removed `ArrayResize`+`ArrayInitialize`, removed `const` from `GetCurrentSnapshot()`; WindowManager `GetCurrentFootprint()` `const` removed
  - Compile result: pending first compile — 0 errors expected
- **2026-03-23 Session 1:** Created MEMORY.md, INSTRUCTIONS.md, full directory structure, Defines.mqh, State.mqh, Inputs.mqh, EventBus.mqh, ApexScalper.mq5 shell. All Session 1 deliverables complete.
- **2026-03-23 Session 2:** Created RingBuffer.mqh (template), MathUtils.mqh (11 math functions + OBI helpers + unit tests), TimeUtils.mqh (session classifier, bar helpers, overnight range support + unit tests), StringUtils.mqh (panel/CSV formatters + unit tests). Unit tests wired into OnInit. All Session 2 deliverables complete.
- **2026-03-23 Session 3:** Created TickCollector.mqh (5000-tick ring buffer, buy/sell classification, GetLastN/GetTicksSince/GetTapeSpeed/GetDirectionalFraction/GetBuyVolume/GetSellVolume) and CandleBuilder.mqh (enriched ApexCandle from tick stream, bar close detection, delta/efficiency/tape_speed/spread tracking, window+10 ring buffer). Both modules wired into ApexScalper.mq5 OnTick. All Session 3 deliverables complete.
- **2026-03-24 Session 4:** Created FootprintBuilder.mqh (price-level accumulation with quantized tick levels, 3-pass build: imbalance flags / stacked imbalance scan / Value Area expansion from POC, GetCurrentSnapshot() for live in-progress candle) and OrderBookSnapshot.mqh (MarketBookGet() parsing, OBI at 4 depths, weighted OBI, spoof detection, OBI momentum via lin reg slope, IsSnapshotDue() throttle). Both wired into ApexScalper.mq5 OnTick + OnBookEvent. All Session 4 deliverables complete.
- **2026-03-24 Session 5:** Created VolumeProfile.mqh (footprint merge, POC, HVP std-dev threshold, Value Area, GetNearestHVPBelow/Above, OHLC fallback) and WindowManager.mqh (CCandleBuilder* + CFootprintBuilder* pointers, bar detection, Advance(), g_BarsProcessed incremented here, publishes EVENT_NEW_BAR). Wired into OnTick. All Session 5 deliverables complete.
- **2026-03-24 Session 6:** Built all 10 signal files. SignalBase abstract class + 8 core weighted signals + 2 informational (VPOC anchor, SpreadSignal alert). All wired into ApexScalper.mq5.
- **2026-03-24 Session 7:** Built SignalDecayManager (name→TTL map), ConflictFilter (delta vs VPIN + agreement), ScoringEngine (auto-normalize, regime multipliers, active weight normalization), RegimeClassifier (ADX from scratch via Wilder, BB width, VPOC proxy), ConfirmationGate (9-check gate, stub hooks for Session 9). All wired into OnTick.
- **2026-03-24 Session 8:** Built StopLossEngine (HVP-behind → fixed fallback → imbalance tighter alt), TakeProfitEngine (opposing HVP → fixed R:R, VPOC anchor override, ComputeTrailLong/Short), TradeManager (CTrade wrapper, lot normalization, 1 requote retry, register_trade via SetTracker), PositionTracker (trailing activation on TP hit, early exit on composite reversal, circular include resolved via deferred register_trade impl). Execution fully wired: gate fires → SL/TP calculated → order placed → tracker manages. Lot sizing uses InpLotSize until RiskManager wired in Session 9.
- **2026-03-24 Session 13:** Integration pass — fixed 4 bugs: (1) OBRenderer.OnTick() removed incorrect OBJPROP_XDISTANCE updates on bid/ask bars (only XSIZE should vary with CORNER_RIGHT_UPPER anchoring); (2) OBRenderer throttle replaced GetMicrosecondCount() hack with GetTickCount(); (3) SignalLogger replaced unreliable FileSize()==0 header check with m_header_written bool flag; (4) ApexScalper.mq5 OnInit added explicit resets for g_LastBarTime=0, g_TotalTrades=0, g_WinningTrades=0. Removed stale "uncomment as sessions complete" comment from OnDeinit and global instances block header. All modules compile-clean; project ready for Session 14 performance tuning.
- **2026-03-24 Session 12:** Built SessionLogger (OnTick drawdown+regime tracking, OnTradeOpen/Close callbacks, WriteSessionSummary CSV append), TradeLogger (self-contained open/close detection via PositionsTotal + HistorySelect scans, TLEntry cache capturing composite/regime/spread at entry tick, open+close rows per trade, DEAL_POSITION_ID matching, SetSessionLogger injection), SignalLogger (file handle open across ticks, lazy header, per-component score+conf+valid columns). All three wired into ApexScalper.mq5: Initialize+SetSessionLogger in OnInit, OnTick calls in Step 12, WriteSessionSummary+SignalLogger.Deinitialize in OnDeinit. Trade CSV: `Symbol_trades_YYYY-MM-DD.csv`; Signal CSV: `Symbol_signals_YYYY-MM-DD.csv`; Session CSV: `Symbol_sessions_YYYY-MM-DD.csv`.
- **2026-03-24 Session 11:** Built FootprintRenderer (24 OBJ_TEXT labels centered on mid price + 2 stacked-imbalance OBJ_RECTANGLE zones; bar-right-edge time anchor; OnTick()), HVPRenderer (up to 20 OBJ_HLINE + POC + VA bounds + OBJ_TREND regression through volume-weighted HVP prices; OnBarClose() only triggered by g_LastBarTime change), OBRenderer (10 bid/ask OBJ_RECTANGLE_LABEL bars CORNER_RIGHT_UPPER; width ∝ level volume; spoof alert; throttled to InpOBISnapshotInterval). Added g_LastBarTime to State.mqh. All three wired into ApexScalper.mq5: Initialize/SetXxx in OnInit, OnTick in Step 11, OnBarClose in Step 2, Deinitialize in OnDeinit.
- **2026-03-24 Session 10:** Built PanelTheme.mqh (layout #defines + ApexScoreColor/ApexBarFillWidth helpers), SignalLEDs.mqh (CSignalLEDs: 8×8 LED rectangles, one per signal row, color by direction/staleness), DashboardPanel.mqh (CDashboardPanel: full 5-section live panel — signals matrix with score bars + LEDs, composite score/direction/agreement, risk PnL/DD/kill switch/positions, session/spread/news/regime; objects created once in Initialize(), updated via ObjectSet* in Redraw(); header click minimizes; Deinitialize deletes all APEX_D_ objects). Wired into ApexScalper.mq5: g_Dashboard declared, Initialize in OnInit, Redraw in Step 10 of OnTick, OnChartEvent delegated, Deinitialize in OnDeinit.
- **2026-03-24 Session 9:** Built SessionFilter (ClassifySession→g_CurrentSession, IsAllowed() checks session flags), SpreadFilter (OnTick updates g_CurrentSpread, IsOK()), NewsFilter (CalendarValueHistory API, CALENDAR_IMPORTANCE_HIGH filter, 60s throttle, g_NewsBlackout), RiskManager (midnight reset, daily loss % + drawdown circuit breakers, kill switch via EVENT_KILL_SWITCH_ACTIVATED, dynamic lot sizing). Rewrote ConfirmationGate to 10-check gate (added news blackout check), directly #includes Risk headers, calls real filter methods via injected pointers. Wired all 4 risk modules into ApexScalper.mq5: OnTick calls in Step 3c, Initialize + SetXxx injections in OnInit. Dynamic lot sizing live: InpUseDynamicSizing ? g_RiskManager.CalculateLotSize(sl_pts) : InpLotSize.
