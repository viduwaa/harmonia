extends Control

@onready var _frequency_value_label: Label = $MarginContainer/VBoxContainer/FrequencyValue
@onready var _note_value_label: Label = $MarginContainer/VBoxContainer/NoteValue
@onready var _confidence_value_label: Label = $MarginContainer/VBoxContainer/ConfidenceValue
@onready var _input_level_value_label: Label = $MarginContainer/VBoxContainer/InputLevelValue
@onready var _input_device_selector: OptionButton = $MarginContainer/VBoxContainer/InputDeviceSelector
@onready var _min_signal_slider: HSlider = $MarginContainer/VBoxContainer/MinSignalSlider
@onready var _min_signal_value_label: Label = $MarginContainer/VBoxContainer/MinSignalValue
@onready var _min_confidence_slider: HSlider = $MarginContainer/VBoxContainer/MinConfidenceSlider
@onready var _min_confidence_value_label: Label = $MarginContainer/VBoxContainer/MinConfidenceValue
@onready var _stability_frames_spin_box: SpinBox = $MarginContainer/VBoxContainer/StabilityFramesSpinBox
@onready var _backend_value_label: Label = $MarginContainer/VBoxContainer/BackendValue
@onready var _status_value_label: Label = $MarginContainer/VBoxContainer/StatusValue
@onready var _log_value_label: RichTextLabel = $MarginContainer/VBoxContainer/LogValue
@onready var _toggle_button: Button = $MarginContainer/VBoxContainer/ToggleRecordingButton

var _audio_processor: Node
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

	_sync_button_state()
	_sync_controls_from_processor()
	_update_labels_from_processor()


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
	_update_labels_from_processor()


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


func _on_input_device_selected(index: int) -> void:
	if _syncing_controls or _audio_processor == null:
		return
	if index < 0 or index >= _input_device_selector.item_count:
		return
	var selected_name: String = _input_device_selector.get_item_text(index)
	var switched: bool = bool(_audio_processor.call("set_input_device_name", selected_name))
	if switched:
		_populate_input_devices()


func _on_min_signal_slider_changed(value: float) -> void:
	_min_signal_value_label.text = "%.1f dB" % value
	if _syncing_controls or _audio_processor == null:
		return
	_audio_processor.call("set_min_signal_db", value)


func _on_min_confidence_slider_changed(value: float) -> void:
	_min_confidence_value_label.text = "%.2f" % value
	if _syncing_controls or _audio_processor == null:
		return
	_audio_processor.call("set_min_confidence", value)


func _on_stability_frames_changed(value: float) -> void:
	if _syncing_controls or _audio_processor == null:
		return
	_audio_processor.call("set_stable_frames_required", int(value))


func _update_labels_from_processor() -> void:
	var frequency: float = float(_audio_processor.call("get_detected_frequency"))
	_frequency_value_label.text = "%.2f Hz" % frequency if frequency > 0.0 else "-- Hz"
	_note_value_label.text = String(_audio_processor.call("get_detected_note"))
	_confidence_value_label.text = "%.2f" % float(_audio_processor.call("get_detected_confidence"))
	_input_level_value_label.text = "%.1f dB" % float(_audio_processor.call("get_input_level_db"))
	_backend_value_label.text = String(_audio_processor.call("get_backend_mode"))
	_status_value_label.text = String(_audio_processor.call("get_status_text"))


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
