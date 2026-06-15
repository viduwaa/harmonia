extends Control

const EXPLORE_WORLD_SCENE_PATH: String = "res://src/gd/scenes/world/ExploreWorldScene.tscn"

@onready var _frequency_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/FrequencyValue
@onready var _note_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/NoteValue
@onready var _confidence_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/ConfidenceValue
@onready var _input_level_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/InputLevelValue
@onready var _noise_floor_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/NoiseFloorValue
@onready var _effective_threshold_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/EffectiveThresholdValue
@onready var _input_device_selector: OptionButton = $MarginContainer/ScrollContainer/VBoxContainer/InputDeviceSelector
@onready var _min_signal_slider: HSlider = $MarginContainer/ScrollContainer/VBoxContainer/MinSignalSlider
@onready var _min_signal_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/MinSignalValue
@onready var _min_confidence_slider: HSlider = $MarginContainer/ScrollContainer/VBoxContainer/MinConfidenceSlider
@onready var _min_confidence_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/MinConfidenceValue
@onready var _stability_frames_spin_box: SpinBox = $MarginContainer/ScrollContainer/VBoxContainer/StabilityFramesSpinBox
@onready var _backend_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/BackendValue
@onready var _battle_target_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/BattleTargetValue
@onready var _battle_turn_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/BattleTurnValue
@onready var _battle_time_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/BattleTimeValue
@onready var _player_hp_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/PlayerHpValue
@onready var _enemy_hp_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/EnemyHpValue
@onready var _deterministic_mode_checkbox: CheckBox = $MarginContainer/ScrollContainer/VBoxContainer/DeterministicModeCheckBox
@onready var _deterministic_seed_spin_box: SpinBox = $MarginContainer/ScrollContainer/VBoxContainer/DeterministicSeedSpinBox
@onready var _forced_target_queue_edit: LineEdit = $MarginContainer/ScrollContainer/VBoxContainer/ForcedTargetQueueEdit
@onready var _apply_battle_config_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/ApplyBattleConfigButton
@onready var _status_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/StatusValue
@onready var _log_value_label: RichTextLabel = $MarginContainer/ScrollContainer/VBoxContainer/LogValue
@onready var _note_retention_spin_box: SpinBox = $MarginContainer/ScrollContainer/VBoxContainer/NoteRetentionSpinBox
@onready var _session_retention_spin_box: SpinBox = $MarginContainer/ScrollContainer/VBoxContainer/SessionRetentionSpinBox
@onready var _apply_retention_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/ApplyRetentionButton
@onready var _auto_clean_enabled_checkbox: CheckBox = $MarginContainer/ScrollContainer/VBoxContainer/AutoCleanEnabledCheckBox
@onready var _auto_clean_age_days_spin_box: SpinBox = $MarginContainer/ScrollContainer/VBoxContainer/AutoCleanAgeDaysSpinBox
@onready var _auto_clean_note_file_mb_spin_box: SpinBox = $MarginContainer/ScrollContainer/VBoxContainer/AutoCleanNoteFileMbSpinBox
@onready var _auto_clean_session_file_mb_spin_box: SpinBox = $MarginContainer/ScrollContainer/VBoxContainer/AutoCleanSessionFileMbSpinBox
@onready var _apply_auto_clean_policy_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/ApplyAutoCleanPolicyButton
@onready var _storage_adapter_selector: OptionButton = $MarginContainer/ScrollContainer/VBoxContainer/StorageAdapterSelector
@onready var _run_adapter_parity_check_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/RunAdapterParityCheckButton
@onready var _log_sqlite_health_summary_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/LogSqliteHealthSummaryButton
@onready var _run_sqlite_qa_cycle_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/RunSqliteQaCycleButton
@onready var _log_stats_value_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/LogStatsValue
@onready var _refresh_stats_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/RefreshStatsButton
@onready var _compact_logs_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/CompactLogsButton
@onready var _export_saves_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/ExportSavesButton
@onready var _reset_logs_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/ResetLogsButton
@onready var _open_world_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/OpenWorldButton
@onready var _toggle_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/ToggleRecordingButton

var _audio_processor: Node
var _local_data_manager: Node
var _battle_manager: Node
var _game_state_manager: Node
var _syncing_controls: bool = false


func _ready() -> void:
	_audio_processor = _resolve_audio_processor()
	if _audio_processor == null:
		push_error("TestScene: AudioProcessor autoload is missing.")
		_toggle_button.disabled = true
		_input_device_selector.disabled = true
		_status_value_label.text = "AudioProcessor missing"
		return
	_toggle_button.disabled = false
	_input_device_selector.disabled = false
	_local_data_manager = _resolve_local_data_manager()
	_battle_manager = _resolve_battle_manager()
	_game_state_manager = _resolve_game_state_manager()

	_toggle_button.pressed.connect(_on_toggle_button_pressed)
	_audio_processor.connect("note_detected", _on_note_detected)
	_audio_processor.connect("capture_state_changed", _on_capture_state_changed)
	_audio_processor.connect("input_level_changed", _on_input_level_changed)
	_audio_processor.connect("backend_mode_changed", _on_backend_mode_changed)
	_audio_processor.connect("diagnostic_logged", _on_diagnostic_logged)
	_input_device_selector.item_selected.connect(_on_input_device_selected)
	_min_signal_slider.value_changed.connect(_on_min_signal_slider_changed)
	_min_confidence_slider.value_changed.connect(_on_min_confidence_slider_changed)
	_stability_frames_spin_box.value_changed.connect(_on_stability_frames_changed)
	_deterministic_mode_checkbox.toggled.connect(_on_deterministic_mode_toggled)
	_deterministic_seed_spin_box.value_changed.connect(_on_deterministic_seed_changed)
	_apply_battle_config_button.pressed.connect(_on_apply_battle_config_pressed)
	_apply_retention_button.pressed.connect(_on_apply_retention_pressed)
	_apply_auto_clean_policy_button.pressed.connect(_on_apply_auto_clean_policy_pressed)
	_storage_adapter_selector.item_selected.connect(_on_storage_adapter_selected)
	_run_adapter_parity_check_button.pressed.connect(_on_run_adapter_parity_check_pressed)
	_log_sqlite_health_summary_button.pressed.connect(_on_log_sqlite_health_summary_pressed)
	_run_sqlite_qa_cycle_button.pressed.connect(_on_run_sqlite_qa_cycle_pressed)
	_refresh_stats_button.pressed.connect(_on_refresh_stats_pressed)
	_compact_logs_button.pressed.connect(_on_compact_logs_pressed)
	_export_saves_button.pressed.connect(_on_export_saves_pressed)
	_reset_logs_button.pressed.connect(_on_reset_logs_pressed)
	_open_world_button.pressed.connect(_on_open_world_pressed)
	_connect_battle_signals()
	_connect_game_state_signals()

	_sync_button_state()
	_sync_controls_from_processor()
	_sync_battle_config_controls()
	_load_saved_battle_debug_config()
	_load_saved_calibration()
	_sync_retention_controls()
	_sync_auto_clean_policy_controls()
	_sync_storage_adapter_controls()
	_update_labels_from_processor()
	_append_runtime_summary()
	_refresh_save_stats()
	_append_save_diagnostics_config_line()


