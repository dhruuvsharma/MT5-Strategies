# DeltaFadeEA — Project Instructions

## Strategy Summary
Contrarian scalper that fades cumulative tick/volume delta extremes.
Uses dynamic Median + MAD thresholds calculated over a rolling analysis window.
Entry requires **both** tick and volume deltas to exceed thresholds, confirmed by
volume-weighted price line slope (green slope + overbought = SHORT; red slope + oversold = LONG).

## Architecture
| File | Layer | Responsibility |
|------|-------|----------------|
| Config.mqh | Config | All inputs, #defines, magic number |
| Market.mqh | Market | Delta calculation, volume footprint, ticks/sec, analysis windows, median/MAD |
| Signal.mqh | Signal | Dynamic threshold calc, signal evaluation |
| Risk.mqh | Risk | Position sizing, SL/TP calculation |
| Trade.mqh | Trade | CTrade order execution, trailing stop, position queries |
| Utils.mqh | Utils | Time filter, all chart display/draw functions, cleanup |
| DeltaFadeEA.mq5 | Core | OnInit/OnDeinit/OnTick/OnChartEvent orchestration |

## Key Design Decisions
- Original file was "SlidingWindow.mq5" (2160 lines, UTF-16). Renamed to DeltaFadeEA.
- Replaced raw MqlTradeRequest/OrderSend with CTrade/CPositionInfo.
- Magic number centralised as EA_MAGIC in Config.mqh.
- Removed unused DisplayThresholdValues() function.
- Weight constants (0.4/0.4/0.2) moved to #defines in Config.
- All Print statements prefixed with [DeltaFadeEA].
- TrailingStop now preserves existing TP when modifying SL.

## Important Notes
- The EA uses `SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)` — returns spread in points, not price units.
- Hour-filter uses 24 separate bool inputs for MT5 strategy tester compatibility.
- Analysis windows shift oldest data out (FIFO) — index 0 is always newest.
