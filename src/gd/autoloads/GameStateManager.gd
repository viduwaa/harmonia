extends Node

signal flow_state_changed(previous_state: String, next_state: String)
signal progression_updated(profile: Dictionary, level_progress: Dictionary)
signal battle_session_committed(result: String, session_id: String, xp_gained: int)
signal active_profile_changed(profile_name: String)

const STATE_IDLE: String = "IDLE"
const STATE_BATTLE_ACTIVE: String = "BATTLE_ACTIVE"
const STATE_POST_BATTLE: String = "POST_BATTLE"
const BATTLE_MODE_PRACTICE: String = "practice"
const WIN_XP_GAIN: int = 120
const LOSS_XP_GAIN: int = 40
const LOCAL_DATA_MANAGER_PATH: String = "/root/LocalDataManager"
const BATTLE_MANAGER_PATH: String = "/root/BattleManager"

var _current_state: String = STATE_IDLE
var _local_data_manager: Node
var _battle_manager: Node
var _profile: Dictionary = {}
var _level_progress: Dictionary = {}
var _active_profile_name: String = ""


func _ready() -> void:
	call_deferred("_bind_runtime_managers")


func get_flow_state() -> String:
	return _current_state


func get_profile() -> Dictionary:
	return _profile.duplicate(true)


func get_level_progress() -> Dictionary:
	return _level_progress.duplicate(true)


func get_active_profile_name() -> String:
	return _active_profile_name


func get_profile_summary() -> Dictionary:
	var level: int = int(_level_progress.get("current_level_index", 1)) if not _level_progress.is_empty() else 1
	var accuracy: float = float(_profile.get("avg_accuracy", 0.0))
	var name: String = _active_profile_name
	if name.is_empty() and not _profile.is_empty():
		name = String(_profile.get("name", ""))
	return {
		"name": name,
		"level": level,
		"avg_accuracy": accuracy
	}


func set_active_profile(profile_name: String) -> bool:
	var name: String = String(profile_name).strip_edges()
	if name.is_empty():
		_clear_active_profile()
		return true

	if _local_data_manager == null:
		_local_data_manager = get_node_or_null(LOCAL_DATA_MANAGER_PATH)
	if _local_data_manager == null or not _local_data_manager.has_method("get_profile"):
		push_warning("GameStateManager: Cannot load profile; LocalDataManager missing.")
		return false
	if not _local_data_manager.has_method("set_active_profile_name"):
		push_warning("GameStateManager: LocalDataManager missing set_active_profile_name.")
		return false

	var profile_record: Dictionary = _local_data_manager.call("get_profile", name) as Dictionary
	if profile_record.is_empty():
		push_warning("GameStateManager: Profile '%s' not found." % name)
		return false

	_profile = profile_record.duplicate(true)
	_level_progress = _normalize_level_progress_from_profile(_profile)
	_active_profile_name = name

	if not bool(_local_data_manager.call("set_active_profile_name", name)):
		push_warning("GameStateManager: Profile loaded, but persisting active selection failed.")

	active_profile_changed.emit(name)
	progression_updated.emit(_profile.duplicate(true), _level_progress.duplicate(true))
	return true


func _clear_active_profile() -> void:
	_profile = {}
	_level_progress = {}
	_active_profile_name = ""
	active_profile_changed.emit("")


func grant_exploration_rewards(xp_bonus: int) -> bool:
	var normalized_bonus: int = max(xp_bonus, 0)
	if normalized_bonus <= 0:
		return true

	if _profile == null or _profile.is_empty():
		_load_progress_documents()

	_profile["xp_total"] = int(_profile.get("xp_total", 0)) + normalized_bonus
	_profile["last_updated_unix_sec"] = int(Time.get_unix_time_from_system())

	return _save_progress_documents()


