# SwingTagEA (cTrader) — Strategy-Specific Claude Instructions

> Also follow the rules in the root `/CLAUDE.md` and this strategy's MT5 sibling at `platforms/MT5/SwingTagEA/CLAUDE.md` (logic parity is mandatory).

## Parity Rule

This is a **port** of the MT5 SwingTagEA. Any divergence from MT5 logic is a bug unless explicitly justified in `.memory/PROJECT_STATE.md`.

**Do NOT "fix" the IsAboveLine quirk** — see MT5 CLAUDE.md note. The reduction `midVal > oldVal` is preserved verbatim.

## API Translation Notes

| MT5 concept | cTrader equivalent in this port |
|-------------|----------------------------------|
| `iHigh(_Symbol, _Period, n)` | `Bars.HighPrices.Last(n)` |
| `iTime(_Symbol, _Period, n)` | `Bars.OpenTimes.Last(n)` |
| `OnTick` + new-bar guard | `OnBar()` (cAlgo fires on bar open) |
| Magic number filter | `Label` filter on Positions/PendingOrders |
| `_Point` | `Symbol.TickSize` |
| `InpSLPoints * _Point` (price distance) | converted to pips via `PointsToPips()` |
| `g_trade.OrderOpen(...ORDER_TYPE_BUY_LIMIT...)` | `PlaceLimitOrder(TradeType.Buy, ...)` |
| `OBJ_TREND` chart object | `Chart.DrawTrendLine()` |

## Bar Indexing

- `OnBar()` runs after a bar closes. `Bars.Last(1)` is the bar that just closed (== MT5's `bar[1]`).
- Therefore: `old = Last(3)`, `mid = Last(2)`, `new = Last(1)`. **Keep this mapping intact.**

## Constraints

- Single-file class. Logical layers are kept as `#region`-style comment blocks; do **not** split into multiple `.cs` files unless the file grows past ~500 lines.
- Never use `Console.WriteLine`. Always `Print(...)`.
- All new orders must use `TradeLabel` so `HasActivePosition` / `DeletePendingOrdersByType` filtering works.
- If you need file I/O later, change `AccessRights = AccessRights.None` → `AccessRights.FileSystem` in the `[Robot(...)]` attribute.

## Known cTrader-side quirks vs MT5

- Pip-vs-Point: MT5 uses absolute "points"; cAlgo's `PlaceLimitOrder` SL/TP take **pips**. Conversion is `pips = points × TickSize / PipSize`.
- DAX: confirm with the broker whether `PipSize` is 1.0 or 0.1 — if 0.1, default `SLPoints/TPPoints = 2000` translates to 200 pips, which still equals 200 index points (correct).
- `OnBar` is fired once per new bar; there's no need for the `_lastProcessedBarTime` guard, but it's retained as defensive belt-and-braces against duplicate invocations during reconnects.
