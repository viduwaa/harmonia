extends Node

const SAVE_DIR_PATH: String = "user://save"
const CALIBRATION_FILE_PATH: String = "user://save/audio_calibration.json"
const CALIBRATION_VERSION: int = 1
const BATTLE_DEBUG_CONFIG_FILE_PATH: String = "user://save/battle_debug_config.json"
const BATTLE_DEBUG_CONFIG_VERSION: int = 1
const PROFILE_FILE_PATH: String = "user://save/profile.json"
const PROFILE_VERSION: int = 1
const LEVEL_PROGRESS_FILE_PATH: String = "user://save/level_progress.json"
const LEVEL_PROGRESS_VERSION: int = 1
const NOTE_ATTEMPTS_FILE_PATH: String = "user://save/note_attempts.jsonl"
const GAME_SESSIONS_FILE_PATH: String = "user://save/game_sessions.jsonl"
const NOTE_ATTEMPT_VERSION: int = 1
const GAME_SESSION_VERSION: int = 1
const SAVE_DIAGNOSTICS_FILE_PATH: String = "user://save/save_diagnostics.json"
const SAVE_DIAGNOSTICS_VERSION: int = 1
const STORAGE_ADAPTER_JSON_ID: String = "json_file"
const STORAGE_ADAPTER_SQLITE_ID: String = "sqlite_scaffold"
const STORAGE_ADAPTER_DEFAULT_ID: String = STORAGE_ADAPTER_JSON_ID
const STORAGE_ADAPTER_JSON_SCRIPT_PATH: String = "res://src/gd/persistence/adapters/JsonFileStorageAdapter.gd"
const STORAGE_ADAPTER_SQLITE_SCRIPT_PATH: String = "res://src/gd/persistence/adapters/SqliteStorageAdapter.gd"
const DEFAULT_MAX_NOTE_ATTEMPT_RECORDS: int = 4000
const DEFAULT_MAX_GAME_SESSION_RECORDS: int = 500
const DEFAULT_AUTO_CLEAN_ENABLED: bool = true
const DEFAULT_MAX_RECORD_AGE_DAYS: int = 30
const DEFAULT_MAX_NOTE_ATTEMPT_FILE_MB: float = 8.0
const DEFAULT_MAX_GAME_SESSION_FILE_MB: float = 2.0
const GUARDRAIL_MIN_NOTE_ATTEMPT_RECORDS: int = 500
const GUARDRAIL_MIN_GAME_SESSION_RECORDS: int = 50
const GUARDRAIL_MIN_RECORD_AGE_DAYS: int = 7
const GUARDRAIL_MIN_NOTE_ATTEMPT_FILE_MB: float = 1.0
const GUARDRAIL_MIN_GAME_SESSION_FILE_MB: float = 0.5

var _max_note_attempt_records: int = DEFAULT_MAX_NOTE_ATTEMPT_RECORDS
var _max_game_session_records: int = DEFAULT_MAX_GAME_SESSION_RECORDS
var _auto_clean_enabled: bool = DEFAULT_AUTO_CLEAN_ENABLED
var _max_record_age_days: int = DEFAULT_MAX_RECORD_AGE_DAYS
var _max_note_attempt_file_mb: float = DEFAULT_MAX_NOTE_ATTEMPT_FILE_MB
var _max_game_session_file_mb: float = DEFAULT_MAX_GAME_SESSION_FILE_MB
var _last_cleanup_report: Dictionary = {}
var _storage_adapter_requested_id: String = STORAGE_ADAPTER_DEFAULT_ID
var _storage_adapter_active_id: String = STORAGE_ADAPTER_DEFAULT_ID
var _storage_adapter_unavailable_reason: String = ""
var _storage_adapter: RefCounted


func _ready() -> void:
	_configure_storage_adapter(STORAGE_ADAPTER_DEFAULT_ID, false)
	_load_save_diagnostics_settings()
	_run_auto_cleanup("startup")


func save_audio_calibration(calibration: Dictionary) -> bool:
	if calibration.is_empty():
		return false
	if not _ensure_save_dir():
		return false

	var payload: Dictionary = {
		"version": CALIBRATION_VERSION,
		"audio_calibration": {
			"input_device_name": String(calibration.get("input_device_name", "")),
			"min_signal_db": float(calibration.get("min_signal_db", -58.0)),
			"min_confidence": float(calibration.get("min_confidence", 0.12)),
			"stable_frames_required": int(calibration.get("stable_frames_required", 3))
		}
	}
	return _write_json_document(CALIBRATION_FILE_PATH, payload, "calibration")


func load_audio_calibration() -> Dictionary:
	if not FileAccess.file_exists(CALIBRATION_FILE_PATH):
		return {}
	var root: Dictionary = _read_json_document(CALIBRATION_FILE_PATH, "calibration")
	if root.is_empty():
		return {}
	var calibration: Dictionary = root.get("audio_calibration", {}) as Dictionary
	if calibration.is_empty():
		return {}

	return {
		"input_device_name": String(calibration.get("input_device_name", "")),
		"min_signal_db": float(calibration.get("min_signal_db", -58.0)),
		"min_confidence": float(calibration.get("min_confidence", 0.12)),
		"stable_frames_required": int(calibration.get("stable_frames_required", 3))
	}


func save_battle_debug_config(config: Dictionary) -> bool:
	if config.is_empty():
		return false
	if not _ensure_save_dir():
		return false

	var forced_patterns: Array = []
	var raw_patterns: Variant = config.get("forced_target_patterns", [])
	if raw_patterns is PackedStringArray:
		for pattern: String in raw_patterns:
			forced_patterns.append(String(pattern))
	elif raw_patterns is Array:
		for pattern_value: Variant in raw_patterns:
			forced_patterns.append(String(pattern_value))

	var payload: Dictionary = {
		"version": BATTLE_DEBUG_CONFIG_VERSION,
		"battle_debug_config": {
			"enabled": bool(config.get("enabled", false)),
			"seed": int(config.get("seed", 1337)),
			"forced_target_patterns": forced_patterns
		}
	}
	return _write_json_document(BATTLE_DEBUG_CONFIG_FILE_PATH, payload, "battle debug config")


func load_battle_debug_config() -> Dictionary:
	if not FileAccess.file_exists(BATTLE_DEBUG_CONFIG_FILE_PATH):
		return {}
	var root: Dictionary = _read_json_document(BATTLE_DEBUG_CONFIG_FILE_PATH, "battle debug config")
	if root.is_empty():
		return {}
	var config: Dictionary = root.get("battle_debug_config", {}) as Dictionary
	if config.is_empty():
		return {}

	var forced_patterns: PackedStringArray = PackedStringArray()
	var raw_patterns: Variant = config.get("forced_target_patterns", [])
	if raw_patterns is PackedStringArray:
		forced_patterns = raw_patterns
	elif raw_patterns is Array:
		for pattern_value: Variant in raw_patterns:
			forced_patterns.append(String(pattern_value))

	return {
		"enabled": bool(config.get("enabled", false)),
		"seed": int(config.get("seed", 1337)),
		"forced_target_patterns": forced_patterns
	}


