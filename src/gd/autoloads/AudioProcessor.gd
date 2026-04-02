extends Node

signal note_detected(frequency: float, note_name: String, confidence: float)
signal capture_state_changed(is_capturing: bool)
signal input_level_changed(level_db: float)

const MIN_FREQUENCY_HZ: float = 60.0
const MAX_FREQUENCY_HZ: float = 1400.0
const FREQUENCY_STEP_HZ: float = 5.0
const MIN_SIGNAL_DB: float = -58.0
const MIN_CONFIDENCE: float = 0.12
const SMOOTHING_ALPHA: float = 0.35
const ANALYSIS_BUS_VOLUME_DB: float = -60.0
const NOTE_NAMES: PackedStringArray = [
	"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
]

var _mic_player: AudioStreamPlayer
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _record_bus_index: int = -1
var _record_bus_state_cached: bool = false
var _record_bus_prev_mute: bool = false
var _record_bus_prev_volume_db: float = 0.0
var _is_capturing: bool = false
var _detected_frequency: float = 0.0
var _detected_note: String = "--"
var _detected_confidence: float = 0.0
var _input_level_db: float = -80.0
var _status_text: String = "Idle"


func _ready() -> void:
	_setup_microphone_player()
	_cache_record_bus_state()
	_resolve_spectrum_analyzer()


func _process(_delta: float) -> void:
	if not _is_capturing:
		return
	if _spectrum == null:
		_resolve_spectrum_analyzer()
		if _spectrum == null:
			return
	_update_detection()


func start_capture() -> void:
	if _is_capturing:
		return
	if _mic_player == null:
		_setup_microphone_player()
	if not _prepare_record_bus_for_analysis():
		_status_text = "Record bus not found"
		return
	if _spectrum == null:
		_resolve_spectrum_analyzer()
	if _spectrum == null:
		push_warning("AudioProcessor: Record bus analyzer was not found.")
		_status_text = "Record analyzer missing"
		return
	_mic_player.play()
	_is_capturing = true
	_status_text = "Capturing"
	capture_state_changed.emit(true)


func stop_capture() -> void:
	if not _is_capturing:
		return
	_mic_player.stop()
	_restore_record_bus_state()
	_is_capturing = false
	_detected_frequency = 0.0
	_detected_note = "--"
	_detected_confidence = 0.0
	_input_level_db = -80.0
	_status_text = "Idle"
	capture_state_changed.emit(false)
	note_detected.emit(_detected_frequency, _detected_note, _detected_confidence)
	input_level_changed.emit(_input_level_db)


func is_capturing() -> bool:
	return _is_capturing


func get_detected_frequency() -> float:
	return _detected_frequency


func get_detected_note() -> String:
	return _detected_note


func get_detected_confidence() -> float:
	return _detected_confidence


func get_input_level_db() -> float:
	return _input_level_db


func get_status_text() -> String:
	return _status_text


func convert_hz_to_note(frequency: float) -> String:
	if frequency <= 0.0:
		return "--"
	var midi_note: int = int(round(69.0 + 12.0 * (log(frequency / 440.0) / log(2.0))))
	var note_index: int = posmod(midi_note, 12)
	var octave: int = int(floor(midi_note / 12.0)) - 1
	return "%s%d" % [NOTE_NAMES[note_index], octave]


func _setup_microphone_player() -> void:
	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = "MicCapturePlayer"
	_mic_player.bus = "Record"
	_mic_player.stream = AudioStreamMicrophone.new()
	add_child(_mic_player)


func _resolve_spectrum_analyzer() -> void:
	_record_bus_index = AudioServer.get_bus_index("Record")
	if _record_bus_index == -1:
		_spectrum = null
		return
	var effect_count: int = AudioServer.get_bus_effect_count(_record_bus_index)
	for effect_index: int in range(effect_count):
		var effect_instance: AudioEffectInstance = AudioServer.get_bus_effect_instance(_record_bus_index, effect_index)
		var spectrum: AudioEffectSpectrumAnalyzerInstance = effect_instance as AudioEffectSpectrumAnalyzerInstance
		if spectrum != null:
			_spectrum = spectrum
			return
	_spectrum = null


