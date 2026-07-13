extends Control

const PRACTICE_SETUP_SCENE_PATH: String = "res://src/gd/scenes/practice/PracticeSetupScene.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://src/gd/scenes/menu/MainMenuScene.tscn"
const AUDIO_PROCESSOR_PATH: String = "/root/AudioProcessor"
const BATTLE_MANAGER_PATH: String = "/root/BattleManager"
const LOCAL_DATA_MANAGER_PATH: String = "/root/LocalDataManager"
const PLAYER_MAX_HP: int = 100
const ENEMY_MAX_HP: int = 100

# Octave match modes (kept in sync with LocalDataManager constants).
const OCTAVE_MODE_PITCH_CLASS: String = "pitch_class"
const OCTAVE_MODE_EXACT_OCTAVE: String = "exact_octave"
const OCTAVE_MODE_DEFAULT: String = OCTAVE_MODE_PITCH_CLASS
# Cents labels for the OptionButton items.
const MATCH_MODE_LABELS: PackedStringArray = ["Pitch Class", "Exact Octave"]

@onready var _player_hp_bar: ProgressBar = %PlayerHpBar
@onready var _enemy_hp_bar: ProgressBar = %EnemyHpBar
@onready var _player_hp_label: Label = %PlayerHpLabel
@onready var _enemy_hp_label: Label = %EnemyHpLabel
@onready var _target_note_label: Label = %TargetNoteLabel
@onready var _detected_note_label: Label = %DetectedNoteLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _status_label: Label = %StatusLabel
@onready var _time_left_bar: ProgressBar = %TimeLeftBar
@onready var _meter_target_label: Label = %MeterTargetLabel
@onready var _meter_detected_label: Label = %MeterDetectedLabel
@onready var _live_hold_label: Label = %LiveHoldLabel
@onready var _spectrum_graph: Control = %SpectrumGraph
@onready var _octave_match_mode_button: OptionButton = %OctaveMatchModeButton
@onready var _meter_status_label: Label = %MeterStatusLabel
@onready var _mic_toggle_button: Button = %MicToggleButton
@onready var _retry_button: Button = %RetryButton
@onready var _back_to_notes_button: Button = %BackToNotesButton
@onready var _exit_button: Button = %ExitButton

var _audio_processor: Node
var _battle_manager: Node
var _local_data_manager: Node
var _selected_note: String = ""
# Turn time limit applied by BattleManager for this practice session.
# Updated from the turn_started signal; 0 means the manager used its default.
var _turn_time_limit_sec: float = 0.0
# Frequency-meter state.
var _target_frequency_hz: float = 0.0
var _octave_match_mode: String = OCTAVE_MODE_DEFAULT
var _last_detected_hz: float = 0.0
var _last_cents_offset: float = 0.0


