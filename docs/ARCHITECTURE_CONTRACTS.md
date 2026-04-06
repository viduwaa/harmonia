# Harmonia Architecture Contracts

Updated: 2026-04-06

## Purpose

This document is the Phase 0 contract baseline for manager responsibilities, signals, payloads, and hybrid GDScript/C# boundaries.

## Manager Responsibilities

### AudioProcessor (autoload)

Responsibilities:

- Own microphone capture lifecycle and no-feedback capture setup.
- Publish detected note/frequency/confidence and runtime diagnostics.
- Own input device and runtime threshold controls.
- Bridge to C# pitch service when available, with safe fallback behavior.

Must not:

- Apply battle scoring or progression rules.
- Persist game/session state directly.

### BattleManager (autoload)

Responsibilities:

- Own battle turn loop, target generation, grading, HP changes, and win/loss result.
- Emit schema-ready NOTE_ATTEMPT and GAME_SESSION payloads.
- Bind payload persistence to LocalDataManager append APIs.

Must not:

- Perform profile/level progression updates.
- Read/write save files directly.

### LocalDataManager (autoload)

Responsibilities:

- Own save/load APIs and file paths for JSON and JSONL data.
- Own diagnostics settings, retention, compaction, auto-clean, and export snapshots.
- Generate diagnostics_report and migration_readiness outputs.

Must not:

- Drive gameplay flow transitions.
- Decide battle grading/HP logic.

### GameStateManager (autoload)

Responsibilities:

- Own high-level flow state transitions: IDLE, BATTLE_ACTIVE, POST_BATTLE.
- Convert latest battle result into progression/profile changes.
- Persist PROFILE and LEVEL_PROGRESS via LocalDataManager.

Must not:

- Implement pitch detection or battle turn grading.
- Perform low-level file operations.

## Signal Contracts

### AudioProcessor

- note_detected(frequency: float, note_name: String, confidence: float)
- capture_state_changed(is_capturing: bool)
- input_level_changed(level_db: float)
- backend_mode_changed(mode: String)
- diagnostic_logged(message: String)

### BattleManager

- battle_started(player_hp: int, enemy_hp: int)
- turn_started(target_note: String, turn_index: int, time_limit_sec: float)
- turn_resolved(target_note: String, detected_note: String, grade: String, player_hp: int, enemy_hp: int)
- battle_ended(result: String, turns: int)
- battle_debug(message: String)
- note_attempt_payload_ready(payload: Dictionary)
- game_session_payload_ready(payload: Dictionary)

### GameStateManager

- flow_state_changed(previous_state: String, next_state: String)
- progression_updated(profile: Dictionary, level_progress: Dictionary)
- battle_session_committed(result: String, session_id: String, xp_gained: int)

## Payload Contracts

### NOTE_ATTEMPT (version 1)

Required keys:

- schema, version
- attempt_id, session_id, turn_index
- target_pattern, target_note, detected_note
- grade, confidence
- enemy_damage, player_damage
- player_hp_after, enemy_hp_after
- turn_elapsed_sec, timed_out
- deterministic_enabled, deterministic_seed
- reason, created_unix_sec

### GAME_SESSION (version 1)

Required keys:

- schema, version
- session_id, result, turns
- started_unix_sec, ended_unix_sec, duration_sec
- note_attempt_count, timeout_count, average_turn_elapsed_sec
- grade_counts
- player_hp_final, enemy_hp_final
- deterministic_enabled, deterministic_seed, forced_target_patterns

### Save Documents (versioned root)

- profile.json: root keys version + profile
- level_progress.json: root keys version + level_progress
- save_diagnostics.json: root keys version + save_diagnostics

## Hybrid Boundary (GDScript + C#)

- GDScript owns managers, scene wiring, and signal orchestration.
- C# owns compute-heavy pitch analysis service (PitchDecisionService).
- Interop entrypoint remains manager-facing and language-agnostic.
- Payload contracts remain dictionary-based and versioned for migration safety.

## Audio Bus Safety Assumptions

- Capture uses Record bus effect chain with Spectrum + Capture enabled.
- Record bus monitor is effectively silenced through analysis volume control.
- Start/stop cycles restore previous bus state to avoid persistent side effects.
- Detection emits only after noise-floor and confidence gates.

## Versioning and Compatibility Rules

- Contract versions are explicit in payload/document roots.
- New fields must be additive where possible.
- Breaking schema changes require version bump and migration note.

## Storage Adapter Boundary

- LocalDataManager now supports adapter selection with default JSON file adapter and fallback safety.
- SQLite adapter now implements document and JSONL persistence behind the same LocalDataManager-facing API contract when runtime SQLite support is available.
- SQLite adapter mirrors writes to JSON/JSONL files to preserve compatibility with current file-based diagnostics and exports.
- Parity validation utility is available through LocalDataManager to compare JSON baseline writes against the active adapter.

## Remaining Follow-up

- Capture and document parity-check evidence using SQLite adapter mode in runtime environments where SQLite support is enabled.
