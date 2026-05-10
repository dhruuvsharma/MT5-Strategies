# FootprintChartPro — EA-Specific Instructions

## Purpose
Professional-grade order flow visualization EA. Canvas-based delta cells footprint chart with 11 analysis panels. Visualization only — no trading.

## Architecture
Adapted decoupled pattern (no Risk/Trade layers — this EA does not trade):

| Layer   | File                   | Responsibility                                          |
|---------|------------------------|---------------------------------------------------------|
| Config  | Config.mqh             | All inputs, enums, structs, constants, global state     |
| Market  | Market.mqh             | Tick processing, DOM, historical bars, volume inference  |
| Signal  | Signal.mqh             | Signal meter, chart analyst report, analysis logic       |
| Render  | Render.mqh             | CCanvas primitives, theme management, color helpers      |
| Panels  | Panels.mqh             | All 11 panel rendering functions                         |
| Core EA | FootprintChartPro.mq5  | OnInit/OnDeinit/OnTick/OnTimer/OnBookEvent orchestration |

## Key Design Decisions
- ALL rendering via CCanvas (ResourceCreate/PixelSet) — NO chart objects
- Tick classification: uptick (bid up) = buy, downtick (bid down) = sell
- Price bucketing: MathFloor(price / bucketSize) * bucketSize
- Volume Inference Engine for brokers without real tick volume
- 6-level intensity coloring for delta cells (buyer high/med/low, seller high/med/low)
- 3-tier diagonal imbalance detection (buy[i] vs sell[i+1])
- 16 color themes with optional override-all mode
- Panel caching: redraw flags to avoid unnecessary recalculation
- Historical bar locking after imbalance/POC calculation

## Panels
1. Delta Cells Footprint (main) — stacked buy×sell cells with delta, POC, imbalance borders
2. Summary Table — vol, buy, sell, delta, POC, cumDelta for current bar
3. DOM — bid/ask depth with volume bars and flash highlights
4. Session Volume Profile — horizontal histogram with POC/VAH/VAL
5. Time & Sales — streaming tape with big order highlights
6. Signal Meter Gauge — analog dial from composite 4-factor scoring
7. Chart Analyst — 9-section report with 6-factor bias scoring
8. RSI(14) — mini line chart with OB/OS levels
9. MACD — mini histogram chart
10. Supply & Demand Zones — overlay on footprint panel
11. Economic Calendar — upcoming events from MQL5 Calendar API
12. Mini Session Chart — M1 candles for configured session window
