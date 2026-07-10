# Harmonia Progress

Updated: 2026-07-10

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
- [x] TestScene one-click SQLite health/readiness summary log action added
- [x] LocalDataManager sqlite-first startup adapter rollout with safe fallback logging added
- [x] TestScene one-click SQLite QA cycle action added (health + parity + snapshot)
- [x] LocalDataManager structured SQLite QA payload contract added (single-result health/parity/snapshot/index)
- [x] TestScene SQLite QA flow switched to manager-owned payload path
- [x] LocalDataManager SQLite QA gate evaluator added with failed-check and warning outputs
- [x] TestScene now logs compact SQLite QA gate PASS/FAIL blocks from manager evaluator
- [x] LocalDataManager SQLite QA gate artifact persistence added (latest JSON + append-only history JSONL)
- [x] TestScene now auto-persists SQLite QA gate artifacts and logs artifact file paths
- [x] Workspace merge-gate verification task added (`harmonia-verify-storage-merge-gate`) with artifact/index validation script
- [x] PR template storage checklist added to enforce merge-gate execution on storage-related changes
- [x] AudioProcessor adaptive noise-floor thresholding added and surfaced in TestScene diagnostics labels
- [x] Non-test `PlayerHudScene` added with live note, confidence, and adaptive-threshold feedback from AudioProcessor
- [x] `PlayerFlowScene` added as non-debug runtime entry, embedding PlayerHud and optional debug-tools handoff
- [x] `PlayerHudScene` gameplay states added (target prompt, hit feedback, battle summary, and session summary)
- [x] `PlayerFlowScene` action strip added (start/stop listening and quick battle reset)
- [x] `PlayerHudScene` reorganized into styled sections (live input, battle state, session summary) with improved readability
- [x] `PlayerFlowScene` styled to match HUD card language (header card, action strip card, and unified colors)
- [x] Icon-ready `TextureRect` slots added in PlayerHudScene and PlayerFlowScene cards with placeholder assets
- [x] Dedicated icon asset scaffold added at `src/gd/assets/ui/icons` and scene slots rewired to named icon files
- [x] Icon naming map added via `src/gd/assets/ui/icons/icon_manifest.json` with scene-slot assignments
- [x] UI skin placeholder resource and asset swap scaffolding added (skin applier + placeholder asset contract)
- [x] First exploration-world slice added (movement field, encounter trigger, and return path to PlayerFlowScene)
- [x] LocalDataManager explore-state persistence added (`save_explore_state`/`load_explore_state`) for checkpoint respawn
- [x] Zone-tiered exploration encounters added (Tier I Meadow and Tier II Cavern battle routing)
- [x] Exploration interactable stubs added (Guide NPC talk interaction and Resonance Relic inspect interaction)
- [x] World debug access improved via redundant entry points (PlayerFlow button + HUD button + TestScene button + F8 shortcut)
- [x] Exploration interactable completion flags now persist in explore-state saves (Guide NPC + Resonance Relic)
- [x] Zone-based exploration rewards added (tier XP bonuses + shard drops) with live world overlay feedback
- [x] PlayerHud session summaries now surface exploration consequences (shards + latest reward outcome)
- [x] First shard sink loop added (spend shards for XP) so exploration rewards feed progression spend decisions
- [x] Encounter trigger now saves a pre-battle exploration checkpoint and preserves it when exiting mid-battle
- [x] Second shard sink choice added (focus vs surge payoff profiles)
- [x] Shard sink telemetry now persists and is exposed in ExploreWorld and PlayerHud for tuning
- [x] Surge sink guardrail added (early-level XP reduction to prevent over-conversion)
- [x] Main menu scene added with entry points to test level and player flow
- [x] Level 01 ExploreWorld gate added with random encounter wins and boss unlock flow
- [x] C# GlobalClass `SQLite` runtime bridge added using `Microsoft.Data.Sqlite`
- [x] Migration-readiness required-artifact checks switched to adapter-aware validation
- [x] Phase 0 Architecture Contracts implementation
- [x] Phase 1 Core Audio Prototype implementation
- [x] Phase 2 Battle Vertical Slice implementation
- [x] Phase 3 Local JSON Persistence implementation
- [x] Phase 4 Game Flow Integration implementation
- [x] Phase 5 Hardening and migration prep

## Current Status

- Done: SQLite adapter runtime is enabled, migration-readiness checks are adapter-aware, startup adapter rollout is sqlite-first with safe fallback, TestScene one-click QA is manager-owned, strict gate evaluation emits explicit PASS/FAIL reasons, QA gate artifacts are persisted with logged evidence paths, a one-command merge-gate verifier is available in workspace tasks, PR checklist enforcement documents the required gate run, adaptive audio noise-floor diagnostics are visible in TestScene, a non-test PlayerHudScene exposes live player-facing pitch feedback, PlayerFlowScene is the runtime entry with optional debug-tools handoff, PlayerHudScene shows target prompt/hit feedback plus battle/session summary states, PlayerFlowScene includes direct player-loop controls for listening and quick battle reset, both scenes share a consistent card-based style, icon placeholders are wired to named assets with a manifest map, a UI skin placeholder resource and asset swap scaffolding are available for rapid replacement, the exploration loop is active with persisted spawn state, zone-tiered encounter pads route battles by explored area, Guide NPC/Relic interactable stubs are playable, world access is now redundant for debugging (buttons in flow/HUD/TestScene plus F8 shortcut), interactable completion flags persist across sessions, exploration now grants zone-tiered XP/shard rewards with in-world reward tracking UI, PlayerHud now surfaces exploration outcome state, both focus/surge shard sinks are playable, shard sink telemetry is persisted and visible in ExploreWorld/HUD for tuning, surge sink XP is reduced below Level 2 as a guardrail, main menu entry points are live, the standalone `MainMenu.tscn` final-menu draft now includes layered background/menu structure, firefly GPU particles, and AnimationPlayer-driven float/fade polish, Level 01 now runs in ExploreWorld with a random encounter gate and boss unlock flow, pre-battle checkpoints are preserved if players exit during battle, Player now resolves the newly added single `idle` animation correctly while preserving directional walk animations, a standalone microphone calibration menu now provides input-device selection, live mic testing, level/pitch diagnostics, threshold controls, persisted calibration, and main/player-flow entry points, and AudioProcessor now separates live pitch candidates from locked gameplay notes using rolling history, dominant-note voting, switch delay, and note release events.
- Next: Validate the microphone calibration menu in the Godot editor with at least Default plus one physical/virtual input device, then validate player idle/walk animation behavior and Level 01 boss gate flow in ExploreWorld.
- Blocked: Godot CLI is not available on PATH in this IDE session, so runtime scene validation must be done from the Godot editor.

## Immediate Next Actions

1. Run `Run SQLite QA Cycle` and then run `harmonia-verify-storage-merge-gate` before merging storage-related changes.
2. FAIL snapshot evidence remains waived-as-pass for this milestone and requires no active work unless release policy changes.
3. Keep migration evidence note updated when new canonical snapshots are intentionally promoted.
