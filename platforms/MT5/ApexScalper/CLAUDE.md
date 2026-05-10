# ApexScalper — Project Instructions

> Refer first to the parent `D:\Github\mt5-ea\CLAUDE.md` for global repo conventions. This file overrides only where ApexScalper deviates.

## Project Snapshot

**APEX Microstructure Scalper** — MT5 EA combining 8 order-flow signals into a weighted composite scoring engine. ~40 modular `.mqh` files. Imported into the monorepo on 2026-04-29 from `github.com/dhruuvsharma/mt5-microstructure-scalper`.

| Signal | Weight | Method |
|--------|--------|--------|
| Cumulative Tick Delta | 20% | Z-scored delta + acceleration + divergence |
| VPIN | 20% | Volume-bucketed flow toxicity |
| Shallow OBI | 15% | Top-3 OBI + spoof detection |
| Footprint Stacked Imbalance | 15% | Consecutive zero-bid/zero-ask |
| Absorption | 10% | Volume / range at key levels |
| Deep OBI | 10% | Top-10 exponentially weighted |
| Tape Speed | 5% | Trade arrival Z-score |
| HVP Regression Slope | 5% | Weighted lin reg through HVP nodes |

## Layout — Different from Repo Standard

This project does NOT follow the global `src/` flat pattern. Each layer has its own folder:

```
ApexScalper/
├── ApexScalper.mq5           # Entry points only — no logic
├── README.md                 # Full strategy + math docs
├── INSTRUCTIONS.md           # Build order, original session-by-session plan
├── MEMORY.md                 # Detailed file registry (all ~40 modules)
├── .memory/PROJECT_STATE.md  # High-level state for Claude
├── Core/      Defines, Inputs, State, EventBus
├── Utils/     RingBuffer, MathUtils, TimeUtils, StringUtils
├── Data/      Tick/Candle/Footprint/OrderBook builders, VolumeProfile, WindowManager
├── Signals/   8 active signals + SpreadSignal/VPOCSignal (informational) + SignalBase
├── Engine/    ScoringEngine, ConflictFilter, SignalDecayManager, RegimeClassifier, ConfirmationGate
├── Execution/ TradeManager, StopLossEngine, TakeProfitEngine, PositionTracker
├── Risk/      RiskManager, SessionFilter, SpreadFilter, NewsFilter
├── UI/        DashboardPanel, FootprintRenderer, HVPRenderer, OBRenderer, SignalLEDs, PanelTheme
└── Logging/   TradeLogger, SignalLogger, SessionLogger
```

**Why preserved:** the layout mirrors the system architecture (data → signal → scoring → confirmation → execution) and is documented in the project's own README/INSTRUCTIONS. Forcing it into `src/` would break ~40 relative includes for no benefit.

## Where to Find Memory

- **`MEMORY.md`** at project root is the authoritative file registry. Every `.mqh` is listed with its purpose and last-modified date. **Read this first** when locating where logic lives.
- **`.memory/PROJECT_STATE.md`** has the high-level project state (sessions, status, known issues).
- Per-file `.mem.md` files are NOT created for ApexScalper — `MEMORY.md`'s table replaces them. Add per-file memos only if a module gains complex hidden invariants.

## Working Rules — ApexScalper Specific

1. **Locate by table, then read.** Use `MEMORY.md`'s file registry to find the module, read that single file, do the change. Do not glob-explore.
2. **Includes are ordered.** `ApexScalper.mq5` enforces include order (Core → Utils → Data → Signals → Engine → Execution → Risk → UI → Logging). Adding a new module: place its `#include` in the matching block, not at the bottom.
3. **No magic numbers.** All tunables go in `Core/Inputs.mqh`. All compile-time constants in `Core/Defines.mqh` (`#define`, not `static const`).
4. **State is global by design.** Modules read/write `Core/State.mqh` globals (`g_CurrentRegime`, `g_LastComposite`, etc.) — that is the agreed shared bus, not a smell to refactor.
5. **Inter-module signaling via EventBus.** Use `EVENT_NEW_BAR`, `EVENT_REGIME_CHANGED`, `EVENT_KILL_SWITCH_ACTIVATED` — do not direct-call across layers.
6. **Ring buffers only.** No `ArrayResize` in tick paths — use `Utils/RingBuffer.mqh`.
7. **All chart objects are reused.** Create once in `Initialize()`, update via `ObjectSet*` in `Redraw()`. Never `ObjectDelete`+`ObjectCreate` on tick.

## When Updating

- Touched a module → update its row's `Last Modified` date in `MEMORY.md`.
- Added/removed a module → update the file registry and `ApexScalper.mq5` include block.
- Added a session of work → append a `Session Log` entry at the bottom of `MEMORY.md`.
- Update `.memory/PROJECT_STATE.md` with the high-level "what changed" only when the project's status, milestone, or open work shifts.

## Open Work

See `.memory/PROJECT_STATE.md`. Current state: all 13 build sessions complete and stable. Session 14 (live tuning per instrument/session) is pending.
