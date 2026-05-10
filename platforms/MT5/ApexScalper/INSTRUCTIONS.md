# ARCHITECTURE DECISIONS & INSTRUCTIONS
Last updated: 2026-03-24 (Session 13 complete)

## Core Principle
Never break a STABLE module to fix another. Always isolate.

## Build Order (strict)
1. Utility layer (math helpers, ring buffers, stats)
2. Data layer (tick handler, OB snapshot, footprint builder)
3. Signal calculators (each isolated)
4. Scoring engine
5. Regime classifier
6. Execution layer
7. Risk manager
8. UI panel
9. Integration / wiring
10. Logging

## Naming Conventions
**Established 2026-03-23:**
- Class names: prefix C (e.g., CTickCollector, CScoringEngine)
- Global module instances in ApexScalper.mq5: prefix g_ (e.g., g_TickCollector)
- Global state variables in State.mqh: prefix g_ (e.g., g_CurrentRegime)
- Input parameters: prefix Inp (e.g., InpWindowSize)
- Enums: ALL_CAPS with module prefix (e.g., REGIME_TRENDING_BULL, SESSION_LONDON, EVENT_NEW_BAR)
- Struct names: PascalCase no prefix (e.g., ApexTick, FootprintRow, SignalResult)
- File-private helpers: lowercase with underscore (e.g., calc_weighted_obi)
- Constants in Defines.mqh: APEX_ prefix, ALL_CAPS (e.g., APEX_MAX_SNAPSHOTS)

## Module Communication Rules
**Established 2026-03-23:**
- Modules communicate ONLY through State.mqh variables and EventBus.mqh pub/sub
- No module includes another module's header and calls its methods directly, unless it owns that module
- Exception: ApexScalper.mq5 owns all modules and wires them; it may call any module's public methods

## Math Decisions
**Established 2026-03-23:**
- OBI range: -1.0 to +1.0 using formula: (bid_vol - ask_vol) / (bid_vol + ask_vol)
- Weighted OBI uses exponential decay: w[i] = decay^(i-1), 1-based level index
- VPIN range: 0 to 1; toxic_flow = 1
- Signal score range: -3.0 to +3.0 (±3 = max conviction)
- Z-score mapping: score = Clamp(zscore / threshold * 3.0, -3.0, 3.0)
- Absorption: A = volume / max(high - low, min_range) — higher = more absorption
- Dynamic lot: (balance * risk_pct/100) / (sl_points * tick_value_per_lot)

## Parameter Decisions
**Established 2026-03-23:**
- All defaults taken from Inputs.mqh as specified in master prompt
- Weights must sum to 1.0 — validated in OnInit, auto-normalized with warning if not
- Signal TTLs are milliseconds (converted from input int ms values)
- Footprint price levels quantized by InpFootprintTickSize ticks

## Architecture Decisions
**2026-03-23:** EventBus uses function pointer arrays (no heap allocation during runtime). Max 8 subscribers per event type. MQL5 does not support std::function — use typedef for function pointers.

**2026-03-23:** All ring buffers pre-allocated in OnInit. Zero dynamic allocation in OnTick. This is mandatory per anti-pattern rules.

**2026-03-23:** Dashboard objects created once in Initialize(), updated via ObjectSet* only. ObjectCreate never called in OnTick.

**2026-03-23:** Session 1 delivers a compilable empty shell. Each subsequent session builds one layer without breaking prior STABLE layers.

**2026-03-23:** MQL5 templates (CRingBuffer<T>) require explicit instantiation per type. All ring buffer types needed by the project are listed as comments at the bottom of RingBuffer.mqh. Add new types there as new modules are created.

**2026-03-23:** Unit tests (MathUtils_RunTests, TimeUtils_RunTests, StringUtils_RunTests) are wired into OnInit. In production, wrap with `#ifdef APEX_DEBUG` or remove after verification. They print to MT5 Experts log.

**2026-03-23:** TimeUtils.IsInTimeRange handles overnight sessions (start > end). ClassifySession assigns LONDON_NY_OVERLAP when both London and NY are active simultaneously — checked before individual session checks.

**2026-03-23:** TickCollector deduplicates ticks by comparing time_msc + last price. Some brokers send repeated ticks on book changes with no price movement — these are skipped.

**2026-03-23:** CandleBuilder receives a pre-classified ApexTick from TickCollector (not raw MqlTick). CandleBuilder.OnTick() must be called *after* TickCollector.OnTick() every bar. Bar close detection uses iTime(Symbol(), InpTimeframe, 0) comparison, not a timer.

**2026-03-23:** CandleBuilder uses the bar_time delta (new_bar_time - prev_bar_time) as the candle duration in seconds for tape_speed. Fallback: PeriodSeconds(InpTimeframe) if delta is zero or negative.

