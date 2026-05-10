# Memory: Risk.mqh

## Purpose
Lot sizing and SL/TP price calculation.

## Exports
- CalculatePositionSize() → double — fixed or risk-based lots
- CalculateBuySL(entryPrice) → double
- CalculateBuyTP(entryPrice) → double
- CalculateSellSL(entryPrice) → double
- CalculateSellTP(entryPrice) → double

## Dependencies
- Imports from: Config.mqh
- Imported by: Trade.mqh

## Last Modified
- Date: 2026-04-06
- Change: Initial creation from SlidingWindow.mq5 decoupling