func save_profile(profile: Dictionary) -> bool:
	if profile.is_empty():
		return false
	if not _ensure_save_dir():
		return false

	var payload: Dictionary = {
		"version": PROFILE_VERSION,
		"profile": {
			"xp_total": int(profile.get("xp_total", 0)),
			"battles_played": int(profile.get("battles_played", 0)),
			"wins": int(profile.get("wins", 0)),
			"losses": int(profile.get("losses", 0)),
			"last_result": String(profile.get("last_result", "")),
			"last_session_id": String(profile.get("last_session_id", "")),
			"last_xp_gain": int(profile.get("last_xp_gain", 0)),
			"last_updated_unix_sec": int(profile.get("last_updated_unix_sec", 0))
		}
	}
	return _write_json_document(PROFILE_FILE_PATH, payload, "profile")


func load_profile() -> Dictionary:
	if not FileAccess.file_exists(PROFILE_FILE_PATH):
		return _default_profile()
	var root: Dictionary = _read_json_document(PROFILE_FILE_PATH, "profile")
	if root.is_empty():
		return _default_profile()
	var profile: Dictionary = root.get("profile", {}) as Dictionary
	if profile.is_empty():
		return _default_profile()

	return {
		"xp_total": int(profile.get("xp_total", 0)),
		"battles_played": int(profile.get("battles_played", 0)),
		"wins": int(profile.get("wins", 0)),
		"losses": int(profile.get("losses", 0)),
		"last_result": String(profile.get("last_result", "")),
		"last_session_id": String(profile.get("last_session_id", "")),
		"last_xp_gain": int(profile.get("last_xp_gain", 0)),
		"last_updated_unix_sec": int(profile.get("last_updated_unix_sec", 0))
	}


func save_level_progress(level_progress: Dictionary) -> bool:
	if level_progress.is_empty():
		return false
	if not _ensure_save_dir():
		return false

	var completed_levels: Array = []
	var raw_completed_levels: Variant = level_progress.get("completed_level_ids", [])
	if raw_completed_levels is PackedStringArray:
		for level_id: String in raw_completed_levels:
			completed_levels.append(level_id)
	elif raw_completed_levels is Array:
		for level_value: Variant in raw_completed_levels:
			completed_levels.append(String(level_value))

	var payload: Dictionary = {
		"version": LEVEL_PROGRESS_VERSION,
		"level_progress": {
			"current_level_index": int(level_progress.get("current_level_index", 1)),
			"max_level_reached": int(level_progress.get("max_level_reached", 1)),
			"completed_level_ids": completed_levels,
			"last_result": String(level_progress.get("last_result", "")),
			"last_updated_unix_sec": int(level_progress.get("last_updated_unix_sec", 0))
		}
	}
	return _write_json_document(LEVEL_PROGRESS_FILE_PATH, payload, "level progress")


func load_level_progress() -> Dictionary:
	if not FileAccess.file_exists(LEVEL_PROGRESS_FILE_PATH):
		return _default_level_progress()
	var root: Dictionary = _read_json_document(LEVEL_PROGRESS_FILE_PATH, "level progress")
	if root.is_empty():
		return _default_level_progress()
	var level_progress: Dictionary = root.get("level_progress", {}) as Dictionary
	if level_progress.is_empty():
		return _default_level_progress()

	var completed_levels: PackedStringArray = PackedStringArray()
	var raw_completed_levels: Variant = level_progress.get("completed_level_ids", [])
	if raw_completed_levels is PackedStringArray:
		completed_levels = raw_completed_levels
	elif raw_completed_levels is Array:
		for level_value: Variant in raw_completed_levels:
			completed_levels.append(String(level_value))

	return {
		"current_level_index": int(level_progress.get("current_level_index", 1)),
		"max_level_reached": int(level_progress.get("max_level_reached", 1)),
		"completed_level_ids": completed_levels,
		"last_result": String(level_progress.get("last_result", "")),
		"last_updated_unix_sec": int(level_progress.get("last_updated_unix_sec", 0))
	}


func append_note_attempt(note_attempt: Dictionary) -> bool:
	if note_attempt.is_empty():
		return false

	var record: Dictionary = note_attempt.duplicate(true)
	record["schema"] = "NOTE_ATTEMPT"
	record["written_unix_sec"] = int(Time.get_unix_time_from_system())
	var written: bool = _append_json_line(NOTE_ATTEMPTS_FILE_PATH, record)
	if not written:
		return false
	return true


func append_game_session(game_session: Dictionary) -> bool:
	if game_session.is_empty():
		return false

	var record: Dictionary = game_session.duplicate(true)
	record["schema"] = "GAME_SESSION"
	record["written_unix_sec"] = int(Time.get_unix_time_from_system())
	var written: bool = _append_json_line(GAME_SESSIONS_FILE_PATH, record)
	if not written:
		return false
	_compact_json_logs()
	_run_auto_cleanup("session_commit")
	return true


func load_note_attempt_records(limit: int = 200) -> Array:
	return _read_json_lines(NOTE_ATTEMPTS_FILE_PATH, limit)


func load_game_session_records(limit: int = 100) -> Array:
	return _read_json_lines(GAME_SESSIONS_FILE_PATH, limit)


func compact_json_logs() -> void:
	_compact_json_logs()


func set_log_retention_limits(note_attempt_limit: int, game_session_limit: int, persist: bool = true) -> bool:
	_max_note_attempt_records = max(note_attempt_limit, 100)
	_max_game_session_records = max(game_session_limit, 10)
	if persist:
		return _save_save_diagnostics_settings()
	return true


func get_log_retention_limits() -> Dictionary:
	return {
		"max_note_attempt_records": _max_note_attempt_records,
		"max_game_session_records": _max_game_session_records
	}


func get_retention_guardrail_warnings(note_attempt_limit: int, game_session_limit: int) -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	if note_attempt_limit < GUARDRAIL_MIN_NOTE_ATTEMPT_RECORDS:
		warnings.append(
			"Note attempt retention below %d may hide regressions too quickly during QA." % GUARDRAIL_MIN_NOTE_ATTEMPT_RECORDS
		)
	if game_session_limit < GUARDRAIL_MIN_GAME_SESSION_RECORDS:
		warnings.append(
			"Game session retention below %d may remove useful progression history." % GUARDRAIL_MIN_GAME_SESSION_RECORDS
		)
	return warnings


func set_auto_clean_policy(
	enabled: bool,
	max_record_age_days: int,
	max_note_attempt_file_mb: float,
	max_game_session_file_mb: float,
	persist: bool = true
) -> bool:
	_auto_clean_enabled = enabled
	_max_record_age_days = max(max_record_age_days, 1)
	_max_note_attempt_file_mb = max(max_note_attempt_file_mb, 0.1)
	_max_game_session_file_mb = max(max_game_session_file_mb, 0.1)
	if persist:
		return _save_save_diagnostics_settings()
	return true


func get_auto_clean_policy() -> Dictionary:
	return {
		"enabled": _auto_clean_enabled,
		"max_record_age_days": _max_record_age_days,
		"max_note_attempt_file_mb": _max_note_attempt_file_mb,
		"max_game_session_file_mb": _max_game_session_file_mb
	}


func get_auto_clean_guardrail_warnings(
	enabled: bool,
	max_record_age_days: int,
	max_note_attempt_file_mb: float,
	max_game_session_file_mb: float
) -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	if not enabled:
		return warnings
	if max_record_age_days < GUARDRAIL_MIN_RECORD_AGE_DAYS:
		warnings.append(
			"Record age below %d days may trim active test sessions unexpectedly." % GUARDRAIL_MIN_RECORD_AGE_DAYS
		)
	if max_note_attempt_file_mb < GUARDRAIL_MIN_NOTE_ATTEMPT_FILE_MB:
		warnings.append(
			"Note attempts file cap below %.1f MB may trigger frequent data loss." % GUARDRAIL_MIN_NOTE_ATTEMPT_FILE_MB
		)
	if max_game_session_file_mb < GUARDRAIL_MIN_GAME_SESSION_FILE_MB:
		warnings.append(
			"Game sessions file cap below %.1f MB may drop progression evidence." % GUARDRAIL_MIN_GAME_SESSION_FILE_MB
		)
	return warnings


