extends Control

const EXPLORE_WORLD_SCENE_PATH: String = "res://src/gd/scenes/world/ExploreWorldScene.tscn"
const SHARD_SINK_SMALL_COST: int = 5
const SHARD_SINK_SMALL_XP_GAIN: int = 35
const SHARD_SINK_LARGE_COST: int = 12
const SHARD_SINK_LARGE_XP_GAIN: int = 100
const SHARD_SINK_SURGE_MIN_LEVEL: int = 2
const SHARD_SINK_SURGE_EARLY_MULTIPLIER: float = 0.6

@onready var _note_value_label: Label = %NoteValue
@onready var _frequency_value_label: Label = %FrequencyValue
@onready var _confidence_value_label: Label = %ConfidenceValue
@onready var _input_level_value_label: Label = %InputLevelValue
@onready var _noise_floor_value_label: Label = %NoiseFloorValue
@onready var _threshold_value_label: Label = %ThresholdValue
@onready var _status_value_label: Label = %StatusValue
@onready var _target_prompt_value_label: Label = %TargetPromptValue
@onready var _hit_feedback_value_label: Label = %HitFeedbackValue
@onready var _battle_summary_value_label: Label = %BattleSummaryValue
@onready var _session_summary_value_label: Label = %SessionSummaryValue
@onready var _exploration_summary_value_label: Label = %ExplorationSummaryValue
@onready var _shard_sink_status_value_label: Label = %ShardSinkStatusValue
@onready var _shard_sink_telemetry_value_label: Label = %ShardSinkTelemetryValue
@onready var _spend_shards_button: Button = %SpendShardsButton
@onready var _spend_shards_surge_button: Button = %SpendShardsSurgeButton
@onready var _toggle_button: Button = %ToggleRecordingButton
@onready var _explore_world_button: Button = %ExploreWorldButton

var _audio_processor: Node
var _battle_manager: Node
var _game_state_manager: Node
var _local_data_manager: Node
var _cached_explore_state: Dictionary = {}


func _ready() -> void:
	UiSkinApplier.apply_to_scene(self, UiSkinApplier.load_default_skin())
	_explore_world_button.pressed.connect(_on_explore_world_pressed)
	_spend_shards_button.pressed.connect(_on_spend_shards_pressed)
	_spend_shards_surge_button.pressed.connect(_on_spend_shards_surge_pressed)
	_audio_processor = _resolve_audio_processor()
	_battle_manager = _resolve_battle_manager()
	_game_state_manager = _resolve_game_state_manager()
	_local_data_manager = _resolve_local_data_manager()
	_connect_battle_signals()
	_connect_game_state_signals()
	_refresh_exploration_state()
	_refresh_session_summary()
	_refresh_battle_summary()
	if _audio_processor == null:
		_toggle_button.disabled = true
		_status_value_label.text = "AudioProcessor missing"
		return

	_toggle_button.pressed.connect(_on_toggle_recording_pressed)
	_connect_audio_signals()
	_sync_toggle_button()
	_refresh_from_processor()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F8:
			_on_explore_world_pressed()


func _process(_delta: float) -> void:
	if _audio_processor == null:
		_audio_processor = _resolve_audio_processor()
		if _audio_processor == null:
			_refresh_battle_summary()
			return
		_connect_audio_signals()
		_toggle_button.disabled = false
	if _battle_manager == null:
		_battle_manager = _resolve_battle_manager()
		_connect_battle_signals()
	if _game_state_manager == null:
		_game_state_manager = _resolve_game_state_manager()
		_connect_game_state_signals()
		_refresh_session_summary()
	if _local_data_manager == null:
		_local_data_manager = _resolve_local_data_manager()
		if _local_data_manager != null:
			_refresh_exploration_state()
	_refresh_from_processor()
	_refresh_battle_summary()


func _resolve_audio_processor() -> Node:
	return get_node_or_null("/root/AudioProcessor")


func _resolve_battle_manager() -> Node:
	return get_node_or_null("/root/BattleManager")


func _resolve_game_state_manager() -> Node:
	return get_node_or_null("/root/GameStateManager")


func _resolve_local_data_manager() -> Node:
	return get_node_or_null("/root/LocalDataManager")


