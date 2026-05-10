# CumulativeDeltaScalper — EA-Specific Instructions

## Strategy
Scalps EURUSD on 1M/3M/5M using tick-level cumulative delta in a sliding window of N candles. When the summed delta crosses ±DeltaThreshold, a scalp trade is opened with ATR-based SL/TP. Filtered by 15M EMA(50) trend and session/risk guards.

## Architecture
Standard decoupled pattern:
- Config.mqh → inputs, constants, all global state variables
- Market.mqh → ATR/EMA handles, tick processing, candle detection, delta buffer
- Signal.mqh → cumulative delta calculation, crossover detection, HTF filter
- Risk.mqh → SL/TP calculation, all guard checks (session, spread, daily limits, cooldown, ATR)
- Trade.mqh → CTrade wrapper, position check, order open, breakeven management
- Utils.mqh → daily stats from history, dashboard (OBJ_LABEL), daily counter reset
- CumulativeDeltaScalper.mq5 → OnInit/OnDeinit/OnTick orchestration only

## Key Design Decisions
- Delta buffer is a circular array (not shifting), index wraps via modulo
- Crossover detection compares current vs previous cumDelta (not just threshold breach)
- Daily stats synced from deal history every tick to catch SL/TP exits
- Breakeven uses 0.5 pip buffer above entry, tracked with bool flag
- Pips = 10 × Point for 5-digit brokers (EURUSD)
