extends Control

const PLAYER_FLOW_SCENE_PATH: String = "res://src/gd/scenes/player/PlayerFlowScene.tscn"
const PLAYER_SPEED_PX_PER_SEC: float = 220.0
const WORLD_PADDING_PX: float = 24.0
const BOSS_GATE_MIN_WINS: int = 1
const BOSS_GATE_MAX_WINS: int = 3
const ENCOUNTER_ZONE_CONFIGS: Dictionary = {
	"EncounterZoneMeadow": {
		"label": "Meadow Tier I",
		"seed": 1107,
		"patterns": ["C4", "D4", "E4", "G4"]
	},
	"EncounterZoneCavern": {
		"label": "Cavern Tier II",
		"seed": 2209,
		"patterns": ["G4+A4", "A4/C5", "C4+E4+G4"],
		"type": "enemy"
	},
	"BossGateZone": {
		"label": "Boss Gate",
		"seed": 9201,
		"patterns": ["C4+E4+G4", "D4+F4+A4", "E4+G4+B4"],
		"type": "boss"
	}
}
# Reward values are initial tuning placeholders and should be adjusted by playtest data.
const ZONE_REWARD_CONFIGS: Dictionary = {
	"EncounterZoneMeadow": {
		"win_xp": 30,
		"loss_xp": 10,
		"win_shards": 2,
		"loss_shards": 1
	},
	"EncounterZoneCavern": {
		"win_xp": 55,
		"loss_xp": 20,
		"win_shards": 4,
		"loss_shards": 2
	}
}

@onready var _world_rect: ColorRect = %WorldRect
@onready var _player_token: ColorRect = %PlayerToken
@onready var _encounter_zone_meadow: ColorRect = %EncounterZoneMeadow
@onready var _encounter_zone_cavern: ColorRect = %EncounterZoneCavern
@onready var _boss_gate_zone: ColorRect = %BossGateZone
@onready var _checkpoint_zone: ColorRect = %CheckpointZone
@onready var _npc_guide_zone: ColorRect = %NpcGuideZone
@onready var _relic_zone: ColorRect = %ResonanceRelicZone
@onready var _status_value: Label = %StatusValue
@onready var _boss_gate_value: Label = %BossGateValue
@onready var _boss_status_value: Label = %BossStatusValue
@onready var _encounter_wins_value: Label = %EncounterWinsValue
@onready var _zone_value: Label = %ZoneValue
@onready var _position_value: Label = %PositionValue
@onready var _reward_value: Label = %RewardValue
@onready var _shards_value: Label = %ShardsValue
@onready var _interaction_hint_value: Label = %InteractionHintValue
@onready var _interaction_stats_value: Label = %InteractionStatsValue
@onready var _sink_telemetry_value: Label = %SinkTelemetryValue
@onready var _return_button: Button = %ReturnButton