func get_save_diagnostics_config() -> Dictionary:
	return {
		"retention_limits": get_log_retention_limits(),
		"auto_clean_policy": get_auto_clean_policy(),
		"last_cleanup": _last_cleanup_report.duplicate(true),
		"storage_adapter": get_storage_adapter_info()
	}


func set_storage_adapter(adapter_id: String, persist: bool = true) -> bool:
	_storage_adapter_requested_id = String(adapter_id).strip_edges().to_lower()
	if _storage_adapter_requested_id.is_empty():
		_storage_adapter_requested_id = STORAGE_ADAPTER_DEFAULT_ID
	var configured: bool = _configure_storage_adapter(_storage_adapter_requested_id)
	if persist:
		return _save_save_diagnostics_settings() and configured
	return configured


func get_storage_adapter_info() -> Dictionary:
	return {
		"requested_id": _storage_adapter_requested_id,
		"active_id": _storage_adapter_active_id,
		"available": _storage_adapter != null,
		"unavailable_reason": _storage_adapter_unavailable_reason
	}


func get_storage_adapter_catalog() -> Dictionary:
	var catalog: Dictionary = {}
	var adapter_ids: PackedStringArray = PackedStringArray([
		STORAGE_ADAPTER_JSON_ID,
		STORAGE_ADAPTER_SQLITE_ID
	])
	for adapter_id: String in adapter_ids:
		var adapter: RefCounted = _create_storage_adapter(adapter_id)
		if adapter == null:
			catalog[adapter_id] = {
				"available": false,
				"reason": "Adapter script failed to instantiate."
			}
			continue
		var available: bool = bool(adapter.call("is_available"))
		catalog[adapter_id] = {
			"available": available,
			"reason": "" if available else String(adapter.call("get_unavailable_reason"))
		}
	return catalog


func run_storage_adapter_parity_check() -> Dictionary:
	var json_adapter: RefCounted = _create_storage_adapter(STORAGE_ADAPTER_JSON_ID)
	if json_adapter == null:
		return {
			"ok": false,
			"status": "failed",
			"message": "Failed to instantiate JSON adapter baseline."
		}

	if _storage_adapter == null:
		return {
			"ok": false,
			"status": "failed",
			"message": "No active adapter configured."
		}

	if not bool(_storage_adapter.call("is_available")):
		return {
			"ok": false,
			"status": "skipped",
			"message": "Active adapter unavailable: %s" % String(_storage_adapter.call("get_unavailable_reason"))
		}

	var base_dir: String = "user://save/parity/%d" % int(Time.get_unix_time_from_system())
	var cases: Array = [
		{
			"name": "profile",
			"payload": {
				"version": PROFILE_VERSION,
				"profile": {
					"xp_total": 321,
					"battles_played": 7,
					"wins": 4,
					"losses": 3,
					"last_result": "Win",
					"last_session_id": "parity_session",
					"last_xp_gain": 120,
					"last_updated_unix_sec": 1111111111
				}
			}
		},
		{
			"name": "level_progress",
			"payload": {
				"version": LEVEL_PROGRESS_VERSION,
				"level_progress": {
					"current_level_index": 4,
					"max_level_reached": 4,
					"completed_level_ids": ["L1", "L2", "L3"],
					"last_result": "Lose",
					"last_updated_unix_sec": 1111111111
				}
			}
		}
	]

	var mismatches: Array = []
	for case_variant: Variant in cases:
		if not (case_variant is Dictionary):
			continue
		var case: Dictionary = case_variant as Dictionary
		var case_name: String = String(case.get("name", "case"))
		var payload: Dictionary = case.get("payload", {}) as Dictionary
		var json_path: String = "%s/json_%s.json" % [base_dir, case_name]
		var active_path: String = "%s/active_%s.json" % [base_dir, case_name]

		if not bool(json_adapter.call("write_json_document", json_path, payload, "\t")):
			mismatches.append("JSON adapter failed to write case: %s" % case_name)
			continue
		if not bool(_storage_adapter.call("write_json_document", active_path, payload, "\t")):
			mismatches.append("Active adapter failed to write case: %s" % case_name)
			continue

		var json_read: Dictionary = json_adapter.call("read_json_document", json_path) as Dictionary
		var active_read: Dictionary = _storage_adapter.call("read_json_document", active_path) as Dictionary
		if not bool(json_read.get("ok", false)):
			mismatches.append("JSON adapter failed to read case: %s" % case_name)
			continue
		if not bool(active_read.get("ok", false)):
			mismatches.append("Active adapter failed to read case: %s" % case_name)
			continue
		if (json_read.get("data", {}) as Dictionary) != (active_read.get("data", {}) as Dictionary):
			mismatches.append("Document parity mismatch for case: %s" % case_name)

	var json_lines_path: String = "%s/json_events.jsonl" % base_dir
	var active_lines_path: String = "%s/active_events.jsonl" % base_dir
	var note_payload: Dictionary = {
		"schema": "NOTE_ATTEMPT",
		"version": NOTE_ATTEMPT_VERSION,
		"session_id": "parity_session",
		"turn_index": 1,
		"grade": "Good"
	}
	var session_payload: Dictionary = {
		"schema": "GAME_SESSION",
		"version": GAME_SESSION_VERSION,
		"session_id": "parity_session",
		"result": "Win",
		"turns": 1
	}

	if not bool(json_adapter.call("append_json_line", json_lines_path, note_payload)):
		mismatches.append("JSON adapter failed JSONL append (note payload).")
	if not bool(json_adapter.call("append_json_line", json_lines_path, session_payload)):
		mismatches.append("JSON adapter failed JSONL append (session payload).")
	if not bool(_storage_adapter.call("append_json_line", active_lines_path, note_payload)):
		mismatches.append("Active adapter failed JSONL append (note payload).")
	if not bool(_storage_adapter.call("append_json_line", active_lines_path, session_payload)):
		mismatches.append("Active adapter failed JSONL append (session payload).")

	var json_lines: Array = json_adapter.call("read_json_lines", json_lines_path, 0) as Array
	var active_lines: Array = _storage_adapter.call("read_json_lines", active_lines_path, 0) as Array
	if json_lines != active_lines:
		mismatches.append("JSONL parity mismatch between baseline and active adapter.")

	return {
		"ok": mismatches.is_empty(),
		"status": "passed" if mismatches.is_empty() else "failed",
		"active_adapter_id": _storage_adapter_active_id,
		"mismatch_count": mismatches.size(),
		"mismatches": mismatches,
		"base_dir": base_dir
	}


func run_auto_cleanup() -> Dictionary:
	return _run_auto_cleanup("manual")


func get_log_record_counts() -> Dictionary:
	var note_attempts: Array = _read_json_lines(NOTE_ATTEMPTS_FILE_PATH, 0)
	var game_sessions: Array = _read_json_lines(GAME_SESSIONS_FILE_PATH, 0)
	return {
		"note_attempt_count": note_attempts.size(),
		"game_session_count": game_sessions.size(),
		"max_note_attempt_records": _max_note_attempt_records,
		"max_game_session_records": _max_game_session_records
	}


