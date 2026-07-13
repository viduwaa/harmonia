extends Control

const MAIN_MENU_SCENE_PATH: String = "res://src/gd/scenes/menu/MainMenuScene.tscn"
const PRACTICE_BATTLE_SCENE_PATH: String = "res://src/gd/scenes/practice/PracticeBattleScene.tscn"
const BATTLE_MANAGER_PATH: String = "/root/BattleManager"
const LOCAL_DATA_MANAGER_PATH: String = "/root/LocalDataManager"
const GAME_STATE_MANAGER_PATH: String = "/root/GameStateManager"
const NOTE_BUTTON_DEFAULT_COLOR: Color = Color(0.149, 0.106, 0.204, 1.0)
const NOTE_BUTTON_SELECTED_COLOR: Color = Color(0.980, 0.968, 0.840, 1.0)
const PRACTICE_NOTES: PackedStringArray = ["C", "D", "E", "F", "G", "A", "B"]
# Preset entries for the timer dropdown. Index 0 is custom (driven by SpinBox);
# the value is clamped against LocalDataManager bounds at apply time.
const TIMER_PRESET_VALUES: Array[float] = [0.0, 2.0, 4.0, 6.0, 10.0]
const TIMER_PRESET_LABELS: PackedStringArray = ["Custom", "2s", "4s", "6s", "10s"]
const DEFAULT_TURN_TIME_SEC: float = 4.0

@onready var _back_button: Button = %BackButton
@onready var _start_button: Button = %StartPracticeButton
@onready var _status_label: Label = %StatusLabel
@onready var _selected_note_value_label: Label = %SelectedNoteValue
@onready var _analytics_title_label: Label = %AnalyticsTitleLabel
@onready var _accuracy_summary_label: Label = %AccuracySummaryLabel
@onready var _history_label: Label = %HistoryLabel
@onready var _note_list: VBoxContainer = %NoteList
@onready var _timer_spin_box: SpinBox = %TimerSpinBox
@onready var _timer_preset_menu: OptionButton = %TimerPresetMenu

var _battle_manager: Node
var _local_data_manager: Node
var _game_state_manager: Node
var _selected_note: String = ""
# Octave match mode persisted for Phase 2 (frequency meter).
# Defaults to pitch_class; toggled by the meter UI's match-mode selector.
var _octave_match_mode: String = "pitch_class"
var _loading_presets: bool = false


func _ready() -> void:
	_battle_manager = get_node_or_null(BATTLE_MANAGER_PATH)
	_local_data_manager = get_node_or_null(LOCAL_DATA_MANAGER_PATH)
	_game_state_manager = get_node_or_null(GAME_STATE_MANAGER_PATH)

	_back_button.pressed.connect(_on_back_pressed)
	_start_button.pressed.connect(_on_start_practice_pressed)

	for child: Node in _note_list.get_children():
		var note_button: Button = child as Button
		if note_button == null:
			continue
		note_button.pressed.connect(_on_note_selected.bind(note_button.text))

	_timer_spin_box.value_changed.connect(_on_timer_value_changed)
	_timer_preset_menu.item_selected.connect(_on_timer_preset_selected)

	_populate_timer_presets()
	_load_practice_settings()

	_sync_note_buttons()
	_refresh_analytics()


func _on_back_pressed() -> void:
	_change_scene(MAIN_MENU_SCENE_PATH, "main menu")


func _on_start_practice_pressed() -> void:
	if _selected_note.is_empty():
		_status_label.text = "Choose a note before starting practice."
		return
	if _battle_manager == null or not _battle_manager.has_method("configure_practice_mode"):
		_status_label.text = "Battle system unavailable."
		return
	if not bool(_battle_manager.call("configure_practice_mode", _selected_note)):
		_status_label.text = "Could not prepare practice battle."
		return
	# Apply the user's per-practice turn-time override (Phase 1).
	var turn_time: float = float(_timer_spin_box.value)
	if _battle_manager.has_method("set_practice_turn_time"):
		_battle_manager.call("set_practice_turn_time", turn_time)
	# Push the persisted octave match mode into BattleManager so the first turn
	# grades with the same rule as the frequency meter before the battle scene
	# re-applies it on _ready.
	if _battle_manager.has_method("set_practice_octave_mode"):
		_battle_manager.call("set_practice_octave_mode", _octave_match_mode)
	_change_scene(PRACTICE_BATTLE_SCENE_PATH, "practice battle")


