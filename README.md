# Trading-Strategies

A multi-platform algorithmic trading repository — MetaTrader 5 (MQL5) and cTrader (cAlgo / C#) versions of the same strategies, kept in parity where the platforms allow.

Maintained by **Dhruv Sharma**.

## Strategies

| Strategy | Type | Instrument | MT5 | cTrader | Summary |
|----------|------|-----------|:---:|:-------:|---------|
| [SwingTagEA](./platforms/MT5/SwingTagEA) | EA | DAX / GER40 | ✅ | [✅](./platforms/cTrader/SwingTagEA) | 3-bar swing pivot fade — limit orders at swing highs/lows |
| [DeltaFadeEA](./platforms/MT5/DeltaFadeEA) | EA | DAX / GER40 | ✅ | [✅](./platforms/cTrader/DeltaFadeEA) | Contrarian scalper — fades cumulative delta extremes via dynamic Median+MAD thresholds, VWAP slope confirmation |
| [CumulativeDeltaScalper](./platforms/MT5/CumulativeDeltaScalper) | EA | EURUSD M1/M3/M5 | ✅ | [✅](./platforms/cTrader/CumulativeDeltaScalper) | Sniper-mode delta crossover with 5-confirmation gate; session-aware, ATR-based SL/TP |
| [FootprintChartPro](./platforms/MT5/FootprintChartPro) | Indicator | Any | ✅ | [⚠️](./platforms/cTrader/FootprintChartPro) | Order flow visualization — delta cells + 11 analysis panels, 16 themes, imbalance detection |
| [ApexScalper](./platforms/MT5/ApexScalper) | EA | Liquid FX / index futures | ✅ | [⚠️](./platforms/cTrader/ApexScalper) | Microstructure scalper — weighted composite of 8 order-flow signals, regime-adaptive |
| [CandleDataCollector](./platforms/MT5/CandleDataCollector) | Utility | Any | ✅ | [✅](./platforms/cTrader/CandleDataCollector) | CSV writer — OHLC + delta + VWAP per candle |
| [TickDataCollector](./platforms/MT5/TickDataCollector) | Utility | Any | ✅ | [✅](./platforms/cTrader/TickDataCollector) | CSV writer — per-tick records with running candle context |

Legend: ✅ available · ⚠️ WIP scaffold (port in progress)

## Repository Structure

```
platforms/
├── MT5/
│   └── <StrategyName>/
│       ├── CLAUDE.md       AI assistant instructions
│       ├── README.md       Strategy docs, inputs, version history
│       ├── .memory/        Memory files for AI context continuity
│       └── src/            .mq5 / .mqh sources
└── cTrader/
    ├── README.md           Platform conventions + cAlgo cheat sheet
    └── <StrategyName>/
        ├── CLAUDE.md
        ├── README.md       MT5 parity notes, parameter mapping, gaps
        ├── .memory/
        └── src/            .cs source
```

## Working Conventions

- Each strategy is portable — same name, same parameters, same intent across platforms.
- See [`platforms/cTrader/README.md`](./platforms/cTrader/README.md) for the MT5 → cAlgo API cheat sheet.
- Repository workflow + memory-file conventions are documented in [`CLAUDE.md`](./CLAUDE.md).

## Author

**Dhruv Sharma**
[linkedin.com/in/dhruvsharmainfo](https://www.linkedin.com/in/dhruvsharmainfo)
