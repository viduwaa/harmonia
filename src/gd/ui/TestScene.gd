extends Control

@onready var _frequency_value_label: Label = $MarginContainer/VBoxContainer/FrequencyValue
@onready var _note_value_label: Label = $MarginContainer/VBoxContainer/NoteValue
@onready var _confidence_value_label: Label = $MarginContainer/VBoxContainer/ConfidenceValue
@onready var _input_level_value_label: Label = $MarginContainer/VBoxContainer/InputLevelValue
@onready var _status_value_label: Label = $MarginContainer/VBoxContainer/StatusValue
@onready var _toggle_button: Button = $MarginContainer/VBoxContainer/ToggleRecordingButton

var _audio_processor: Node
var _bootstrap_attempted: bool = false
var _autoload_warning_emitted: bool = false


func _ready() -> void:
	_toggle_button.pressed.connect(_on_toggle_button_pressed)
	_audio_processor = _resolve_audio_processor()
	if _audio_processor == null:
		_toggle_button.disabled = false
		_status_value_label.text = "AudioProcessor unavailable (will retry)"
	else:
		_ensure_audio_signal_connections()

	_sync_button_state()
	_update_labels_from_processor()


func _process(_delta: float) -> void:
	if _audio_processor == null:
		_audio_processor = _resolve_audio_processor()
		if _audio_processor == null:
			return
		_ensure_audio_signal_connections()
		return
	_update_labels_from_processor()


func _on_toggle_button_pressed() -> void:
	if _audio_processor == null:
		_audio_processor = _resolve_audio_processor()
	if _audio_processor == null:
		_status_value_label.text = "AudioProcessor unavailable (retrying)"
		return
	_ensure_audio_signal_connections()

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


func _update_labels_from_processor() -> void:
	if _audio_processor == null:
		return
	var frequency: float = float(_audio_processor.call("get_detected_frequency"))
	_frequency_value_label.text = "%.2f Hz" % frequency if frequency > 0.0 else "-- Hz"
	_note_value_label.text = String(_audio_processor.call("get_detected_note"))
	_confidence_value_label.text = "%.2f" % float(_audio_processor.call("get_detected_confidence"))
	_input_level_value_label.text = "%.1f dB" % float(_audio_processor.call("get_input_level_db"))
	_status_value_label.text = String(_audio_processor.call("get_status_text"))


func _sync_button_state() -> void:
	if _audio_processor == null:
		_toggle_button.text = "Start Recording"
		return
	_toggle_button.text = "Stop Recording" if bool(_audio_processor.call("is_capturing")) else "Start Recording"


func _resolve_audio_processor() -> Node:
	var existing: Node = get_node_or_null("/root/AudioProcessor")
	if existing != null:
		_autoload_warning_emitted = false
		return existing

	if not _bootstrap_attempted:
		_bootstrap_attempted = true
		var audio_processor_script: Script = load("res://src/gd/autoloads/AudioProcessor.gd")
		if audio_processor_script != null:
			var fallback_instance: Node = audio_processor_script.new() as Node
			if fallback_instance != null:
				fallback_instance.name = "AudioProcessor"
				get_tree().root.add_child(fallback_instance)
				_status_value_label.text = "AudioProcessor bootstrapped locally"
				return fallback_instance

	if not _autoload_warning_emitted:
		push_warning("TestScene: AudioProcessor autoload not found at /root/AudioProcessor.")
		_autoload_warning_emitted = true
	return null


func _ensure_audio_signal_connections() -> void:
	if _audio_processor == null:
		return
	if not _audio_processor.is_connected("note_detected", _on_note_detected):
		_audio_processor.connect("note_detected", _on_note_detected)
	if not _audio_processor.is_connected("capture_state_changed", _on_capture_state_changed):
		_audio_processor.connect("capture_state_changed", _on_capture_state_changed)
	if not _audio_processor.is_connected("input_level_changed", _on_input_level_changed):
		_audio_processor.connect("input_level_changed", _on_input_level_changed)
