# Memory: Config.mqh

## Purpose
All input parameters, enumerations, data structures, constants, and global state for FootprintChartPro.

## Exports (public inputs / globals)
- Enums: ENUM_VP_MODE, ENUM_VP_DISPLAY, ENUM_COLOR_THEME (16 themes)
- Structs: PriceLevel, FootprintBar, DOMLevel, TSTick, VolumeProfileLevel, SupplyDemandZone, EconomicEvent, MiniChartCandle, AnalystSection
- Input groups: Main Panel, Footprint Settings, Volume Inference, Imbalance Detection, DOM Panel, Volume Profile, Time & Sales, Signal Meter, Chart Analyst, Indicators, Supply & Demand Zones, Economic Calendar, Mini Session Chart, Fonts, Theme & Colors, Intensity Colors
- Theme-applied color globals: g_BullCandleColor, g_BearCandleColor, g_BuyTextColor, g_SellTextColor, etc.
- Constants: FP_MAX_BARS (600), FP_MAX_LEVELS (500), FP_MAX_DOM_LEVELS (40), FP_CANVAS_NAME
- Global state: g_fpBars[], g_domLevels[], g_tsTicks[], g_vpLevels[], g_zones[], g_calendarEvents[], g_sessionCandles[], g_analystSections[9], indicator handles (g_hRSI, g_hMACD, etc.), panel redraw flags

## Dependencies
- Imports from: none
- Imported by: Market.mqh, Signal.mqh, Render.mqh, Panels.mqh

## Last Modified
- Date: 2026-04-14
- Change: Initial creation with full input parameters and structures from spec.