func _bind_runtime_managers() -> void:
	_local_data_manager = get_node_or_null(LOCAL_DATA_MANAGER_PATH)
	if _local_data_manager == null:
		push_warning("GameStateManager: LocalDataManager not found.")
		return

	_load_active_profile()

	_battle_manager = get_node_or_null(BATTLE_MANAGER_PATH)
	if _battle_manager == null:
		push_warning("GameStateManager: BattleManager not found.")
		return

	if not _battle_manager.is_connected("battle_started", _on_battle_started):
		_battle_manager.connect("battle_started", _on_battle_started)
	if not _battle_manager.is_connected("battle_ended", _on_battle_ended):
		_battle_manager.connect("battle_ended", _on_battle_ended)


func _load_active_profile() -> void:
	if _local_data_manager == null:
		return
	var active_name: String = ""
	if _local_data_manager.has_method("get_active_profile_name"):
		active_name = String(_local_data_manager.call("get_active_profile_name"))
	if not active_name.is_empty() and _local_data_manager.has_method("get_profile"):
		var record: Dictionary = _local_data_manager.call("get_profile", active_name) as Dictionary
		if not record.is_empty():
			_profile = record.duplicate(true)
			_level_progress = _normalize_level_progress_from_profile(_profile)
			_active_profile_name = active_name
			progression_updated.emit(_profile.duplicate(true), _level_progress.duplicate(true))
			return

	_load_progress_documents()


func _on_battle_started(_player_hp: int, _enemy_hp: int) -> void:
	_transition_state(STATE_BATTLE_ACTIVE)


func _on_battle_ended(result: String, _turns: int) -> void:
	_transition_state(STATE_POST_BATTLE)
	var latest_session: Dictionary = _fetch_latest_game_session()
	if String(latest_session.get("mode", "")) == BATTLE_MODE_PRACTICE:
		_recompute_avg_accuracy()
		_save_progress_documents()
		_transition_state(STATE_IDLE)
		return
	_apply_progression_from_result(result, latest_session)
	_save_progress_documents()
	_transition_state(STATE_IDLE)


func _load_progress_documents() -> void:
	if _local_data_manager.has_method("load_profile"):
		_profile = _local_data_manager.call("load_profile") as Dictionary
	if _profile == null or _profile.is_empty():
		_profile = _default_profile()

	if _local_data_manager.has_method("load_level_progress"):
		_level_progress = _local_data_manager.call("load_level_progress") as Dictionary
	if _level_progress == null or _level_progress.is_empty():
		_level_progress = _default_level_progress()


func _save_progress_documents() -> bool:
	if _local_data_manager == null:
		return false

	if _active_profile_name.is_empty():
		push_warning("GameStateManager: Cannot save; no active profile selected.")
		return false

	_profile["name"] = _active_profile_name
	_profile["level_progress"] = _level_progress.duplicate(true)
	_profile["last_updated_unix_sec"] = int(Time.get_unix_time_from_system())

	var profile_saved: bool = false
	if _local_data_manager.has_method("save_profile_by_name"):
		profile_saved = bool(_local_data_manager.call("save_profile_by_name", _active_profile_name, _profile))
	if not profile_saved:
		push_warning("GameStateManager: Failed to persist profile document for '%s'." % _active_profile_name)

	progression_updated.emit(_profile.duplicate(true), _level_progress.duplicate(true))

	return profile_saved


func _fetch_latest_game_session() -> Dictionary:
	if _local_data_manager == null:
		return {}
	if not _local_data_manager.has_method("load_game_session_records"):
		return {}

	var records: Array = _local_data_manager.call("load_game_session_records", 1) as Array
	if records == null or records.is_empty():
		return {}

	var latest: Variant = records[records.size() - 1]
	if latest is Dictionary:
		return latest as Dictionary
	return {}


