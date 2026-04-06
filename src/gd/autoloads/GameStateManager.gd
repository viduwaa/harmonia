extends Node

signal flow_state_changed(previous_state: String, next_state: String)
signal progression_updated(profile: Dictionary, level_progress: Dictionary)
signal battle_session_committed(result: String, session_id: String, xp_gained: int)

const STATE_IDLE: String = "IDLE"
const STATE_BATTLE_ACTIVE: String = "BATTLE_ACTIVE"
const STATE_POST_BATTLE: String = "POST_BATTLE"
const WIN_XP_GAIN: int = 120
const LOSS_XP_GAIN: int = 40

var _current_state: String = STATE_IDLE
var _local_data_manager: Node
var _battle_manager: Node
var _profile: Dictionary = {}
var _level_progress: Dictionary = {}


func _ready() -> void:
	call_deferred("_bind_runtime_managers")


func get_flow_state() -> String:
	return _current_state


func get_profile() -> Dictionary:
	return _profile.duplicate(true)


func get_level_progress() -> Dictionary:
	return _level_progress.duplicate(true)


func _bind_runtime_managers() -> void:
	_local_data_manager = get_node_or_null("/root/LocalDataManager")
	if _local_data_manager == null:
		push_warning("GameStateManager: LocalDataManager not found.")
		return

	_load_progress_documents()

	_battle_manager = get_node_or_null("/root/BattleManager")
	if _battle_manager == null:
		push_warning("GameStateManager: BattleManager not found.")
		return

	if not _battle_manager.is_connected("battle_started", _on_battle_started):
		_battle_manager.connect("battle_started", _on_battle_started)
	if not _battle_manager.is_connected("battle_ended", _on_battle_ended):
		_battle_manager.connect("battle_ended", _on_battle_ended)


func _on_battle_started(_player_hp: int, _enemy_hp: int) -> void:
	_transition_state(STATE_BATTLE_ACTIVE)


func _on_battle_ended(result: String, _turns: int) -> void:
	_transition_state(STATE_POST_BATTLE)
	var latest_session: Dictionary = _fetch_latest_game_session()
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


func _save_progress_documents() -> void:
	if _local_data_manager == null:
		return

	var profile_saved: bool = false
	var level_saved: bool = false
	if _local_data_manager.has_method("save_profile"):
		profile_saved = bool(_local_data_manager.call("save_profile", _profile))
	if _local_data_manager.has_method("save_level_progress"):
		level_saved = bool(_local_data_manager.call("save_level_progress", _level_progress))
	if not profile_saved:
		push_warning("GameStateManager: Failed to persist profile document.")
	if not level_saved:
		push_warning("GameStateManager: Failed to persist level progress document.")


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
