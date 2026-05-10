# FootprintChartPro (cTrader) — Strategy-Specific Claude Instructions

> **STATUS: WIP scaffold.** Minimal viable delta-cell footprint only. The MT5 sibling has 11 analysis panels, 16 themes, volume inference engine, and 3-tier imbalance detection — none of those are ported.

> Also follow `/CLAUDE.md` and the MT5 sibling at `platforms/MT5/FootprintChartPro/CLAUDE.md`.

## What's Implemented

- cAlgo Indicator (not Robot — visualization only, no trading)
- Per-tick bid bucketing into N-pip price levels per bar
- Per-bar render: delta cells (rectangle + text) coloured by sign + POC highlight

## What's NOT Implemented (vs MT5)

❌ All 11 analysis panels: DOM, Volume Profile, Time & Sales, Signal Meter, Chart Analyst, RSI, MACD, S&D Zones, Calendar, Mini Session Chart, plus the 11th unspecified one
❌ 16 themes / theme switching
❌ Volume inference engine (cAlgo doesn't expose tick volumes anyway)
❌ 3-tier imbalance detection (Diagonal / Stacked / Vertical)
❌ Real-time DOM streaming (would need `Symbol.MarketDepth.Updated` event + custom panel)

## Hard Constraints

- It is an **`[Indicator]`**, not a `[Robot]`. Don't switch base classes — cAlgo Indicators have a different lifecycle (Calculate per bar) and can be attached to charts as overlays without consuming a cBot slot.
- `IsOverlay = true` on the `[Indicator]` attribute ensures the rendering goes onto the price chart, not a separate sub-window.
- Volume classification is uptick/downtick based — cAlgo has no trade-side data per tick.
- Object name prefix `FCP_` — keep it; the cleanup loop relies on it.

## API Notes

- `Chart.DrawRectangle(name, t1, p1, t2, p2, color, thickness, style)` returns `ChartRectangle`. Modify properties to update rather than re-create when the same name exists (cAlgo replaces by name automatically).
- `Chart.DrawText(name, text, time, price, color)` returns `ChartText`. Set `HorizontalAlignment` / `VerticalAlignment` / `FontSize` after creation.
- `Chart.RemoveObject(name)` deletes a named object.
- `Color.FromHex("FF1E90FF")` — first two chars are alpha.

## Future Direction

To approach MT5 parity, the panels would each become a separate cAlgo Indicator (or a single Indicator with multiple sub-windows is not supported — cAlgo limits one indicator to one chart panel). Realistically, you'd ship a handful of the most-used panels (DOM, Volume Profile, Signal Meter) as separate Indicators in this same folder, share a common base class for state/theme management.