func _ready() -> void:
	_audio_processor = get_node_or_null(AUDIO_PROCESSOR_PATH)
	_battle_manager = get_node_or_null(BATTLE_MANAGER_PATH)
	_local_data_manager = get_node_or_null(LOCAL_DATA_MANAGER_PATH)

	_mic_toggle_button.pressed.connect(_on_mic_toggle_pressed)
	_retry_button.pressed.connect(_on_retry_pressed)
	_back_to_notes_button.pressed.connect(_on_back_to_notes_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_octave_match_mode_button.item_selected.connect(_on_octave_match_mode_selected)

	_connect_audio_signals()
	_connect_battle_signals()
	_initialize_battle_view()
	_initialize_meter()
	call_deferred("_begin_practice_battle")


func _process(_delta: float) -> void:
	_update_time_left_bar()


func _initialize_battle_view() -> void:
	_player_hp_bar.max_value = PLAYER_MAX_HP
	_enemy_hp_bar.max_value = ENEMY_MAX_HP
	_player_hp_bar.value = PLAYER_MAX_HP
	_enemy_hp_bar.value = ENEMY_MAX_HP
	_player_hp_label.text = "HARM • %d / %d" % [PLAYER_MAX_HP, PLAYER_MAX_HP]
	_enemy_hp_label.text = "SLIME • %d / %d" % [ENEMY_MAX_HP, ENEMY_MAX_HP]
	_detected_note_label.text = "--"
	_feedback_label.text = "Select a steady pitch and hold the target note."
	_status_label.text = "Preparing practice battle..."
	_retry_button.disabled = true
	_time_left_bar.value = 100.0
	if _battle_manager != null and _battle_manager.has_method("get_practice_turn_time"):
		_turn_time_limit_sec = float(_battle_manager.call("get_practice_turn_time"))
	if _turn_time_limit_sec <= 0.0:
		# BattleManager practice default (unset) -> treat as 4.0s for the meter.
		_turn_time_limit_sec = 4.0
	_time_left_bar.max_value = _turn_time_limit_sec
	_time_left_bar.value = _turn_time_limit_sec

	if _battle_manager != null and _battle_manager.has_method("get_practice_target_note"):
		_selected_note = String(_battle_manager.call("get_practice_target_note")).strip_edges()
	_target_note_label.text = _selected_note if not _selected_note.is_empty() else "--"
	_sync_mic_button()


func _begin_practice_battle() -> void:
	if _battle_manager == null or not _battle_manager.has_method("start_practice_battle"):
		_status_label.text = "Battle system unavailable."
		return
	if _selected_note.is_empty():
		_status_label.text = "No practice note selected."
		return

	_battle_manager.call("start_practice_battle", _selected_note)
	# Configure the frequency-meter center on AudioProcessor so spectrum_bins_updated
	# fires while capturing. _selected_note is a full note+octave like "C4".
	_apply_meter_center()
	if _audio_processor != null and not bool(_audio_processor.call("is_capturing")):
		_audio_processor.call("start_capture")
	_status_label.text = "Practice battle live."
	_sync_mic_button()


func _connect_audio_signals() -> void:
	if _audio_processor == null:
		return
	if not _audio_processor.is_connected("note_detected", _on_note_detected):
		_audio_processor.connect("note_detected", _on_note_detected)
	if not _audio_processor.is_connected("pitch_candidate_changed", _on_pitch_candidate_changed):
		_audio_processor.connect("pitch_candidate_changed", _on_pitch_candidate_changed)
	if not _audio_processor.is_connected("input_level_changed", _on_input_level_changed):
		_audio_processor.connect("input_level_changed", _on_input_level_changed)
	if not _audio_processor.is_connected("capture_state_changed", _on_capture_state_changed):
		_audio_processor.connect("capture_state_changed", _on_capture_state_changed)
	if _audio_processor.has_signal("spectrum_bins_updated") and not _audio_processor.is_connected("spectrum_bins_updated", _on_spectrum_bins_updated):
		_audio_processor.connect("spectrum_bins_updated", _on_spectrum_bins_updated)


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
	# Live hold-quality indicator (practice hold model). Fires each frame with
	# the current detected note, the most-held note this turn, and the
	# proportion of the turn the player has held an acceptable note (0..1).
	if _battle_manager.has_signal("turn_note_live") and not _battle_manager.is_connected("turn_note_live", _on_turn_note_live):
		_battle_manager.connect("turn_note_live", _on_turn_note_live)


func _on_mic_toggle_pressed() -> void:
	if _audio_processor == null:
		_status_label.text = "Microphone unavailable."
		return
	if bool(_audio_processor.call("is_capturing")):
		_audio_processor.call("stop_capture")
		_status_label.text = "Microphone paused."
	else:
		_audio_processor.call("start_capture")
		if _battle_manager != null and not bool(_battle_manager.call("is_battle_active")):
			_battle_manager.call("start_practice_battle", _selected_note)
		_status_label.text = "Microphone active."
	_sync_mic_button()


func _on_retry_pressed() -> void:
	if _battle_manager == null:
		return
	_battle_manager.call("stop_battle")
	_begin_practice_battle()
	_feedback_label.text = "Retry started. Match the target note cleanly."
	_retry_button.disabled = true


func _on_back_to_notes_pressed() -> void:
	_stop_runtime_audio_and_battle()
	_change_scene(PRACTICE_SETUP_SCENE_PATH, "practice setup")


func _on_exit_pressed() -> void:
	_stop_runtime_audio_and_battle()
	_change_scene(MAIN_MENU_SCENE_PATH, "main menu")


func _on_note_detected(_frequency: float, note_name: String, confidence: float) -> void:
	_detected_note_label.text = "%s • %.2f" % [note_name, confidence]


func _on_capture_state_changed(_is_capturing: bool) -> void:
	_sync_mic_button()


func _on_battle_started(player_hp: int, enemy_hp: int) -> void:
	_update_hp(player_hp, enemy_hp)
	_feedback_label.text = "Pitch Match! Hold the target note to attack."
	_status_label.text = "Battle started."


func _on_turn_started(target_note: String, turn_index: int, time_limit_sec: float) -> void:
	_target_note_label.text = target_note
	_turn_time_limit_sec = maxf(float(time_limit_sec), 0.001)
	_time_left_bar.max_value = _turn_time_limit_sec
	_time_left_bar.value = _turn_time_limit_sec
	_feedback_label.text = "Turn %d • Sing %s within %.1fs" % [turn_index, target_note, time_limit_sec]
	# Reset the practice-live indicator; turn_note_live will refresh it.
	if _live_hold_label != null:
		_live_hold_label.text = ""


## Live per-frame indicator for the practice hold-quality model. Shows the
## note the player is currently producing vs the target, plus what fraction of
## the turn they have held the acceptable note. The grade label itself is left
## for turn_resolved; this is the "keep going" coaching line.
func _on_turn_note_live(target_note: String, detected_note: String, mode_note: String, hold_quality: float) -> void:
	if _live_hold_label == null:
		return
	# Detected note drives the existing DetectedNoteLabel so the art path and the
	# live coaching path agree on what was just sung (don't stomp it on timeout).
	_detected_note_label.text = detected_note if not detected_note.is_empty() else "--"
	var hold_pct: int = int(round(hold_quality * 100.0))
	var played_note: String = mode_note if not mode_note.is_empty() and mode_note != "--" else detected_note
	if played_note.is_empty() or played_note == "--":
		_live_hold_label.text = "Hold the target note • %d%%" % hold_pct
	else:
		_live_hold_label.text = "Played %s • target %s • hold %d%%" % [played_note, target_note, hold_pct]


func _on_turn_resolved(target_note: String, detected_note: String, grade: String, player_hp: int, enemy_hp: int) -> void:
	_target_note_label.text = target_note
	_detected_note_label.text = detected_note
	_feedback_label.text = "%s • target %s • detected %s" % [grade, target_note, detected_note]
	# Clear the live indicator now that the graded result text owns the feedback line.
	if _live_hold_label != null:
		_live_hold_label.text = ""
	_update_hp(player_hp, enemy_hp)


func _on_battle_ended(result: String, turns: int) -> void:
	_feedback_label.text = "Practice battle %s in %d turns." % [result, turns]
	_status_label.text = "Choose retry, switch note, or exit."
	_retry_button.disabled = false


func _update_hp(player_hp: int, enemy_hp: int) -> void:
	_player_hp_bar.value = player_hp
	_enemy_hp_bar.value = enemy_hp
	_player_hp_label.text = "HARM • %d / %d" % [player_hp, PLAYER_MAX_HP]
	_enemy_hp_label.text = "SLIME • %d / %d" % [enemy_hp, ENEMY_MAX_HP]


func _update_time_left_bar() -> void:
	if _battle_manager == null or not _battle_manager.has_method("is_battle_active"):
		return
	if not bool(_battle_manager.call("is_battle_active")):
		return
	if not _battle_manager.has_method("get_turn_time_left"):
		return
	if _turn_time_limit_sec <= 0.0:
		return
	var time_left: float = float(_battle_manager.call("get_turn_time_left"))
	_time_left_bar.value = clampf(time_left, 0.0, _turn_time_limit_sec)


func _sync_mic_button() -> void:
	if _audio_processor == null:
		_mic_toggle_button.text = "Mic Unavailable"
		_mic_toggle_button.disabled = true
		return
	_mic_toggle_button.disabled = false
	_mic_toggle_button.text = "Disable Mic" if bool(_audio_processor.call("is_capturing")) else "Enable Mic"


func _stop_runtime_audio_and_battle() -> void:
	if _battle_manager != null and _battle_manager.has_method("stop_battle"):
		_battle_manager.call("stop_battle")
	if _battle_manager != null and _battle_manager.has_method("clear_practice_mode"):
		_battle_manager.call("clear_practice_mode")
	if _audio_processor != null:
		if _audio_processor.has_method("set_meter_center_hz"):
			_audio_processor.call("set_meter_center_hz", 0.0)
		if bool(_audio_processor.call("is_capturing")):
			_audio_processor.call("stop_capture")


func _change_scene(scene_path: String, scene_label: String) -> void:
	var result: Error = get_tree().change_scene_to_file(scene_path)
	if result != OK:
		push_warning("PracticeBattleScene: Failed to open %s scene." % scene_label)


# ---------------------------------------------------------------------------
# Phase 2: frequency meter (cents-offset needle + spectrum band graph)
# ---------------------------------------------------------------------------

func _initialize_meter() -> void:
	# Populate the octave-match-mode OptionButton.
	_octave_match_mode_button.clear()
	for label: String in MATCH_MODE_LABELS:
		_octave_match_mode_button.add_item(label)

	# Load persisted octave match mode.
	var loaded_mode: String = OCTAVE_MODE_DEFAULT
	if _local_data_manager != null and _local_data_manager.has_method("load_practice_settings"):
		var settings: Dictionary = _local_data_manager.call("load_practice_settings") as Dictionary
		if not settings.is_empty():
			loaded_mode = String(settings.get("octave_match_mode", OCTAVE_MODE_DEFAULT))
	_octave_match_mode = _normalize_octave_mode(loaded_mode)
	_octave_match_mode_button.select(_octave_mode_to_index(_octave_match_mode))
	# Propagate the loaded match mode to BattleManager so gameplay grading and
	# the frequency meter agree (grace-vs-exact octave rule shared between both).
	_apply_octave_mode_to_battle_manager()

	# Seed the meter with the target note's reference frequency.
	_apply_meter_center()
	_meter_detected_label.text = "--"
	_meter_status_label.text = "--"


func _apply_meter_center() -> void:
	if _audio_processor == null or not _audio_processor.has_method("set_meter_center_hz"):
		return
	# _selected_note is a full note+octave like "C4"; resolve its equal-tempered Hz.
	var midi: int = -1
	if _audio_processor.has_method("note_to_midi"):
		midi = int(_audio_processor.call("note_to_midi", _selected_note))
	if midi < 0:
		# Fallback: the note string may be a bare class ("C"); try octave 4.
		if _audio_processor.has_method("note_to_midi"):
			midi = int(_audio_processor.call("note_to_midi", "%s4" % _selected_note))
	if midi < 0:
		_target_frequency_hz = 0.0
		return
	if _audio_processor.has_method("midi_to_hz"):
		_target_frequency_hz = float(_audio_processor.call("midi_to_hz", midi))
	else:
		_target_frequency_hz = 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)
	_audio_processor.call("set_meter_center_hz", _target_frequency_hz)
	_meter_target_label.text = "TARGET  %s  (%.1f Hz)" % [_selected_note, _target_frequency_hz]


