# SwingTagEA (cTrader)

cTrader / cAlgo port of [SwingTagEA-MT5](../../MT5/SwingTagEA).

3-bar swing pivot fade for DAX (GER40):
- **SELL LIMIT** at the mid bar's HIGH when both mid-bar extremes peak above the oldest bar.
- **BUY LIMIT** at the mid bar's LOW when both mid-bar extremes trough below the oldest bar.
- Symmetric SL/TP defaulting to **2000 points** (sized for DAX index ticks).
- Default trading window 13:00–16:00 broker time (London afternoon / DAX peak liquidity).

## Parameter Mapping (MT5 → cTrader)

| MT5 input | cTrader Parameter | Default |
|-----------|-------------------|---------|
| `InpLots` | `Volume (Lots)` | 0.1 |
| `InpSLPoints` | `Stop Loss (Points)` | 2000 |
| `InpTPPoints` | `Take Profit (Points)` | 2000 |
| `InpMagicNumber` | `Order Label` (string instead of ulong) | "SwingTagEA" |
| `InpOrderManagement` | `Smart Order Management` | true |
| `InpUseTradingHours` | `Use Trading Hours` | true |
| `InpTradingStartTime` | `Session Start (HH:MM)` | "13:00" |
| `InpTradingEndTime` | `Session End (HH:MM)` | "16:00" |

## API Differences vs MT5

- **Bar event model.** cAlgo fires `OnBar()` when a new bar opens — replaces MT5's `OnTick` + new-bar guard.
- **Order direction.** cTrader has no separate `BUY_LIMIT` / `SELL_LIMIT` enum; it uses `TradeType.Buy` / `Sell` and the `PlaceLimitOrder` method.
- **SL/TP in pips, not points.** Conversion in `PointsToPips()`: `pips = points × Symbol.TickSize / Symbol.PipSize`. Verify on first run that the SL/TP distance in price terms matches MT5.
- **Identification.** Magic number → `Label` string. All filtering of `Positions` / `PendingOrders` uses `Label == TradeLabel`.

## Install

1. Open cTrader → **Automate**
2. Right-click cBots → **New cBot** → name it `SwingTagEA`
3. Replace generated source with `src/SwingTagEA.cs`
4. **Build (F6)**, drag onto a DAX/GER40 chart, configure parameters, **Start**

## Status

Active. Logic parity with MT5 confirmed by code review. Recommended pre-live: tester run on the same DAX symbol used by the MT5 EA, comparing entry/exit timestamps over a representative session window.

## Author

**Dhruv Sharma** · [linkedin.com/in/dhruvsharmainfo](https://www.linkedin.com/in/dhruvsharmainfo)