var _audio_processor: Node
var _battle_manager: Node
var _game_state_manager: Node
var _local_data_manager: Node
var _battle_in_progress: bool = false
var _meadow_encounter_latched: bool = false
var _cavern_encounter_latched: bool = false
var _boss_encounter_latched: bool = false
var _checkpoint_latched: bool = false
var _previous_deterministic_enabled: bool = false
var _previous_deterministic_seed: int = 1337
var _previous_deterministic_patterns: PackedStringArray = PackedStringArray()
var _npc_interaction_count: int = 0
var _relic_interaction_count: int = 0
var _npc_guide_completed: bool = false
var _relic_completed: bool = false
var _resource_shards_total: int = 0
var _last_reward_summary: String = "No rewards claimed yet."
var _last_zone_reward_key: String = ""
var _last_zone_reward_xp: int = 0
var _last_zone_reward_shards: int = 0
var _boss_gate_required_wins: int = 0
var _boss_gate_current_wins: int = 0
var _boss_defeated: bool = false
var _shard_sink_small_spends: int = 0
var _shard_sink_large_spends: int = 0
var _shard_sink_total_spends: int = 0
var _shard_sink_total_shards_spent: int = 0
var _shard_sink_total_xp_gained: int = 0
var _shard_sink_last_choice: String = ""
var _active_encounter_zone_key: String = ""
var _last_pre_battle_checkpoint_id: String = ""
var _active_zone_label: String = "Neutral Field"
var _boss_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	UiSkinApplier.apply_to_scene(self, UiSkinApplier.load_default_skin())
	_audio_processor = get_node_or_null("/root/AudioProcessor")
	_battle_manager = get_node_or_null("/root/BattleManager")
	_game_state_manager = get_node_or_null("/root/GameStateManager")
	_local_data_manager = get_node_or_null("/root/LocalDataManager")
	_boss_rng.randomize()
	_cache_previous_battle_config()

	_return_button.pressed.connect(_on_return_button_pressed)
	if _battle_manager != null:
		if not _battle_manager.is_connected("battle_started", _on_battle_started):
			_battle_manager.connect("battle_started", _on_battle_started)
		if not _battle_manager.is_connected("battle_ended", _on_battle_ended):
			_battle_manager.connect("battle_ended", _on_battle_ended)

	call_deferred("_finalize_scene_state")


func _exit_tree() -> void:
	_restore_previous_battle_config()


func _process(delta: float) -> void:
	_move_player(delta)
	_refresh_position_label()
	_refresh_zone_label()
	_handle_encounter_overlap()
	_handle_checkpoint_overlap()
	_update_interaction_hint()
	_handle_interactions()


func _finalize_scene_state() -> void:
	_load_saved_spawn()
	_ensure_boss_gate_setup()
	_clamp_player_to_world()
	_sanitize_spawn_if_inside_encounter()
	_refresh_position_label()
	_refresh_zone_label()
	_refresh_interaction_stats()
	_refresh_reward_summary()
	_refresh_boss_gate_status()
	var cleared_stale_battle: bool = _clear_stale_battle_state_on_entry()
	if cleared_stale_battle:
		_set_status("Cleared stale battle state. Explore the field and step into an encounter zone when ready.")
	else:
		if _boss_defeated:
			_set_status("Boss defeated. Level complete.")
		else:
			_set_status("Explore the field. Win %d encounters to unlock the boss gate." % _boss_gate_required_wins)
	_update_interaction_hint()


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

	var meadow_overlaps: bool = _overlaps(_player_token, _encounter_zone_meadow)
	if meadow_overlaps:
		if not _meadow_encounter_latched:
			_meadow_encounter_latched = true
			_trigger_encounter_battle("EncounterZoneMeadow")
	else:
		_meadow_encounter_latched = false

	var cavern_overlaps: bool = _overlaps(_player_token, _encounter_zone_cavern)
	if cavern_overlaps:
		if not _cavern_encounter_latched:
			_cavern_encounter_latched = true
			_trigger_encounter_battle("EncounterZoneCavern")
	else:
		_cavern_encounter_latched = false

	var boss_overlaps: bool = _overlaps(_player_token, _boss_gate_zone)
	if boss_overlaps:
		if not _boss_encounter_latched:
			_boss_encounter_latched = true
			_trigger_encounter_battle("BossGateZone")
	else:
		_boss_encounter_latched = false


func _handle_checkpoint_overlap() -> void:
	var overlaps: bool = _overlaps(_player_token, _checkpoint_zone)
	if overlaps:
		if not _checkpoint_latched:
			_checkpoint_latched = true
			_save_current_spawn("checkpoint_a")
			_set_status("Checkpoint saved.")
	else:
		_checkpoint_latched = false


func _overlaps(a: Control, b: Control) -> bool:
	var a_rect: Rect2 = Rect2(a.position, a.size)
	var b_rect: Rect2 = Rect2(b.position, b.size)
	return a_rect.intersects(b_rect)


