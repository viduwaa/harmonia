extends Control

const AUDIO_PROCESSOR_PATH: String = "/root/AudioProcessor"
const LOCAL_DATA_MANAGER_PATH: String = "/root/LocalDataManager"
const MAIN_MENU_SCENE_PATH: String = "res://src/gd/scenes/menu/MainMenuScene.tscn"
const PLAYER_FLOW_SCENE_PATH: String = "res://src/gd/scenes/player/PlayerFlowScene.tscn"
const PROFILE_SELECT_SCENE_PATH: String = "res://src/gd/scenes/menu/ProfileSelectScene.tscn"
const DEFAULT_MIN_SIGNAL_DB: float = -58.0
const DEFAULT_MIN_CONFIDENCE: float = 0.12
const DEFAULT_STABLE_FRAMES: int = 3
const LEVEL_BAR_COUNT: int = 28
const LEVEL_DB_MIN: float = -80.0
const LEVEL_DB_MAX: float = -20.0
const VALID_NOTE_HOLD_SEC: float = 0.75
const UI_REFRESH_INTERVAL_SEC: float = 0.10
const LEVEL_SMOOTH_ALPHA: float = 0.25

@onready var _input_device_selector: OptionButton = %InputDeviceSelector
@onready var _refresh_devices_button: Button = %RefreshDevicesButton
@onready var _test_mic_button: Button = %TestMicButton
@onready var _save_continue_button: Button = %SaveContinueButton
@onready var _reset_defaults_button: Button = %ResetDefaultsButton
@onready var _back_button: Button = %BackButton
@onready var _level_bars_container: HBoxContainer = %LevelBars
@onready var _pitch_value_label: Label = %PitchValue
@onready var _frequency_value_label: Label = %FrequencyValue
@onready var _confidence_value_label: Label = %ConfidenceValue
@onready var _input_level_value_label: Label = %InputLevelValue
@onready var _noise_floor_value_label: Label = %NoiseFloorValue
@onready var _threshold_value_label: Label = %ThresholdValue
@onready var _backend_value_label: Label = %BackendValue
@onready var _status_value_label: Label = %StatusValue
@onready var _guidance_label: Label = %GuidanceLabel
@onready var _min_signal_slider: HSlider = %MinSignalSlider
@onready var _min_signal_value_label: Label = %MinSignalValue
@onready var _min_confidence_slider: HSlider = %MinConfidenceSlider
@onready var _min_confidence_value_label: Label = %MinConfidenceValue
@onready var _stable_frames_spin_box: SpinBox = %StableFramesSpinBox

var _audio_processor: Node
var _local_data_manager: Node
var _syncing_controls: bool = false
var _owns_capture_session: bool = false
var _level_bars: Array[ColorRect] = []
var _last_note_name: String = "--"
var _last_frequency: float = 0.0
var _last_confidence: float = 0.0
var _last_note_elapsed_sec: float = VALID_NOTE_HOLD_SEC
var _ui_refresh_elapsed_sec: float = 0.0
var _latest_input_level_db: float = LEVEL_DB_MIN
var _latest_noise_floor_db: float = LEVEL_DB_MIN
var _latest_threshold_db: float = DEFAULT_MIN_SIGNAL_DB
var _latest_backend_mode: String = "--"
var _latest_status_text: String = "Idle"
var _display_level_db: float = LEVEL_DB_MIN


func _ready() -> void:
	UiSkinApplier.apply_to_scene(self, UiSkinApplier.load_default_skin())
	_build_level_meter()
	_connect_ui_signals()
	_audio_processor = _resolve_audio_processor()
	_local_data_manager = _resolve_local_data_manager()
	if _audio_processor == null:
		_set_audio_unavailable_state("AudioProcessor missing")
		return

	_connect_audio_signals()
	_load_saved_calibration()
	_sync_controls_from_processor()
	_refresh_from_processor()


func _exit_tree() -> void:
	if _owns_capture_session and _audio_processor != null and bool(_audio_processor.call("is_capturing")):
		_audio_processor.call("stop_capture")
	_owns_capture_session = false


func _process(delta: float) -> void:
	if _audio_processor == null:
		_audio_processor = _resolve_audio_processor()
		if _audio_processor == null:
			return
		_connect_audio_signals()
		_sync_controls_from_processor()

	if _local_data_manager == null:
		_local_data_manager = _resolve_local_data_manager()

	_last_note_elapsed_sec += delta
	_ui_refresh_elapsed_sec += delta
	if _ui_refresh_elapsed_sec >= UI_REFRESH_INTERVAL_SEC:
		_ui_refresh_elapsed_sec = 0.0
		_refresh_from_processor()