**2026-03-23:** Module instantiation order in OnInit: EventBus → TickCollector → CandleBuilder → FootprintBuilder → OrderBookSnapshot → (Session 5: VolumeProfile → WindowManager). Each module's Initialize() must return true or INIT_FAILED is returned.

**2026-03-24:** FootprintBuilder uses a static FPAccumRow[] array (size APEX_MAX_FOOTPRINT_ROWS=500) as the per-bar accumulator. Rows are quantized by `MathRound(price / (tick_size * InpFootprintTickSize))`. Sorted ascending at bar close via insertion sort (small N). The 3 passes: (1) fill rows + find POC, (2) stacked imbalance scan, (3) Value Area expansion from POC outward choosing higher-volume side first.

**2026-03-24:** OrderBookSnapshot uses MarketBookGet() which returns bids (BOOK_TYPE_BUY) before asks (BOOK_TYPE_ASK) in the array. Spoof detection: if the largest level from `InpOBISpoofDetectSnap` snapshots ago has volume < half its original value now, flag spoof_suspected. OBI momentum = LinearRegressionSlope of weighted_obi over last N snapshots.

**2026-03-24:** OrderBookSnapshot.TakeSnapshot() is called from both OnBookEvent() (immediate on book change) and OnTick() when IsSnapshotDue() is true (throttled fallback). This ensures snapshots even when OnBookEvent is unavailable.

**2026-03-24:** VolumeProfile.Rebuild() is always called with BOTH footprints[] and candles[] arrays. If footprint data is empty (window not yet populated), it falls back to approximating volume profile from ApexCandle OHLC midpoints. This prevents null profiles during the warmup period.

**2026-03-24:** WindowManager holds raw pointers to CCandleBuilder and CFootprintBuilder. These objects are declared as value instances in ApexScalper.mq5, so their addresses are stable. WindowManager.Initialize() is called after both builders are initialized. WindowManager increments g_BarsProcessed and g_BarsSinceLastTrade — no other module should increment these.

**2026-03-24:** WindowManager.OnTick() handles all bar detection. Signal modules must not use iTime() themselves for bar detection — they rely on EVENT_NEW_BAR via EventBus or on IsWindowReady() before computing.

**2026-03-24:** VPINSignal and TapeSpeedSignal maintain internal state that must be updated every tick via OnTick(). Call these before Calculate() in OnTick(). All other signals are stateless — they read directly from data layer on each Calculate() call.

**2026-03-24:** OBISignal exposes CalculateShallow() and CalculateDeep() as separate calls. ScoringEngine receives both as separate SignalResult entries with different names ("OBI_SHALLOW" and "OBI_DEEP") and weights (InpWeightOBI and InpWeightOBIDeep). The default Calculate() returns shallow only.

**2026-03-24:** VPOCSignal and SpreadSignal have Weight() = 0.0. They are NOT passed to ScoringEngine's core 8. Their side effects (anchor flag, widening alert) are consumed by TP engine and risk layer respectively. They are still called every tick for side-effect updates.

**2026-03-24:** Signal score confidence: when a signal is not ready or data is insufficient, is_valid=false is set. ScoringEngine must check is_valid before including in composite. Signals with low confidence (< 0.2) still contribute but at reduced effective weight.

**2026-03-24:** ScoringEngine normalizes the composite score by the sum of ACTIVE (valid, non-stale) signal weights rather than the total weight sum. This prevents artificial deflation of the composite during the warmup period when some signals are not yet ready.

**2026-03-24:** RegimeClassifier ADX: uses Wilder smoothing (seed = sum of first period bars; subsequent = prev - prev/period + raw). CopyHigh/CopyLow/CopyClose return newest-first; ArrayReverse() is called to convert to oldest-first before processing. ADX is computed on InpRegimeTF, not InpTimeframe.

**2026-03-24 SESSION 9 UPDATE:** ConfirmationGate was rewritten in Session 9 to directly #include Risk headers (SessionFilter.mqh, SpreadFilter.mqh, NewsFilter.mqh, RiskManager.mqh). The stub methods were replaced with real pointer calls: m_session.IsAllowed(), m_spread.IsOK(), m_news.IsAllowed(), m_risk.GetOpenPositionCount(). The gate is now 10-check (news blackout added as check 8). MQL5 #pragma once prevents double-inclusion when both ConfirmationGate.mqh and ApexScalper.mq5 include the Risk headers.

**2026-03-24:** ConflictFilter does NOT block when both delta and VPIN agree. It only fires when they actively disagree AND composite is near the threshold band. A strong composite (above threshold + band) trades through the conflict.

