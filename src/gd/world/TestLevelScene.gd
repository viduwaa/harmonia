extends Control

const MAIN_MENU_SCENE_PATH: String = "res://src/gd/scenes/menu/MainMenuScene.tscn"
const TEST_LEVEL_SCENE_NAME: String = "TestLevelScene"
const PLAYER_SPEED_PX_PER_SEC: float = 220.0
const WORLD_PADDING_PX: float = 24.0
const BOSS_GATE_MIN_WINS: int = 1
const BOSS_GATE_MAX_WINS: int = 3

const ENCOUNTER_CONFIGS: Dictionary = {
	"EncounterZoneA": {
		"label": "Skirmish Alpha",
		"seed": 3101,
		"patterns": ["C4", "D4", "E4"],
		"type": "enemy"
	},
	"EncounterZoneB": {
		"label": "Skirmish Beta",
		"seed": 3207,
		"patterns": ["E4", "G4", "A4"],
		"type": "enemy"
	},
	"EncounterZoneC": {
		"label": "Skirmish Gamma",
		"seed": 3309,
		"patterns": ["D4", "F4", "A4"],
		"type": "enemy"
	},
	"BossGateZone": {
		"label": "Boss Gate",
		"seed": 9001,
		"patterns": ["C4+E4+G4", "D4+F4+A4", "E4+G4+B4"],
		"type": "boss"
	}
}

@onready var _world_rect: ColorRect = %WorldRect
@onready var _player_token: ColorRect = %PlayerToken
@onready var _encounter_zone_a: ColorRect = %EncounterZoneA
@onready var _encounter_zone_b: ColorRect = %EncounterZoneB
@onready var _encounter_zone_c: ColorRect = %EncounterZoneC
@onready var _boss_gate_zone: ColorRect = %BossGateZone
@onready var _status_value: Label = %StatusValue
@onready var _boss_gate_value: Label = %BossGateValue
@onready var _boss_status_value: Label = %BossStatusValue
@onready var _encounter_wins_value: Label = %EncounterWinsValue
@onready var _position_value: Label = %PositionValue
@onready var _last_encounter_value: Label = %LastEncounterValue
@onready var _reset_level_button: Button = %ResetLevelButton
@onready var _return_to_menu_button: Button = %ReturnToMenuButton

var _audio_processor: Node
var _battle_manager: Node
var _local_data_manager: Node
var _battle_in_progress: bool = false
var _active_encounter_zone_key: String = ""
var _boss_gate_required_wins: int = 0
var _boss_gate_current_wins: int = 0
var _boss_defeated: bool = false
var _encounter_latches: Dictionary = {}
var _zone_nodes: Dictionary = {}
var _boss_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_audio_processor = get_node_or_null("/root/AudioProcessor")
	_battle_manager = get_node_or_null("/root/BattleManager")
	_local_data_manager = get_node_or_null("/root/LocalDataManager")
	_boss_rng.randomize()

	_zone_nodes = {
		"EncounterZoneA": _encounter_zone_a,
		"EncounterZoneB": _encounter_zone_b,
		"EncounterZoneC": _encounter_zone_c,
		"BossGateZone": _boss_gate_zone
	}

	_reset_level_button.pressed.connect(_on_reset_level_pressed)
	_return_to_menu_button.pressed.connect(_on_return_to_menu_pressed)

	if _battle_manager != null:
		if not _battle_manager.is_connected("battle_started", _on_battle_started):
			_battle_manager.connect("battle_started", _on_battle_started)
		if not _battle_manager.is_connected("battle_ended", _on_battle_ended):
			_battle_manager.connect("battle_ended", _on_battle_ended)

	call_deferred("_finalize_scene_state")


func _process(delta: float) -> void:
	_move_player(delta)
	_refresh_position_label()
	_handle_encounter_overlap()
	_refresh_boss_gate_status()


func _finalize_scene_state() -> void:
	_load_saved_state()
	_ensure_boss_gate_setup()
	_sanitize_spawn_if_inside_encounter()
	_refresh_boss_gate_status()
	_refresh_position_label()
	_refresh_last_encounter_label("Awaiting encounters")
	_set_status("Clear %d encounter wins to open the boss gate." % _boss_gate_required_wins)


func _move_player(delta: float) -> void:
	if _battle_in_progress:
		return

	var input_vector: Vector2 = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if input_vector.length_squared() <= 0.0:
		return

	_player_token.position += input_vector.normalized() * PLAYER_SPEED_PX_PER_SEC * delta
	_clamp_player_to_world()


func _clamp_player_to_world() -> void:
	var min_position: Vector2 = Vector2(WORLD_PADDING_PX, WORLD_PADDING_PX)
	var max_position: Vector2 = _world_rect.size - _player_token.size - Vector2(WORLD_PADDING_PX, WORLD_PADDING_PX)
	max_position.x = max(max_position.x, min_position.x)
	max_position.y = max(max_position.y, min_position.y)
	_player_token.position = _player_token.position.clamp(min_position, max_position)


