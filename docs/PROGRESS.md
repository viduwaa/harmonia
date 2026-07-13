# Harmonia Progress

Updated: 2026-07-12

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
- [x] Profile selection cards now activate existing profiles on click/keyboard confirm
- [x] Profile selection layout now uses a fixed 3-column card grid to prevent overflow
- [x] Profile create/delete dialogs now match the menu theme and main menu has a themed bottom-left switch-profile card
- [x] Practice Mode now routes to a dedicated note-select setup scene and dedicated single-note practice battle scene backed by BattleManager practice mode
- [x] Phase 0 Architecture Contracts implementation
- [x] Phase 1 Core Audio Prototype implementation
- [x] Phase 2 Battle Vertical Slice implementation
- [x] Phase 3 Local JSON Persistence implementation
- [x] Phase 4 Game Flow Integration implementation
- [x] Phase 5 Hardening and migration prep
- Done: SQLite adapter runtime is enabled, migration-readiness checks are adapter-aware, startup adapter rollout is sqlite-first with safe fallback, TestScene one-click QA is manager-owned, strict gate evaluation emits explicit PASS/FAIL reasons, QA gate artifacts are persisted with logged evidence paths, a one-command merge-gate verifier is available in workspace tasks, PR checklist enforcement documents the required gate run, adaptive audio noise-floor diagnostics are visible in TestScene, a non-test PlayerHudScene exposes live player-facing pitch feedback, PlayerFlowScene is the runtime entry with optional debug-tools handoff, PlayerHudScene shows target prompt/hit feedback plus battle/session summary states, PlayerFlowScene includes direct player-loop controls for listening and quick battle reset, both scenes share a consistent card-based style, icon placeholders are wired to named assets with a manifest map, a UI skin placeholder resource and asset swap scaffolding are available for rapid replacement, the exploration loop is active with persisted spawn state, zone-tiered encounter pads route battles by explored area, Guide NPC/Relic interactable stubs are playable, world access is now redundant for debugging (buttons in flow/HUD/TestScene plus F8 shortcut), interactable completion flags persist across sessions, exploration now grants zone-tiered XP/shard rewards with in-world reward tracking UI, PlayerHud now surfaces exploration outcome state, both focus/surge shard sinks are playable, shard sink telemetry is persisted and visible in ExploreWorld/HUD for tuning, surge sink XP is reduced below Level 2 as a guardrail, main menu entry points are live, the standalone `MainMenu.tscn` final-menu draft now includes layered background/menu structure, firefly GPU particles, and AnimationPlayer-driven float/fade polish, Level 01 now runs in ExploreWorld with a random encounter gate and boss unlock flow, pre-battle checkpoints are preserved if players exit during battle, Player now resolves the newly added single `idle` animation correctly while preserving directional walk animations, a standalone microphone calibration menu now provides input-device selection, live mic testing, level/pitch diagnostics, threshold controls, persisted calibration, and main/player-flow entry points, AudioProcessor now separates live pitch candidates from locked gameplay notes using rolling history, dominant-note voting, switch delay, and note release events, multi-profile support is wired through LocalDataManager (profiles.json collection, max 3, active_profile.json selection, legacy single-profile import) with the migration-readiness gate switched to a profiles_document_contract check and parity cases updated, GameStateManager is now per-profile (set_active_profile, load/save by name, avg_accuracy recompute from NOTE_ATTEMPT grades), BattleManager stamps profile_name on NOTE_ATTEMPT and GAME_SESSION payloads, a BootScene launch router sends first-run users to MicrophoneCalibrationScene and returning users to ProfileSelectScene, a ProfileSelectScene provides list/create/select/delete with max-3 and unique-name enforcement, existing profile cards now activate correctly from click or keyboard confirm, the profile selection area now renders as a fixed 3-column grid to prevent loaded-card overflow, the profile create/delete dialogs now match the menu theme, the main menu now includes a themed bottom-left profile switch card with active-profile readout, and Practice Mode now routes through a dedicated note-select screen into a dedicated single-note battle scene backed by BattleManager practice mode while avoiding normal progression rewards, Practice Mode now supports a custom per-note hold timer (1-30 s) selected via SpinBox/preset dropdown in the setup screen and persisted via a new practice_settings.json document in LocalDataManager, and the practice battle scene now shows a live time-left ProgressBar for the running turn, Practice Mode now ships a frequency-match meter in the practice battle scene combining a cents-offset needle (driven by AudioProcessor.pitch_candidate_changed) with a custom-draw frequency-spectrum bar graph (driven by a new spectrum_bins_updated signal on AudioProcessor exposing METER_BAND_COUNT log-spaced bands across +/-1 octave around the target), with a user-selectable Pitch Class vs Exact Octave match mode persisted via practice_settings.json and AudioProcessor exposing note_to_midi / midi_to_hz / set_meter_center_hz helpers for the meter math, and Practice Mode replaces the old instant punish-on-wrong-note grading with a forgiving hold-quality model: BattleManager now accumulates per-turn note samples, computes the mode (most-held) note as the canonical played note, lerp-scales enemy damage by held_acceptable_sec / turn_time (Perfect/Good/Near banding) and only punishes the player at timeout for true misses (scaled by pitch-class distance from the target), the practice scene's octave match selector is now propagated to BattleManager so the gameplay grading rule and the frequency-meter needle agree, instant-hit resolution is preserved for clean sustained correct notes (>= instant_hit_hold_sec of acceptable hold; default lowered from 0.35s to 0.20s so short bursts of correct singing register as hits) so good attempts still feel snappy, the per-frame confidence floor is now synced at runtime from AudioProcessor.get_min_confidence() so the MicrophoneCalibrationScene slider flows into gameplay grading (no more meter-says-in-tune-but-grading-says-Miss disconnection), the timeout Near band was lowered from 0.15 to 0.08 so a ~0.32s burst of correct singing on a 4.0s turn escapes Miss at timeout (was 0.6s), and a live `Played X • target Y • hold N%` coaching label is wired to a new turn_note_live signal so players get grace to find the right pitch without one-shot punishment while searching. The practice instant-hit grading bug (singing the target note perfectly still resolved as a Miss because the resolution divided accept_sec by the full turn limit instead of recognizing the instant-hit trigger directly) has been fixed: instant-hits now grade as Perfect/Good from the locking confidence so a clean held target note damages the enemy as intended; the per-turn accumulator state is now correctly reset between turns (previous turns no longer leak _turn_acceptable_held_sec / _practice_instant_hit_armed into the new turn) so subsequent turns evaluate cleanly; and additional diagnostic logging (PracFrame ...) was added to _accumulate_practice_frame so detection confidence, acceptability and accumulation progress are visible in the editor Output panel during tuning.
- Next: Validate the practice hold-quality model in the Godot editor end-to-end (Main Menu -> Practice Setup -> Practice Battle): confirm the live `Played X • target Y • hold N%` coaching label updates each frame, holding a correct note for ~0.20s now resolves the turn instantly as a Perfect/Good hit (enemy takes damage) instead of a Miss, a ~0.32s burst of correct singing at timeout grades as Near (no longer Miss), and wrong notes during the window update the live indicator without punishing the player; cross-check by reading the `PracFrame ...` diagnostic lines in the Output panel which report detected note, frequency, confidence, target, octave_mode, acceptability, accept_sec, target_sec, and time_left at every note transition (the confidence floor printed there now tracks the AudioProcessor calibration slider rather than the hardcoded MIN_CONFIDENCE_GOOD); then verify the Pitch Class vs Exact Octave selector is obeyed by both the frequency meter and the BattleManager grading (toggle the selector to Exact Octave and confirm a C5 voice against a C4 target no longer grades as a hit); finally tune the difficulty profile constants via set_practice_difficulty for harder levels once the default values feel balanced.
- Blocked: Godot CLI is not available on PATH in this IDE session, so runtime scene validation must be done from the Godot editor; the merge-gate verification script must be run before merging storage-related changes.

## Immediate Next Actions

1. Run `Run SQLite QA Cycle` and then run `harmonia-verify-storage-merge-gate` before merging storage-related changes.
2. FAIL snapshot evidence remains waived-as-pass for this milestone and requires no active work unless release policy changes.
3. Keep migration evidence note updated when new canonical snapshots are intentionally promoted.