func _process(_delta: float) -> void:
	if _audio_processor == null:
		_audio_processor = _resolve_audio_processor()
		if _audio_processor == null:
			return
		if not _audio_processor.is_connected("note_detected", _on_note_detected):
			_audio_processor.connect("note_detected", _on_note_detected)
		if not _audio_processor.is_connected("capture_state_changed", _on_capture_state_changed):
			_audio_processor.connect("capture_state_changed", _on_capture_state_changed)
		if not _audio_processor.is_connected("input_level_changed", _on_input_level_changed):
			_audio_processor.connect("input_level_changed", _on_input_level_changed)
		if not _audio_processor.is_connected("backend_mode_changed", _on_backend_mode_changed):
			_audio_processor.connect("backend_mode_changed", _on_backend_mode_changed)
		if not _audio_processor.is_connected("diagnostic_logged", _on_diagnostic_logged):
			_audio_processor.connect("diagnostic_logged", _on_diagnostic_logged)
		_sync_controls_from_processor()
		return
	if _battle_manager == null:
		_battle_manager = _resolve_battle_manager()
		_connect_battle_signals()
		_sync_battle_config_controls()
	if _game_state_manager == null:
		_game_state_manager = _resolve_game_state_manager()
		_connect_game_state_signals()
	_update_labels_from_processor()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F8:
			_on_open_world_pressed()


func _on_toggle_button_pressed() -> void:
	if _audio_processor == null:
		_audio_processor = _resolve_audio_processor()
	if _audio_processor == null:
		_toggle_button.disabled = true
		_status_value_label.text = "AudioProcessor missing"
		return

	if bool(_audio_processor.call("is_capturing")):
		_audio_processor.call("stop_capture")
	else:
		_audio_processor.call("start_capture")
	_toggle_button.disabled = false
	_sync_button_state()


func _on_open_world_pressed() -> void:
	var result: Error = get_tree().change_scene_to_file(EXPLORE_WORLD_SCENE_PATH)
	if result != OK:
		push_warning("TestScene: Failed to open explore world scene.")


func _on_note_detected(frequency: float, note_name: String, confidence: float) -> void:
	_frequency_value_label.text = "%.2f Hz" % frequency if frequency > 0.0 else "-- Hz"
	_note_value_label.text = note_name
	_confidence_value_label.text = "%.2f" % confidence


func _on_capture_state_changed(_is_capturing: bool) -> void:
	_sync_button_state()


func _on_input_level_changed(level_db: float) -> void:
	_input_level_value_label.text = "%.1f dB" % level_db


func _on_backend_mode_changed(mode: String) -> void:
	_backend_value_label.text = mode


func _on_diagnostic_logged(message: String) -> void:
	_log_value_label.append_text("%s\n" % message)
	_log_value_label.scroll_to_line(_log_value_label.get_line_count())


func _on_battle_started(player_hp: int, enemy_hp: int) -> void:
	_player_hp_value_label.text = str(player_hp)
	_enemy_hp_value_label.text = str(enemy_hp)
	_battle_turn_value_label.text = "0"
	_battle_target_value_label.text = "--"
	_battle_time_value_label.text = "0.0s"
	_log_value_label.append_text("[Battle] Start P:%d E:%d\n" % [player_hp, enemy_hp])


func _on_turn_started(target_note: String, turn_index: int, time_limit_sec: float) -> void:
	_battle_target_value_label.text = target_note
	_battle_turn_value_label.text = str(turn_index)
	_battle_time_value_label.text = "%.1fs" % time_limit_sec
	_log_value_label.append_text("[Battle] Turn %d Target:%s Time:%.1fs\n" % [turn_index, target_note, time_limit_sec])


func _on_turn_resolved(target_note: String, detected_note: String, grade: String, player_hp: int, enemy_hp: int) -> void:
	_player_hp_value_label.text = str(player_hp)
	_enemy_hp_value_label.text = str(enemy_hp)
	_log_value_label.append_text(
		"[Battle] %s Target:%s Detected:%s P:%d E:%d\n" % [
			grade,
			target_note,
			detected_note,
			player_hp,
			enemy_hp
		]
	)


func _on_battle_ended(result: String, turns: int) -> void:
	_battle_time_value_label.text = "0.0s"
	_log_value_label.append_text("[Battle] End %s in %d turns\n" % [result, turns])


func _on_flow_state_changed(previous_state: String, next_state: String) -> void:
	_log_value_label.append_text("[Flow] State %s -> %s\n" % [previous_state, next_state])


func _on_progression_updated(profile: Dictionary, level_progress: Dictionary) -> void:
	var xp_total: int = int(profile.get("xp_total", 0))
	var level_index: int = int(level_progress.get("current_level_index", 1))
	_log_value_label.append_text("[Flow] Progress XP:%d NextLevel:L%d\n" % [xp_total, level_index])


func _on_battle_session_committed(result: String, session_id: String, xp_gained: int) -> void:
	_log_value_label.append_text(
		"[Flow] Session committed result:%s xp:+%d session:%s\n" % [
			result,
			xp_gained,
			session_id
		]
	)
	_append_runtime_summary()
	_refresh_save_stats()


func _on_refresh_stats_pressed() -> void:
	_refresh_save_stats()