func _handle_encounter_overlap() -> void:
	if _battle_in_progress:
		return

	for zone_key_variant: Variant in _zone_nodes.keys():
		var zone_key: String = String(zone_key_variant)
		var zone_node: Control = _zone_nodes.get(zone_key) as Control
		if zone_node == null:
			continue

		var overlaps: bool = _overlaps(_player_token, zone_node)
		var latched: bool = bool(_encounter_latches.get(zone_key, false))
		if overlaps and not latched:
			_encounter_latches[zone_key] = true
			_trigger_encounter_battle(zone_key)
		elif not overlaps:
			_encounter_latches[zone_key] = false


func _trigger_encounter_battle(zone_key: String) -> void:
	if _audio_processor == null:
		_set_status("Encounter reached, but AudioProcessor is missing.")
		return
	if not ENCOUNTER_CONFIGS.has(zone_key):
		return

	var encounter_type: String = String(ENCOUNTER_CONFIGS[zone_key].get("type", "enemy"))
	if encounter_type == "boss":
		if _boss_defeated:
			_set_status("Boss already defeated. Level complete.")
			return
		if not _is_boss_unlocked():
			var remaining: int = max(_boss_gate_required_wins - _boss_gate_current_wins, 0)
			_set_status("Boss gate locked. Win %d more encounters." % remaining)
			return

	_save_current_state("encounter_pre_%s" % zone_key.to_lower(), true)
	_apply_encounter_tier(zone_key)
	_active_encounter_zone_key = zone_key

	var is_capturing: bool = bool(_audio_processor.call("is_capturing"))
	if not is_capturing:
		_audio_processor.call("start_capture")
	elif _battle_manager != null:
		_battle_manager.call("stop_battle")
		_battle_manager.call("start_battle")

	_set_status("%s started. Match the target notes." % String(ENCOUNTER_CONFIGS[zone_key].get("label", "Encounter")))


func _apply_encounter_tier(zone_key: String) -> void:
	if _battle_manager == null:
		return
	if not ENCOUNTER_CONFIGS.has(zone_key):
		return

	var config: Dictionary = ENCOUNTER_CONFIGS[zone_key] as Dictionary
	var seed: int = int(config.get("seed", 1337))
	var patterns: PackedStringArray = PackedStringArray()
	var raw_patterns: Variant = config.get("patterns", [])
	if raw_patterns is PackedStringArray:
		patterns = raw_patterns
	elif raw_patterns is Array:
		for pattern_value: Variant in raw_patterns:
			patterns.append(String(pattern_value))

	_battle_manager.call("configure_deterministic", true, seed, patterns)


func _on_battle_started(_player_hp: int, _enemy_hp: int) -> void:
	_battle_in_progress = true
	_refresh_last_encounter_label("Battle active")


func _on_battle_ended(result: String, turns: int) -> void:
	_battle_in_progress = false
	var encounter_label: String = String(ENCOUNTER_CONFIGS.get(_active_encounter_zone_key, {}).get("label", "Encounter"))
	var encounter_type: String = String(ENCOUNTER_CONFIGS.get(_active_encounter_zone_key, {}).get("type", "enemy"))
	var summary: String = "%s %s in %d turns" % [encounter_label, result, turns]
	_refresh_last_encounter_label(summary)

	if result == "Win":
		if encounter_type == "boss":
			_boss_defeated = true
			_set_status("Boss defeated. Level complete.")
			_save_current_state("boss_win", true)
		else:
			_boss_gate_current_wins += 1
			_save_current_state("encounter_post_%s" % _active_encounter_zone_key.to_lower(), true)
			if _is_boss_unlocked():
				_set_status("Boss gate unlocked. Proceed to the boss zone.")
			else:
				var remaining: int = max(_boss_gate_required_wins - _boss_gate_current_wins, 0)
				_set_status("Encounter cleared. Win %d more encounters." % remaining)
	else:
		_set_status("Encounter lost. Win encounters to open the boss gate.")

	_active_encounter_zone_key = ""


func _ensure_boss_gate_setup() -> void:
	if _boss_defeated:
		return
	if _boss_gate_required_wins > 0:
		return

	_boss_gate_required_wins = _boss_rng.randi_range(BOSS_GATE_MIN_WINS, BOSS_GATE_MAX_WINS)
	_boss_gate_current_wins = 0
	_save_current_state("boss_gate_init", true)


func _is_boss_unlocked() -> bool:
	return _boss_gate_current_wins >= _boss_gate_required_wins and _boss_gate_required_wins > 0


func _refresh_boss_gate_status() -> void:
	_encounter_wins_value.text = "%d" % _boss_gate_current_wins
	_boss_gate_value.text = "%d / %d" % [_boss_gate_current_wins, _boss_gate_required_wins]
	if _boss_defeated:
		_boss_status_value.text = "Defeated"
		return
	if _is_boss_unlocked():
		_boss_status_value.text = "Unlocked"
	else:
		_boss_status_value.text = "Locked"