func clear_battle_logs() -> bool:
	var note_ok: bool = _truncate_file(NOTE_ATTEMPTS_FILE_PATH)
	var session_ok: bool = _truncate_file(GAME_SESSIONS_FILE_PATH)
	return note_ok and session_ok


func export_save_snapshot() -> Dictionary:
	if not _ensure_save_dir():
		return {
			"ok": false,
			"message": "Failed to ensure save directory."
		}

	var save_dir_abs: String = ProjectSettings.globalize_path(SAVE_DIR_PATH)
	var exports_dir_abs: String = save_dir_abs.path_join("exports")
	var exports_dir_error: Error = DirAccess.make_dir_recursive_absolute(exports_dir_abs)
	if exports_dir_error != OK and exports_dir_error != ERR_ALREADY_EXISTS:
		return {
			"ok": false,
			"message": "Failed to create exports directory."
		}

	var now: Dictionary = Time.get_datetime_dict_from_system()
	var stamp: String = "%04d%02d%02d_%02d%02d%02d" % [
		int(now.get("year", 1970)),
		int(now.get("month", 1)),
		int(now.get("day", 1)),
		int(now.get("hour", 0)),
		int(now.get("minute", 0)),
		int(now.get("second", 0))
	]

	var snapshot_dir_abs: String = exports_dir_abs.path_join("snapshot_%s" % stamp)
	var snapshot_dir_error: Error = DirAccess.make_dir_recursive_absolute(snapshot_dir_abs)
	if snapshot_dir_error != OK and snapshot_dir_error != ERR_ALREADY_EXISTS:
		return {
			"ok": false,
			"message": "Failed to create snapshot directory."
		}

	var copied_files: Array = []
	var candidate_files: Dictionary = {
		"audio_calibration.json": CALIBRATION_FILE_PATH,
		"battle_debug_config.json": BATTLE_DEBUG_CONFIG_FILE_PATH,
		"profile.json": PROFILE_FILE_PATH,
		"level_progress.json": LEVEL_PROGRESS_FILE_PATH,
		"save_diagnostics.json": SAVE_DIAGNOSTICS_FILE_PATH,
		"note_attempts.jsonl": NOTE_ATTEMPTS_FILE_PATH,
		"game_sessions.jsonl": GAME_SESSIONS_FILE_PATH
	}

	for file_name: String in candidate_files.keys():
		var source_path: String = String(candidate_files[file_name])
		if not FileAccess.file_exists(source_path):
			continue
		if _copy_file_to_absolute_dir(source_path, snapshot_dir_abs, file_name):
			copied_files.append(file_name)

	var report_file_name: String = "diagnostics_report.json"
	var report_file_abs: String = snapshot_dir_abs.path_join(report_file_name)
	var report_payload: Dictionary = _build_diagnostics_snapshot_report(snapshot_dir_abs, copied_files)
	var report_written: bool = _write_json_file_absolute(report_file_abs, report_payload)
	var migration_readiness: Dictionary = report_payload.get("migration_readiness", {}) as Dictionary
	if report_written:
		copied_files.append(report_file_name)

	var readiness_index_result: Dictionary = _write_migration_readiness_index(exports_dir_abs)
	var readiness_index_file: String = String(readiness_index_result.get("index_file", ""))
	var has_pass: bool = bool(readiness_index_result.get("has_pass", false))
	var has_warn: bool = bool(readiness_index_result.get("has_warn", false))
	var has_fail: bool = bool(readiness_index_result.get("has_fail", false))
	var evidence_coverage_complete: bool = has_pass and has_warn and has_fail

	var message: String = "Exported %d files." % copied_files.size()
	if report_written:
		message = "Exported %d files (including diagnostics report)." % copied_files.size()

	return {
		"ok": true,
		"message": message,
		"export_dir": snapshot_dir_abs,
		"files": copied_files,
		"report_file": report_file_abs if report_written else "",
		"migration_readiness": migration_readiness,
		"readiness_index_file": readiness_index_file,
		"readiness_evidence_coverage_complete": evidence_coverage_complete
	}


func _build_diagnostics_snapshot_report(snapshot_dir_abs: String, copied_files: Array) -> Dictionary:
	var retention_limits: Dictionary = get_log_retention_limits()
	var auto_clean_policy: Dictionary = get_auto_clean_policy()
	var counts: Dictionary = get_log_record_counts()
	var profile: Dictionary = load_profile()
	var level_progress: Dictionary = load_level_progress()
	var latest_game_session: Dictionary = {}
	var latest_note_attempt: Dictionary = {}

	var game_sessions: Array = load_game_session_records(1)
	if not game_sessions.is_empty() and game_sessions[game_sessions.size() - 1] is Dictionary:
		latest_game_session = game_sessions[game_sessions.size() - 1] as Dictionary

	var note_attempts: Array = load_note_attempt_records(1)
	if not note_attempts.is_empty() and note_attempts[note_attempts.size() - 1] is Dictionary:
		latest_note_attempt = note_attempts[note_attempts.size() - 1] as Dictionary

	var retention_warnings: PackedStringArray = get_retention_guardrail_warnings(
		int(retention_limits.get("max_note_attempt_records", DEFAULT_MAX_NOTE_ATTEMPT_RECORDS)),
		int(retention_limits.get("max_game_session_records", DEFAULT_MAX_GAME_SESSION_RECORDS))
	)
	var auto_clean_warnings: PackedStringArray = get_auto_clean_guardrail_warnings(
		bool(auto_clean_policy.get("enabled", DEFAULT_AUTO_CLEAN_ENABLED)),
		int(auto_clean_policy.get("max_record_age_days", DEFAULT_MAX_RECORD_AGE_DAYS)),
		float(auto_clean_policy.get("max_note_attempt_file_mb", DEFAULT_MAX_NOTE_ATTEMPT_FILE_MB)),
		float(auto_clean_policy.get("max_game_session_file_mb", DEFAULT_MAX_GAME_SESSION_FILE_MB))
	)
	var migration_readiness: Dictionary = _build_migration_readiness(
		retention_limits,
		auto_clean_policy,
		counts,
		profile,
		latest_game_session
	)

	return {
		"schema": "SAVE_DIAGNOSTICS_SNAPSHOT",
		"version": 2,
		"generated_unix_sec": int(Time.get_unix_time_from_system()),
		"snapshot_dir": snapshot_dir_abs,
		"copied_files": copied_files,
		"retention_limits": retention_limits,
		"auto_clean_policy": auto_clean_policy,
		"last_cleanup": _last_cleanup_report.duplicate(true),
		"log_counts": counts,
		"profile": profile,
		"level_progress": level_progress,
		"latest_game_session": latest_game_session,
		"latest_note_attempt": latest_note_attempt,
		"guardrail_warnings": {
			"retention": retention_warnings,
			"auto_clean": auto_clean_warnings
		},
		"migration_readiness": migration_readiness
	}