func _on_note_selected(note_name: String) -> void:
	_selected_note = String(note_name).strip_edges().to_upper()
	_status_label.text = "Ready to practice %s4." % _selected_note
	_sync_note_buttons()
	_refresh_analytics()


func _sync_note_buttons() -> void:
	for child: Node in _note_list.get_children():
		var note_button: Button = child as Button
		if note_button == null:
			continue
		var is_selected: bool = note_button.text.to_upper() == _selected_note
		note_button.add_theme_color_override("font_color", NOTE_BUTTON_SELECTED_COLOR if is_selected else NOTE_BUTTON_DEFAULT_COLOR)
		note_button.add_theme_color_override("font_hover_color", NOTE_BUTTON_SELECTED_COLOR if is_selected else NOTE_BUTTON_DEFAULT_COLOR)
		note_button.add_theme_color_override("font_pressed_color", NOTE_BUTTON_SELECTED_COLOR if is_selected else NOTE_BUTTON_DEFAULT_COLOR)

	_selected_note_value_label.text = "%s4" % _selected_note if not _selected_note.is_empty() else "--"
	_start_button.disabled = _selected_note.is_empty()


func _refresh_analytics() -> void:
	var active_profile_name: String = _get_active_profile_name()
	var selected_note_full: String = "%s4" % _selected_note if not _selected_note.is_empty() else ""
	var filtered_attempts: Array = []
	var filtered_sessions: Array = []

	if _local_data_manager != null and _local_data_manager.has_method("load_note_attempt_records"):
		for attempt_variant: Variant in _local_data_manager.call("load_note_attempt_records", 0) as Array:
			if not (attempt_variant is Dictionary):
				continue
			var attempt: Dictionary = attempt_variant as Dictionary
			if String(attempt.get("mode", "")) != "practice":
				continue
			if not active_profile_name.is_empty() and String(attempt.get("profile_name", "")) != active_profile_name:
				continue
			if not selected_note_full.is_empty() and String(attempt.get("practice_target_note", "")) != selected_note_full:
				continue
			filtered_attempts.append(attempt)

	if _local_data_manager != null and _local_data_manager.has_method("load_game_session_records"):
		for session_variant: Variant in _local_data_manager.call("load_game_session_records", 0) as Array:
			if not (session_variant is Dictionary):
				continue
			var session: Dictionary = session_variant as Dictionary
			if String(session.get("mode", "")) != "practice":
				continue
			if not active_profile_name.is_empty() and String(session.get("profile_name", "")) != active_profile_name:
				continue
			if not selected_note_full.is_empty() and String(session.get("practice_target_note", "")) != selected_note_full:
				continue
			filtered_sessions.append(session)

	_analytics_title_label.text = "SESSION ANALYTICS" if selected_note_full.is_empty() else "SESSION ANALYTICS • %s4" % _selected_note
	_accuracy_summary_label.text = _build_accuracy_summary(filtered_attempts, filtered_sessions, selected_note_full)
	_history_label.text = _build_history_text(filtered_sessions, filtered_attempts)


func _build_accuracy_summary(filtered_attempts: Array, filtered_sessions: Array, selected_note_full: String) -> String:
	if selected_note_full.is_empty():
		return "Select a note to view recent practice accuracy, wins, and attempts."
	if filtered_attempts.is_empty():
		return "No practice data for %s yet. Start a session to generate note accuracy and timing history." % selected_note_full

	var total_attempts: int = filtered_attempts.size()
	var on_target_attempts: int = 0
	for attempt_variant: Variant in filtered_attempts:
		var attempt: Dictionary = attempt_variant as Dictionary
		var grade: String = String(attempt.get("grade", ""))
		if grade == "Perfect" or grade == "Good":
			on_target_attempts += 1

	var wins: int = 0
	for session_variant: Variant in filtered_sessions:
		var session: Dictionary = session_variant as Dictionary
		if String(session.get("result", "")) == "Win":
			wins += 1

	var accuracy_percent: float = (float(on_target_attempts) / float(total_attempts) * 100.0) if total_attempts > 0 else 0.0
	return "Pitch accuracy %.0f%% • %d attempts • %d sessions • %d wins" % [
		accuracy_percent,
		total_attempts,
		filtered_sessions.size(),
		wins
	]