func _connect_audio_signals() -> void:
	if not _audio_processor.is_connected("note_detected", _on_note_detected):
		_audio_processor.connect("note_detected", _on_note_detected)
	if not _audio_processor.is_connected("capture_state_changed", _on_capture_state_changed):
		_audio_processor.connect("capture_state_changed", _on_capture_state_changed)
	if not _audio_processor.is_connected("input_level_changed", _on_input_level_changed):
		_audio_processor.connect("input_level_changed", _on_input_level_changed)


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


func _connect_game_state_signals() -> void:
	if _game_state_manager == null:
		return
	if not _game_state_manager.is_connected("progression_updated", _on_progression_updated):
		_game_state_manager.connect("progression_updated", _on_progression_updated)
	if not _game_state_manager.is_connected("battle_session_committed", _on_battle_session_committed):
		_game_state_manager.connect("battle_session_committed", _on_battle_session_committed)


func _on_toggle_recording_pressed() -> void:
	if _audio_processor == null:
		return
	if bool(_audio_processor.call("is_capturing")):
		_audio_processor.call("stop_capture")
	else:
		_audio_processor.call("start_capture")
	_sync_toggle_button()


func _on_note_detected(frequency: float, note_name: String, confidence: float) -> void:
	_frequency_value_label.text = "%.2f Hz" % frequency if frequency > 0.0 else "-- Hz"
	_note_value_label.text = note_name
	_confidence_value_label.text = "%.2f" % confidence


func _on_capture_state_changed(_is_capturing: bool) -> void:
	_sync_toggle_button()


func _on_input_level_changed(level_db: float) -> void:
	_input_level_value_label.text = "%.1f dB" % level_db


func _on_explore_world_pressed() -> void:
	var result: Error = get_tree().change_scene_to_file(EXPLORE_WORLD_SCENE_PATH)
	if result != OK:
		push_warning("PlayerHudScene: Failed to open explore world scene.")


func _on_battle_started(player_hp: int, enemy_hp: int) -> void:
	_hit_feedback_value_label.text = "Battle started. Match the target note."
	_update_battle_summary_text(0, player_hp, enemy_hp, 0.0)


func _on_turn_started(target_note: String, turn_index: int, time_limit_sec: float) -> void:
	_target_prompt_value_label.text = target_note
	_hit_feedback_value_label.text = "Listen and sing the target note."
	var player_hp: int = int(_battle_manager.call("get_player_hp")) if _battle_manager != null else 0
	var enemy_hp: int = int(_battle_manager.call("get_enemy_hp")) if _battle_manager != null else 0
	_update_battle_summary_text(turn_index, player_hp, enemy_hp, time_limit_sec)


func _on_turn_resolved(target_note: String, detected_note: String, grade: String, player_hp: int, enemy_hp: int) -> void:
	_target_prompt_value_label.text = target_note
	_hit_feedback_value_label.text = "%s | target %s | detected %s" % [grade, target_note, detected_note]
	var turn_index: int = int(_battle_manager.call("get_turn_index")) if _battle_manager != null else 0
	var time_left: float = float(_battle_manager.call("get_turn_time_left")) if _battle_manager != null else 0.0
	_update_battle_summary_text(turn_index, player_hp, enemy_hp, time_left)


func _on_battle_ended(result: String, turns: int) -> void:
	_target_prompt_value_label.text = "--"
	_hit_feedback_value_label.text = "Battle %s in %d turns" % [result, turns]
	var player_hp: int = int(_battle_manager.call("get_player_hp")) if _battle_manager != null else 0
	var enemy_hp: int = int(_battle_manager.call("get_enemy_hp")) if _battle_manager != null else 0
	_update_battle_summary_text(turns, player_hp, enemy_hp, 0.0)


func _on_progression_updated(profile: Dictionary, level_progress: Dictionary) -> void:
	_refresh_session_summary_from_data(profile, level_progress)


func _on_battle_session_committed(result: String, session_id: String, xp_gained: int) -> void:
	var profile: Dictionary = _game_state_manager.call("get_profile") as Dictionary if _game_state_manager != null else {}
	var level_progress: Dictionary = _game_state_manager.call("get_level_progress") as Dictionary if _game_state_manager != null else {}
	var event_summary: String = "Last: %s | XP +%d | Session %s" % [result, xp_gained, session_id]
	_refresh_session_summary_from_data(profile, level_progress, event_summary)


