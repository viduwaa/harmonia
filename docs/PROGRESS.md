# Harmonia Progress

Updated: 2026-04-06

## Master Checklist

- [x] Discovery of current repository baseline
- [x] Architecture alignment decisions captured
- [x] Cross-IDE workspace instruction files established
- [x] Cross-IDE agent detection and warning guardrails added
- [x] Hybrid C# + GDScript routing and fallback policy added
- [x] Hybrid architecture and configuration guide documented
- [x] VS Code launch and task debugger configuration added
- [x] Additional VS Code launch profiles (editor-only and direct TestScene) added
- [x] Audio detection reliability patch and on-screen status diagnostics added
- [x] TestScene runtime fallback bootstrap for missing AudioProcessor added
- [x] Autoload-resolution retry and warning-spam suppression fix added
- [x] TestScene high-value controls: input device selector and live calibration settings added
- [x] Audio note stability-frame gating added for cleaner detections
- [x] Optional C# pitch-decision backend scaffold and GDScript fallback bridge added
- [x] C# backend instantiation fixed (ClassDB path) and capture-based YIN analyzer implemented
- [x] YIN implementation rechecked and corrected end-to-end (GDScript bridge + C# service + capture bus)
- [x] Runtime diagnostics and TestScene log panel added for audio backend troubleshooting
- [x] Live UI calibration controls (signal threshold, confidence, stable frames) fully wired to AudioProcessor
- [x] LocalDataManager JSON persistence added for audio calibration and input device selection
- [x] BattleManager vertical slice implemented with turn loop, hit grading, and HP resolution
- [x] Deterministic battle config controls (seed + forced patterns) and JSON persistence wired via LocalDataManager
- [x] NOTE_ATTEMPT and GAME_SESSION payload contracts added to BattleManager event flow
- [x] NOTE_ATTEMPT and GAME_SESSION JSONL persistence wired (BattleManager signals -> LocalDataManager append APIs)
- [x] GameStateManager session lifecycle and progression persistence flow integrated
- [x] JSONL retention compaction and runtime diagnostics summary logging added
- [x] In-UI save diagnostics tools added (stats, compact, reset logs, export snapshot)
- [x] Configurable retention thresholds added (persisted + in-UI controls)
- [x] Auto-clean policies added (time-based + size-based) with startup/session execution
- [x] Startup save diagnostics config and last-cleanup summary logging added
- [x] In-UI auto-clean policy controls added (enable/age/size thresholds)
- [x] Guardrail warning lines added for aggressive retention and auto-clean values
- [x] One-click diagnostics snapshot report export added for QA handoff
- [x] Migration-readiness checklist/status added to diagnostics snapshot export
- [x] TestScene snapshot export now logs migration readiness summary line
- [x] Snapshot exports now auto-generate migration_readiness_index.json across snapshots
- [x] TestScene export log now reports PASS/WARN/FAIL triplet evidence coverage status
- [x] Migration readiness QA evidence note added with canonical PASS/WARN snapshot artifacts
- [x] FAIL snapshot evidence waived with documented risk acceptance
- [x] LocalDataManager storage adapter boundary introduced with pluggable adapter selection
- [x] SQLite storage adapter scaffold added behind LocalDataManager persistence API
- [x] JSON-vs-active adapter write parity utility added for migration testing
- [x] Runtime-dependent SQLite adapter logic added (documents + JSONL + compatibility mirroring)
- [x] TestScene storage adapter selector and parity-check trigger controls added
- [x] C# GlobalClass `SQLite` runtime bridge added using `Microsoft.Data.Sqlite`
- [x] Phase 0 Architecture Contracts implementation
- [x] Phase 1 Core Audio Prototype implementation
- [x] Phase 2 Battle Vertical Slice implementation
- [x] Phase 3 Local JSON Persistence implementation
- [x] Phase 4 Game Flow Integration implementation
- [x] Phase 5 Hardening and migration prep

## Current Status

- Done: SQLite adapter behavior is implemented, and runtime `SQLite` class support is now provided in-project via C# bridge.
- Next: Run and record SQLite parity-check evidence in-editor to confirm class discovery and active adapter usage.
- Blocked: None.

## Immediate Next Actions

1. Run TestScene with SQLite-capable runtime and set adapter to `sqlite_scaffold` in Save Tools.
2. Execute adapter parity check and archive the result summary as migration evidence.
3. Export a save snapshot in SQLite mode and confirm diagnostics/report/index outputs remain consistent.
