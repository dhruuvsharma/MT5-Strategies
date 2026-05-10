# Memory: Signal.mqh

## Purpose
Signal meter calculation (composite 4-factor scoring) and chart analyst report generation (9 sections with 6-factor bias scoring).

## Exports (public functions)
- CheckPOCAcceptance() → bool — price tested POC for N bars within distance
- CalculateSignalMeterValue() → double — composite signal (-100 to +100): MA alignment, ATR regime, POC acceptance, volume bias
- GenerateChartAnalystReport() — fills g_analystSections[9]: Pair Info, Trend+HTF, DOM Analysis, Time & Sales, Order Flow, Volume, Imbalances, Key Levels, Setup+Advisor Summary

## Dependencies
- Imports from: Config.mqh, Market.mqh
- Imported by: Panels.mqh, FootprintChartPro.mq5

## Last Modified
- Date: 2026-04-14
- Change: Initial creation with signal meter and chart analyst report.