func _on_apply_retention_pressed() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("set_log_retention_limits"):
		return

	var note_limit: int = int(_note_retention_spin_box.value)
	var session_limit: int = int(_session_retention_spin_box.value)
	var retention_warnings: PackedStringArray = PackedStringArray()
	if _local_data_manager.has_method("get_retention_guardrail_warnings"):
		retention_warnings = _to_string_array(
			_local_data_manager.call("get_retention_guardrail_warnings", note_limit, session_limit)
		)
	_append_guardrail_warnings("Retention", retention_warnings)

	var saved: bool = bool(_local_data_manager.call("set_log_retention_limits", note_limit, session_limit, true))
	if _local_data_manager.has_method("compact_json_logs"):
		_local_data_manager.call("compact_json_logs")
	_log_value_label.append_text(
		"[Save] Retention updated note:%d sessions:%d saved:%s warnings:%d\n" % [
			note_limit,
			session_limit,
			str(saved),
			retention_warnings.size()
		]
	)
	_refresh_save_stats()
	_append_save_diagnostics_config_line()


func _on_apply_auto_clean_policy_pressed() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("set_auto_clean_policy"):
		return

	var enabled: bool = _auto_clean_enabled_checkbox.button_pressed
	var age_days: int = int(_auto_clean_age_days_spin_box.value)
	var note_mb: float = float(_auto_clean_note_file_mb_spin_box.value)
	var session_mb: float = float(_auto_clean_session_file_mb_spin_box.value)
	var policy_warnings: PackedStringArray = PackedStringArray()
	if _local_data_manager.has_method("get_auto_clean_guardrail_warnings"):
		policy_warnings = _to_string_array(
			_local_data_manager.call("get_auto_clean_guardrail_warnings", enabled, age_days, note_mb, session_mb)
		)
	_append_guardrail_warnings("AutoClean", policy_warnings)

	var saved: bool = bool(_local_data_manager.call("set_auto_clean_policy", enabled, age_days, note_mb, session_mb, true))

	var cleanup_status: String = "skipped"
	if _local_data_manager.has_method("run_auto_cleanup"):
		var cleanup_report: Dictionary = _local_data_manager.call("run_auto_cleanup") as Dictionary
		cleanup_status = String(cleanup_report.get("status", "unknown"))

	_log_value_label.append_text(
		"[Save] Auto-clean policy updated enabled:%s age_days:%d size_mb(n:%.1f s:%.1f) saved:%s cleanup:%s warnings:%d\n" % [
			str(enabled),
			age_days,
			note_mb,
			session_mb,
			str(saved),
			cleanup_status,
			policy_warnings.size()
		]
	)
	_refresh_save_stats()
	_append_save_diagnostics_config_line()


func _on_compact_logs_pressed() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("compact_json_logs"):
		return

	_local_data_manager.call("compact_json_logs")
	_log_value_label.append_text("[Save] Manual compaction completed\n")
	_refresh_save_stats()


func _on_storage_adapter_selected(index: int) -> void:
	if _syncing_controls or _local_data_manager == null:
		return
	if not _local_data_manager.has_method("set_storage_adapter"):
		return
	if index < 0 or index >= _storage_adapter_selector.item_count:
		return

	var adapter_id: String = String(_storage_adapter_selector.get_item_metadata(index))
	if adapter_id.is_empty():
		return
	var availability: Dictionary = _get_storage_adapter_availability(adapter_id)
	if not bool(availability.get("available", false)):
		_log_value_label.append_text(
			"[Save] Storage adapter '%s' unavailable: %s\n" % [
				adapter_id,
				String(availability.get("reason", "Unknown reason."))
			]
		)
		_sync_storage_adapter_controls()
		return

	var saved: bool = bool(_local_data_manager.call("set_storage_adapter", adapter_id, true))
	var adapter_info: Dictionary = {}
	if _local_data_manager.has_method("get_storage_adapter_info"):
		adapter_info = _local_data_manager.call("get_storage_adapter_info") as Dictionary

	_log_value_label.append_text(
		"[Save] Storage adapter requested:%s active:%s saved:%s\n" % [
			adapter_id,
			String(adapter_info.get("active_id", "unknown")),
			str(saved)
		]
	)
	_sync_storage_adapter_controls()
	_append_save_diagnostics_config_line()


func _on_run_adapter_parity_check_pressed() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("run_storage_adapter_parity_check"):
		return

	var parity: Dictionary = _local_data_manager.call("run_storage_adapter_parity_check") as Dictionary
	var status: String = String(parity.get("status", "unknown"))
	var message: String = String(parity.get("message", ""))
	_log_value_label.append_text(
		"[Save] Adapter parity status:%s mismatches:%d adapter:%s\n" % [
			status,
			int(parity.get("mismatch_count", 0)),
			String(parity.get("active_adapter_id", "unknown"))
		]
	)
	if not message.is_empty():
		_log_value_label.append_text("[Save] Adapter parity message:%s\n" % message)

	var mismatches: Array = parity.get("mismatches", []) as Array
	for mismatch_variant: Variant in mismatches:
		_log_value_label.append_text("[Save] Adapter parity mismatch:%s\n" % String(mismatch_variant))

	var base_dir: String = String(parity.get("base_dir", ""))
	if not base_dir.is_empty():
		_log_value_label.append_text("[Save] Adapter parity artifacts:%s\n" % base_dir)


func _on_log_sqlite_health_summary_pressed() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("get_sqlite_health_summary"):
		_log_value_label.append_text("[SQLiteHealth] LocalDataManager does not expose get_sqlite_health_summary\n")
		return
	var summary: Dictionary = _local_data_manager.call("get_sqlite_health_summary") as Dictionary
	var lines: PackedStringArray = _build_sqlite_health_summary_lines(summary)
	for line: String in lines:
		_log_value_label.append_text("%s\n" % line)