func _refresh_last_encounter_label(summary: String) -> void:
	_last_encounter_value.text = summary


func _load_saved_state() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("load_explore_state"):
		return

	var explore_state: Dictionary = _local_data_manager.call("load_explore_state") as Dictionary
	if explore_state == null or explore_state.is_empty():
		return

	if String(explore_state.get("last_scene", "")) == TEST_LEVEL_SCENE_NAME:
		_player_token.position = Vector2(
			float(explore_state.get("last_spawn_x", _player_token.position.x)),
			float(explore_state.get("last_spawn_y", _player_token.position.y))
		)

	_boss_gate_required_wins = int(explore_state.get("boss_gate_required_wins", 0))
	_boss_gate_current_wins = int(explore_state.get("boss_gate_current_wins", 0))
	_boss_defeated = bool(explore_state.get("boss_defeated", false))


func _save_current_state(checkpoint_id: String, ensure_not_in_encounter: bool) -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("save_explore_state"):
		return

	var spawn_position: Vector2 = _player_token.position
	if ensure_not_in_encounter and _is_inside_any_encounter_zone_at_position(spawn_position):
		spawn_position = _get_safe_spawn_position()

	var payload: Dictionary = _local_data_manager.call("load_explore_state") as Dictionary
	if payload == null:
		payload = {}

	payload["last_spawn_x"] = spawn_position.x
	payload["last_spawn_y"] = spawn_position.y
	payload["last_scene"] = TEST_LEVEL_SCENE_NAME
	payload["last_checkpoint_id"] = checkpoint_id
	payload["boss_gate_required_wins"] = _boss_gate_required_wins
	payload["boss_gate_current_wins"] = _boss_gate_current_wins
	payload["boss_defeated"] = _boss_defeated
	payload["last_reward_summary"] = _last_encounter_value.text
	payload["last_updated_unix_sec"] = int(Time.get_unix_time_from_system())

	var saved: bool = bool(_local_data_manager.call("save_explore_state", payload))
	if not saved:
		push_warning("TestLevelScene: Failed to persist level state.")


func _sanitize_spawn_if_inside_encounter() -> void:
	if not _is_inside_any_encounter_zone_at_position(_player_token.position):
		return
	_player_token.position = _get_safe_spawn_position()
	_clamp_player_to_world()


func _get_safe_spawn_position() -> Vector2:
	var fallback_spawn: Vector2 = Vector2(120.0, 120.0)
	if not _is_inside_any_encounter_zone_at_position(fallback_spawn):
		return _clamp_position_to_world(fallback_spawn)

	return _clamp_position_to_world(Vector2(160.0, 160.0))


func _clamp_position_to_world(position: Vector2) -> Vector2:
	var min_position: Vector2 = Vector2(WORLD_PADDING_PX, WORLD_PADDING_PX)
	var max_position: Vector2 = _world_rect.size - _player_token.size - Vector2(WORLD_PADDING_PX, WORLD_PADDING_PX)
	max_position.x = max(max_position.x, min_position.x)
	max_position.y = max(max_position.y, min_position.y)
	return position.clamp(min_position, max_position)


func _is_inside_any_encounter_zone_at_position(candidate_position: Vector2) -> bool:
	return _overlaps_at_position(candidate_position, _encounter_zone_a) or _overlaps_at_position(candidate_position, _encounter_zone_b) or _overlaps_at_position(candidate_position, _encounter_zone_c) or _overlaps_at_position(candidate_position, _boss_gate_zone)


func _overlaps(a: Control, b: Control) -> bool:
	var a_rect: Rect2 = Rect2(a.position, a.size)
	var b_rect: Rect2 = Rect2(b.position, b.size)
	return a_rect.intersects(b_rect)


func _overlaps_at_position(candidate_position: Vector2, zone: Control) -> bool:
	var candidate_rect: Rect2 = Rect2(candidate_position, _player_token.size)
	var zone_rect: Rect2 = Rect2(zone.position, zone.size)
	return candidate_rect.intersects(zone_rect)


func _refresh_position_label() -> void:
	_position_value.text = "(%.0f, %.0f)" % [_player_token.position.x, _player_token.position.y]


func _set_status(value: String) -> void:
	_status_value.text = value


func _on_reset_level_pressed() -> void:
	_boss_defeated = false
	_boss_gate_required_wins = 0
	_boss_gate_current_wins = 0
	_ensure_boss_gate_setup()
	_player_token.position = Vector2(120.0, 120.0)
	_clamp_player_to_world()
	_refresh_boss_gate_status()
	_refresh_position_label()
	_refresh_last_encounter_label("Reset complete")
	_set_status("New run started. Clear %d encounters to open the boss gate." % _boss_gate_required_wins)


func _on_return_to_menu_pressed() -> void:
	var result: Error = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if result != OK:
		push_warning("TestLevelScene: Failed to return to main menu.")