func _trigger_encounter_battle(zone_key: String) -> void:
	if _audio_processor == null:
		_set_status("Encounter reached, but AudioProcessor is missing.")
		return
	if zone_key == "BossGateZone":
		if _boss_defeated:
			_set_status("Boss already defeated. Level complete.")
			return
		if not _is_boss_unlocked():
			var remaining: int = max(_boss_gate_required_wins - _boss_gate_current_wins, 0)
			_set_status("Boss gate locked. Win %d more encounters." % remaining)
			return

	_save_pre_battle_checkpoint(zone_key)
	_apply_zone_encounter_tier(zone_key)
	_active_encounter_zone_key = zone_key
	var zone_label: String = _get_zone_label(zone_key)

	var is_capturing: bool = bool(_audio_processor.call("is_capturing"))
	if not is_capturing:
		_audio_processor.call("start_capture")
	elif _battle_manager != null:
		_battle_manager.call("stop_battle")
		_battle_manager.call("start_battle")

	_set_status("%s encounter triggered. Battle starting..." % zone_label)


func _apply_zone_encounter_tier(zone_key: String) -> void:
	if _battle_manager == null:
		return
	if not ENCOUNTER_ZONE_CONFIGS.has(zone_key):
		return

	var config: Dictionary = ENCOUNTER_ZONE_CONFIGS[zone_key] as Dictionary
	var seed: int = int(config.get("seed", 1337))
	var patterns: PackedStringArray = PackedStringArray()
	var raw_patterns: Variant = config.get("patterns", [])
	if raw_patterns is PackedStringArray:
		patterns = raw_patterns
	elif raw_patterns is Array:
		for pattern_value: Variant in raw_patterns:
			patterns.append(String(pattern_value))

	_battle_manager.call("configure_deterministic", true, seed, patterns)


func _get_zone_label(zone_key: String) -> String:
	if not ENCOUNTER_ZONE_CONFIGS.has(zone_key):
		return "Neutral"
	var config: Dictionary = ENCOUNTER_ZONE_CONFIGS[zone_key] as Dictionary
	return String(config.get("label", "Neutral"))


func _get_encounter_type(zone_key: String) -> String:
	if not ENCOUNTER_ZONE_CONFIGS.has(zone_key):
		return "enemy"
	var config: Dictionary = ENCOUNTER_ZONE_CONFIGS[zone_key] as Dictionary
	return String(config.get("type", "enemy"))


func _on_battle_started(_player_hp: int, _enemy_hp: int) -> void:
	_battle_in_progress = true
	_set_status("Battle in progress for %s. Hold position and sing the target note." % _active_zone_label)


func _on_battle_ended(result: String, turns: int) -> void:
	_battle_in_progress = false
	var encounter_type: String = _get_encounter_type(_active_encounter_zone_key)
	var reward_summary: String = ""
	if encounter_type != "boss":
		reward_summary = _grant_zone_rewards(result)

	if result == "Win" and encounter_type == "boss":
		_boss_defeated = true
		_set_status("Boss defeated. Level complete.")
		_save_current_spawn("boss_win", true)
		_refresh_boss_gate_status()
		_active_encounter_zone_key = ""
		return

	if result == "Win" and encounter_type != "boss":
		_boss_gate_current_wins += 1
		_save_current_spawn("enemy_win_%s" % _active_encounter_zone_key.to_lower(), true)
		_refresh_boss_gate_status()
		if _is_boss_unlocked():
			_set_status("Boss gate unlocked. Proceed to the boss zone.")
		else:
			var remaining: int = max(_boss_gate_required_wins - _boss_gate_current_wins, 0)
			_set_status("Encounter cleared. Win %d more encounters." % remaining)
	elif encounter_type != "boss":
		_set_status("Encounter lost. Win encounters to open the boss gate.")

	_save_current_spawn("post_battle", true)
	_last_pre_battle_checkpoint_id = ""
	if encounter_type != "boss" and not reward_summary.is_empty():
		_set_status("%s %s" % [_status_value.text, reward_summary])
	_active_encounter_zone_key = ""