func _on_run_sqlite_qa_cycle_pressed() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("run_sqlite_qa_cycle"):
		_log_value_label.append_text("[Save] SQLite QA cycle API unavailable in LocalDataManager\n")
		return

	_log_value_label.append_text("[Save] SQLite QA cycle started\n")
	var cycle: Dictionary = _local_data_manager.call("run_sqlite_qa_cycle") as Dictionary
	_append_sqlite_qa_cycle_summary(cycle)
	var gate: Dictionary = {}
	if _local_data_manager.has_method("validate_sqlite_qa_cycle_result"):
		gate = _local_data_manager.call("validate_sqlite_qa_cycle_result", cycle) as Dictionary
		_append_sqlite_qa_gate_result(gate)
		if _local_data_manager.has_method("persist_sqlite_qa_gate_artifacts"):
			var artifact_result: Dictionary = _local_data_manager.call("persist_sqlite_qa_gate_artifacts", cycle, gate) as Dictionary
			_append_sqlite_qa_gate_artifact_result(artifact_result)
		else:
			_log_value_label.append_text("[SaveGate] SQLite QA gate artifact API unavailable in LocalDataManager\n")
	else:
		_log_value_label.append_text("[SaveGate] SQLite QA gate evaluator unavailable in LocalDataManager\n")
	var health_after: Dictionary = cycle.get("health_after", {}) as Dictionary
	var lines: PackedStringArray = _build_sqlite_health_summary_lines(health_after)
	for line: String in lines:
		_log_value_label.append_text("%s\n" % line)
	_refresh_save_stats()
	_sync_storage_adapter_controls()
	_append_save_diagnostics_config_line()
	_log_value_label.append_text("[Save] SQLite QA cycle completed status:%s\n" % String(cycle.get("status", "unknown")))


