# CandleDataCollector (cTrader) — Strategy-Specific Claude Instructions

> Also follow `/CLAUDE.md` and the MT5 sibling at `platforms/MT5/CandleDataCollector/CLAUDE.md`.

## Purpose
Data collection utility — builds tick-aggregated candles and writes them to CSV for Python backtesting. No trade execution.

## CSV Schema (MUST match MT5 sibling exactly)
`DateTime, Open, High, Low, Close, TickDelta, VolumeDelta, Volume, VWAP, Range, TickCount, TicksPerSec, CumDelta, Session`

Don't add or reorder columns without also updating the MT5 EA — Python downstream code is the consumer of both.

## Volume Caveat

**cTrader does not expose per-tick volume**, so each tick is counted as **1 unit** of volume. This matches MT5 Forex behaviour where `tick.volume == 1` per tick when the broker doesn't provide real volume. For futures-symbol parity with MT5 (where `tick.volume` reflects actual contracts), the cTrader port will under-report — document this in the consumer's notes.

## Hard Constraints

- `AccessRights = AccessRights.FileSystem` is required for `StreamWriter`. Don't drop this.
- Output path defaults to `MyDocuments\cAlgoData\` to avoid clashing with cTrader-internal directories.
- Session bucket boundaries (Asian/London/etc.) are **UTC** (matching MT5). Use `Server.Time` only if the broker clock is UTC; otherwise apply `.ToUniversalTime()` first.
- `CultureInfo.InvariantCulture` on every `ToString("Fn")` — non-invariant cultures will produce comma decimal separators and break the CSV.

## Differences from MT5

- File path: MT5 writes to `<Common>\Files\` via `FILE_COMMON`; cTrader writes wherever `OutputFolder` says (default `MyDocuments\cAlgoData`).
- "Volume" semantics: MT5 may have real volume on futures, cTrader does not. See above.
- Time bucket math: MT5 uses integer division; cTrader uses `DateTime.Ticks` integer division.