func _save_pre_battle_checkpoint(zone_key: String) -> void:
	_last_pre_battle_checkpoint_id = "pre_battle_%s" % zone_key.to_lower()
	_save_current_spawn(_last_pre_battle_checkpoint_id)


func _load_saved_spawn() -> void:
	if _local_data_manager == null:
		return
	if not _local_data_manager.has_method("load_explore_state"):
		return

	var explore_state: Dictionary = _local_data_manager.call("load_explore_state") as Dictionary
	if explore_state == null or explore_state.is_empty():
		return

	_player_token.position = Vector2(
		float(explore_state.get("last_spawn_x", _player_token.position.x)),
		float(explore_state.get("last_spawn_y", _player_token.position.y))
	)
	_npc_interaction_count = int(explore_state.get("npc_interaction_count", 0))
	_relic_interaction_count = int(explore_state.get("relic_interaction_count", 0))
	_npc_guide_completed = bool(explore_state.get("npc_guide_completed", false))
	_relic_completed = bool(explore_state.get("relic_completed", false))
	_resource_shards_total = int(explore_state.get("resource_shards_total", 0))
	_last_reward_summary = String(explore_state.get("last_reward_summary", "No rewards claimed yet."))
	_last_zone_reward_key = String(explore_state.get("last_zone_reward_key", ""))
	_last_zone_reward_xp = int(explore_state.get("last_zone_reward_xp", 0))
	_last_zone_reward_shards = int(explore_state.get("last_zone_reward_shards", 0))
	_boss_gate_required_wins = int(explore_state.get("boss_gate_required_wins", 0))
	_boss_gate_current_wins = int(explore_state.get("boss_gate_current_wins", 0))
	_boss_defeated = bool(explore_state.get("boss_defeated", false))
	_shard_sink_small_spends = int(explore_state.get("shard_sink_small_spends", 0))
	_shard_sink_large_spends = int(explore_state.get("shard_sink_large_spends", 0))
	_shard_sink_total_spends = int(explore_state.get("shard_sink_total_spends", 0))
	_shard_sink_total_shards_spent = int(explore_state.get("shard_sink_total_shards_spent", 0))
	_shard_sink_total_xp_gained = int(explore_state.get("shard_sink_total_xp_gained", 0))
	_shard_sink_last_choice = String(explore_state.get("shard_sink_last_choice", ""))
	if _last_reward_summary.is_empty():
		_last_reward_summary = "No rewards claimed yet."


func _save_current_spawn(checkpoint_id: String, ensure_not_in_encounter: bool = false) -> void:
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
	payload["last_scene"] = "ExploreWorldScene"
	payload["last_checkpoint_id"] = checkpoint_id
	payload["npc_interaction_count"] = _npc_interaction_count
	payload["relic_interaction_count"] = _relic_interaction_count
	payload["npc_guide_completed"] = _npc_guide_completed
	payload["relic_completed"] = _relic_completed
	payload["resource_shards_total"] = _resource_shards_total
	payload["last_reward_summary"] = _last_reward_summary
	payload["last_zone_reward_key"] = _last_zone_reward_key
	payload["last_zone_reward_xp"] = _last_zone_reward_xp
	payload["last_zone_reward_shards"] = _last_zone_reward_shards
	payload["boss_gate_required_wins"] = _boss_gate_required_wins
	payload["boss_gate_current_wins"] = _boss_gate_current_wins
	payload["boss_defeated"] = _boss_defeated
	payload["shard_sink_small_spends"] = _shard_sink_small_spends
	payload["shard_sink_large_spends"] = _shard_sink_large_spends
	payload["shard_sink_total_spends"] = _shard_sink_total_spends
	payload["shard_sink_total_shards_spent"] = _shard_sink_total_shards_spent
	payload["shard_sink_total_xp_gained"] = _shard_sink_total_xp_gained
	payload["shard_sink_last_choice"] = _shard_sink_last_choice
	payload["last_updated_unix_sec"] = int(Time.get_unix_time_from_system())
	var saved: bool = bool(_local_data_manager.call("save_explore_state", payload))
	if not saved:
		push_warning("ExploreWorldScene: Failed to persist explore state.")