func _build_sqlite_health_summary_lines(summary: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[SQLiteHealth] ----")
	if summary == null or summary.is_empty():
		lines.append("[SQLiteHealth] Summary payload unavailable.")
		return lines

	var adapter_info: Dictionary = summary.get("adapter", {}) as Dictionary
	var requested_id: String = String(adapter_info.get("requested_id", "unknown"))
	var active_id: String = String(adapter_info.get("active_id", "unknown"))
	var adapter_available: bool = bool(adapter_info.get("available", false))
	var unavailable_reason: String = String(adapter_info.get("unavailable_reason", ""))
	lines.append(
		"[SQLiteHealth] adapter requested:%s active:%s available:%s" % [
			requested_id,
			active_id,
			str(adapter_available)
		]
	)
	if not unavailable_reason.is_empty():
		lines.append("[SQLiteHealth] adapter unavailable_reason:%s" % unavailable_reason)

	var sqlite_catalog_entry: Dictionary = summary.get("sqlite_catalog", {}) as Dictionary
	lines.append(
		"[SQLiteHealth] sqlite_scaffold available:%s reason:%s" % [
			str(bool(sqlite_catalog_entry.get("available", false))),
			String(sqlite_catalog_entry.get("reason", ""))
		]
	)

	var sqlite_db: Dictionary = summary.get("db", {}) as Dictionary
	lines.append(
		"[SQLiteHealth] db exists:%s size_bytes:%d path:%s" % [
			str(bool(sqlite_db.get("exists", false))),
			int(sqlite_db.get("size_bytes", 0)),
			String(sqlite_db.get("absolute_path", ""))
		]
	)

	var latest_artifacts: Dictionary = summary.get("latest_artifacts", {}) as Dictionary
	var latest_parity_dir: String = String(latest_artifacts.get("parity_dir", ""))
	var latest_snapshot_dir: String = String(latest_artifacts.get("snapshot_dir", ""))
	lines.append(
		"[SQLiteHealth] latest parity:%s snapshot:%s" % [
			latest_parity_dir if not latest_parity_dir.is_empty() else "none",
			latest_snapshot_dir if not latest_snapshot_dir.is_empty() else "none"
		]
	)

	var index_summary: Dictionary = summary.get("readiness_index", {}) as Dictionary
	var index_abs_path: String = String(summary.get("readiness_index_path", ""))
	if not bool(index_summary.get("ok", false)):
		lines.append(
			"[SQLiteHealth] readiness_index unavailable path:%s reason:%s" % [
				index_abs_path,
				String(index_summary.get("reason", "not found"))
			]
		)
		return lines

	lines.append(
		"[SQLiteHealth] readiness_index status:%s latest_snapshot:%s" % [
			String(index_summary.get("latest_status", "unknown")),
			String(index_summary.get("latest_snapshot_name", "unknown"))
		]
	)
	lines.append(
		"[SQLiteHealth] readiness_index counts(pass:%d warn:%d fail:%d unknown:%d)" % [
			int(index_summary.get("count_pass", 0)),
			int(index_summary.get("count_warn", 0)),
			int(index_summary.get("count_fail", 0)),
			int(index_summary.get("count_unknown", 0))
		]
	)
	lines.append(
		"[SQLiteHealth] readiness_index coverage(pass:%s warn:%s fail:%s triplet:%s)" % [
			str(bool(index_summary.get("has_pass", false))),
			str(bool(index_summary.get("has_warn", false))),
			str(bool(index_summary.get("has_fail", false))),
			str(bool(index_summary.get("has_complete_triplet", false)))
		]
	)
	lines.append("[SQLiteHealth] readiness_index path:%s" % index_abs_path)
	return lines


func _append_sqlite_qa_cycle_summary(cycle: Dictionary) -> void:
	if cycle == null or cycle.is_empty():
		_log_value_label.append_text("[Save] SQLite QA cycle result payload is empty\n")
		return

	var adapter_info: Dictionary = cycle.get("adapter", {}) as Dictionary
	var parity: Dictionary = cycle.get("parity", {}) as Dictionary
	var snapshot: Dictionary = cycle.get("snapshot", {}) as Dictionary
	var readiness_index: Dictionary = cycle.get("readiness_index", {}) as Dictionary

	_log_value_label.append_text(
		"[Save] SQLite QA result status:%s ok:%s message:%s\n" % [
			String(cycle.get("status", "unknown")),
			str(bool(cycle.get("ok", false))),
			String(cycle.get("message", ""))
		]
	)
	_log_value_label.append_text(
		"[Save] SQLite QA adapter requested:%s active:%s switch_ok:%s\n" % [
			String(adapter_info.get("requested_id", "unknown")),
			String(adapter_info.get("active_id", "unknown")),
			str(bool(cycle.get("adapter_switch_ok", false)))
		]
	)
	if parity != null and not parity.is_empty():
		_log_value_label.append_text(
			"[Save] SQLite QA parity status:%s mismatches:%d\n" % [
				String(parity.get("status", "unknown")),
				int(parity.get("mismatch_count", 0))
			]
		)
	var snapshot_ok: bool = bool(snapshot.get("ok", false))
	if snapshot != null and not snapshot.is_empty():
		_log_value_label.append_text(
			"[Save] SQLite QA snapshot ok:%s dir:%s\n" % [
				str(snapshot_ok),
				String(snapshot.get("export_dir", ""))
			]
		)
	if readiness_index != null and not readiness_index.is_empty():
		_log_value_label.append_text(
			"[Save] SQLite QA readiness status:%s counts(pass:%d warn:%d fail:%d unknown:%d)\n" % [
				String(readiness_index.get("latest_status", "unknown")),
				int(readiness_index.get("count_pass", 0)),
				int(readiness_index.get("count_warn", 0)),
				int(readiness_index.get("count_fail", 0)),
				int(readiness_index.get("count_unknown", 0))
			]
		)


func _append_sqlite_qa_gate_result(gate: Dictionary) -> void:
	if gate == null or gate.is_empty():
		_log_value_label.append_text("[SaveGate] SQLite QA gate result payload is empty\n")
		return

	var gate_ok: bool = bool(gate.get("ok", false))
	var status_label: String = "PASS" if gate_ok else "FAIL"
	_log_value_label.append_text(
		"[SaveGate] SQLite QA Gate %s: %s\n" % [
			status_label,
			String(gate.get("summary_message", ""))
		]
	)

	var failed_checks: PackedStringArray = _to_string_array(gate.get("failed_checks", PackedStringArray()))
	for failed_check: String in failed_checks:
		_log_value_label.append_text("[SaveGate] FAIL %s\n" % failed_check)

	var warnings: PackedStringArray = _to_string_array(gate.get("warnings", PackedStringArray()))
	for warning: String in warnings:
		_log_value_label.append_text("[SaveGate] WARN %s\n" % warning)


func _append_sqlite_qa_gate_artifact_result(result: Dictionary) -> void:
	if result == null or result.is_empty():
		_log_value_label.append_text("[SaveGate] SQLite QA gate artifact result payload is empty\n")
		return

	_log_value_label.append_text(
		"[SaveGate] Artifact status:%s ok:%s message:%s\n" % [
			String(result.get("status", "unknown")),
			str(bool(result.get("ok", false))),
			String(result.get("message", ""))
		]
	)
	_log_value_label.append_text(
		"[SaveGate] Artifact latest:%s\n" % String(result.get("latest_absolute_path", ""))
	)
	_log_value_label.append_text(
		"[SaveGate] Artifact history:%s\n" % String(result.get("history_absolute_path", ""))
	)


func _sync_storage_adapter_controls() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("get_storage_adapter_info"):
		return

	var adapter_info: Dictionary = _local_data_manager.call("get_storage_adapter_info") as Dictionary
	var requested_id: String = String(adapter_info.get("requested_id", "json_file"))
	var active_id: String = String(adapter_info.get("active_id", "json_file"))
	var unavailable_reason: String = String(adapter_info.get("unavailable_reason", ""))

	_syncing_controls = true
	_storage_adapter_selector.clear()
	_storage_adapter_selector.add_item("JSON File (default)")
	_storage_adapter_selector.set_item_metadata(0, "json_file")
	_storage_adapter_selector.add_item("SQLite (scaffold)")
	_storage_adapter_selector.set_item_metadata(1, "sqlite_scaffold")

	for idx: int in range(_storage_adapter_selector.item_count):
		var option_adapter_id: String = String(_storage_adapter_selector.get_item_metadata(idx))
		var option_availability: Dictionary = _get_storage_adapter_availability(option_adapter_id)
		_storage_adapter_selector.set_item_disabled(idx, not bool(option_availability.get("available", false)))

	var selected_index: int = 0
	var preferred_selection_id: String = active_id if not active_id.is_empty() else requested_id
	for idx: int in range(_storage_adapter_selector.item_count):
		if String(_storage_adapter_selector.get_item_metadata(idx)) == preferred_selection_id:
			selected_index = idx
			break
	_storage_adapter_selector.select(selected_index)
	_syncing_controls = false

	if not unavailable_reason.is_empty():
		_log_value_label.append_text(
			"[Summary] StorageAdapter requested:%s active:%s reason:%s\n" % [
				requested_id,
				active_id,
				unavailable_reason
			]
		)
	else:
		_log_value_label.append_text(
			"[Summary] StorageAdapter requested:%s active:%s\n" % [
				requested_id,
				active_id
			]
		)


func _get_storage_adapter_availability(adapter_id: String) -> Dictionary:
	if _local_data_manager == null:
		return {
			"available": false,
			"reason": "LocalDataManager unavailable."
		}
	if not _local_data_manager.has_method("get_storage_adapter_catalog"):
		return {
			"available": true,
			"reason": ""
		}

	var catalog: Dictionary = _local_data_manager.call("get_storage_adapter_catalog") as Dictionary
	if catalog == null or catalog.is_empty():
		return {
			"available": false,
			"reason": "Storage adapter catalog is empty."
		}

	var entry: Dictionary = catalog.get(adapter_id, {}) as Dictionary
	if entry == null or entry.is_empty():
		return {
			"available": false,
			"reason": "Adapter is not registered."
		}
	return {
		"available": bool(entry.get("available", false)),
		"reason": String(entry.get("reason", ""))
	}


func _on_export_saves_pressed() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("export_save_snapshot"):
		return

	var result: Dictionary = _local_data_manager.call("export_save_snapshot") as Dictionary
	var ok: bool = bool(result.get("ok", false))
	var message: String = String(result.get("message", "Export complete."))
	if ok:
		var export_dir: String = String(result.get("export_dir", ""))
		var report_file: String = String(result.get("report_file", ""))
		var migration_readiness: Dictionary = result.get("migration_readiness", {}) as Dictionary
		var readiness_index_file: String = String(result.get("readiness_index_file", ""))
		var triplet_coverage: bool = bool(result.get("readiness_evidence_coverage_complete", false))
		if not export_dir.is_empty():
			_log_value_label.append_text("[Save] %s Path:%s\n" % [message, export_dir])
		if not report_file.is_empty():
			_log_value_label.append_text("[Save] Diagnostics report:%s\n" % report_file)
		if not readiness_index_file.is_empty():
			_log_value_label.append_text("[Save] Readiness index:%s\n" % readiness_index_file)
		if migration_readiness != null and not migration_readiness.is_empty():
			var readiness_status: String = String(migration_readiness.get("status", "unknown")).to_upper()
			var readiness_summary: Dictionary = migration_readiness.get("summary", {}) as Dictionary
			_log_value_label.append_text(
				"[Save] MigrationReadiness:%s (%d/%d checks)\n" % [
					readiness_status,
					int(readiness_summary.get("passed_checks", 0)),
					int(readiness_summary.get("total_checks", 0))
				]
			)
			_log_value_label.append_text("[Save] EvidenceTripletCoverage:%s\n" % str(triplet_coverage))
		return
	_log_value_label.append_text("[Save] %s\n" % message)


func _on_reset_logs_pressed() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("clear_battle_logs"):
		return

	var ok: bool = bool(_local_data_manager.call("clear_battle_logs"))
	_log_value_label.append_text("[Save] Battle logs reset: %s\n" % str(ok))
	_refresh_save_stats()


func _append_runtime_summary() -> void:
	if _local_data_manager == null or _game_state_manager == null:
		return

	var flow_state: String = "--"
	if _game_state_manager.has_method("get_flow_state"):
		flow_state = String(_game_state_manager.call("get_flow_state"))

	var profile: Dictionary = {}
	if _game_state_manager.has_method("get_profile"):
		profile = _game_state_manager.call("get_profile") as Dictionary

	var level_progress: Dictionary = {}
	if _game_state_manager.has_method("get_level_progress"):
		level_progress = _game_state_manager.call("get_level_progress") as Dictionary

	var latest_session: Dictionary = {}
	if _local_data_manager.has_method("load_game_session_records"):
		var sessions: Array = _local_data_manager.call("load_game_session_records", 1) as Array
		if sessions != null and not sessions.is_empty() and sessions[sessions.size() - 1] is Dictionary:
			latest_session = sessions[sessions.size() - 1] as Dictionary

	_log_value_label.append_text(
		"[Summary] Flow:%s XP:%d W:%d L:%d Level:L%d\n" % [
			flow_state,
			int(profile.get("xp_total", 0)),
			int(profile.get("wins", 0)),
			int(profile.get("losses", 0)),
			int(level_progress.get("current_level_index", 1))
		]
	)

	if not latest_session.is_empty():
		_log_value_label.append_text(
			"[Summary] LastSession:%s Result:%s Turns:%d Attempts:%d\n" % [
				String(latest_session.get("session_id", "--")),
				String(latest_session.get("result", "--")),
				int(latest_session.get("turns", 0)),
				int(latest_session.get("note_attempt_count", 0))
			]
		)


func _refresh_save_stats() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("get_log_record_counts"):
		return

	var stats: Dictionary = _local_data_manager.call("get_log_record_counts") as Dictionary
	_log_stats_value_label.text = "Attempts:%d/%d Sessions:%d/%d" % [
		int(stats.get("note_attempt_count", 0)),
		int(stats.get("max_note_attempt_records", 0)),
		int(stats.get("game_session_count", 0)),
		int(stats.get("max_game_session_records", 0))
	]


func _sync_retention_controls() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("get_log_retention_limits"):
		return

	var limits: Dictionary = _local_data_manager.call("get_log_retention_limits") as Dictionary
	_syncing_controls = true
	_note_retention_spin_box.value = int(limits.get("max_note_attempt_records", int(_note_retention_spin_box.value)))
	_session_retention_spin_box.value = int(limits.get("max_game_session_records", int(_session_retention_spin_box.value)))
	_syncing_controls = false


func _sync_auto_clean_policy_controls() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("get_auto_clean_policy"):
		return

	var policy: Dictionary = _local_data_manager.call("get_auto_clean_policy") as Dictionary
	_syncing_controls = true
	_auto_clean_enabled_checkbox.button_pressed = bool(policy.get("enabled", true))
	_auto_clean_age_days_spin_box.value = int(policy.get("max_record_age_days", int(_auto_clean_age_days_spin_box.value)))
	_auto_clean_note_file_mb_spin_box.value = float(policy.get("max_note_attempt_file_mb", float(_auto_clean_note_file_mb_spin_box.value)))
	_auto_clean_session_file_mb_spin_box.value = float(policy.get("max_game_session_file_mb", float(_auto_clean_session_file_mb_spin_box.value)))
	_syncing_controls = false


func _append_save_diagnostics_config_line() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("get_save_diagnostics_config"):
		return

	var config: Dictionary = _local_data_manager.call("get_save_diagnostics_config") as Dictionary
	if config == null or config.is_empty():
		return

	var retention: Dictionary = config.get("retention_limits", {}) as Dictionary
	var auto_clean: Dictionary = config.get("auto_clean_policy", {}) as Dictionary
	_log_value_label.append_text(
		"[Summary] SaveConfig retention(note:%d session:%d) auto_clean:%s age_days:%d size_mb(n:%.1f s:%.1f)\n" % [
			int(retention.get("max_note_attempt_records", 0)),
			int(retention.get("max_game_session_records", 0)),
			str(bool(auto_clean.get("enabled", false))),
			int(auto_clean.get("max_record_age_days", 0)),
			float(auto_clean.get("max_note_attempt_file_mb", 0.0)),
			float(auto_clean.get("max_game_session_file_mb", 0.0))
		]
	)

	var storage_adapter: Dictionary = config.get("storage_adapter", {}) as Dictionary
	if storage_adapter != null and not storage_adapter.is_empty():
		_log_value_label.append_text(
			"[Summary] SaveConfig storage requested:%s active:%s available:%s\n" % [
				String(storage_adapter.get("requested_id", "unknown")),
				String(storage_adapter.get("active_id", "unknown")),
				str(bool(storage_adapter.get("available", false)))
			]
		)

	var last_cleanup: Dictionary = config.get("last_cleanup", {}) as Dictionary
	if last_cleanup == null or last_cleanup.is_empty():
		return
	_log_value_label.append_text(
		"[Summary] LastCleanup trigger:%s status:%s age_trim(n:%d s:%d) size_trim(n:%d s:%d) final(n:%d s:%d)\n" % [
			String(last_cleanup.get("trigger", "--")),
			String(last_cleanup.get("status", "--")),
			int(last_cleanup.get("trimmed_age_note_attempts", 0)),
			int(last_cleanup.get("trimmed_age_game_sessions", 0)),
			int(last_cleanup.get("trimmed_size_note_attempts", 0)),
			int(last_cleanup.get("trimmed_size_game_sessions", 0)),
			int(last_cleanup.get("final_note_attempt_count", 0)),
			int(last_cleanup.get("final_game_session_count", 0))
		]
	)


func _append_guardrail_warnings(context_label: String, warnings: PackedStringArray) -> void:
	if warnings.is_empty():
		return
	for warning: String in warnings:
		_log_value_label.append_text("[Guardrail] %s %s\n" % [context_label, warning])


func _to_string_array(raw_value: Variant) -> PackedStringArray:
	var output: PackedStringArray = PackedStringArray()
	if raw_value is PackedStringArray:
		for item: String in raw_value:
			output.append(item)
		return output
	if raw_value is Array:
		for value: Variant in raw_value:
			output.append(String(value))
	return output


func _on_battle_debug(message: String) -> void:
	_log_value_label.append_text("%s\n" % message)
	_log_value_label.scroll_to_line(_log_value_label.get_line_count())


func _on_deterministic_mode_toggled(_enabled: bool) -> void:
	if _syncing_controls:
		return
	_apply_battle_config()


func _on_deterministic_seed_changed(_value: float) -> void:
	if _syncing_controls:
		return
	_apply_battle_config()


func _on_apply_battle_config_pressed() -> void:
	_apply_battle_config()


func _on_input_device_selected(index: int) -> void:
	if _syncing_controls or _audio_processor == null:
		return
	if index < 0 or index >= _input_device_selector.item_count:
		return
	var selected_name: String = _input_device_selector.get_item_text(index)
	var switched: bool = bool(_audio_processor.call("set_input_device_name", selected_name))
	if switched:
		_populate_input_devices()
		_persist_calibration()


func _on_min_signal_slider_changed(value: float) -> void:
	_min_signal_value_label.text = "%.1f dB" % value
	if _syncing_controls or _audio_processor == null:
		return
	_audio_processor.call("set_min_signal_db", value)
	_persist_calibration()


func _on_min_confidence_slider_changed(value: float) -> void:
	_min_confidence_value_label.text = "%.2f" % value
	if _syncing_controls or _audio_processor == null:
		return
	_audio_processor.call("set_min_confidence", value)
	_persist_calibration()


func _on_stability_frames_changed(value: float) -> void:
	if _syncing_controls or _audio_processor == null:
		return
	_audio_processor.call("set_stable_frames_required", int(value))
	_persist_calibration()


func _update_labels_from_processor() -> void:
	var frequency: float = float(_audio_processor.call("get_detected_frequency"))
	_frequency_value_label.text = "%.2f Hz" % frequency if frequency > 0.0 else "-- Hz"
	_note_value_label.text = String(_audio_processor.call("get_detected_note"))
	_confidence_value_label.text = "%.2f" % float(_audio_processor.call("get_detected_confidence"))
	_input_level_value_label.text = "%.1f dB" % float(_audio_processor.call("get_input_level_db"))
	if _audio_processor.has_method("get_noise_floor_db"):
		_noise_floor_value_label.text = "%.1f dB" % float(_audio_processor.call("get_noise_floor_db"))
	if _audio_processor.has_method("get_effective_min_signal_db"):
		_effective_threshold_value_label.text = "%.1f dB" % float(_audio_processor.call("get_effective_min_signal_db"))
	_backend_value_label.text = String(_audio_processor.call("get_backend_mode"))
	_status_value_label.text = String(_audio_processor.call("get_status_text"))
	_update_battle_labels()


func _sync_controls_from_processor() -> void:
	if _audio_processor == null:
		return
	_syncing_controls = true
	_populate_input_devices()
	var min_signal: float = float(_audio_processor.call("get_min_signal_db"))
	var min_confidence: float = float(_audio_processor.call("get_min_confidence"))
	var stable_frames: int = int(_audio_processor.call("get_stable_frames_required"))
	_min_signal_slider.value = min_signal
	_min_signal_value_label.text = "%.1f dB" % min_signal
	_min_confidence_slider.value = min_confidence
	_min_confidence_value_label.text = "%.2f" % min_confidence
	_stability_frames_spin_box.value = stable_frames
	_syncing_controls = false


func _populate_input_devices() -> void:
	_input_device_selector.clear()
	var devices: PackedStringArray = _audio_processor.call("get_input_device_names") as PackedStringArray
	if devices == null or devices.is_empty():
		_input_device_selector.add_item("No input devices")
		_input_device_selector.select(0)
		_input_device_selector.disabled = true
		return

	var current_device: String = String(_audio_processor.call("get_input_device_name"))
	var selected_index: int = 0
	for i: int in range(devices.size()):
		var device_name: String = devices[i]
		_input_device_selector.add_item(device_name)
		if device_name == current_device:
			selected_index = i
	_input_device_selector.disabled = false
	_input_device_selector.select(selected_index)


func _load_saved_calibration() -> void:
	if _audio_processor == null or _local_data_manager == null:
		return
	if not _local_data_manager.has_method("load_audio_calibration"):
		return

	var calibration: Dictionary = _local_data_manager.call("load_audio_calibration") as Dictionary
	if calibration == null or calibration.is_empty():
		return

	var input_device_name: String = String(calibration.get("input_device_name", ""))
	if not input_device_name.is_empty():
		_audio_processor.call("set_input_device_name", input_device_name)

	_audio_processor.call("set_min_signal_db", float(calibration.get("min_signal_db", -58.0)))
	_audio_processor.call("set_min_confidence", float(calibration.get("min_confidence", 0.12)))
	_audio_processor.call("set_stable_frames_required", int(calibration.get("stable_frames_required", 3)))
	_sync_controls_from_processor()


func _persist_calibration() -> void:
	if _audio_processor == null or _local_data_manager == null:
		return
	if not _local_data_manager.has_method("save_audio_calibration"):
		return

	var payload: Dictionary = {
		"input_device_name": String(_audio_processor.call("get_input_device_name")),
		"min_signal_db": float(_audio_processor.call("get_min_signal_db")),
		"min_confidence": float(_audio_processor.call("get_min_confidence")),
		"stable_frames_required": int(_audio_processor.call("get_stable_frames_required"))
	}
	_local_data_manager.call("save_audio_calibration", payload)


func _update_battle_labels() -> void:
	if _battle_manager == null:
		return
	if not _battle_manager.call("is_battle_active"):
		return
	_battle_target_value_label.text = String(_battle_manager.call("get_target_note"))
	_battle_turn_value_label.text = str(int(_battle_manager.call("get_turn_index")))
	_battle_time_value_label.text = "%.1fs" % float(_battle_manager.call("get_turn_time_left"))
	_player_hp_value_label.text = str(int(_battle_manager.call("get_player_hp")))
	_enemy_hp_value_label.text = str(int(_battle_manager.call("get_enemy_hp")))


func _sync_battle_config_controls() -> void:
	if _battle_manager == null:
		return
	if not _battle_manager.has_method("get_deterministic_mode"):
		return

	_syncing_controls = true
	_deterministic_mode_checkbox.button_pressed = bool(_battle_manager.call("get_deterministic_mode"))
	_deterministic_seed_spin_box.value = int(_battle_manager.call("get_deterministic_seed"))
	var patterns: PackedStringArray = _battle_manager.call("get_forced_target_patterns") as PackedStringArray
	_forced_target_queue_edit.text = _format_forced_patterns(patterns)
	_syncing_controls = false


func _apply_battle_config() -> void:
	if _battle_manager == null:
		return
	if not _battle_manager.has_method("configure_deterministic"):
		return

	var forced_patterns: PackedStringArray = _parse_forced_patterns(_forced_target_queue_edit.text)
	_battle_manager.call(
		"configure_deterministic",
		_deterministic_mode_checkbox.button_pressed,
		int(_deterministic_seed_spin_box.value),
		forced_patterns
	)
	_persist_battle_debug_config()


func _load_saved_battle_debug_config() -> void:
	if _battle_manager == null or _local_data_manager == null:
		return
	if not _local_data_manager.has_method("load_battle_debug_config"):
		return

	var config: Dictionary = _local_data_manager.call("load_battle_debug_config") as Dictionary
	if config == null or config.is_empty():
		return

	var forced_patterns: PackedStringArray = PackedStringArray()
	var raw_patterns: Variant = config.get("forced_target_patterns", PackedStringArray())
	if raw_patterns is PackedStringArray:
		forced_patterns = raw_patterns
	elif raw_patterns is Array:
		for pattern_value: Variant in raw_patterns:
			forced_patterns.append(String(pattern_value))

	_battle_manager.call(
		"configure_deterministic",
		bool(config.get("enabled", false)),
		int(config.get("seed", 1337)),
		forced_patterns
	)
	_sync_battle_config_controls()


func _persist_battle_debug_config() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("save_battle_debug_config"):
		return

	var payload: Dictionary = {
		"enabled": _deterministic_mode_checkbox.button_pressed,
		"seed": int(_deterministic_seed_spin_box.value),
		"forced_target_patterns": _parse_forced_patterns(_forced_target_queue_edit.text)
	}
	_local_data_manager.call("save_battle_debug_config", payload)


func _parse_forced_patterns(raw_text: String) -> PackedStringArray:
	var output: PackedStringArray = PackedStringArray()
	var tokens: PackedStringArray = raw_text.split(",", false)
	for token: String in tokens:
		var cleaned: String = token.strip_edges()
		if cleaned.is_empty():
			continue
		output.append(cleaned)
	return output


func _format_forced_patterns(patterns: PackedStringArray) -> String:
	if patterns == null or patterns.is_empty():
		return ""
	return ", ".join(patterns)


func _sync_button_state() -> void:
	if _audio_processor == null:
		_toggle_button.text = "Start Recording"
		return
	_toggle_button.text = "Stop Recording" if bool(_audio_processor.call("is_capturing")) else "Start Recording"


func _resolve_audio_processor() -> Node:
	var existing: Node = get_node_or_null("/root/AudioProcessor")
	if existing != null:
		return existing

	push_warning("TestScene: AudioProcessor autoload not found at /root/AudioProcessor.")
	return null


func _resolve_local_data_manager() -> Node:
	var existing: Node = get_node_or_null("/root/LocalDataManager")
	if existing != null:
		return existing

	push_warning("TestScene: LocalDataManager autoload not found at /root/LocalDataManager.")
	return null


func _resolve_battle_manager() -> Node:
	var existing: Node = get_node_or_null("/root/BattleManager")
	if existing != null:
		return existing

	push_warning("TestScene: BattleManager autoload not found at /root/BattleManager.")
	return null


func _resolve_game_state_manager() -> Node:
	var existing: Node = get_node_or_null("/root/GameStateManager")
	if existing != null:
		return existing

	push_warning("TestScene: GameStateManager autoload not found at /root/GameStateManager.")
	return null


func _connect_battle_signals() -> void:
	if _battle_manager == null:
		return
	if not _battle_manager.is_connected("battle_started", _on_battle_started):
		_battle_manager.connect("battle_started", _on_battle_started)
	if not _battle_manager.is_connected("turn_started", _on_turn_started):
		_battle_manager.connect("turn_started", _on_turn_started)
	if not _battle_manager.is_connected("turn_resolved", _on_turn_resolved):
		_battle_manager.connect("turn_resolved", _on_turn_resolved)
	if not _battle_manager.is_connected("battle_ended", _on_battle_ended):
		_battle_manager.connect("battle_ended", _on_battle_ended)
	if not _battle_manager.is_connected("battle_debug", _on_battle_debug):
		_battle_manager.connect("battle_debug", _on_battle_debug)


func _connect_game_state_signals() -> void:
	if _game_state_manager == null:
		return
	if not _game_state_manager.is_connected("flow_state_changed", _on_flow_state_changed):
		_game_state_manager.connect("flow_state_changed", _on_flow_state_changed)
	if not _game_state_manager.is_connected("progression_updated", _on_progression_updated):
		_game_state_manager.connect("progression_updated", _on_progression_updated)
	if not _game_state_manager.is_connected("battle_session_committed", _on_battle_session_committed):
		_game_state_manager.connect("battle_session_committed", _on_battle_session_committed)