func _on_pitch_candidate_changed(frequency: float, note_name: String, confidence: float) -> void:
	# Live (un-locked) candidate -- drives the meter needle.
	if frequency <= 0.0:
		_last_detected_hz = 0.0
		_last_cents_offset = 0.0
		_meter_detected_label.text = "--"
		_meter_status_label.text = "--"
		if _spectrum_graph != null:
			_spectrum_graph.set_needle(0.0, 0.0)
		return
	var cents: float = _cents_offset_to_note(frequency, _selected_note, _octave_match_mode)
	_last_detected_hz = float(frequency)
	_last_cents_offset = cents
	var det_note: String = note_name
	if det_note.is_empty() and _audio_processor != null and _audio_processor.has_method("convert_hz_to_note"):
		det_note = String(_audio_processor.call("convert_hz_to_note", frequency))
	_meter_detected_label.text = "%s  ·  %.1f Hz  ·  %+.0f¢" % [det_note, frequency, cents]
	_meter_status_label.text = _meter_status_text(cents)
	if _spectrum_graph != null:
		_spectrum_graph.set_needle(float(frequency), cents)


func _on_spectrum_bins_updated(bins: PackedVector2Array, center_hz: float) -> void:
	if _spectrum_graph != null:
		_spectrum_graph.set_bins(bins, center_hz)


