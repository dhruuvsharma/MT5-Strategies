# PROJECT_STATE — ApexScalper

> Lightweight pointer to the authoritative project memory. The full file registry lives in `../MEMORY.md` — start there when locating modules.

## Current Status (2026-04-29)

| Aspect | State |
|--------|-------|
| Build phase | Sessions 1–13 complete and stable |
| Compile | Passes after Session 14 fixes (2026-03-24) |
| Tested | Smoke-tested in MT5 strategy tester. Live-data verification pending for OBI signals (cannot replay from tick history). |
| Open milestone | Session 14 — per-instrument / per-session threshold tuning |
| Repo integration | Imported into mt5-ea monorepo 2026-04-29; folder renamed `mt5-microstructure-scalper` → `ApexScalper` |

## What This Project Does

Microstructure scalper. 8 order-flow signals → weighted composite score on every tick → trades fire only when (|composite| > threshold) AND (≥4 signals agree) AND (top-2 weighted signals don't conflict) AND (all risk/session/spread/regime gates pass). SL anchored to nearest HVP; TP at opposing HVP. Regime classifier (ADX + BB width + VPOC stability) dynamically scales weights.

## Where Things Live

- File-by-file purpose: `../MEMORY.md` § File Registry (single table, ~50 rows)
- Strategy + math: `../README.md`
- Original build plan / session order: `../INSTRUCTIONS.md`
- Project conventions for Claude: `../CLAUDE.md`
- Layered repo conventions: `../../CLAUDE.md`

## Known Issues / TODOs

- [ ] Live tuning per instrument & session (Session 14)
- [ ] OBI signals cannot be replayed from MT5 tick history → backtest understates real-world signal quality. Needs live-data validation.
- [ ] Per-file `.mem.md` files not created — `MEMORY.md` table covers it. Add only if a module develops non-obvious invariants.

## Decision Log

- **2026-04-29** — Folder renamed to `ApexScalper` to match EA name and repo's folder=EAName convention. Internal multi-folder structure (Core/Data/Engine/etc.) preserved over the global `src/` flat pattern because it matches the system's architectural layers and avoids 40+ broken includes.
- **2026-03-24** — Session 14 compile fix: switched RingBuffer API to reference-based `Push`/`Get`, replaced `static const` with `#define` for constants used in array sizing, and changed `SignalBase` helper API to void-with-out-param to satisfy MQL5 template/include constraints.

## Last Modified

2026-04-29 — Imported into mt5-ea, repo memory scaffolding added.