func _build_migration_readiness(
	retention_limits: Dictionary,
	auto_clean_policy: Dictionary,
	counts: Dictionary,
	profile: Dictionary,
	latest_game_session: Dictionary
) -> Dictionary:
	var checks: Array = []
	var fail_reasons: PackedStringArray = PackedStringArray()
	var warn_reasons: PackedStringArray = PackedStringArray()

	var required_files: PackedStringArray = PackedStringArray([
		PROFILE_FILE_PATH,
		LEVEL_PROGRESS_FILE_PATH,
		SAVE_DIAGNOSTICS_FILE_PATH,
		NOTE_ATTEMPTS_FILE_PATH,
		GAME_SESSIONS_FILE_PATH
	])
	var missing_required_files: PackedStringArray = PackedStringArray()
	for required_file_path: String in required_files:
		if not FileAccess.file_exists(required_file_path):
			missing_required_files.append(required_file_path.get_file())
	_append_migration_check(
		checks,
		"required_files_present",
		missing_required_files.is_empty(),
		"fail",
		"All required save files are present." if missing_required_files.is_empty() else "Missing files: %s" % ", ".join(missing_required_files),
		fail_reasons,
		warn_reasons
	)

	var profile_doc_check: Dictionary = _evaluate_document_contract(PROFILE_FILE_PATH, "profile")
	_append_migration_check(
		checks,
		"profile_document_contract",
		bool(profile_doc_check.get("ok", false)),
		"fail",
		String(profile_doc_check.get("detail", "")),
		fail_reasons,
		warn_reasons
	)

	var level_doc_check: Dictionary = _evaluate_document_contract(LEVEL_PROGRESS_FILE_PATH, "level_progress")
	_append_migration_check(
		checks,
		"level_progress_document_contract",
		bool(level_doc_check.get("ok", false)),
		"fail",
		String(level_doc_check.get("detail", "")),
		fail_reasons,
		warn_reasons
	)

	var diagnostics_doc_check: Dictionary = _evaluate_document_contract(SAVE_DIAGNOSTICS_FILE_PATH, "save_diagnostics")
	_append_migration_check(
		checks,
		"save_diagnostics_document_contract",
		bool(diagnostics_doc_check.get("ok", false)),
		"fail",
		String(diagnostics_doc_check.get("detail", "")),
		fail_reasons,
		warn_reasons
	)

	if latest_game_session.is_empty():
		_append_migration_check(
			checks,
			"profile_session_linkage",
			false,
			"warn",
			"No GAME_SESSION records available yet.",
			fail_reasons,
			warn_reasons
		)
	else:
		var profile_session_matches: bool = String(profile.get("last_session_id", "")) == String(latest_game_session.get("session_id", ""))
		var profile_result_matches: bool = String(profile.get("last_result", "")) == String(latest_game_session.get("result", ""))
		_append_migration_check(
			checks,
			"profile_session_linkage",
			profile_session_matches and profile_result_matches,
			"fail",
			"Profile linkage to latest session is valid." if profile_session_matches and profile_result_matches else "Profile last_session_id/last_result do not match latest GAME_SESSION.",
			fail_reasons,
			warn_reasons
		)

		var expected_xp_gain: int = 120 if String(latest_game_session.get("result", "")) == "Win" else 40
		var xp_gain_matches: bool = int(profile.get("last_xp_gain", 0)) == expected_xp_gain
		_append_migration_check(
			checks,
			"profile_xp_rule",
			xp_gain_matches,
			"fail",
			"Profile last_xp_gain follows result rule." if xp_gain_matches else "Profile last_xp_gain does not match result-based XP rule.",
			fail_reasons,
			warn_reasons
		)

		var all_note_attempts: Array = load_note_attempt_records(0)
		var attempts_for_latest_session: int = 0
		for note_attempt_variant: Variant in all_note_attempts:
			if note_attempt_variant is Dictionary:
				var note_attempt: Dictionary = note_attempt_variant as Dictionary
				if String(note_attempt.get("session_id", "")) == String(latest_game_session.get("session_id", "")):
					attempts_for_latest_session += 1
		var session_attempts_match: bool = attempts_for_latest_session == int(latest_game_session.get("note_attempt_count", 0))
		_append_migration_check(
			checks,
			"session_attempt_count_alignment",
			session_attempts_match,
			"fail",
			"Latest session note attempt count aligns with NOTE_ATTEMPT records." if session_attempts_match else "Latest session note_attempt_count does not match NOTE_ATTEMPT records.",
			fail_reasons,
			warn_reasons
		)

	var live_note_count: int = load_note_attempt_records(0).size()
	var live_session_count: int = load_game_session_records(0).size()
	var count_alignment_ok: bool = (
		int(counts.get("note_attempt_count", -1)) == live_note_count
		and int(counts.get("game_session_count", -1)) == live_session_count
	)
	_append_migration_check(
		checks,
		"log_count_alignment",
		count_alignment_ok,
		"fail",
		"Report log counts align with current JSONL files." if count_alignment_ok else "Report log counts differ from current JSONL files.",
		fail_reasons,
		warn_reasons
	)

	var retention_guardrail_warnings: PackedStringArray = get_retention_guardrail_warnings(
		int(retention_limits.get("max_note_attempt_records", DEFAULT_MAX_NOTE_ATTEMPT_RECORDS)),
		int(retention_limits.get("max_game_session_records", DEFAULT_MAX_GAME_SESSION_RECORDS))
	)
	var auto_clean_guardrail_warnings: PackedStringArray = get_auto_clean_guardrail_warnings(
		bool(auto_clean_policy.get("enabled", DEFAULT_AUTO_CLEAN_ENABLED)),
		int(auto_clean_policy.get("max_record_age_days", DEFAULT_MAX_RECORD_AGE_DAYS)),
		float(auto_clean_policy.get("max_note_attempt_file_mb", DEFAULT_MAX_NOTE_ATTEMPT_FILE_MB)),
		float(auto_clean_policy.get("max_game_session_file_mb", DEFAULT_MAX_GAME_SESSION_FILE_MB))
	)
	var policy_warning_text: PackedStringArray = PackedStringArray()
	for item: String in retention_guardrail_warnings:
		policy_warning_text.append(item)
	for item: String in auto_clean_guardrail_warnings:
		policy_warning_text.append(item)
	_append_migration_check(
		checks,
		"policy_guardrail_compliance",
		policy_warning_text.is_empty(),
		"warn",
		"Retention and auto-clean settings are above guardrail thresholds." if policy_warning_text.is_empty() else ", ".join(policy_warning_text),
		fail_reasons,
		warn_reasons
	)

	var passed_checks: int = 0
	var failed_checks: int = 0
	var warned_checks: int = 0
	for check_variant: Variant in checks:
		if not (check_variant is Dictionary):
			continue
		var check: Dictionary = check_variant as Dictionary
		if bool(check.get("ok", false)):
			passed_checks += 1
			continue
		if String(check.get("severity", "")) == "fail":
			failed_checks += 1
		else:
			warned_checks += 1

	var status: String = "pass"
	if failed_checks > 0:
		status = "fail"
	elif warned_checks > 0:
		status = "warn"

	return {
		"status": status,
		"summary": {
			"total_checks": checks.size(),
			"passed_checks": passed_checks,
			"failed_checks": failed_checks,
			"warned_checks": warned_checks
		},
		"checks": checks,
		"fail_reasons": fail_reasons,
		"warn_reasons": warn_reasons
	}


