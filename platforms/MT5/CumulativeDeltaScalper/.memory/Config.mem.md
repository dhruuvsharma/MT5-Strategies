# Memory: Config.mqh

## Purpose
All inputs, constants, indicator-period defines, and global state for CumulativeDeltaScalper v2.

## Exports (public inputs / globals)
- **Delta Settings**: WindowSize, DeltaThreshold
- **Sessions**: UseSessionFilter, OverlapOnly + Overlap[Start/End][Hour/Min], UseAsia/London/NewYorkSession + their hour/min ranges, ENUM_SESSION_ID enum (NONE/ASIA/LONDON/NY/OVERLAP)
- **Sniper Filters**: MinConfirmations (0..5), EMASlopeBars, ADXThreshold, SpreadAvgMultiplier, SpreadHistorySize
- **Trade Settings**: UseRiskBasedSizing, RiskPercentPerTrade, FixedLotSize, MaxLotSize, TP_Multiplier (0.4), SL_Multiplier (0.8), UseBreakeven, BreakevenPips, MaxSpreadPoints, Slippage
- **Fast Exit**: MaxTradeSeconds, AdverseDeltaExit, AdverseDeltaCooldown
- **Filters**: UseHTFFilter, MinATR, MaxATR
- **Risk Management**: MaxTradesPerSession (2), MaxDailyTrades (3), MaxDailyLossPercent, MinSecondsBetweenTrades, LossCooldownMinutes, StopAfterFirstWin, StopAfterFirstLoss
- **Display / Identity**: ShowUI, FootprintBlockPips, MagicNumber, EAComment
- **Defines**: ATR_PERIOD, EMA_PERIOD/TIMEFRAME, ADX_PERIOD/TIMEFRAME, STOPS_LEVEL_BUFFER_MULT, dashboard + sliding-window names
- **Globals**: indicator handles (atr/ema/adx), tick state (prevBid, up/down counts, deltaBuffer, prevCumDelta, liveDelta), pipSize, daily tracking, cooldown timers, session counters (currentSession, tradeCount, wins, losses), spread history ring, open-trade tracking (g_openTradeTime, g_openTradeDirection), g_breakevenApplied, dashboard labels

## Dependencies
- Imports from: none
- Imported by: Market.mqh

## Key Decisions
- 2026-05-08 — v2.0: removed `LotSize` (replaced by UseRiskBasedSizing + RiskPercentPerTrade + FixedLotSize). Added ENUM_SESSION_ID. Sniper defaults: TP 0.4×ATR, SL 0.8×ATR, MaxTradesPerSession=2, MaxDailyTrades=3, OverlapOnly=true.
- Pip size computed at runtime via SymbolInfo (MarketInit) — no longer hardcoded to 5-digit.

## Last Modified
- Date: 2026-05-08
- Change: v2 sniper restructure — sessions, sniper filters, fast-exit, risk-based sizing, expanded global state.