func _on_input_level_changed(level_db: float) -> void:
	# Dim the meter graph when below the effective noise floor / capture paused.
	if _spectrum_graph == null or _audio_processor == null:
		return
	var effective_min_db: float = -80.0
	if _audio_processor.has_method("get_effective_min_signal_db"):
		effective_min_db = float(_audio_processor.call("get_effective_min_signal_db"))
	var is_capturing: bool = bool(_audio_processor.call("is_capturing"))
	var dimmed: bool = (not is_capturing) or (level_db < effective_min_db)
	_spectrum_graph.set_dimmed(dimmed)


func _on_octave_match_mode_selected(index: int) -> void:
	_octave_match_mode = _index_to_octave_mode(index)
	_persist_octave_match_mode()
	_apply_octave_mode_to_battle_manager()
	# Re-evaluate the current needle with the new mode.
	if _last_detected_hz > 0.0:
		_on_pitch_candidate_changed(_last_detected_hz, "", 0.0)
	_meter_status_label.text = _meter_status_text(_last_cents_offset)


func _cents_offset_to_note(detected_hz: float, target_note_name: String, mode: String) -> float:
	# Returns signed cents offset of detected_hz relative to the target note.
	# pitch_class mode compares against the nearest octave of the target note
	# (C4 target + C5 voice = 0 cents). exact_octave mode compares against
	# the exact target frequency (C4 target + C5 voice = +1200 cents).
	if detected_hz <= 0.0 or target_note_name.is_empty():
		return 0.0
	if _audio_processor == null or not _audio_processor.has_method("note_to_midi"):
		return 0.0
	var target_midi: int = int(_audio_processor.call("note_to_midi", target_note_name))
	if target_midi < 0:
		return 0.0
	var ref_hz: float
	if mode == OCTAVE_MODE_EXACT_OCTAVE:
		if _audio_processor.has_method("midi_to_hz"):
			ref_hz = float(_audio_processor.call("midi_to_hz", target_midi))
		else:
			ref_hz = 440.0 * pow(2.0, (float(target_midi) - 69.0) / 12.0)
	else:
		# pitch_class: find the octave of the target's pitch class nearest to detected_hz.
		var pitch_class_index: int = posmod(target_midi, 12)
		var detected_midi: int = int(round(69.0 + 12.0 * (log(detected_hz / 440.0) / log(2.0))))
		var nearest_octave_midi: int = (int(floor(float(detected_midi) / 12.0)) * 12) + pitch_class_index
		if _audio_processor.has_method("midi_to_hz"):
			ref_hz = float(_audio_processor.call("midi_to_hz", nearest_octave_midi))
		else:
			ref_hz = 440.0 * pow(2.0, (float(nearest_octave_midi) - 69.0) / 12.0)
	return 1200.0 * log(detected_hz / ref_hz) / log(2.0)