func _build_history_text(filtered_sessions: Array, filtered_attempts: Array) -> String:
	if filtered_sessions.is_empty():
		return "Recent sessions will appear here once you finish a practice battle."

	var lines: PackedStringArray = PackedStringArray()
	var session_count: int = min(filtered_sessions.size(), 5)
	for index: int in range(session_count):
		var session: Dictionary = filtered_sessions[filtered_sessions.size() - 1 - index] as Dictionary
		lines.append(
			"%s  •  %s  •  %s  •  %d turns" % [
				_format_date(int(session.get("ended_unix_sec", 0))),
				String(session.get("practice_target_note", "--")),
				String(session.get("result", "--")),
				int(session.get("turns", 0))
			]
		)

	if not filtered_attempts.is_empty():
		var latest_attempt: Dictionary = filtered_attempts[filtered_attempts.size() - 1] as Dictionary
		lines.append("")
		lines.append(
			"Latest feedback: %s on %s (confidence %.2f)" % [
				String(latest_attempt.get("grade", "--")),
				String(latest_attempt.get("detected_note", "--")),
				float(latest_attempt.get("confidence", 0.0))
			]
		)

	return "\n".join(lines)


func _get_active_profile_name() -> String:
	if _game_state_manager != null and _game_state_manager.has_method("get_active_profile_name"):
		return String(_game_state_manager.call("get_active_profile_name")).strip_edges()
	return ""


func _format_date(unix_sec: int) -> String:
	if unix_sec <= 0:
		return "--"
	var stamp: Dictionary = Time.get_datetime_dict_from_unix_time(unix_sec)
	return "%02d/%02d/%04d" % [int(stamp.get("day", 0)), int(stamp.get("month", 0)), int(stamp.get("year", 0))]


func _change_scene(scene_path: String, scene_label: String) -> void:
	var result: Error = get_tree().change_scene_to_file(scene_path)
	if result != OK:
		push_warning("PracticeSetupScene: Failed to open %s scene." % scene_label)


# ---------------------------------------------------------------------------
# Phase 1: custom per-note practice timer + persistence
# ---------------------------------------------------------------------------

func _populate_timer_presets() -> void:
	_loading_presets = true
	_timer_preset_menu.clear()
	for label: String in TIMER_PRESET_LABELS:
		_timer_preset_menu.add_item(label)
	_loading_presets = false


func _load_practice_settings() -> void:
	if _local_data_manager == null or not _local_data_manager.has_method("load_practice_settings"):
		return
	var settings: Dictionary = _local_data_manager.call("load_practice_settings") as Dictionary
	if settings.is_empty():
		return
	var turn_time: float = float(settings.get("turn_time_sec", DEFAULT_TURN_TIME_SEC))
	_octave_match_mode = String(settings.get("octave_match_mode", "pitch_class"))
	_loading_presets = true
	_timer_spin_box.value = turn_time
	_loading_presets = false
	_sync_timer_preset_menu_to_value(turn_time)


func _persist_practice_settings() -> void:
	if _local_data_manager == null or not _local_data_manager.has_method("save_practice_settings"):
		return
	var settings: Dictionary = {
		"turn_time_sec": float(_timer_spin_box.value),
		"octave_match_mode": _octave_match_mode
	}
	_local_data_manager.call("save_practice_settings", settings)


func _sync_timer_preset_menu_to_value(value: float) -> void:
	for index: int in range(TIMER_PRESET_VALUES.size()):
		if is_equal_approx(float(TIMER_PRESET_VALUES[index]), value):
			_loading_presets = true
			_timer_preset_menu.select(index)
			_loading_presets = false
			return
	# No exact preset match -> select the "Custom" entry (index 0).
	_loading_presets = true
	_timer_preset_menu.select(0)
	_loading_presets = false


func _on_timer_value_changed(_new_value: float) -> void:
	if _loading_presets:
		return
	_sync_timer_preset_menu_to_value(float(_timer_spin_box.value))
	_persist_practice_settings()


func _on_timer_preset_selected(index: int) -> void:
	if _loading_presets or index < 0 or index >= TIMER_PRESET_VALUES.size():
		return
	var preset_value: float = float(TIMER_PRESET_VALUES[index])
	if preset_value <= 0.0:
		# "Custom" -- do not override the SpinBox; stay on the current value.
		return
	_loading_presets = true
	_timer_spin_box.value = preset_value
	_loading_presets = false
	_persist_practice_settings()
