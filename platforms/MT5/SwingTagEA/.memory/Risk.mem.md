# Memory: Risk.mqh

## Purpose
Calculates stop loss and take profit prices from Config inputs. Pure arithmetic — no market calls, no trade calls.

## Exports (public symbols)
- `CalcStopLoss(ENUM_ORDER_TYPE, double entryPrice) → double`
- `CalcTakeProfit(ENUM_ORDER_TYPE, double entryPrice) → double`

## Dependencies
- Imports from: Config.mqh
- Imported by: Trade.mqh

## Key Decisions
- 2026-04-05 — Default SL/TP of 2000 points is sized for DAX index — would be ~200 pips on FX; must be recalibrated for any non-index instrument

## Known Issues / TODOs
- [ ] No account-equity-based lot sizing — InpLots is fixed; dynamic sizing would live in Risk.mqh when added

## Last Modified
- Date: 2026-04-05
- Change: Created from inline SL/TP math in ProcessSignal() during v2.0.0 refactor