func _on_spend_shards_pressed() -> void:
	_execute_shard_sink(
		SHARD_SINK_SMALL_COST,
		SHARD_SINK_SMALL_XP_GAIN,
		"small",
		"Focus attunement"
	)


func _on_spend_shards_surge_pressed() -> void:
	_execute_shard_sink(
		SHARD_SINK_LARGE_COST,
		SHARD_SINK_LARGE_XP_GAIN,
		"large",
		"Surge attunement"
	)


func _execute_shard_sink(cost: int, xp_gain: int, sink_key: String, sink_label: String) -> void:
	if _local_data_manager == null or not _local_data_manager.has_method("load_explore_state"):
		_shard_sink_status_value_label.text = "Shard sink unavailable: LocalDataManager missing."
		return
	if _game_state_manager == null or not _game_state_manager.has_method("grant_exploration_rewards"):
		_shard_sink_status_value_label.text = "Shard sink unavailable: GameStateManager missing."
		return

	var explore_state: Dictionary = _local_data_manager.call("load_explore_state") as Dictionary
	if explore_state == null or explore_state.is_empty():
		_shard_sink_status_value_label.text = "Shard sink unavailable: Explore state not ready."
		return

	var shard_total: int = int(explore_state.get("resource_shards_total", 0))
	if shard_total < cost:
		_shard_sink_status_value_label.text = "Need %d shards (%d/%d)." % [cost, shard_total, cost]
		_update_spend_button_state(shard_total)
		return

	var effective_xp_gain: int = xp_gain
	var guardrail_note: String = ""
	if sink_key == "large":
		effective_xp_gain = _compute_surge_xp_gain(xp_gain)
		if effective_xp_gain < xp_gain:
			guardrail_note = " (reduced until L%d)" % SHARD_SINK_SURGE_MIN_LEVEL

	explore_state["resource_shards_total"] = shard_total - cost
	explore_state["last_reward_summary"] = "%s: -%d shards, +%d XP%s." % [
		sink_label,
		cost,
		effective_xp_gain,
		guardrail_note
	]
	if sink_key == "small":
		explore_state["shard_sink_small_spends"] = int(explore_state.get("shard_sink_small_spends", 0)) + 1
	elif sink_key == "large":
		explore_state["shard_sink_large_spends"] = int(explore_state.get("shard_sink_large_spends", 0)) + 1
	explore_state["shard_sink_total_spends"] = int(explore_state.get("shard_sink_total_spends", 0)) + 1
	explore_state["shard_sink_total_shards_spent"] = int(explore_state.get("shard_sink_total_shards_spent", 0)) + cost
	explore_state["shard_sink_total_xp_gained"] = int(explore_state.get("shard_sink_total_xp_gained", 0)) + effective_xp_gain
	explore_state["shard_sink_last_choice"] = sink_key
	explore_state["last_updated_unix_sec"] = int(Time.get_unix_time_from_system())
	var explore_saved: bool = bool(_local_data_manager.call("save_explore_state", explore_state))
	if not explore_saved:
		_shard_sink_status_value_label.text = "Failed to persist shard spend."
		return

	var xp_saved: bool = bool(_game_state_manager.call("grant_exploration_rewards", effective_xp_gain))
	if not xp_saved:
		_shard_sink_status_value_label.text = "Shards spent, but XP grant failed."
		return

	_cached_explore_state = explore_state.duplicate(true)
	_shard_sink_status_value_label.text = "%s complete: -%d shards, +%d XP%s." % [
		sink_label,
		cost,
		effective_xp_gain,
		guardrail_note
	]
	var profile: Dictionary = _game_state_manager.call("get_profile") as Dictionary if _game_state_manager != null else {}
	var level_progress: Dictionary = _game_state_manager.call("get_level_progress") as Dictionary if _game_state_manager != null else {}
	_refresh_session_summary_from_data(profile, level_progress)


func _sync_toggle_button() -> void:
	if _audio_processor == null:
		_toggle_button.text = "Start Listening"
		_toggle_button.disabled = true
		return
	_toggle_button.disabled = false
	_toggle_button.text = "Stop Listening" if bool(_audio_processor.call("is_capturing")) else "Start Listening"


