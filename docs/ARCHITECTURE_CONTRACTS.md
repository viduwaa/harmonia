# Harmonia Architecture Contracts

Updated: 2026-04-20

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
- Own structured SQLite QA payload generation for health, parity, snapshot, and readiness index results.

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

- note_detected(frequency: float, note_name: String, confidence: float) — compatibility signal for accepted/locked notes
- pitch_candidate_changed(frequency: float, note_name: String, confidence: float)
- note_locked(frequency: float, note_name: String, confidence: float)
- note_released(note_name: String)
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
- Raw pitch candidates can update continuously for calibration UI.
- Gameplay note decisions use rolling candidate history, dominant-note voting, note locking, and release grace after noise-floor/confidence gates.

## Versioning and Compatibility Rules

- Contract versions are explicit in payload/document roots.
- New fields must be additive where possible.
- Breaking schema changes require version bump and migration note.

## Storage Adapter Boundary

- LocalDataManager now supports adapter selection with default JSON file adapter and fallback safety.
- SQLite adapter now implements document and JSONL persistence behind the same LocalDataManager-facing API contract when runtime SQLite support is available.
- SQLite adapter mirrors writes to JSON/JSONL files to preserve compatibility with current file-based diagnostics and exports.
- Parity validation utility is available through LocalDataManager to compare JSON baseline writes against the active adapter.
- LocalDataManager startup adapter rollout is sqlite-first when no persisted adapter preference exists, with safe fallback and explicit reason logging.

## SQLite QA Payload Contract

- Manager entrypoint: `LocalDataManager.run_sqlite_qa_cycle()`.
- Gate evaluator entrypoint: `LocalDataManager.validate_sqlite_qa_cycle_result(result)`.
- Gate artifact persistence entrypoint: `LocalDataManager.persist_sqlite_qa_gate_artifacts(cycle, gate)`.
- Required top-level keys: `ok`, `status`, `message`, `adapter_switch_ok`, `adapter`, `health_before`, `parity`, `snapshot`, `health_after`, `readiness_index`.
- `status` values: `passed` or `failed`.
- `adapter` mirrors `get_storage_adapter_info()` contract (`requested_id`, `active_id`, `available`, `unavailable_reason`).
- `health_before`/`health_after` are produced by `get_sqlite_health_summary()` and include SQLite catalog availability, DB path/exists/size, latest parity/snapshot dir names, and readiness index summary.
- QA gate minimum pass criteria for persistence validation runs:
    - `adapter.active_id == sqlite_scaffold`
    - `parity.ok == true`
    - `snapshot.ok == true`
    - `readiness_index.ok == true`
    - `readiness_index.latest_status != fail`
- `validate_sqlite_qa_cycle_result` returns `ok`, `failed_checks`, `warnings`, and `summary_message` and is the canonical gate output.
- `persist_sqlite_qa_gate_artifacts` writes two evidence artifacts:
    - latest JSON document: `user://save/qa/sqlite_qa_gate_latest.json`
    - append-only history JSONL stream: `user://save/qa/sqlite_qa_gate_history.jsonl`
- TestScene Save Tools should consume manager payloads as the single source for one-click QA reporting.
- Merge gate rule: storage-related changes must pass `validate_sqlite_qa_cycle_result` with `ok == true` and persist gate artifacts successfully before merge.
- Operational enforcement command: run task `harmonia-verify-storage-merge-gate` (or script `scripts/verify-storage-merge-gate.ps1`) before merge for storage-related PRs.

## Remaining Follow-up

- Capture and document parity-check evidence using SQLite adapter mode in runtime environments where SQLite support is enabled.