func _write_migration_readiness_index(exports_dir_abs: String) -> Dictionary:
	if exports_dir_abs.is_empty():
		return {}

	var snapshots: Array = _collect_snapshot_dirs(exports_dir_abs)
	if snapshots.is_empty():
		return {
			"index_file": "",
			"has_pass": false,
			"has_warn": false,
			"has_fail": false
		}

	var entries: Array = []
	var has_pass: bool = false
	var has_warn: bool = false
	var has_fail: bool = false
	var latest_pass_snapshot: String = ""
	var latest_warn_snapshot: String = ""
	var latest_fail_snapshot: String = ""

	for snapshot_abs: String in snapshots:
		var entry: Dictionary = _read_snapshot_readiness_entry(snapshot_abs)
		entries.append(entry)
		var status: String = String(entry.get("status", "unknown"))
		if status == "pass":
			has_pass = true
			if latest_pass_snapshot.is_empty():
				latest_pass_snapshot = snapshot_abs
		elif status == "warn":
			has_warn = true
			if latest_warn_snapshot.is_empty():
				latest_warn_snapshot = snapshot_abs
		elif status == "fail":
			has_fail = true
			if latest_fail_snapshot.is_empty():
				latest_fail_snapshot = snapshot_abs

	var status_counts: Dictionary = {
		"pass": 0,
		"warn": 0,
		"fail": 0,
		"unknown": 0
	}
	for entry_variant: Variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var status: String = String((entry_variant as Dictionary).get("status", "unknown"))
		if status_counts.has(status):
			status_counts[status] = int(status_counts.get(status, 0)) + 1
		else:
			status_counts["unknown"] = int(status_counts.get("unknown", 0)) + 1

	var index_payload: Dictionary = {
		"schema": "SAVE_MIGRATION_READINESS_INDEX",
		"version": 1,
		"generated_unix_sec": int(Time.get_unix_time_from_system()),
		"exports_dir": exports_dir_abs,
		"latest_snapshot": snapshots[0],
		"latest_status": String((entries[0] as Dictionary).get("status", "unknown")),
		"status_counts": status_counts,
		"latest_pass_snapshot": latest_pass_snapshot,
		"latest_warn_snapshot": latest_warn_snapshot,
		"latest_fail_snapshot": latest_fail_snapshot,
		"coverage": {
			"has_pass": has_pass,
			"has_warn": has_warn,
			"has_fail": has_fail,
			"has_complete_triplet": has_pass and has_warn and has_fail
		},
		"snapshots": entries
	}

	var index_file_abs: String = exports_dir_abs.path_join("migration_readiness_index.json")
	if not _write_json_file_absolute(index_file_abs, index_payload):
		return {
			"index_file": "",
			"has_pass": has_pass,
			"has_warn": has_warn,
			"has_fail": has_fail
		}

	return {
		"index_file": index_file_abs,
		"has_pass": has_pass,
		"has_warn": has_warn,
		"has_fail": has_fail
	}


func _collect_snapshot_dirs(exports_dir_abs: String) -> Array:
	var snapshot_dirs: Array = []
	var dir: DirAccess = DirAccess.open(exports_dir_abs)
	if dir == null:
		return snapshot_dirs

	dir.list_dir_begin()
	while true:
		var entry_name: String = dir.get_next()
		if entry_name.is_empty():
			break
		if entry_name == "." or entry_name == "..":
			continue
		if not dir.current_is_dir():
			continue
		if not entry_name.begins_with("snapshot_"):
			continue
		snapshot_dirs.append(exports_dir_abs.path_join(entry_name))
	dir.list_dir_end()

	snapshot_dirs.sort_custom(Callable(self, "_snapshot_sort_desc"))
	return snapshot_dirs


func _snapshot_sort_desc(a: String, b: String) -> bool:
	return a > b


