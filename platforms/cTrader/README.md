# cTrader Strategies

cAlgo / cTrader Automate ports of the strategies in `platforms/MT5/`.

## Project Layout

Each strategy lives in its own folder with the same `CLAUDE.md` + `README.md` + `.memory/` + `src/` convention as MT5:

```
<StrategyName>/
├── CLAUDE.md          # AI assistant instructions for this project
├── README.md          # Strategy docs, parameters, version history, parity notes vs MT5
├── .memory/           # PROJECT_STATE.md + per-file *.mem.md
└── src/
    └── <StrategyName>.cs
```

cBots and Indicators are C# classes decorated with `[Robot(...)]` or `[Indicator(...)]`.

## How to Install in cTrader

1. Open **cTrader Automate** (formerly cAlgo)
2. Right-click in the **cBots** (or **Indicators**) panel → **Add** → **New cBot/Indicator**
3. Replace the stub source with the contents of `src/<StrategyName>.cs`
4. **Build** (F6) — compilation errors will surface inline
5. Drag the cBot onto a chart, configure parameters, **Start**

Alternatively, copy the `.cs` file into `Documents/cAlgo/Sources/Robots/<StrategyName>/` and open the `.csproj` (when present) directly.

## Parity vs MT5

These ports aim for **behavioural parity** with the MT5 originals — same entry/exit rules, same parameters where the API permits. Each strategy's `README.md` documents:

- **Parameter mapping** — MT5 input → cTrader `[Parameter]`
- **API differences** — places where cAlgo behaves unlike MT5 (e.g. tick volume, timeframe naming, symbol metadata)
- **Known gaps** — anything not yet ported or not portable

## API Cheat Sheet (MT5 → cAlgo)

| MT5 | cAlgo |
|-----|-------|
| `OnInit()` | `OnStart()` |
| `OnDeinit()` | `OnStop()` |
| `OnTick()` | `OnTick()` |
| `iClose(_Symbol, tf, i)` | `Bars.ClosePrices.Last(i)` (or `MarketData.GetBars(tf)`) |
| `SymbolInfoDouble(_Symbol, SYMBOL_BID)` | `Symbol.Bid` |
| `OrderSend / CTrade.Buy / Sell` | `ExecuteMarketOrder(TradeType.Buy/Sell, ...)` |
| `PositionsTotal()` / `CPositionInfo` | `Positions` collection |
| `Print(...)` | `Print(...)` |
| `MathAbs / MathMax / MathMin` | `Math.Abs / Math.Max / Math.Min` |
| `iATR` etc. (handle-based) | `Indicators.AverageTrueRange(...).Result` |
| `TimeCurrent()` | `Server.Time` |
| `_Point` / `_Digits` | `Symbol.PipSize` / `Symbol.Digits` |

## Status

| Strategy | Port Status | Notes |
|----------|-------------|-------|
| [SwingTagEA](./SwingTagEA) | ✅ Active | Single-file cBot, full parity, no UI |
| [DeltaFadeEA](./DeltaFadeEA) | ✅ Active | Single-file cBot, full signal parity, no visual layer |
| [CumulativeDeltaScalper](./CumulativeDeltaScalper) | ✅ Active | Single-file cBot, all 5 sniper confirmations + fast exits, no dashboard |
| [CandleDataCollector](./CandleDataCollector) | ✅ Active | Per-tick volume = 1 (cAlgo limitation) |
| [TickDataCollector](./TickDataCollector) | ✅ Active | Per-tick volume = 1 (cAlgo limitation) |
| [ApexScalper](./ApexScalper) | ⚠️ WIP scaffold | Structure + 8 signal stubs returning 0; no trades placed |
| [FootprintChartPro](./FootprintChartPro) | ⚠️ WIP scaffold | `[Indicator]`. Footprint cells only — 11 panels NOT ported |

See each strategy's `README.md` for parameter mapping, API differences vs MT5, and known gaps.