func _meter_status_text(cents: float) -> String:
	var abs_cents: float = absf(cents)
	if _octave_match_mode == OCTAVE_MODE_EXACT_OCTAVE:
		if abs_cents > 600.0:
			return "Wrong octave"
		if abs_cents <= 10.0:
			return "In tune ✓"
		if abs_cents <= 25.0:
			return "Close"
		if cents > 0.0:
			return "Tune down ↓"
		return "Tune up ↑"
	# pitch_class: large offsets mean different pitch class, not wrong octave.
	if abs_cents <= 10.0:
		return "In tune ✓"
	if abs_cents <= 50.0:
		if cents > 0.0:
			return "Tune down ↓"
		return "Tune up ↑"
	return "Different note"


func _octave_mode_to_index(mode: String) -> int:
	if mode == OCTAVE_MODE_EXACT_OCTAVE:
		return 1
	return 0


func _index_to_octave_mode(index: int) -> String:
	if index == 1:
		return OCTAVE_MODE_EXACT_OCTAVE
	return OCTAVE_MODE_PITCH_CLASS


func _normalize_octave_mode(mode: String) -> String:
	if mode == OCTAVE_MODE_EXACT_OCTAVE:
		return OCTAVE_MODE_EXACT_OCTAVE
	return OCTAVE_MODE_PITCH_CLASS


## Push the meter's current octave match mode into BattleManager so the
## practice hold-quality grading uses the same rule as the visual needle. No-op
## if BattleManager doesn't expose set_practice_octave_mode (older build).
func _apply_octave_mode_to_battle_manager() -> void:
	if _battle_manager == null or not _battle_manager.has_method("set_practice_octave_mode"):
		return
	_battle_manager.call("set_practice_octave_mode", _octave_match_mode)


func _persist_octave_match_mode() -> void:
	if _local_data_manager == null or not _local_data_manager.has_method("save_practice_settings"):
		return
	# Load existing settings to preserve turn_time_sec, then update the mode field.
	var settings: Dictionary = {}
	if _local_data_manager.has_method("load_practice_settings"):
		settings = _local_data_manager.call("load_practice_settings") as Dictionary
	if settings.is_empty():
		settings = {"turn_time_sec": 4.0, "octave_match_mode": _octave_match_mode}
	else:
		settings["octave_match_mode"] = _octave_match_mode
	_local_data_manager.call("save_practice_settings", settings)
