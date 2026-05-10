# PROJECT_STATE — SwingTagEA

## Current Status
Refactored from original monolithic file. All layers created and verified. Ready for live testing.

## Architecture Decisions

| Decision | Reason |
|----------|--------|
| `CandleData` struct in `Market.mqh` | Eliminates 12-parameter function signature; single pass-by-ref keeps call sites clean |
| Preserve `IsAboveLine` as simple `>` comparison | Original math bug reduces to `testPrice > endPrice`; changing it would alter the strategy edge |
| `CTrade` / `CPositionInfo` / `COrderInfo` | MQL5 best practice; provides built-in error handling and type safety over raw `OrderSend` |
| `ORDER_FILLING_FOK` kept as default | Matches original intent; documented in CLAUDE.md as broker-dependent |
| Symbol filter added to position/order loops | Bug fix — original could match orders from another symbol with same magic on multi-chart setups |
| `ResetLastError()` before every trade call | Bug fix — prevents stale error codes from prior operations masking real errors |
| `NormalizeDouble(InpLots, 2)` added | Bug fix — original passed raw double volume; broker may reject un-normalised lots |
| `#property strict` removed | MQL4-only directive; harmless but incorrect in MQL5 |

## Open TODOs

- [ ] Add account-equity-based lot sizing option (currently fixed lots only)
- [ ] Add spread filter to skip signal during high-spread conditions
- [ ] Confirm `ORDER_FILLING_FOK` vs broker-specific requirement before live use
- [ ] Back-test IsAboveLine fix (real trend-line interpolation) as a separate variant — do NOT modify main source without user approval
- [ ] Add configurable `InpOrderFilling` input if multi-broker support is needed

## File Inventory

| File | Layer | Purpose |
|------|-------|---------|
| src/Config.mqh | Config | All inputs and #define constants |
| src/Market.mqh | Market | CandleData struct + GetCandleData() |
| src/Signal.mqh | Signal | Pivot detection, GetSignal() |
| src/Risk.mqh | Risk | CalcStopLoss(), CalcTakeProfit() |
| src/Trade.mqh | Trade | CTrade wrapper, ProcessSignal() |
| src/Utils.mqh | Utils | IsWithinTradingHours(), drawing helpers |
| src/SwingTagEA.mq5 | Core | OnInit / OnDeinit / OnTick orchestration |

## Archive
_(no archived entries yet)_