func _read_snapshot_readiness_entry(snapshot_abs: String) -> Dictionary:
	var report_file_abs: String = snapshot_abs.path_join("diagnostics_report.json")
	if not FileAccess.file_exists(report_file_abs):
		return {
			"snapshot_dir": snapshot_abs,
			"status": "unknown",
			"summary": {
				"total_checks": 0,
				"passed_checks": 0,
				"failed_checks": 0,
				"warned_checks": 0
			},
			"has_report": false,
			"report_file": ""
		}

	var report_file: FileAccess = FileAccess.open(report_file_abs, FileAccess.READ)
	if report_file == null:
		return {
			"snapshot_dir": snapshot_abs,
			"status": "unknown",
			"summary": {
				"total_checks": 0,
				"passed_checks": 0,
				"failed_checks": 0,
				"warned_checks": 0
			},
			"has_report": false,
			"report_file": report_file_abs
		}

	var json: JSON = JSON.new()
	if json.parse(report_file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {
			"snapshot_dir": snapshot_abs,
			"status": "unknown",
			"summary": {
				"total_checks": 0,
				"passed_checks": 0,
				"failed_checks": 0,
				"warned_checks": 0
			},
			"has_report": false,
			"report_file": report_file_abs
		}

	var report: Dictionary = json.data as Dictionary
	var migration_readiness: Dictionary = report.get("migration_readiness", {}) as Dictionary
	var summary: Dictionary = migration_readiness.get("summary", {}) as Dictionary
	return {
		"snapshot_dir": snapshot_abs,
		"status": String(migration_readiness.get("status", "unknown")),
		"summary": {
			"total_checks": int(summary.get("total_checks", 0)),
			"passed_checks": int(summary.get("passed_checks", 0)),
			"failed_checks": int(summary.get("failed_checks", 0)),
			"warned_checks": int(summary.get("warned_checks", 0))
		},
		"has_report": true,
		"report_file": report_file_abs,
		"generated_unix_sec": int(report.get("generated_unix_sec", 0))
	}


func _evaluate_document_contract(file_path: String, payload_key: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {
			"ok": false,
			"detail": "File is missing: %s" % file_path.get_file()
		}

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"detail": "Failed to open file: %s" % file_path.get_file()
		}

	var raw_text: String = file.get_as_text()
	var json: JSON = JSON.new()
	if json.parse(raw_text) != OK:
		return {
			"ok": false,
			"detail": "JSON parse failed: %s" % file_path.get_file()
		}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {
			"ok": false,
			"detail": "Document root is not a Dictionary: %s" % file_path.get_file()
		}

	var root: Dictionary = json.data as Dictionary
	if not root.has("version"):
		return {
			"ok": false,
			"detail": "Missing version field: %s" % file_path.get_file()
		}
	if not root.has(payload_key):
		return {
			"ok": false,
			"detail": "Missing payload key '%s' in %s" % [payload_key, file_path.get_file()]
		}
	if typeof(root.get(payload_key, {})) != TYPE_DICTIONARY:
		return {
			"ok": false,
			"detail": "Payload key '%s' is not a Dictionary in %s" % [payload_key, file_path.get_file()]
		}

	return {
		"ok": true,
		"detail": "Document contract valid."
	}


func _append_migration_check(
	checks: Array,
	check_name: String,
	ok: bool,
	severity: String,
	detail: String,
	fail_reasons: PackedStringArray,
	warn_reasons: PackedStringArray
) -> void:
	checks.append({
		"name": check_name,
		"ok": ok,
		"severity": severity,
		"detail": detail
	})
	if ok:
		return
	if severity == "fail":
		fail_reasons.append("%s: %s" % [check_name, detail])
	else:
		warn_reasons.append("%s: %s" % [check_name, detail])


func _append_json_line(file_path: String, payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	if not _ensure_save_dir():
		return false
	if _storage_adapter == null:
		_configure_storage_adapter(STORAGE_ADAPTER_DEFAULT_ID)
	if _storage_adapter == null or not _storage_adapter.has_method("append_json_line"):
		push_warning("LocalDataManager: Storage adapter cannot append JSONL: %s" % file_path)
		return false
	var ok: bool = bool(_storage_adapter.call("append_json_line", file_path, payload))
	if not ok:
		push_warning("LocalDataManager: Adapter append JSONL failed: %s" % file_path)
	return ok


func _read_json_lines(file_path: String, limit: int) -> Array:
	if _storage_adapter == null:
		_configure_storage_adapter(STORAGE_ADAPTER_DEFAULT_ID)
	if _storage_adapter == null or not _storage_adapter.has_method("read_json_lines"):
		push_warning("LocalDataManager: Storage adapter cannot read JSONL: %s" % file_path)
		return []
	return _storage_adapter.call("read_json_lines", file_path, limit) as Array


func _compact_json_logs() -> void:
	_compact_json_line_file(NOTE_ATTEMPTS_FILE_PATH, _max_note_attempt_records)
	_compact_json_line_file(GAME_SESSIONS_FILE_PATH, _max_game_session_records)


func _compact_json_line_file(file_path: String, max_records: int) -> void:
	if max_records <= 0:
		return

	var records: Array = _read_json_lines(file_path, 0)
	if records.size() <= max_records:
		return

	var kept_records: Array = records.slice(records.size() - max_records, records.size())
	if not _rewrite_json_line_file(file_path, kept_records):
		push_warning("LocalDataManager: Failed to compact JSONL file: %s" % file_path)


func _save_save_diagnostics_settings() -> bool:
	if not _ensure_save_dir():
		return false

	var payload: Dictionary = {
		"version": SAVE_DIAGNOSTICS_VERSION,
		"save_diagnostics": {
			"max_note_attempt_records": _max_note_attempt_records,
			"max_game_session_records": _max_game_session_records,
			"auto_clean_enabled": _auto_clean_enabled,
			"max_record_age_days": _max_record_age_days,
			"max_note_attempt_file_mb": _max_note_attempt_file_mb,
			"max_game_session_file_mb": _max_game_session_file_mb,
			"storage_adapter_id": _storage_adapter_requested_id
		}
	}
	return _write_json_document(SAVE_DIAGNOSTICS_FILE_PATH, payload, "save diagnostics settings")


func _load_save_diagnostics_settings() -> void:
	if not FileAccess.file_exists(SAVE_DIAGNOSTICS_FILE_PATH):
		return
	var root: Dictionary = _read_json_document(SAVE_DIAGNOSTICS_FILE_PATH, "save diagnostics settings")
	if root.is_empty():
		return
	var diagnostics: Dictionary = root.get("save_diagnostics", {}) as Dictionary
	if diagnostics.is_empty():
		return

	_max_note_attempt_records = max(int(diagnostics.get("max_note_attempt_records", DEFAULT_MAX_NOTE_ATTEMPT_RECORDS)), 100)
	_max_game_session_records = max(int(diagnostics.get("max_game_session_records", DEFAULT_MAX_GAME_SESSION_RECORDS)), 10)
	_auto_clean_enabled = bool(diagnostics.get("auto_clean_enabled", DEFAULT_AUTO_CLEAN_ENABLED))
	_max_record_age_days = max(int(diagnostics.get("max_record_age_days", DEFAULT_MAX_RECORD_AGE_DAYS)), 1)
	_max_note_attempt_file_mb = max(float(diagnostics.get("max_note_attempt_file_mb", DEFAULT_MAX_NOTE_ATTEMPT_FILE_MB)), 0.1)
	_max_game_session_file_mb = max(float(diagnostics.get("max_game_session_file_mb", DEFAULT_MAX_GAME_SESSION_FILE_MB)), 0.1)
	_storage_adapter_requested_id = String(diagnostics.get("storage_adapter_id", STORAGE_ADAPTER_DEFAULT_ID)).strip_edges().to_lower()
	if _storage_adapter_requested_id.is_empty():
		_storage_adapter_requested_id = STORAGE_ADAPTER_DEFAULT_ID
	_configure_storage_adapter(_storage_adapter_requested_id, false)


func _run_auto_cleanup(trigger: String) -> Dictionary:
	var report: Dictionary = {
		"trigger": trigger,
		"ran_unix_sec": int(Time.get_unix_time_from_system()),
		"enabled": _auto_clean_enabled,
		"trimmed_age_note_attempts": 0,
		"trimmed_age_game_sessions": 0,
		"trimmed_size_note_attempts": 0,
		"trimmed_size_game_sessions": 0,
		"final_note_attempt_count": int(get_log_record_counts().get("note_attempt_count", 0)),
		"final_game_session_count": int(get_log_record_counts().get("game_session_count", 0)),
		"status": "skipped"
	}

	if not _auto_clean_enabled:
		_last_cleanup_report = report
		return report

	var trimmed_age_note_attempts: int = _prune_records_older_than(NOTE_ATTEMPTS_FILE_PATH, _max_record_age_days)
	var trimmed_age_game_sessions: int = _prune_records_older_than(GAME_SESSIONS_FILE_PATH, _max_record_age_days)
	var trimmed_size_note_attempts: int = _enforce_file_size_limit(NOTE_ATTEMPTS_FILE_PATH, _max_note_attempt_file_mb)
	var trimmed_size_game_sessions: int = _enforce_file_size_limit(GAME_SESSIONS_FILE_PATH, _max_game_session_file_mb)

	_compact_json_logs()

	var counts: Dictionary = get_log_record_counts()
	report["trimmed_age_note_attempts"] = trimmed_age_note_attempts
	report["trimmed_age_game_sessions"] = trimmed_age_game_sessions
	report["trimmed_size_note_attempts"] = trimmed_size_note_attempts
	report["trimmed_size_game_sessions"] = trimmed_size_game_sessions
	report["final_note_attempt_count"] = int(counts.get("note_attempt_count", 0))
	report["final_game_session_count"] = int(counts.get("game_session_count", 0))
	report["status"] = "completed"

	_last_cleanup_report = report
	return report


func _prune_records_older_than(file_path: String, max_age_days: int) -> int:
	if max_age_days <= 0:
		return 0
	if not FileAccess.file_exists(file_path):
		return 0

	var records: Array = _read_json_lines(file_path, 0)
	if records.is_empty():
		return 0

	var cutoff_unix_sec: int = int(Time.get_unix_time_from_system()) - (max_age_days * 86400)
	var kept_records: Array = []
	var trimmed_count: int = 0
	for record_variant: Variant in records:
		if record_variant is Dictionary:
			var record: Dictionary = record_variant as Dictionary
			var record_unix_sec: int = _extract_record_unix_sec(record)
			if record_unix_sec > 0 and record_unix_sec < cutoff_unix_sec:
				trimmed_count += 1
				continue
			kept_records.append(record)
		else:
			kept_records.append(record_variant)

	if trimmed_count <= 0:
		return 0
	if _rewrite_json_line_file(file_path, kept_records):
		return trimmed_count
	return 0


func _enforce_file_size_limit(file_path: String, max_file_mb: float) -> int:
	if max_file_mb <= 0.0:
		return 0
	if not FileAccess.file_exists(file_path):
		return 0

	var max_bytes: int = int(max_file_mb * 1024.0 * 1024.0)
	var current_bytes: int = _get_file_size_bytes(file_path)
	if current_bytes <= max_bytes:
		return 0

	var records: Array = _read_json_lines(file_path, 0)
	if records.size() <= 1:
		return 0

	var keep_count: int = max(int(floor(float(records.size()) * float(max_bytes) / float(max(current_bytes, 1)))), 1)
	keep_count = min(keep_count, records.size())
	var kept_records: Array = records.slice(records.size() - keep_count, records.size())
	if not _rewrite_json_line_file(file_path, kept_records):
		return 0

	while _get_file_size_bytes(file_path) > max_bytes and keep_count > 1:
		keep_count -= 1
		kept_records = records.slice(records.size() - keep_count, records.size())
		if not _rewrite_json_line_file(file_path, kept_records):
			break

	return records.size() - keep_count


func _get_file_size_bytes(file_path: String) -> int:
	if _storage_adapter == null:
		_configure_storage_adapter(STORAGE_ADAPTER_DEFAULT_ID)
	if _storage_adapter == null or not _storage_adapter.has_method("get_file_size_bytes"):
		return 0
	return int(_storage_adapter.call("get_file_size_bytes", file_path))


func _rewrite_json_line_file(file_path: String, records: Array) -> bool:
	if not _ensure_save_dir():
		return false
	if _storage_adapter == null:
		_configure_storage_adapter(STORAGE_ADAPTER_DEFAULT_ID)
	if _storage_adapter == null or not _storage_adapter.has_method("rewrite_json_lines"):
		push_warning("LocalDataManager: Storage adapter cannot rewrite JSONL: %s" % file_path)
		return false
	return bool(_storage_adapter.call("rewrite_json_lines", file_path, records))


func _extract_record_unix_sec(record: Dictionary) -> int:
	var candidate_keys: PackedStringArray = PackedStringArray([
		"written_unix_sec",
		"created_unix_sec",
		"ended_unix_sec",
		"started_unix_sec",
		"last_updated_unix_sec"
	])
	for key: String in candidate_keys:
		if not record.has(key):
			continue
		var value: int = int(record.get(key, 0))
		if value > 0:
			return value
	return 0


func _truncate_file(file_path: String) -> bool:
	if not _ensure_save_dir():
		return false
	if _storage_adapter == null:
		_configure_storage_adapter(STORAGE_ADAPTER_DEFAULT_ID)
	if _storage_adapter == null or not _storage_adapter.has_method("truncate_file"):
		push_warning("LocalDataManager: Storage adapter cannot truncate file: %s" % file_path)
		return false
	return bool(_storage_adapter.call("truncate_file", file_path))


func _copy_file_to_absolute_dir(source_file_path: String, target_dir_abs: String, file_name: String) -> bool:
	var source_file: FileAccess = FileAccess.open(source_file_path, FileAccess.READ)
	if source_file == null:
		push_warning("LocalDataManager: Failed to open source file for export: %s" % source_file_path)
		return false

	var target_file_path: String = target_dir_abs.path_join(file_name)
	var target_file: FileAccess = FileAccess.open(target_file_path, FileAccess.WRITE)
	if target_file == null:
		push_warning("LocalDataManager: Failed to open target file for export: %s" % target_file_path)
		return false

	var data: PackedByteArray = source_file.get_buffer(source_file.get_length())
	target_file.store_buffer(data)
	target_file.flush()
	return true


func _write_json_file_absolute(file_path: String, payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_warning("LocalDataManager: Failed to write JSON file: %s" % file_path)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	return true


func _write_json_document(file_path: String, payload: Dictionary, label: String) -> bool:
	if payload.is_empty():
		return false
	if _storage_adapter == null:
		_configure_storage_adapter(STORAGE_ADAPTER_DEFAULT_ID)
	if _storage_adapter == null or not _storage_adapter.has_method("write_json_document"):
		push_warning("LocalDataManager: No writable storage adapter for %s." % label)
		return false
	var ok: bool = bool(_storage_adapter.call("write_json_document", file_path, payload, "\t"))
	if not ok:
		push_warning("LocalDataManager: Failed to write %s via adapter '%s'." % [label, _storage_adapter_active_id])
	return ok


func _read_json_document(file_path: String, label: String) -> Dictionary:
	if _storage_adapter == null:
		_configure_storage_adapter(STORAGE_ADAPTER_DEFAULT_ID)
	if _storage_adapter == null or not _storage_adapter.has_method("read_json_document"):
		push_warning("LocalDataManager: No readable storage adapter for %s." % label)
		return {}
	var result: Dictionary = _storage_adapter.call("read_json_document", file_path) as Dictionary
	if result == null:
		push_warning("LocalDataManager: Adapter returned null read result for %s." % label)
		return {}
	if not bool(result.get("ok", false)):
		push_warning("LocalDataManager: Failed to read %s via adapter '%s': %s" % [
			label,
			_storage_adapter_active_id,
			String(result.get("error", "unknown error"))
		])
		return {}
	return result.get("data", {}) as Dictionary


func _configure_storage_adapter(adapter_id: String, emit_warnings: bool = true) -> bool:
	var normalized: String = String(adapter_id).strip_edges().to_lower()
	if normalized.is_empty():
		normalized = STORAGE_ADAPTER_DEFAULT_ID

	var requested_adapter: RefCounted = _create_storage_adapter(normalized)
	if requested_adapter == null:
		if emit_warnings:
			push_warning("LocalDataManager: Unknown adapter '%s', falling back to '%s'." % [normalized, STORAGE_ADAPTER_DEFAULT_ID])
		normalized = STORAGE_ADAPTER_DEFAULT_ID
		requested_adapter = _create_storage_adapter(normalized)

	if requested_adapter == null:
		_storage_adapter = null
		_storage_adapter_active_id = "none"
		_storage_adapter_unavailable_reason = "Failed to instantiate default adapter."
		return false

	if bool(requested_adapter.call("is_available")):
		_storage_adapter = requested_adapter
		_storage_adapter_active_id = String(requested_adapter.call("get_adapter_id"))
		_storage_adapter_unavailable_reason = ""
		return true

	var reason: String = String(requested_adapter.call("get_unavailable_reason"))
	_storage_adapter_unavailable_reason = reason
	if normalized != STORAGE_ADAPTER_DEFAULT_ID:
		if emit_warnings:
			push_warning("LocalDataManager: Adapter '%s' unavailable (%s). Falling back to '%s'." % [
				normalized,
				reason,
				STORAGE_ADAPTER_DEFAULT_ID
			])
		var fallback_adapter: RefCounted = _create_storage_adapter(STORAGE_ADAPTER_DEFAULT_ID)
		if fallback_adapter != null and bool(fallback_adapter.call("is_available")):
			_storage_adapter = fallback_adapter
			_storage_adapter_active_id = String(fallback_adapter.call("get_adapter_id"))
			return true

	_storage_adapter = null
	_storage_adapter_active_id = "none"
	return false


func _create_storage_adapter(adapter_id: String) -> RefCounted:
	var script_path: String = ""
	match adapter_id:
		STORAGE_ADAPTER_JSON_ID:
			script_path = STORAGE_ADAPTER_JSON_SCRIPT_PATH
		STORAGE_ADAPTER_SQLITE_ID:
			script_path = STORAGE_ADAPTER_SQLITE_SCRIPT_PATH
		_:
			return null

	var script: Script = load(script_path)
	if script == null:
		return null
	var instance: Variant = script.new()
	if instance is RefCounted:
		return instance as RefCounted
	return null


func _default_profile() -> Dictionary:
	return {
		"xp_total": 0,
		"battles_played": 0,
		"wins": 0,
		"losses": 0,
		"last_result": "",
		"last_session_id": "",
		"last_xp_gain": 0,
		"last_updated_unix_sec": 0
	}


func _default_level_progress() -> Dictionary:
	return {
		"current_level_index": 1,
		"max_level_reached": 1,
		"completed_level_ids": PackedStringArray(),
		"last_result": "",
		"last_updated_unix_sec": 0
	}


func _ensure_save_dir() -> bool:
	var error: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR_PATH)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_warning("LocalDataManager: Failed to ensure save directory.")
		return false
	return true