func _grant_zone_rewards(result: String) -> String:
	if _active_encounter_zone_key.is_empty():
		return ""
	if not ZONE_REWARD_CONFIGS.has(_active_encounter_zone_key):
		_active_encounter_zone_key = ""
		return ""

	var config: Dictionary = ZONE_REWARD_CONFIGS[_active_encounter_zone_key] as Dictionary
	var is_win: bool = result == "Win"
	var xp_bonus: int = int(config.get("win_xp", 0)) if is_win else int(config.get("loss_xp", 0))
	var shard_drop: int = int(config.get("win_shards", 0)) if is_win else int(config.get("loss_shards", 0))

	if xp_bonus > 0:
		var reward_saved: bool = _apply_exploration_xp_bonus(xp_bonus)
		if not reward_saved:
			push_warning("ExploreWorldScene: Failed to persist exploration XP reward.")
			xp_bonus = 0

	_resource_shards_total += shard_drop
	_last_zone_reward_key = _active_encounter_zone_key
	_last_zone_reward_xp = xp_bonus
	_last_zone_reward_shards = shard_drop
	var zone_label: String = _get_zone_label(_active_encounter_zone_key)
	_last_reward_summary = "%s reward: +%d XP, +%d shards." % [zone_label, xp_bonus, shard_drop]
	_refresh_reward_summary()

	_active_encounter_zone_key = ""
	return _last_reward_summary


func _apply_exploration_xp_bonus(xp_bonus: int) -> bool:
	if xp_bonus <= 0:
		return true

	if _game_state_manager != null and _game_state_manager.has_method("grant_exploration_rewards"):
		return bool(_game_state_manager.call("grant_exploration_rewards", xp_bonus))

	if _local_data_manager != null:
		if _local_data_manager.has_method("load_profile") and _local_data_manager.has_method("save_profile"):
			var profile: Dictionary = _local_data_manager.call("load_profile") as Dictionary
			if profile == null or profile.is_empty():
				return false
			profile["xp_total"] = int(profile.get("xp_total", 0)) + xp_bonus
			profile["last_updated_unix_sec"] = int(Time.get_unix_time_from_system())
			return bool(_local_data_manager.call("save_profile", profile))

	return false


func _refresh_zone_label() -> void:
	if _overlaps(_player_token, _boss_gate_zone):
		_active_zone_label = _get_zone_label("BossGateZone")
	elif _overlaps(_player_token, _encounter_zone_cavern):
		_active_zone_label = _get_zone_label("EncounterZoneCavern")
	elif _overlaps(_player_token, _encounter_zone_meadow):
		_active_zone_label = _get_zone_label("EncounterZoneMeadow")
	else:
		_active_zone_label = "Neutral Field"
	_zone_value.text = _active_zone_label


func _update_interaction_hint() -> void:
	if _battle_in_progress:
		_interaction_hint_value.text = "Interactions disabled during battle."
		return
	if _overlaps(_player_token, _npc_guide_zone):
		if _npc_guide_completed:
			_interaction_hint_value.text = "Press Enter to revisit Guide NPC dialogue."
		else:
			_interaction_hint_value.text = "Press Enter to talk to Guide NPC (first-time completion reward)."
		return
	if _overlaps(_player_token, _relic_zone):
		if _relic_completed:
			_interaction_hint_value.text = "Press Enter to re-check the Resonance Relic."
		else:
			_interaction_hint_value.text = "Press Enter to inspect Resonance Relic (first-time completion reward)."
		return
	_interaction_hint_value.text = "Move near the Guide NPC or Relic, then press Enter."