func _refresh_from_processor() -> void:
	if _audio_processor == null:
		return

	_note_value_label.text = String(_audio_processor.call("get_detected_note"))
	_frequency_value_label.text = "%.2f Hz" % float(_audio_processor.call("get_detected_frequency"))
	_confidence_value_label.text = "%.2f" % float(_audio_processor.call("get_detected_confidence"))
	_input_level_value_label.text = "%.1f dB" % float(_audio_processor.call("get_input_level_db"))

	if _audio_processor.has_method("get_noise_floor_db"):
		_noise_floor_value_label.text = "%.1f dB" % float(_audio_processor.call("get_noise_floor_db"))
	else:
		_noise_floor_value_label.text = "-- dB"

	if _audio_processor.has_method("get_effective_min_signal_db"):
		_threshold_value_label.text = "%.1f dB" % float(_audio_processor.call("get_effective_min_signal_db"))
	else:
		_threshold_value_label.text = "-- dB"

	if _audio_processor.has_method("get_status_text"):
		_status_value_label.text = String(_audio_processor.call("get_status_text"))


func _refresh_battle_summary() -> void:
	if _battle_manager == null:
		_battle_summary_value_label.text = "Battle manager unavailable"
		return

	var is_active: bool = bool(_battle_manager.call("is_battle_active"))
	if not is_active:
		if _target_prompt_value_label.text.is_empty() or _target_prompt_value_label.text == "--":
			_target_prompt_value_label.text = "--"
		var player_hp_idle: int = int(_battle_manager.call("get_player_hp"))
		var enemy_hp_idle: int = int(_battle_manager.call("get_enemy_hp"))
		_update_battle_summary_text(int(_battle_manager.call("get_turn_index")), player_hp_idle, enemy_hp_idle, 0.0)
		return

	_target_prompt_value_label.text = String(_battle_manager.call("get_target_note"))
	_update_battle_summary_text(
		int(_battle_manager.call("get_turn_index")),
		int(_battle_manager.call("get_player_hp")),
		int(_battle_manager.call("get_enemy_hp")),
		float(_battle_manager.call("get_turn_time_left"))
	)


func _update_battle_summary_text(turn_index: int, player_hp: int, enemy_hp: int, time_left_sec: float) -> void:
	_battle_summary_value_label.text = "Turn %d | Player HP %d | Enemy HP %d | Time %.1fs" % [
		turn_index,
		player_hp,
		enemy_hp,
		max(time_left_sec, 0.0)
	]


func _refresh_session_summary() -> void:
	if _game_state_manager == null:
		_session_summary_value_label.text = "Profile unavailable"
		_exploration_summary_value_label.text = "Exploration: unavailable"
		return
	_refresh_exploration_state()
	var profile: Dictionary = _game_state_manager.call("get_profile") as Dictionary
	var level_progress: Dictionary = _game_state_manager.call("get_level_progress") as Dictionary
	_refresh_session_summary_from_data(profile, level_progress)


func _refresh_session_summary_from_data(profile: Dictionary, level_progress: Dictionary, event_summary: String = "") -> void:
	var xp_total: int = int(profile.get("xp_total", 0))
	var battles: int = int(profile.get("battles_played", 0))
	var wins: int = int(profile.get("wins", 0))
	var losses: int = int(profile.get("losses", 0))
	var level_index: int = int(level_progress.get("current_level_index", 1))
	var shard_total: int = int(_cached_explore_state.get("resource_shards_total", 0))
	var last_reward_summary: String = String(_cached_explore_state.get("last_reward_summary", "No exploration rewards yet."))
	var shard_sink_telemetry: String = _build_sink_telemetry_text(_cached_explore_state)
	if last_reward_summary.is_empty():
		last_reward_summary = "No exploration rewards yet."
	_session_summary_value_label.text = "XP %d | Battles %d (W:%d L:%d) | Level L%d" % [
		xp_total,
		battles,
		wins,
		losses,
		level_index
	]
	_exploration_summary_value_label.text = "Exploration: Shards %d | %s" % [
		shard_total,
		last_reward_summary
	]
	_shard_sink_telemetry_value_label.text = shard_sink_telemetry
	_update_spend_button_state(shard_total)
	if not event_summary.is_empty():
		_session_summary_value_label.text += "\n%s" % event_summary