func _apply_progression_from_result(result: String, session_payload: Dictionary) -> void:
	var xp_gain: int = WIN_XP_GAIN if result == "Win" else LOSS_XP_GAIN
	_profile["battles_played"] = int(_profile.get("battles_played", 0)) + 1
	if result == "Win":
		_profile["wins"] = int(_profile.get("wins", 0)) + 1
	else:
		_profile["losses"] = int(_profile.get("losses", 0)) + 1
	_profile["xp_total"] = int(_profile.get("xp_total", 0)) + xp_gain
	_profile["last_result"] = result
	_profile["last_xp_gain"] = xp_gain
	_profile["last_session_id"] = String(session_payload.get("session_id", ""))
	_profile["last_updated_unix_sec"] = int(Time.get_unix_time_from_system())

	_recompute_avg_accuracy()

	var current_level_index: int = max(int(_level_progress.get("current_level_index", 1)), 1)
	var max_level_reached: int = max(int(_level_progress.get("max_level_reached", 1)), current_level_index)
	var completed_level_ids: PackedStringArray = PackedStringArray()
	var raw_completed_level_ids: Variant = _level_progress.get("completed_level_ids", PackedStringArray())
	if raw_completed_level_ids is PackedStringArray:
		completed_level_ids = raw_completed_level_ids
	elif raw_completed_level_ids is Array:
		for level_value: Variant in raw_completed_level_ids:
			completed_level_ids.append(String(level_value))

	if result == "Win":
		var completed_level_id: String = "L%d" % current_level_index
		if not completed_level_ids.has(completed_level_id):
			completed_level_ids.append(completed_level_id)
		current_level_index += 1
		max_level_reached = max(max_level_reached, current_level_index)

	_level_progress["current_level_index"] = current_level_index
	_level_progress["max_level_reached"] = max_level_reached
	_level_progress["completed_level_ids"] = completed_level_ids
	_level_progress["last_result"] = result
	_level_progress["last_updated_unix_sec"] = int(Time.get_unix_time_from_system())

	progression_updated.emit(_profile.duplicate(true), _level_progress.duplicate(true))
	battle_session_committed.emit(result, String(_profile.get("last_session_id", "")), xp_gain)


func _recompute_avg_accuracy() -> void:
	if _active_profile_name.is_empty():
		return
	if _local_data_manager == null or not _local_data_manager.has_method("load_note_attempt_records"):
		return

	var all_records: Array = _local_data_manager.call("load_note_attempt_records", 0) as Array
	if all_records.is_empty():
		_profile["avg_accuracy"] = 0.0
		return

	var total: int = 0
	var on_target: int = 0
	for record_variant: Variant in all_records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant as Dictionary
		if String(record.get("profile_name", _active_profile_name)) != _active_profile_name:
			continue
		total += 1
		var grade: String = String(record.get("grade", ""))
		if grade == "Perfect" or grade == "Good":
			on_target += 1

	_profile["avg_accuracy"] = (float(on_target) / float(total) * 100.0) if total > 0 else 0.0


func _normalize_level_progress_from_profile(profile: Dictionary) -> Dictionary:
	var lp_variant: Variant = profile.get("level_progress", {})
	if typeof(lp_variant) == TYPE_DICTIONARY and not (lp_variant as Dictionary).is_empty():
		var lp: Dictionary = lp_variant as Dictionary
		var completed_levels: PackedStringArray = PackedStringArray()
		var raw_completed: Variant = lp.get("completed_level_ids", PackedStringArray())
		if raw_completed is PackedStringArray:
			completed_levels = raw_completed
		elif raw_completed is Array:
			for level_value: Variant in raw_completed:
				completed_levels.append(String(level_value))
		return {
			"current_level_index": int(lp.get("current_level_index", 1)),
			"max_level_reached": int(lp.get("max_level_reached", 1)),
			"completed_level_ids": completed_levels,
			"last_result": String(lp.get("last_result", "")),
			"last_updated_unix_sec": int(lp.get("last_updated_unix_sec", 0))
		}
	return _default_level_progress()


func _transition_state(next_state: String) -> void:
	if _current_state == next_state:
		return
	var previous_state: String = _current_state
	_current_state = next_state
	flow_state_changed.emit(previous_state, next_state)


func _default_profile() -> Dictionary:
	return {
		"xp_total": 0,
		"battles_played": 0,
		"wins": 0,
		"losses": 0,
		"last_result": "",
		"last_session_id": "",
		"last_xp_gain": 0,
		"last_updated_unix_sec": 0,
		"avg_accuracy": 0.0
	}


func _default_level_progress() -> Dictionary:
	return {
		"current_level_index": 1,
		"max_level_reached": 1,
		"completed_level_ids": PackedStringArray(),
		"last_result": "",
		"last_updated_unix_sec": 0
	}
