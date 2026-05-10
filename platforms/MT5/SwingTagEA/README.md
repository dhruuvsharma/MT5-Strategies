# SwingTagEA

## Strategy Overview

SwingTagEA identifies **3-bar swing pivot** structures on the chart and places a limit order to fade the extreme price level. When the middle bar of a 3-bar window peaks above the oldest bar (both high and low), the EA considers it a local swing high and places a SELL LIMIT at that high. The inverse applies for a swing low — a BUY LIMIT is placed at the mid bar's low.

The strategy is a pure price-action, mean-reversion fade. No indicators are used. A visual triangle is drawn connecting the 3 bars' highs (and separately their lows), coloured green when the mid bar is higher, red when lower.

## Recommended Instruments and Timeframes

| Instrument | Timeframe | Notes |
|------------|-----------|-------|
| DAX / GER40 | M5 – H1 | Primary target; SL/TP defaults sized for index points |
| Other indices | M5 – H1 | Adjust InpSLPoints / InpTPPoints for the instrument's point value |
| FX pairs | Not recommended | 2000-point default SL/TP would be enormous on FX |

## Input Parameter Reference

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| InpLots | double | 0.1 | Fixed trade volume in lots |
| InpSLPoints | int | 2000 | Stop loss distance in points from entry |
| InpTPPoints | int | 2000 | Take profit distance in points from entry |
| InpMagicNumber | ulong | 123456 | Unique identifier — change if running multiple EAs on the same account |
| InpOrderManagement | bool | true | When true: skips signal if same-direction position exists; cancels stale pending orders of the same type before placing a new one |
| InpUseTradingHours | bool | true | Enables the session time filter |
| InpTradingStartTime | string | "13:00" | Session open in broker server time (HH:MM) |
| InpTradingEndTime | string | "16:00" | Session close in broker server time (HH:MM) |

## How the EA Works — Step by Step

1. **Bar-change guard** — OnTick stores the open time of bar[0]. If it has not changed since the last tick, execution stops immediately. All logic runs once per completed bar.

2. **Trading hours filter** — if `InpUseTradingHours` is enabled, the current broker time is compared against the configured session window. Ticks outside the window are discarded.

3. **Data collection** — highs, lows, and open times are fetched for bars `[1]`, `[2]`, and `[3]` (all completed). Bar `[3]` is "old", `[2]` is "mid", `[1]` is "new".

4. **Pivot detection** — two boolean flags are computed:
   - `highGreen = midHigh > oldHigh`
   - `lowGreen  = midLow  > oldLow`

5. **Drawing** — a triangle is drawn for the highs (old→mid→new) and a separate triangle for the lows. Each is coloured LimeGreen if its flag is true, IndianRed if false. Previous triangles are deleted before drawing new ones.

6. **Signal evaluation**:
   - `highGreen AND lowGreen` → mid bar is a swing high → **SELL LIMIT at midHigh**
   - `NOT highGreen AND NOT lowGreen` → mid bar is a swing low → **BUY LIMIT at midLow**
   - Mixed → no signal this bar

7. **Order management** (when `InpOrderManagement = true`):
   - If a position in the same direction already exists, the signal is skipped.
   - Any stale pending order of the same type is cancelled.

8. **Order placement** — a limit order is placed at the entry price with SL and TP calculated in points from entry. Volume is normalised before submission.

## Known Limitations

- **Fixed lot sizing** — no account-balance-based position sizing. Manual adjustment required per account.
- **`IsAboveLine` original math** — the original code contained a bug where the trend-line interpolation always simplified to a direct price comparison (`midVal > oldVal`). This behavior is preserved intentionally; the triangle drawing is therefore a visual of the comparison, not a true trend-line intersection test.
- **No spread filter** — during high-spread moments (news, open/close) limit orders may fill at worse prices or not at all.
- **Same SL and TP by default** — symmetric risk/reward of 1:1. Adjust `InpTPPoints` if a different R:R is desired.
- **Broker time dependency** — the session filter uses broker server time, which varies by broker. Verify the offset for your broker before live trading.

## Version History

| Version | Date | Change |
|---------|------|--------|
| v1.0.0 | 2026-04-05 | Original monolithic file (DaxAlgo - StratTagger.mq5) |
| v2.0.0 | 2026-04-05 | Refactored to 6-layer decoupled architecture; fixed bugs (no symbol filter, no ResetLastError, raw OrderSend, #property strict, unnormalised lot); CTrade/CPositionInfo/COrderInfo adopted |
