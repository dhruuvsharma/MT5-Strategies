# Trading-Strategies Repository — Claude Code Global Instructions

A multi-platform algorithmic trading repo: MetaTrader 5 (MQL5) and cTrader (cAlgo / C#) versions of the same strategies, kept in parity where the platforms allow.

## Repository Structure
```
/
├── CLAUDE.md                       ← Global instructions (this file)
├── README.md
├── .memory/
│   └── REPO_MAP.md                 ← Master index of all strategies × platforms
└── platforms/
    ├── MT5/
    │   └── <StrategyName>/
    │       ├── CLAUDE.md           ← Strategy-specific instructions
    │       ├── README.md
    │       ├── .memory/
    │       │   ├── PROJECT_STATE.md
    │       │   └── <FileName>.mem.md
    │       └── src/
    │           └── <FileName>.mq5 / .mqh
    └── cTrader/
        ├── README.md               ← cTrader conventions + status table
        └── <StrategyName>/
            ├── CLAUDE.md
            ├── README.md
            ├── .memory/
            │   ├── PROJECT_STATE.md
            │   └── <FileName>.mem.md
            └── src/
                └── <StrategyName>.cs
```

A given strategy may exist on one or both platforms — always check `.memory/REPO_MAP.md` for the canonical list.

## Core Workflow — Follow This Every Single Session

### Step 1 — Orient (ALWAYS first, no exceptions)
1. Read `/CLAUDE.md` (this file)
2. Read `/.memory/REPO_MAP.md`
3. Read the platform's `platforms/<MT5|cTrader>/README.md` if working on a port or platform-wide concern
4. Read the strategy-specific `platforms/<platform>/<StrategyName>/CLAUDE.md` if working inside a project
5. Read `<...>/.memory/PROJECT_STATE.md`
6. Scan all `*.mem.md` files in the relevant `.memory/` folder
7. Identify which source files need changes based on memory files
8. Read ONLY those source files — never read unrelated files

### Step 2 — Plan Before Touching Code
- State your understanding of the required change in one paragraph
- List exactly which files will be created / modified / deleted
- If ambiguous, ask ONE clarifying question before proceeding

### Step 3 — Implement (follow Decoupled Architecture below)

### Step 4 — Update Memory (ALWAYS last, no exceptions)
- Update the `.mem.md` for every file touched
- Update `PROJECT_STATE.md` with what changed and why
- Update `REPO_MAP.md` if new files, folders, or platform ports were created

## Code Architecture — Decoupled Pattern

### MT5 (MQL5)
Every EA must be split into these layers, each in its own file:

| Layer    | File           | Responsibility                            |
|----------|----------------|-------------------------------------------|
| Config   | Config.mqh     | All inputs and constants — nothing else   |
| Market   | Market.mqh     | Price data, indicators, symbol info       |
| Signal   | Signal.mqh     | Entry/exit signal logic only              |
| Risk     | Risk.mqh       | Lot sizing, SL/TP calculation             |
| Trade    | Trade.mqh      | Order placement, modification, close      |
| Utils    | Utils.mqh      | Logging, formatting, shared helpers       |
| Core EA  | <EAName>.mq5   | OnInit/OnDeinit/OnTick — orchestration only |

### cTrader (cAlgo / C#)
cTrader projects compile as a single `[Robot]` or `[Indicator]` class. Where complexity warrants, split into multiple `.cs` files inside `src/` using region folders / partial classes — but the same conceptual layers apply:

| Layer    | C# convention                                             |
|----------|-----------------------------------------------------------|
| Config   | `[Parameter]` properties on the Robot class               |
| Market   | private `MarketSnapshot` helper class / region            |
| Signal   | private `SignalEngine` helper / region                    |
| Risk     | private `RiskCalculator` helper / region                  |
| Trade    | inline `ExecuteMarketOrder` / `ModifyPosition` calls      |
| Utils    | static helper class `<StrategyName>Utils`                 |

Rules (both platforms):
- No layer imports from a layer above it (no circular dependencies)
- `OnTick` / event handlers must read like plain English — only function calls, no raw logic
- All magic numbers go in Config (`#define` in MT5, `[Parameter]` or `const` in cTrader), never inline
- Every function does ONE thing
- Max function length: 40 lines — if longer, split it
- All `Print` statements must include strategy + platform prefix: `[StrategyName]` or `[StrategyName-cT]` for cTrader

### MT5-specific
- Use `CTrade` for all order operations
- Use `CPositionInfo`, `COrderInfo` for state queries
- Always check `GetLastError()` after trade operations
- Handle every return value from trade functions

### cTrader-specific
- Use `ExecuteMarketOrder` / `PlaceLimitOrder` for entries
- Iterate `Positions` for state queries; filter by `Label` matching the strategy name
- Always check the `TradeResult.IsSuccessful` return value
- Use `[Parameter(...)]` for inputs; never read globals

## Memory File Format — `<FileName>.mem.md`

```markdown
# Memory: <FileName>.<ext>

## Purpose
One sentence: what this file does.

## Exports (public functions / classes / inputs)
- FunctionName(params) → return type — what it does

## Dependencies
- Imports from: [list of files]
- Imported by: [list of files]

## Key Decisions
- <date> — <decision and reason>

## Known Issues / TODOs
- [ ] <issue>

## Last Modified
- Date: YYYY-MM-DD
- Change: <one-line summary>
```

## Token & Memory Optimization Rules

**Reading:**
- NEVER read a file you don't need to modify
- Use memory files to locate changes — read source only to confirm
- When memory files are sufficient, do not re-read source code

**Writing:**
- Keep memory files under 120 lines — summarize older entries
- If `PROJECT_STATE.md` exceeds 200 lines, archive old entries under `## Archive`
- Prefer targeted edits over full rewrites

**Context Management:**
- At session start, load: CLAUDE.md + REPO_MAP.md + project memory files (~5 files max before reading code)
- Never load all source files at once — lazy-load on demand
- If context is getting large, say so and ask which task to prioritize

## Commit Message Format
```
[<StrategyName>] <type>: <short description>
[<StrategyName>-cT] <type>: <short description>     ← cTrader-only changes
[<StrategyName>-MT5] <type>: <short description>    ← MT5-only changes when both platforms exist
```
type: `feat | fix | refactor | docs | memory | struct | port`

Use `port` for cross-platform porting work.

## MQL5 Code Standards
- Use `CTrade` class for all order operations
- Use `CPositionInfo`, `COrderInfo` for state queries
- Always check `GetLastError()` after trade operations
- Use `#define` for constants in `Config.mqh`
- No magic numbers inline ever
- All `Print`/`Log` must include EA name prefix
- Handle every possible return value from trade functions

## C# / cAlgo Code Standards
- Target the latest cTrader Automate API surface (no deprecated `MarketSeries` — use `Bars`)
- All inputs as `[Parameter(...)]` with explicit `DefaultValue`, `MinValue`, `MaxValue`, `Step` where meaningful
- Use `[Robot(TimeZone = TimeZones.UTC, AccessRights = AccessRights.None)]` (or `FileSystem` if writing CSV)
- Use `Symbol.NormalizeVolumeInUnits(...)` before any market order
- Always inspect `TradeResult.IsSuccessful`; log `TradeResult.Error` on failure
- Tag every order with a strategy-unique `Label` so `Positions` queries can filter cleanly
- All file I/O via `System.IO` with explicit `using` statements (cTrader requires `AccessRights.FileSystem`)
- No `Console.WriteLine` — always `Print(...)` so output appears in cTrader's log panel