func _resolve_audio_processor() -> Node:
	return get_node_or_null(AUDIO_PROCESSOR_PATH)


func _resolve_local_data_manager() -> Node:
	return get_node_or_null(LOCAL_DATA_MANAGER_PATH)


func _connect_ui_signals() -> void:
	_input_device_selector.item_selected.connect(_on_input_device_selected)
	_refresh_devices_button.pressed.connect(_on_refresh_devices_pressed)
	_test_mic_button.pressed.connect(_on_test_mic_pressed)
	_save_continue_button.pressed.connect(_on_save_continue_pressed)
	_reset_defaults_button.pressed.connect(_on_reset_defaults_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_min_signal_slider.value_changed.connect(_on_min_signal_slider_changed)
	_min_confidence_slider.value_changed.connect(_on_min_confidence_slider_changed)
	_stable_frames_spin_box.value_changed.connect(_on_stable_frames_changed)


func _connect_audio_signals() -> void:
	if _audio_processor == null:
		return
	if not _audio_processor.is_connected("note_detected", _on_note_detected):
		_audio_processor.connect("note_detected", _on_note_detected)
	if _audio_processor.has_signal("pitch_candidate_changed") and not _audio_processor.is_connected("pitch_candidate_changed", _on_pitch_candidate_changed):
		_audio_processor.connect("pitch_candidate_changed", _on_pitch_candidate_changed)
	if not _audio_processor.is_connected("capture_state_changed", _on_capture_state_changed):
		_audio_processor.connect("capture_state_changed", _on_capture_state_changed)
	if not _audio_processor.is_connected("input_level_changed", _on_input_level_changed):
		_audio_processor.connect("input_level_changed", _on_input_level_changed)
	if not _audio_processor.is_connected("backend_mode_changed", _on_backend_mode_changed):
		_audio_processor.connect("backend_mode_changed", _on_backend_mode_changed)


func _build_level_meter() -> void:
	_level_bars.clear()
	for child: Node in _level_bars_container.get_children():
		child.queue_free()

	for index: int in range(LEVEL_BAR_COUNT):
		var bar: ColorRect = ColorRect.new()
		bar.custom_minimum_size = Vector2(10.0, 42.0 + float(index % 7) * 3.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_END
		bar.color = Color(0.149, 0.259, 0.31, 0.7)
		_level_bars_container.add_child(bar)
		_level_bars.append(bar)


func _set_audio_unavailable_state(message: String) -> void:
	_input_device_selector.clear()
	_input_device_selector.add_item("No input devices")
	_input_device_selector.disabled = true
	_refresh_devices_button.disabled = true
	_test_mic_button.disabled = true
	_save_continue_button.disabled = true
	_reset_defaults_button.disabled = true
	_min_signal_slider.editable = false
	_min_confidence_slider.editable = false
	_stable_frames_spin_box.editable = false
	_pitch_value_label.text = "--"
	_frequency_value_label.text = "-- Hz"
	_confidence_value_label.text = "--"
	_input_level_value_label.text = "-- dB"
	_noise_floor_value_label.text = "-- dB"
	_threshold_value_label.text = "-- dB"
	_backend_value_label.text = "Unavailable"
	_status_value_label.text = message
	_guidance_label.text = "Audio system unavailable. Confirm the AudioProcessor autoload is active."
	_update_level_meter(LEVEL_DB_MIN)


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
	_stable_frames_spin_box.value = stable_frames
	_syncing_controls = false


func _populate_input_devices() -> void:
	if _audio_processor == null:
		return
	_input_device_selector.clear()
	var devices: PackedStringArray = _audio_processor.call("get_input_device_names") as PackedStringArray
	if devices == null or devices.is_empty():
		_input_device_selector.add_item("No input devices")
		_input_device_selector.select(0)
		_input_device_selector.disabled = true
		_guidance_label.text = "No microphone input devices were detected. Check OS privacy settings and reconnect your mic."
		return

	var current_device: String = String(_audio_processor.call("get_input_device_name"))
	var selected_index: int = 0
	for index: int in range(devices.size()):
		var device_name: String = devices[index]
		_input_device_selector.add_item(device_name)
		if device_name == current_device:
			selected_index = index
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
	_audio_processor.call("set_min_signal_db", float(calibration.get("min_signal_db", DEFAULT_MIN_SIGNAL_DB)))
	_audio_processor.call("set_min_confidence", float(calibration.get("min_confidence", DEFAULT_MIN_CONFIDENCE)))
	_audio_processor.call("set_stable_frames_required", int(calibration.get("stable_frames_required", DEFAULT_STABLE_FRAMES)))


func _persist_calibration() -> bool:
	if _audio_processor == null or _local_data_manager == null:
		return false
	if not _local_data_manager.has_method("save_audio_calibration"):
		return false
	var payload: Dictionary = {
		"input_device_name": String(_audio_processor.call("get_input_device_name")),
		"min_signal_db": float(_audio_processor.call("get_min_signal_db")),
		"min_confidence": float(_audio_processor.call("get_min_confidence")),
		"stable_frames_required": int(_audio_processor.call("get_stable_frames_required"))
	}
	return bool(_local_data_manager.call("save_audio_calibration", payload))


func _refresh_from_processor() -> void:
	if _audio_processor == null:
		return
	_latest_input_level_db = float(_audio_processor.call("get_input_level_db"))
	_latest_noise_floor_db = float(_audio_processor.call("get_noise_floor_db")) if _audio_processor.has_method("get_noise_floor_db") else LEVEL_DB_MIN
	_latest_threshold_db = float(_audio_processor.call("get_effective_min_signal_db")) if _audio_processor.has_method("get_effective_min_signal_db") else float(_audio_processor.call("get_min_signal_db"))
	_latest_backend_mode = String(_audio_processor.call("get_backend_mode"))
	_latest_status_text = String(_audio_processor.call("get_status_text"))
	var is_capturing: bool = bool(_audio_processor.call("is_capturing"))

	if not is_capturing:
		_last_frequency = 0.0
		_last_note_name = "--"
		_last_confidence = 0.0
	elif _last_note_elapsed_sec >= VALID_NOTE_HOLD_SEC:
		_last_frequency = 0.0
		_last_note_name = "Listening..."
		_last_confidence = 0.0

	_display_level_db = lerp(_display_level_db, _latest_input_level_db, LEVEL_SMOOTH_ALPHA)
	_set_label_text(_pitch_value_label, _last_note_name)
	_set_label_text(_frequency_value_label, "%.2f Hz" % _last_frequency if _last_frequency > 0.0 else "-- Hz")
	_set_label_text(_confidence_value_label, "%.2f" % _last_confidence)
	_set_label_text(_input_level_value_label, "%.1f dB" % _display_level_db)
	_set_label_text(_noise_floor_value_label, "%.1f dB" % _latest_noise_floor_db)
	_set_label_text(_threshold_value_label, "%.1f dB" % _latest_threshold_db)
	_set_label_text(_backend_value_label, _latest_backend_mode)
	_set_label_text(_status_value_label, _latest_status_text)
	_update_level_meter(_display_level_db)
	_update_test_button()
	_update_guidance(_latest_input_level_db, _latest_threshold_db, _last_confidence)


func _set_label_text(label: Label, text: String) -> void:
	if label.text == text:
		return
	label.text = text


func _resolve_display_note(frequency: float, note_name: String) -> String:
	if frequency <= 0.0:
		return "--"
	if not note_name.is_empty() and note_name != "--":
		return note_name
	if _audio_processor != null and _audio_processor.has_method("convert_hz_to_note"):
		var candidate_note: String = String(_audio_processor.call("convert_hz_to_note", frequency))
		if not candidate_note.is_empty() and candidate_note != "--":
			return "%s (stabilizing)" % candidate_note
	return "Detecting..."


func _update_test_button() -> void:
	if _audio_processor == null:
		_test_mic_button.text = "Test Mic"
		_test_mic_button.disabled = true
		return
	var is_capturing: bool = bool(_audio_processor.call("is_capturing"))
	_test_mic_button.disabled = false
	_test_mic_button.text = "Stop Test" if is_capturing else "Test Mic"


func _update_level_meter(input_level_db: float) -> void:
	var normalized: float = clampf((input_level_db - LEVEL_DB_MIN) / (LEVEL_DB_MAX - LEVEL_DB_MIN), 0.0, 1.0)
	var active_count: int = int(round(normalized * float(_level_bars.size())))
	for index: int in range(_level_bars.size()):
		var bar: ColorRect = _level_bars[index]
		if index >= active_count:
			bar.color = Color(0.149, 0.259, 0.31, 0.7)
		elif index > int(float(_level_bars.size()) * 0.82):
			bar.color = Color(0.98, 0.27, 0.22, 0.95)
		elif index > int(float(_level_bars.size()) * 0.62):
			bar.color = Color(0.96, 0.69, 0.2, 0.95)
		else:
			bar.color = Color(0.27, 0.82, 0.42, 0.95)


func _update_guidance(input_level_db: float, threshold_db: float, confidence: float) -> void:
	if _audio_processor == null:
		return
	var is_capturing: bool = bool(_audio_processor.call("is_capturing"))
	if not is_capturing:
		_set_label_text(_guidance_label, "Press Test Mic, then sing or hum a steady comfortable note.")
		return

	if input_level_db <= threshold_db:
		_set_label_text(_guidance_label, "Signal is too quiet. Move closer, sing a little louder, or choose another input device.")
		return

	if _last_note_elapsed_sec <= VALID_NOTE_HOLD_SEC and _last_note_name != "--" and confidence >= float(_audio_processor.call("get_min_confidence")):
		_set_label_text(_guidance_label, "Mic is reading your pitch clearly. Save when this stays stable.")
		return

	_set_label_text(_guidance_label, "Listening... hold one steady pitch for a moment.")


func _reset_defaults() -> void:
	if _audio_processor == null:
		return
	_audio_processor.call("set_min_signal_db", DEFAULT_MIN_SIGNAL_DB)
	_audio_processor.call("set_min_confidence", DEFAULT_MIN_CONFIDENCE)
	_audio_processor.call("set_stable_frames_required", DEFAULT_STABLE_FRAMES)
	_sync_controls_from_processor()
	_persist_calibration()
	_guidance_label.text = "Calibration defaults restored. Test your mic again before continuing."


func _open_scene(scene_path: String) -> void:
	if _owns_capture_session and _audio_processor != null and bool(_audio_processor.call("is_capturing")):
		_audio_processor.call("stop_capture")
	_owns_capture_session = false
	var result: Error = get_tree().change_scene_to_file(scene_path)
	if result != OK:
		push_warning("MicrophoneCalibrationScene: Failed to open scene %s." % scene_path)


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
		_guidance_label.text = "Input device selected. Press Test Mic to verify detection."
	else:
		_guidance_label.text = "Could not select that input device. Try Refresh Devices or use Default."


func _on_refresh_devices_pressed() -> void:
	_populate_input_devices()
	_guidance_label.text = "Input devices refreshed."


func _on_test_mic_pressed() -> void:
	if _audio_processor == null:
		return
	if bool(_audio_processor.call("is_capturing")):
		_audio_processor.call("stop_capture")
		_owns_capture_session = false
		_latest_input_level_db = LEVEL_DB_MIN
		_display_level_db = LEVEL_DB_MIN
		_guidance_label.text = "Mic test stopped."
	else:
		_audio_processor.call("start_capture")
		_owns_capture_session = true
		_last_note_name = "--"
		_last_frequency = 0.0
		_last_confidence = 0.0
		_last_note_elapsed_sec = VALID_NOTE_HOLD_SEC
		_latest_input_level_db = LEVEL_DB_MIN
		_display_level_db = LEVEL_DB_MIN
		_guidance_label.text = "Listening... sing or hum one steady note."
	_update_test_button()


func _on_save_continue_pressed() -> void:
	if _persist_calibration():
		_open_scene(PROFILE_SELECT_SCENE_PATH)
	else:
		_guidance_label.text = "Calibration could not be saved. Check LocalDataManager availability."


func _on_reset_defaults_pressed() -> void:
	_reset_defaults()


func _on_back_pressed() -> void:
	if _local_data_manager != null and _local_data_manager.has_method("has_audio_calibration") and bool(_local_data_manager.call("has_audio_calibration")):
		_open_scene(PROFILE_SELECT_SCENE_PATH)
	else:
		_open_scene(MAIN_MENU_SCENE_PATH)


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


func _on_stable_frames_changed(value: float) -> void:
	if _syncing_controls or _audio_processor == null:
		return
	_audio_processor.call("set_stable_frames_required", int(value))
	_persist_calibration()


func _on_note_detected(frequency: float, note_name: String, confidence: float) -> void:
	var display_note: String = _resolve_display_note(frequency, note_name)
	_last_frequency = frequency
	_last_note_name = display_note
	_last_confidence = confidence
	_last_note_elapsed_sec = 0.0 if frequency > 0.0 and display_note != "--" else VALID_NOTE_HOLD_SEC


func _on_pitch_candidate_changed(frequency: float, note_name: String, confidence: float) -> void:
	var display_note: String = _resolve_display_note(frequency, note_name)
	_last_frequency = frequency
	_last_note_name = display_note
	_last_confidence = confidence
	_last_note_elapsed_sec = 0.0 if frequency > 0.0 and display_note != "--" else VALID_NOTE_HOLD_SEC


func _on_capture_state_changed(_is_capturing: bool) -> void:
	_update_test_button()


func _on_input_level_changed(level_db: float) -> void:
	_latest_input_level_db = level_db


func _on_backend_mode_changed(mode: String) -> void:
	_latest_backend_mode = mode
