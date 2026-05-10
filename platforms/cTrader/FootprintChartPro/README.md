# FootprintChartPro (cTrader) — WIP Scaffold

> ⚠️ **Status: Work-In-Progress scaffold.** Minimal viable footprint cell renderer only. **None** of the 11 MT5 analysis panels are ported.

cTrader / cAlgo port of [FootprintChartPro-MT5](../../MT5/FootprintChartPro). cAlgo `[Indicator]` (not a cBot — visualisation only).

## What's Implemented

✅ Per-tick bid bucketing into N-pip price levels per bar
✅ Per-bar render: delta cells (rectangle + signed delta text)
✅ POC (highest-volume bucket) highlighted in distinct colour
✅ Configurable: block size, max bars back, cell width, colours
✅ Basic object lifecycle (cleanup of bars beyond the back-window)

## What's NOT Implemented (yet)

The MT5 sibling exposes 11 analysis panels — none are ported:

❌ DOM (Depth of Market) panel
❌ Volume Profile panel (separate from footprint)
❌ Time & Sales panel
❌ Signal Meter
❌ Chart Analyst panel
❌ RSI panel
❌ MACD panel
❌ Supply & Demand Zones overlay
❌ Economic Calendar panel
❌ Mini Session Chart
❌ 16 theme presets / theme switching
❌ 3-tier imbalance detection (Diagonal / Stacked / Vertical)
❌ Volume inference engine (cAlgo doesn't expose tick volumes anyway)
❌ Real-time MarketDepth streaming for the DOM

## Why a Scaffold?

The MT5 indicator is **3,100+ lines across 6 files**, with a substantial portion devoted to the 11 panels and theme system — it's effectively a UI suite, not a single visualisation. Faithfully porting all panels to cAlgo (where each Indicator is one chart attachment) would mean breaking it into ~10 separate Indicators with shared theme/state plumbing — a multi-day project.

The scaffold gives you the **most useful part** (the footprint cells) and a clear list of what else is missing.

## Volume Classification Caveat

cAlgo doesn't expose trade-side data per tick. Buy vs sell is inferred from uptick/downtick (price went up vs price went down). MT5's "volume inference engine" likely uses the same heuristic plus tick volume magnitude — but cAlgo also doesn't expose per-tick volume. So the cTrader port is a strict **count-based** footprint (each tick counts as 1 unit on its inferred side).

## Install

1. Open cTrader → **Automate** → New Custom Indicator → name it `FootprintChartPro`.
2. Replace generated source with `src/FootprintChartPro.cs`.
3. Build (F6).
4. Drop on a chart, configure colour/block-pip/back-bars, and the footprint cells should render.

## Status

WIP scaffold. Footprint-cell rendering only. Use this as a base if you want to extend toward MT5 parity panel-by-panel.

## Author

**Dhruv Sharma** · [linkedin.com/in/dhruvsharmainfo](https://www.linkedin.com/in/dhruvsharmainfo)
