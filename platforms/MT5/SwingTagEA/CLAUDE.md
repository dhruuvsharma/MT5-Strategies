# SwingTagEA — EA-Specific Claude Instructions

> Also follow all rules in the root /CLAUDE.md.

## Instrument and Timeframe Focus

- **Primary:** DAX (GER40), intraday timeframes M5 to H1.
- SL/TP defaults are **2000 points** — sized for DAX index point values, not FX pips. If porting to FX, both `InpSLPoints` and `InpTPPoints` must be re-calibrated significantly.
- The 13:00–16:00 default session aligns with the **London afternoon / DAX peak liquidity window** in broker server time (typically UTC+2 in summer, UTC+3 in winter for most brokers). Confirm offset per broker.

## Broker / Execution Constraints

- Uses `ORDER_FILLING_FOK` — some brokers on certain accounts require `ORDER_FILLING_RETURN` or `ORDER_FILLING_IOC`. If orders fail to place, try changing the filling mode in `Trade.mqh → InitTradeObjects()`.
- `ORDER_TIME_GTC` is used for pending orders — they persist until manually cancelled or filled. If the broker caps GTC duration, switch to `ORDER_TIME_DAY`.
- The EA uses a single magic number. **Always change `InpMagicNumber`** if running more than one instance on the same account.

## Strategy-Specific Quirks

1. **IsAboveLine is not a trend line** — despite the name, the original implementation always reduced to `midVal > oldVal`. This is preserved verbatim in `Signal.mqh`. Do NOT "fix" this to be a real interpolated trend-line check without explicit user confirmation — it would change the strategy edge.

2. **Bar numbering convention** — `old = bar[3]`, `mid = bar[2]`, `new = bar[1]`. Bar[0] is never touched (live/incomplete). Any edit to `Market.mqh` must respect this.

3. **Signal uses only old vs mid** — bar[1] (new) is used only for drawing the third vertex of the triangle; it plays no role in signal generation. Do not accidentally introduce a dependency on bar[1] in `Signal.mqh`.

4. **Drawing is destructive per bar** — all previous `HighLine_*` and `LowLine_*` objects are deleted at the start of each bar before new ones are drawn. Only the current bar's triangles appear. This is intentional.

5. **Mixed signal = no trade** — when `highGreen != lowGreen`, no order is placed and no message is logged. This is by design.

## Layer Dependency Map

```
Config.mqh
   └── Market.mqh
   └── Risk.mqh
   └── Utils.mqh ──── Market.mqh
   └── Signal.mqh ─── Market.mqh
   └── Trade.mqh ──── Risk.mqh
SwingTagEA.mq5 ─── all of the above
```

No file may import from `Trade.mqh` except `SwingTagEA.mq5`. No file may import from `Signal.mqh` except `SwingTagEA.mq5`.