func _cache_record_bus_state() -> void:
	if _record_bus_state_cached:
		return
	_record_bus_index = AudioServer.get_bus_index("Record")
	if _record_bus_index == -1:
		return
	_record_bus_prev_mute = AudioServer.is_bus_mute(_record_bus_index)
	_record_bus_prev_volume_db = AudioServer.get_bus_volume_db(_record_bus_index)
	_record_bus_state_cached = true


func _prepare_record_bus_for_analysis() -> bool:
	_record_bus_index = AudioServer.get_bus_index("Record")
	if _record_bus_index == -1:
		return false
	if not _record_bus_state_cached:
		_cache_record_bus_state()
	# Keep the bus effectively silent while still letting effects process.
	AudioServer.set_bus_mute(_record_bus_index, false)
	AudioServer.set_bus_volume_db(_record_bus_index, ANALYSIS_BUS_VOLUME_DB)
	return true


func _restore_record_bus_state() -> void:
	if _record_bus_index == -1 or not _record_bus_state_cached:
		return
	AudioServer.set_bus_mute(_record_bus_index, _record_bus_prev_mute)
	AudioServer.set_bus_volume_db(_record_bus_index, _record_bus_prev_volume_db)


func _update_detection() -> void:
	var loudest_frequency: float = 0.0
	var loudest_magnitude: float = 0.0
	var total_magnitude: float = 0.0
	var bin_count: int = 0
	var frequency: float = MIN_FREQUENCY_HZ

	while frequency <= MAX_FREQUENCY_HZ:
		var frequency_hi: float = min(frequency + FREQUENCY_STEP_HZ, MAX_FREQUENCY_HZ)
		var magnitude_stereo: Vector2 = _spectrum.get_magnitude_for_frequency_range(
			frequency,
			frequency_hi,
			AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX
		)
		var magnitude: float = (magnitude_stereo.x + magnitude_stereo.y) * 0.5
		bin_count += 1
		total_magnitude += magnitude
		if magnitude > loudest_magnitude:
			loudest_magnitude = magnitude
			loudest_frequency = frequency + (frequency_hi - frequency) * 0.5
		frequency += FREQUENCY_STEP_HZ

	_input_level_db = linear_to_db(max(loudest_magnitude, 0.0000001))
	input_level_changed.emit(_input_level_db)
	if _input_level_db < MIN_SIGNAL_DB:
		_clear_detection("Waiting for louder input")
		return

	var average_magnitude: float = total_magnitude / max(float(bin_count), 1.0)
	var peak_ratio: float = loudest_magnitude / max(average_magnitude, 0.0000001)
	var confidence: float = clamp((peak_ratio - 1.0) / 6.0, 0.0, 1.0)
	if confidence < MIN_CONFIDENCE or loudest_frequency <= 0.0:
		_clear_detection("Input detected but not stable")
		return

	if _detected_frequency <= 0.0:
		_detected_frequency = loudest_frequency
	else:
		_detected_frequency = lerp(_detected_frequency, loudest_frequency, SMOOTHING_ALPHA)
	_detected_note = convert_hz_to_note(_detected_frequency)
	_detected_confidence = confidence
	_status_text = "Capturing"
	print("[AudioProcessor] Note: %s | Freq: %.2f Hz | Confidence: %.2f" % [_detected_note, _detected_frequency, _detected_confidence])
	note_detected.emit(_detected_frequency, _detected_note, _detected_confidence)


func _clear_detection(status: String) -> void:
	_detected_frequency = 0.0
	_detected_note = "--"
	_detected_confidence = 0.0
	_status_text = status
	note_detected.emit(_detected_frequency, _detected_note, _detected_confidence)