func _handle_interactions() -> void:
	if _battle_in_progress:
		return
	if not Input.is_action_just_pressed("ui_accept"):
		return

	if _overlaps(_player_token, _npc_guide_zone):
		_npc_interaction_count += 1
		if not _npc_guide_completed:
			_npc_guide_completed = true
			_resource_shards_total += 1
			_last_reward_summary = "Guide NPC completion reward: +1 shard."
			_set_status("Guide NPC: Try the Meadow tier before the Cavern tier. You earned +1 shard.")
		else:
			_set_status("Guide NPC: Try the Meadow tier before the Cavern tier.")
		_save_current_spawn("npc_guide")
		_refresh_interaction_stats()
		_refresh_reward_summary()
		return

	if _overlaps(_player_token, _relic_zone):
		_relic_interaction_count += 1
		if not _relic_completed:
			_relic_completed = true
			_resource_shards_total += 2
			_last_reward_summary = "Resonance Relic completion reward: +2 shards."
			_set_status("Resonance Relic: Ancient harmonics resonate through the field. You recovered +2 shards.")
		else:
			_set_status("Resonance Relic: Ancient harmonics resonate through the field.")
		_save_current_spawn("relic_site")
		_refresh_interaction_stats()
		_refresh_reward_summary()


func _refresh_interaction_stats() -> void:
	_interaction_stats_value.text = "NPC talks: %d (%s) | Relic checks: %d (%s)" % [
		_npc_interaction_count,
		"complete" if _npc_guide_completed else "incomplete",
		_relic_interaction_count,
		"complete" if _relic_completed else "incomplete"
	]
	_refresh_boss_gate_status()


func _refresh_reward_summary() -> void:
	_reward_value.text = _last_reward_summary
	_shards_value.text = "%d" % _resource_shards_total
	_refresh_sink_telemetry_summary()
	_refresh_boss_gate_status()


func _ensure_boss_gate_setup() -> void:
	if _boss_defeated:
		return
	if _boss_gate_required_wins > 0:
		return
	_boss_gate_required_wins = _boss_rng.randi_range(BOSS_GATE_MIN_WINS, BOSS_GATE_MAX_WINS)
	_boss_gate_current_wins = 0
	_save_current_spawn("boss_gate_init", true)


func _is_boss_unlocked() -> bool:
	return _boss_gate_required_wins > 0 and _boss_gate_current_wins >= _boss_gate_required_wins


func _refresh_boss_gate_status() -> void:
	_boss_gate_value.text = "%d / %d" % [_boss_gate_current_wins, _boss_gate_required_wins]
	_encounter_wins_value.text = "%d" % _boss_gate_current_wins
	if _boss_defeated:
		_boss_status_value.text = "Defeated"
		return
	if _is_boss_unlocked():
		_boss_status_value.text = "Unlocked"
	else:
		_boss_status_value.text = "Locked"


func _refresh_sink_telemetry_summary() -> void:
	var last_choice_label: String = "none"
	if _shard_sink_last_choice == "small":
		last_choice_label = "focus"
	elif _shard_sink_last_choice == "large":
		last_choice_label = "surge"

	_sink_telemetry_value.text = "Sinks: total %d | focus %d | surge %d | spent %d shards -> %d XP | last %s" % [
		_shard_sink_total_spends,
		_shard_sink_small_spends,
		_shard_sink_large_spends,
		_shard_sink_total_shards_spent,
		_shard_sink_total_xp_gained,
		last_choice_label
	]