func _refresh_exploration_state() -> void:
	if _local_data_manager == null or not _local_data_manager.has_method("load_explore_state"):
		_cached_explore_state = {}
		_exploration_summary_value_label.text = "Exploration: unavailable"
		_shard_sink_telemetry_value_label.text = "Sinks: unavailable"
		_update_spend_button_state(0)
		return

	var explore_state: Dictionary = _local_data_manager.call("load_explore_state") as Dictionary
	if explore_state == null:
		explore_state = {}
	_cached_explore_state = explore_state.duplicate(true)


func _update_spend_button_state(shard_total: int) -> void:
	var has_small_shards: bool = shard_total >= SHARD_SINK_SMALL_COST
	var has_large_shards: bool = shard_total >= SHARD_SINK_LARGE_COST
	var level_index: int = _get_current_level_index()
	var surge_guardrail_note: String = ""
	if level_index < SHARD_SINK_SURGE_MIN_LEVEL:
		surge_guardrail_note = " (reduced until L%d)" % SHARD_SINK_SURGE_MIN_LEVEL
	_spend_shards_button.disabled = not has_small_shards
	_spend_shards_surge_button.disabled = not has_large_shards
	_spend_shards_button.text = "Spend %d Shards -> +%d XP (Focus)" % [SHARD_SINK_SMALL_COST, SHARD_SINK_SMALL_XP_GAIN]
	_spend_shards_surge_button.text = "Spend %d Shards -> +%d XP (Surge%s)" % [
		SHARD_SINK_LARGE_COST,
		SHARD_SINK_LARGE_XP_GAIN,
		surge_guardrail_note
	]

	if has_large_shards:
		if _shard_sink_status_value_label.text.begins_with("Need "):
			if surge_guardrail_note.is_empty():
				_shard_sink_status_value_label.text = "All sink options ready."
			else:
				_shard_sink_status_value_label.text = "All sink options ready. Surge XP reduced until Level %d." % SHARD_SINK_SURGE_MIN_LEVEL
		return

	if has_small_shards:
		if _shard_sink_status_value_label.text.begins_with("Need "):
			_shard_sink_status_value_label.text = "Focus sink ready. Need %d shards for surge sink (%d/%d)." % [
				SHARD_SINK_LARGE_COST,
				shard_total,
				SHARD_SINK_LARGE_COST
			]
		return

	_shard_sink_status_value_label.text = "Need %d shards for focus sink (%d/%d)." % [
		SHARD_SINK_SMALL_COST,
		shard_total,
		SHARD_SINK_SMALL_COST
	]


func _compute_surge_xp_gain(base_gain: int) -> int:
	var level_index: int = _get_current_level_index()
	if level_index >= SHARD_SINK_SURGE_MIN_LEVEL:
		return base_gain
	return max(1, int(round(float(base_gain) * SHARD_SINK_SURGE_EARLY_MULTIPLIER)))


func _get_current_level_index() -> int:
	if _game_state_manager == null or not _game_state_manager.has_method("get_level_progress"):
		return 1
	var level_progress: Dictionary = _game_state_manager.call("get_level_progress") as Dictionary
	return int(level_progress.get("current_level_index", 1))


func _build_sink_telemetry_text(explore_state: Dictionary) -> String:
	var total_spends: int = int(explore_state.get("shard_sink_total_spends", 0))
	var small_spends: int = int(explore_state.get("shard_sink_small_spends", 0))
	var large_spends: int = int(explore_state.get("shard_sink_large_spends", 0))
	var total_shards_spent: int = int(explore_state.get("shard_sink_total_shards_spent", 0))
	var total_xp_gained: int = int(explore_state.get("shard_sink_total_xp_gained", 0))
	var last_choice: String = String(explore_state.get("shard_sink_last_choice", ""))
	var last_choice_label: String = "none"
	if last_choice == "small":
		last_choice_label = "focus"
	elif last_choice == "large":
		last_choice_label = "surge"

	return "Sinks: total %d | focus %d | surge %d | spent %d shards -> %d XP | last %s" % [
		total_spends,
		small_spends,
		large_spends,
		total_shards_spent,
		total_xp_gained,
		last_choice_label
	]