**2026-03-24:** TradeManager and PositionTracker have a circular dependency (each needs a pointer to the other). Resolved by: (1) TradeManager declares `register_trade()` with a forward pointer type and deferred implementation; (2) PositionTracker.mqh includes TradeManager.mqh and provides the implementation body at file end. Include order in ApexScalper.mq5: StopLossEngine → TakeProfitEngine → TradeManager → PositionTracker.

**2026-03-24:** Dynamic lot sizing: `InpUseDynamicSizing ? g_RiskManager.CalculateLotSize(sl_pts) : InpLotSize`. sl_pts = MathAbs(entry - sl) / SYMBOL_POINT. CalculateLotSize clamps to SYMBOL_VOLUME_MIN/MAX and rounds down to SYMBOL_VOLUME_STEP. Falls back to InpLotSize when sl_points < 1e-10.

**2026-03-24:** RiskManager.OnTick() is called in Step 3c of OnTick (before signal calculation) rather than Step 8 (after position tracking). This ensures kill switch is activated before ShouldTrade() is evaluated on the same tick.

**2026-03-24:** NewsFilter throttles CalendarValueHistory() to once per 60 seconds (CHECK_INTERVAL_SECS constant). The calendar API is expensive — never call in OnTick without throttling. g_NewsBlackout is set true/false on each calendar poll and retained between polls.

**2026-03-24:** RiskManager daily P&L tracking: uses balance change since start of day + current open floating P&L. `day_start_balance` is a static local reset at midnight. Approximation assumes no intraday deposits/withdrawals.

**2026-03-24:** TakeProfitEngine discards opposing-HVP TP if `tp_dist < sl_dist * InpTPFixedRR` — this ensures minimum R:R is always respected even when an HVP is found. The HVP TP is only used if it provides equal or better R:R than the fixed ratio.

**2026-03-24:** PositionTracker early exit fires when composite direction flips AND score exceeds InpCompositeThreshold AND trade_allowed=true. This prevents exits on weak/noisy score flips.

**2026-03-24:** TradeLogger uses MT5's native APIs (PositionsTotal + HistorySelect/HistoryDealsTotal) to detect opens and closes without modifying any STABLE module. Composite score at entry is captured from g_LastComposite at the tick when the new position is first detected — same tick the trade was placed. Matched on close via DEAL_POSITION_ID == position ticket.

**2026-03-24:** SignalLogger keeps its file handle open across ticks (performance). Only call Deinitialize() once on EA stop to flush and close. Do NOT call FileClose per tick. Header is written lazily on first tick where component_count > 0, since during Initialize() signals may not yet be calculated.

**2026-03-24:** SessionLogger.WriteSessionSummary() is called from OnDeinit (before the event bus reset). It uses g_TotalTrades and g_WinningTrades from State.mqh for basic counts, plus its own internal running stats for composite averages and max drawdown.

**2026-03-24:** All log files use `InpLogFolder + Symbol() + "_type_YYYY-MM-DD.csv"` paths within the MQL5\Files directory. FolderCreate() is called at Initialize() time. FileIsExist() check before open determines whether to write the CSV header row.

**2026-03-24:** DashboardPanel.mqh uses the "create once, update always" pattern. ObjectCreate is called only in Initialize(). Redraw() calls only ObjectSetString/ObjectSetInteger — never ObjectCreate. This prevents flicker and chart object list bloat. All chart objects are named with "APEX_D_" prefix so Deinitialize() can bulk-delete by scanning ObjectsTotal().

**2026-03-24:** Score bar is two objects: "SR_BARBG_i" (dark grey, fixed width = APEX_PNL_BAR_W) and "SR_BAR_i" (colored fill, width varies). The fill x-position shifts left or right of center depending on direction: positive scores extend right from center, negative extend left. When score=0 or stale, fill width = 0. A 1px center-divider rect ("SR_BCTR_i") marks the zero line.

**2026-03-24:** Minimize/maximize: clicking the header rectangle (HDR_BG, SELECTABLE=true) fires CHARTEVENT_OBJECT_CLICK. Toggles m_minimized, iterates all APEX_D_ objects to set OBJPROP_TIMEFRAMES OBJ_NO_PERIODS/OBJ_ALL_PERIODS, then resizes BG to just the header height. Header objects (BG, HDR_BG, HDR_TITLE, HDR_SYM, HDR_REG) are always kept visible.

**2026-03-24:** DashboardPanel.mqh has no dependency on Engine/ or Execution/ headers — all data from g_* globals (State.mqh), AccountInfoDouble(), and direct position counting. This avoids circular dependency risk.

**2026-03-23:** The EA is symbol-agnostic and timeframe-agnostic. All SymbolInfo calls use Symbol() at runtime. All period references use input parameters.