func _cache_previous_battle_config() -> void:
	if _battle_manager == null:
		return
	if not _battle_manager.has_method("get_deterministic_mode"):
		return
	if not _battle_manager.has_method("get_deterministic_seed"):
		return
	if not _battle_manager.has_method("get_forced_target_patterns"):
		return

	_previous_deterministic_enabled = bool(_battle_manager.call("get_deterministic_mode"))
	_previous_deterministic_seed = int(_battle_manager.call("get_deterministic_seed"))
	var raw_patterns: Variant = _battle_manager.call("get_forced_target_patterns")
	_previous_deterministic_patterns = PackedStringArray()
	if raw_patterns is PackedStringArray:
		_previous_deterministic_patterns = raw_patterns
	elif raw_patterns is Array:
		for pattern_value: Variant in raw_patterns:
			_previous_deterministic_patterns.append(String(pattern_value))


func _restore_previous_battle_config() -> void:
	if _battle_manager == null:
		return
	if not _battle_manager.has_method("configure_deterministic"):
		return
	_battle_manager.call(
		"configure_deterministic",
		_previous_deterministic_enabled,
		_previous_deterministic_seed,
		_previous_deterministic_patterns
	)


func _on_return_button_pressed() -> void:
	if _battle_in_progress:
		_set_status("Exited during battle. Pre-battle exploration checkpoint preserved.")
	else:
		_save_current_spawn("manual_return", true)
	var result: Error = get_tree().change_scene_to_file(PLAYER_FLOW_SCENE_PATH)
	if result != OK:
		push_warning("ExploreWorldScene: Failed to return to PlayerFlowScene.")


func _set_status(value: String) -> void:
	_status_value.text = value


func _refresh_position_label() -> void:
	_position_value.text = "(%.0f, %.0f)" % [_player_token.position.x, _player_token.position.y]


func _sanitize_spawn_if_inside_encounter() -> void:
	if not _is_inside_any_encounter_zone_at_position(_player_token.position):
		return

	_player_token.position = _get_safe_spawn_position()
	_clamp_player_to_world()
	_save_current_spawn("spawn_sanitized", true)


func _clear_stale_battle_state_on_entry() -> bool:
	if _battle_manager == null:
		_battle_in_progress = false
		return false

	if not bool(_battle_manager.call("is_battle_active")):
		_battle_in_progress = false
		return false

	_battle_manager.call("stop_battle")
	_battle_in_progress = bool(_battle_manager.call("is_battle_active"))
	return not _battle_in_progress


func _is_inside_any_encounter_zone_at_position(candidate_position: Vector2) -> bool:
	return _overlaps_at_position(candidate_position, _encounter_zone_meadow) or _overlaps_at_position(candidate_position, _encounter_zone_cavern) or _overlaps_at_position(candidate_position, _boss_gate_zone)


func _overlaps_at_position(candidate_position: Vector2, zone: Control) -> bool:
	var candidate_rect: Rect2 = Rect2(candidate_position, _player_token.size)
	var zone_rect: Rect2 = Rect2(zone.position, zone.size)
	return candidate_rect.intersects(zone_rect)


func _get_safe_spawn_position() -> Vector2:
	var checkpoint_based_spawn: Vector2 = _checkpoint_zone.position + ((_checkpoint_zone.size - _player_token.size) * 0.5)
	if not _is_inside_any_encounter_zone_at_position(checkpoint_based_spawn):
		return _clamp_position_to_world(checkpoint_based_spawn)

	var fallback_spawn: Vector2 = Vector2(120.0, 120.0)
	return _clamp_position_to_world(fallback_spawn)


func _clamp_position_to_world(position: Vector2) -> Vector2:
	var min_position: Vector2 = Vector2(WORLD_PADDING_PX, WORLD_PADDING_PX)
	var max_position: Vector2 = _world_rect.size - _player_token.size - Vector2(WORLD_PADDING_PX, WORLD_PADDING_PX)
	max_position.x = max(max_position.x, min_position.x)
	max_position.y = max(max_position.y, min_position.y)
	return position.clamp(min_position, max_position)
