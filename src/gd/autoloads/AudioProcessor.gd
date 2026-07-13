extends Node

signal note_detected(frequency: float, note_name: String, confidence: float)
signal pitch_candidate_changed(frequency: float, note_name: String, confidence: float)
signal note_locked(frequency: float, note_name: String, confidence: float)
signal note_released(note_name: String)
signal capture_state_changed(is_capturing: bool)
signal input_level_changed(level_db: float)
signal backend_mode_changed(mode: String)
signal diagnostic_logged(message: String)
## Frequency-meter visualization data. Emitted each capture frame while a meter
## center is configured. bins[i].x = band center Hz, bins[i].y = magnitude
## (linear, 0..1). band_count bands span +/-1 octave around the meter center.
signal spectrum_bins_updated(bins: PackedVector2Array, center_hz: float)

const MIN_FREQUENCY_HZ: float = 60.0
const MAX_FREQUENCY_HZ: float = 1400.0
const FREQUENCY_STEP_HZ: float = 5.0
const DEFAULT_MIN_SIGNAL_DB: float = -58.0
const DEFAULT_MIN_CONFIDENCE: float = 0.12
const ADAPTIVE_NOISE_MARGIN_DB: float = 9.0
const NOISE_FLOOR_SMOOTH_ALPHA: float = 0.08
const SMOOTHING_ALPHA: float = 0.35
const NOTE_HISTORY_WINDOW_SEC: float = 0.22
const NOTE_LOCK_MIN_RATIO: float = 0.65
const NOTE_SWITCH_MIN_SEC: float = 0.18
const NOTE_RELEASE_GRACE_SEC: float = 0.20
const ANALYSIS_BUS_VOLUME_DB: float = -60.0
const CAPTURE_FRAME_COUNT: int = 2048
const CSHARP_PITCH_CLASS_NAME: String = "PitchDecisionService"
const CSHARP_PITCH_SINGLETON_PATH: NodePath = ^"/root/PitchDecisionService"
const BACKEND_RETRY_INTERVAL_SEC: float = 1.0
# Frequency-meter bands: count and span (in octaves) around the meter center.
const METER_BAND_COUNT: int = 24
const METER_BAND_SPAN_OCTAVES: float = 2.0  # +/-1 octave either side
# English note classes used in code with Sinhala solfege reference:
# C = ඩෝ (Do), C# = ඩෝ ශාප් (Do Sharp)
# D = රේ (Re), D# = රේ ශාප් (Re Sharp)
# E = මි (Mi)
# F = ෆා (Fa), F# = ෆා ශාප් (Fa Sharp)
# G = සෝ (So), G# = සෝ ශාප් (So Sharp)
# A = ලා (La), A# = ලා ශාප් (La Sharp)
# B = ති (Ti)
const NOTE_NAMES: PackedStringArray = [
	"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
]

var _mic_player: AudioStreamPlayer
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _capture: AudioEffectCapture
var _record_bus_index: int = -1
var _record_bus_state_cached: bool = false
var _record_bus_prev_mute: bool = false
var _record_bus_prev_volume_db: float = 0.0
var _stable_frames_required: int = 3
var _min_signal_db: float = DEFAULT_MIN_SIGNAL_DB
var _min_confidence: float = DEFAULT_MIN_CONFIDENCE
var _candidate_note: String = ""
var _stable_frame_count: int = 0
var _candidate_history: Array[Dictionary] = []
var _candidate_switch_elapsed_sec: float = 0.0
var _invalid_input_elapsed_sec: float = 0.0
var _locked_note: String = "--"
var _locked_frequency: float = 0.0
var _locked_confidence: float = 0.0
var _pitch_service: Object
var _backend_mode: String = "GDScript"
var _backend_retry_elapsed: float = 0.0
var _is_capturing: bool = false
var _detected_frequency: float = 0.0
var _detected_note: String = "--"
var _detected_confidence: float = 0.0
var _input_level_db: float = -80.0
var _noise_floor_db: float = -80.0
var _effective_min_signal_db: float = DEFAULT_MIN_SIGNAL_DB
var _status_text: String = "Idle"
var _last_csharp_skip_reason: String = "C# backend not resolved"
# Frequency-meter center Hz. When > 0, spectrum_bins_updated is emitted each
# capture frame with bands centered on this frequency (set by practice scene).
var _meter_center_hz: float = 0.0


func _ready() -> void:
	_setup_microphone_player()
	_cache_record_bus_state()
	_ensure_record_bus_effects()
	_resolve_audio_effect_instances()
	_resolve_pitch_backend()


func _process(delta: float) -> void:
	if _pitch_service == null:
		_backend_retry_elapsed += delta
		if _backend_retry_elapsed >= BACKEND_RETRY_INTERVAL_SEC:
			_backend_retry_elapsed = 0.0
			_resolve_pitch_backend()

	if not _is_capturing:
		return
	if _spectrum == null or _capture == null:
		_resolve_audio_effect_instances()
		if _spectrum == null:
			return
	_update_detection(delta)


func start_capture() -> void:
	if _is_capturing:
		return
	_resolve_pitch_backend()
	if _mic_player == null:
		_setup_microphone_player()
	if not _prepare_record_bus_for_analysis():
		_set_status("Record bus not found")
		return
	_ensure_record_bus_effects()
	if _spectrum == null or _capture == null:
		_resolve_audio_effect_instances()
	if _spectrum == null:
		push_warning("AudioProcessor: Record bus analyzer was not found.")
		_set_status("Record analyzer missing")
		return
	if _capture != null:
		_capture.clear_buffer()
	_reset_adaptive_noise_floor()
	_reset_note_decision_state()
	_mic_player.play()
	_is_capturing = true
	_set_status("Capturing")
	_log_event("Capture started")
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
	_reset_adaptive_noise_floor()
	_reset_note_decision_state()
	_set_status("Idle")
	_log_event("Capture stopped")
	# Clear the frequency meter with a zeroed frame so listeners can dim/blank.
	if _meter_center_hz > 0.0:
		var zero_bins: PackedVector2Array = PackedVector2Array()
		zero_bins.resize(METER_BAND_COUNT)
		for i: int in range(METER_BAND_COUNT):
			zero_bins[i] = Vector2(0.0, 0.0)
		spectrum_bins_updated.emit(zero_bins, _meter_center_hz)
	capture_state_changed.emit(false)
	note_released.emit("--")
	note_detected.emit(_detected_frequency, _detected_note, _detected_confidence)
	pitch_candidate_changed.emit(0.0, "--", 0.0)
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


func get_noise_floor_db() -> float:
	return _noise_floor_db


func get_effective_min_signal_db() -> float:
	return _effective_min_signal_db


func get_status_text() -> String:
	return _status_text


func get_backend_mode() -> String:
	return _backend_mode


func get_input_device_names() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func get_input_device_name() -> String:
	return AudioServer.get_input_device()


func set_input_device_name(device_name: String) -> bool:
	var normalized: String = device_name.strip_edges()
	if normalized.is_empty():
		return false

	var devices: PackedStringArray = AudioServer.get_input_device_list()
	if devices.find(normalized) == -1:
		_log_event("Input device not found: %s" % normalized)
		return false

	if AudioServer.get_input_device() == normalized:
		return true

	var resume_capture: bool = _is_capturing
	if resume_capture:
		stop_capture()

	AudioServer.set_input_device(normalized)
	_log_event("Input device selected: %s" % normalized)

	# Rebind microphone stream so the player follows the selected input device.
	if _mic_player != null:
		_mic_player.stream = AudioStreamMicrophone.new()

	if resume_capture:
		start_capture()

	return true


func set_min_signal_db(value: float) -> void:
	var clamped: float = clamp(value, -80.0, -20.0)
	if is_equal_approx(_min_signal_db, clamped):
		return
	_min_signal_db = clamped
	_recompute_effective_min_signal_db()
	_log_event("Threshold updated: min_signal_db=%.1f" % _min_signal_db)


func get_min_signal_db() -> float:
	return _min_signal_db


func set_min_confidence(value: float) -> void:
	var clamped: float = clamp(value, 0.0, 1.0)
	if is_equal_approx(_min_confidence, clamped):
		return
	_min_confidence = clamped
	_log_event("Threshold updated: min_confidence=%.2f" % _min_confidence)


func get_min_confidence() -> float:
	return _min_confidence


func set_stable_frames_required(value: int) -> void:
	var clamped: int = clampi(value, 1, 12)
	if _stable_frames_required == clamped:
		return
	_stable_frames_required = clamped
	_log_event("Detection updated: stable_frames_required=%d" % _stable_frames_required)


func get_stable_frames_required() -> int:
	return _stable_frames_required


func convert_hz_to_note(frequency: float) -> String:
	if frequency <= 0.0:
		return "--"
	var midi_note: int = int(round(69.0 + 12.0 * (log(frequency / 440.0) / log(2.0))))
	var note_index: int = posmod(midi_note, 12)
	var octave: int = int(floor(midi_note / 12.0)) - 1
	return "%s%d" % [NOTE_NAMES[note_index], octave]


## Set the frequency-meter center (Hz). When > 0 and capturing, the
## spectrum_bins_updated signal fires each frame with METER_BAND_COUNT bands
## spanning +/-1 octave around this frequency. Pass 0.0 to disable emission.
func set_meter_center_hz(hz: float) -> void:
	_meter_center_hz = maxf(float(hz), 0.0)


func get_meter_center_hz() -> float:
	return _meter_center_hz


## Returns the equal-tempered frequency (A4=440Hz) for a MIDI note number.
func midi_to_hz(midi_note: int) -> float:
	return 440.0 * pow(2.0, (float(midi_note) - 69.0) / 12.0)


## Returns the MIDI note number for a note name like "C4" or "A#3".
## Returns -1 if the name cannot be parsed.
func note_to_midi(note_name: String) -> int:
	var cleaned: String = note_name.strip_edges().to_upper()
	if cleaned.is_empty() or cleaned.length() < 2:
		return -1
	# Pitch class: 1-2 leading chars (letter + optional accidental).
	# ``class_name`` is a GDScript keyword; use ``pitch_class_name`` instead.
	var pitch_class_name: String = ""
	var octave_str: String = ""
	var i: int = 0
	if i < cleaned.length() and cleaned[i] >= "A" and cleaned[i] <= "G":
		pitch_class_name += cleaned[i]
		i += 1
		if i < cleaned.length() and (cleaned[i] == "#" or cleaned[i] == "B"):
			pitch_class_name += cleaned[i]
			i += 1
	else:
		return -1

	octave_str = cleaned.substr(i)
	if octave_str.is_valid_int():
		var octave: int = int(octave_str)
		var class_index: int = NOTE_NAMES.find(pitch_class_name)
		if class_index == -1:
			return -1
		return (octave + 1) * 12 + class_index
	return -1


## Build the per-band magnitude snapshot for the frequency meter and emit it.
## Bands are logarithmically spaced across +/-1 octave around _meter_center_hz.
func _emit_spectrum_bins() -> void:
	if _meter_center_hz <= 0.0 or _spectrum == null:
		return
	var bins: PackedVector2Array = PackedVector2Array()
	bins.resize(METER_BAND_COUNT)
	# Log-spaced band centers: center * 2^(-1 + 2*i/(N-1)).
	var half_span: float = METER_BAND_SPAN_OCTAVES * 0.5
	var bin_width_octaves: float = (2.0 * half_span) / float(METER_BAND_COUNT - 1)
	# Per-band half-width in Hz (a fraction of the band spacing for overlap).
	for i: int in range(METER_BAND_COUNT):
		var octave_offset: float = -half_span + bin_width_octaves * float(i)
		var band_center_hz: float = _meter_center_hz * pow(2.0, octave_offset)
		var band_half_hz: float = band_center_hz * (pow(2.0, bin_width_octaves * 0.5) - 1.0) * 0.6
		var lo: float = max(band_center_hz - band_half_hz, MIN_FREQUENCY_HZ)
		var hi: float = min(band_center_hz + band_half_hz, MAX_FREQUENCY_HZ)
		var mag_stereo: Vector2 = _spectrum.get_magnitude_for_frequency_range(
			lo,
		hi,
		AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX
		)
		var mag: float = (mag_stereo.x + mag_stereo.y) * 0.5
		# Normalize to 0..1 with a gentle curve for readability.
		var normalized: float = clamp(sqrt(mag) * 12.0, 0.0, 1.0)
		bins[i] = Vector2(band_center_hz, normalized)
	spectrum_bins_updated.emit(bins, _meter_center_hz)


func _setup_microphone_player() -> void:
	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = "MicCapturePlayer"
	_mic_player.bus = "Record"
	_mic_player.stream = AudioStreamMicrophone.new()
	add_child(_mic_player)


func _resolve_audio_effect_instances() -> void:
	_record_bus_index = AudioServer.get_bus_index("Record")
	if _record_bus_index == -1:
		_spectrum = null
		_capture = null
		return
	_ensure_record_bus_effects()

	_spectrum = null
	_capture = null
	var effect_count: int = AudioServer.get_bus_effect_count(_record_bus_index)
	for effect_index: int in range(effect_count):
		var effect_resource: AudioEffect = AudioServer.get_bus_effect(_record_bus_index, effect_index)
		var effect_instance: AudioEffectInstance = AudioServer.get_bus_effect_instance(_record_bus_index, effect_index)
		if effect_resource is AudioEffectSpectrumAnalyzer:
			var spectrum: AudioEffectSpectrumAnalyzerInstance = effect_instance as AudioEffectSpectrumAnalyzerInstance
			if spectrum != null:
				_spectrum = spectrum
		elif effect_resource is AudioEffectCapture:
			var capture_effect: AudioEffectCapture = effect_resource as AudioEffectCapture
			if capture_effect != null:
				_capture = capture_effect


func _ensure_record_bus_effects() -> void:
	_record_bus_index = AudioServer.get_bus_index("Record")
	if _record_bus_index == -1:
		return

	var has_spectrum: bool = false
	var has_capture: bool = false
	var effect_count: int = AudioServer.get_bus_effect_count(_record_bus_index)
	for effect_index: int in range(effect_count):
		var effect_resource: AudioEffect = AudioServer.get_bus_effect(_record_bus_index, effect_index)
		if effect_resource is AudioEffectSpectrumAnalyzer:
			has_spectrum = true
			AudioServer.set_bus_effect_enabled(_record_bus_index, effect_index, true)
		elif effect_resource is AudioEffectCapture:
			has_capture = true
			AudioServer.set_bus_effect_enabled(_record_bus_index, effect_index, true)

	if not has_spectrum:
		var spectrum_effect: AudioEffectSpectrumAnalyzer = AudioEffectSpectrumAnalyzer.new()
		AudioServer.add_bus_effect(_record_bus_index, spectrum_effect)

	if not has_capture:
		var capture_effect: AudioEffectCapture = AudioEffectCapture.new()
		capture_effect.buffer_length = 0.2
		AudioServer.add_bus_effect(_record_bus_index, capture_effect)


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
	AudioServer.set_bus_mute(_record_bus_index, false)
	AudioServer.set_bus_volume_db(_record_bus_index, ANALYSIS_BUS_VOLUME_DB)
	return true


func _restore_record_bus_state() -> void:
	if _record_bus_index == -1 or not _record_bus_state_cached:
		return
	AudioServer.set_bus_mute(_record_bus_index, _record_bus_prev_mute)
	AudioServer.set_bus_volume_db(_record_bus_index, _record_bus_prev_volume_db)


func _resolve_pitch_backend() -> void:
	if _pitch_service != null:
		return

	var singleton: Node = get_node_or_null(CSHARP_PITCH_SINGLETON_PATH)
	if singleton != null and singleton.has_method("AnalyzeSamples"):
		_pitch_service = singleton
		_last_csharp_skip_reason = ""
		_set_backend_mode("CSharp")
		_log_event("C# backend resolved via singleton")
		return

	if not ClassDB.class_exists(CSHARP_PITCH_CLASS_NAME):
		_last_csharp_skip_reason = "C# singleton/class not registered"
		_set_backend_mode("GDScript")
		_log_event(_last_csharp_skip_reason)
		return

	var instance: Object = ClassDB.instantiate(CSHARP_PITCH_CLASS_NAME)
	if instance == null:
		_last_csharp_skip_reason = "ClassDB instantiation failed"
		_set_backend_mode("GDScript")
		_log_event(_last_csharp_skip_reason)
		return

	_pitch_service = instance
	_last_csharp_skip_reason = ""
	_set_backend_mode("CSharp")
	_log_event("C# backend resolved via ClassDB")


func _set_backend_mode(mode: String) -> void:
	if _backend_mode == mode:
		return
	_backend_mode = mode
	backend_mode_changed.emit(_backend_mode)


func _try_csharp_yin_detection() -> Dictionary:
	if _pitch_service == null:
		return {"valid": false, "reason": "Pitch service unavailable"}
	if _capture == null:
		return {"valid": false, "reason": "Capture effect missing"}
	if not _pitch_service.has_method("AnalyzeSamples"):
		return {"valid": false, "reason": "AnalyzeSamples method missing"}

	if not _capture.can_get_buffer(CAPTURE_FRAME_COUNT):
		return {"valid": false, "reason": "Waiting for capture frames"}

	var sample_frames: PackedVector2Array = _capture.get_buffer(CAPTURE_FRAME_COUNT)
	if sample_frames.is_empty():
		return {"valid": false, "reason": "Capture buffer empty"}
	var sample_array: Array = []
	sample_array.resize(sample_frames.size())
	for i: int in range(sample_frames.size()):
		sample_array[i] = sample_frames[i]

	var result: Variant = _pitch_service.call(
		"AnalyzeSamples",
		sample_array,
		float(AudioServer.get_mix_rate()),
		MIN_FREQUENCY_HZ,
		MAX_FREQUENCY_HZ,
		_min_confidence
	)
	if result is Dictionary:
		var detected: Dictionary = result as Dictionary
		if bool(detected.get("valid", false)):
			detected["source"] = "CSharpYIN"
			detected["reason"] = ""
		else:
			detected["reason"] = String(detected.get("status", "YIN result invalid"))
		return detected
	return {"valid": false, "reason": "C# result not a Dictionary"}


func _analyze_spectrum_bins() -> Dictionary:
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

	var input_level_db: float = linear_to_db(max(loudest_magnitude, 0.0000001))
	var average_magnitude: float = total_magnitude / max(float(bin_count), 1.0)
	var peak_ratio: float = loudest_magnitude / max(average_magnitude, 0.0000001)
	var confidence: float = clamp((peak_ratio - 1.0) / 6.0, 0.0, 1.0)
	return {
		"valid": loudest_frequency > 0.0,
		"frequency": loudest_frequency,
		"confidence": confidence,
		"input_level_db": input_level_db,
		"source": "GDScriptFFT"
	}


func _update_detection(delta: float) -> void:
	_emit_spectrum_bins()
	var detection: Dictionary = _try_csharp_yin_detection()
	if not bool(detection.get("valid", false)):
		_last_csharp_skip_reason = String(detection.get("reason", "YIN fallback"))
		detection = _analyze_spectrum_bins()
		detection["fallback_reason"] = _last_csharp_skip_reason
	else:
		_last_csharp_skip_reason = ""

	var raw_frequency: float = float(detection.get("frequency", 0.0))
	var confidence: float = float(detection.get("confidence", 0.0))
	_input_level_db = float(detection.get("input_level_db", -80.0))
	_update_adaptive_noise_floor(raw_frequency, confidence)
	input_level_changed.emit(_input_level_db)

	if _input_level_db < _effective_min_signal_db:
		_handle_invalid_note_input(delta, "Waiting for louder input")
		return

	if confidence < _min_confidence or raw_frequency <= 0.0:
		_handle_invalid_note_input(delta, "Input detected but not stable")
		return

	_invalid_input_elapsed_sec = 0.0
	var source: String = String(detection.get("source", _backend_mode))
	var candidate_frequency: float = raw_frequency if _locked_frequency <= 0.0 else lerp(_locked_frequency, raw_frequency, SMOOTHING_ALPHA)
	var candidate_note: String = convert_hz_to_note(raw_frequency)
	pitch_candidate_changed.emit(raw_frequency, candidate_note, confidence)
	_add_candidate_sample(candidate_note, raw_frequency, confidence, delta)

	var dominant: Dictionary = _get_dominant_candidate()
	var dominant_note: String = String(dominant.get("note", "--"))
	var dominant_count: int = int(dominant.get("count", 0))
	var dominant_frequency: float = float(dominant.get("frequency", candidate_frequency))
	var dominant_confidence: float = float(dominant.get("confidence", confidence))
	var required_count: int = _get_required_candidate_count()

	if dominant_note == "--" or dominant_count < required_count:
		_stable_frame_count = dominant_count
		_set_status("Stabilizing note (%d/%d)" % [dominant_count, required_count])
		_emit_current_locked_note()
		return

	_stable_frame_count = dominant_count
	if _locked_note == "--":
		_lock_note(dominant_note, dominant_frequency, dominant_confidence, source, detection)
		return

	if dominant_note == _locked_note:
		_candidate_note = dominant_note
		_candidate_switch_elapsed_sec = 0.0
		_update_locked_note(dominant_frequency, dominant_confidence, source, detection)
		return

	if dominant_note != _candidate_note:
		_candidate_note = dominant_note
		_candidate_switch_elapsed_sec = 0.0
	else:
		_candidate_switch_elapsed_sec += delta

	if _candidate_switch_elapsed_sec < NOTE_SWITCH_MIN_SEC:
		_set_status("Holding %s; testing %s" % [_locked_note, dominant_note])
		_emit_current_locked_note()
		return

	_lock_note(dominant_note, dominant_frequency, dominant_confidence, source, detection)


func _handle_invalid_note_input(delta: float, status: String) -> void:
	_candidate_history.clear()
	_candidate_note = ""
	_stable_frame_count = 0
	_candidate_switch_elapsed_sec = 0.0
	pitch_candidate_changed.emit(0.0, "--", 0.0)
	_invalid_input_elapsed_sec += delta
	_set_status(status)
	if _locked_note != "--" and _invalid_input_elapsed_sec >= NOTE_RELEASE_GRACE_SEC:
		_release_locked_note(_locked_note)
	elif _locked_note == "--":
		_detected_frequency = 0.0
		_detected_note = "--"
		_detected_confidence = 0.0
		note_detected.emit(_detected_frequency, _detected_note, _detected_confidence)


func _clear_detection(status: String) -> void:
	_reset_note_decision_state()
	_set_status(status)
	note_detected.emit(_detected_frequency, _detected_note, _detected_confidence)
	pitch_candidate_changed.emit(0.0, "--", 0.0)


func _reset_note_decision_state() -> void:
	_candidate_note = ""
	_stable_frame_count = 0
	_candidate_history.clear()
	_candidate_switch_elapsed_sec = 0.0
	_invalid_input_elapsed_sec = 0.0
	_locked_note = "--"
	_locked_frequency = 0.0
	_locked_confidence = 0.0
	_detected_frequency = 0.0
	_detected_note = "--"
	_detected_confidence = 0.0


func _add_candidate_sample(note_name: String, frequency: float, confidence: float, delta: float) -> void:
	for sample: Dictionary in _candidate_history:
		sample["age"] = float(sample.get("age", 0.0)) + delta
	_candidate_history.append({
		"note": note_name,
		"frequency": frequency,
		"confidence": confidence,
		"age": 0.0
	})
	var retained: Array[Dictionary] = []
	for sample: Dictionary in _candidate_history:
		if float(sample.get("age", 0.0)) <= NOTE_HISTORY_WINDOW_SEC:
			retained.append(sample)
	_candidate_history = retained


func _get_dominant_candidate() -> Dictionary:
	if _candidate_history.is_empty():
		return {"note": "--", "count": 0, "frequency": 0.0, "confidence": 0.0}

	var stats: Dictionary = {}
	for sample: Dictionary in _candidate_history:
		var note_name: String = String(sample.get("note", "--"))
		if note_name == "--":
			continue
		if not stats.has(note_name):
			stats[note_name] = {
				"count": 0,
				"frequency_sum": 0.0,
				"confidence_sum": 0.0
			}
		var note_stats: Dictionary = stats[note_name] as Dictionary
		note_stats["count"] = int(note_stats.get("count", 0)) + 1
		note_stats["frequency_sum"] = float(note_stats.get("frequency_sum", 0.0)) + float(sample.get("frequency", 0.0))
		note_stats["confidence_sum"] = float(note_stats.get("confidence_sum", 0.0)) + float(sample.get("confidence", 0.0))

	var best_note: String = "--"
	var best_count: int = 0
	var best_frequency: float = 0.0
	var best_confidence: float = 0.0
	for note_name: String in stats.keys():
		var note_stats: Dictionary = stats[note_name] as Dictionary
		var count: int = int(note_stats.get("count", 0))
		if count > best_count:
			best_note = note_name
			best_count = count
			best_frequency = float(note_stats.get("frequency_sum", 0.0)) / float(max(count, 1))
			best_confidence = float(note_stats.get("confidence_sum", 0.0)) / float(max(count, 1))

	return {
		"note": best_note,
		"count": best_count,
		"frequency": best_frequency,
		"confidence": best_confidence
	}


func _get_required_candidate_count() -> int:
	var history_count: int = max(_candidate_history.size(), 1)
	var ratio_count: int = int(ceil(float(history_count) * NOTE_LOCK_MIN_RATIO))
	return max(_stable_frames_required, ratio_count)


func _lock_note(note_name: String, frequency: float, confidence: float, source: String, detection: Dictionary) -> void:
	var previous_note: String = _locked_note
	_locked_note = note_name
	_locked_frequency = frequency
	_locked_confidence = confidence
	_detected_frequency = frequency
	_detected_note = note_name
	_detected_confidence = confidence
	_candidate_note = note_name
	_candidate_switch_elapsed_sec = 0.0
	if previous_note != note_name:
		_log_note_capture(source, frequency, note_name, confidence)
	_apply_capture_status(source, detection)
	note_locked.emit(_detected_frequency, _detected_note, _detected_confidence)
	note_detected.emit(_detected_frequency, _detected_note, _detected_confidence)


func _update_locked_note(frequency: float, confidence: float, source: String, detection: Dictionary) -> void:
	_locked_frequency = lerp(_locked_frequency, frequency, SMOOTHING_ALPHA) if _locked_frequency > 0.0 else frequency
	_locked_confidence = confidence
	_detected_frequency = _locked_frequency
	_detected_note = _locked_note
	_detected_confidence = _locked_confidence
	_apply_capture_status(source, detection)
	note_detected.emit(_detected_frequency, _detected_note, _detected_confidence)


func _emit_current_locked_note() -> void:
	if _locked_note == "--":
		_detected_frequency = 0.0
		_detected_note = "--"
		_detected_confidence = 0.0
		return
	_detected_frequency = _locked_frequency
	_detected_note = _locked_note
	_detected_confidence = _locked_confidence
	note_detected.emit(_detected_frequency, _detected_note, _detected_confidence)


func _release_locked_note(note_name: String) -> void:
	_locked_note = "--"
	_locked_frequency = 0.0
	_locked_confidence = 0.0
	_detected_frequency = 0.0
	_detected_note = "--"
	_detected_confidence = 0.0
	note_released.emit(note_name)
	note_detected.emit(_detected_frequency, _detected_note, _detected_confidence)


func _apply_capture_status(source: String, detection: Dictionary) -> void:
	if source == "GDScriptFFT" and String(detection.get("fallback_reason", "")) != "":
		_set_status("Locked (%s: %s)" % [source, String(detection.get("fallback_reason", ""))])
	else:
		_set_status("Locked (%s)" % source)


func _set_status(status: String) -> void:
	_status_text = status


func _reset_adaptive_noise_floor() -> void:
	_noise_floor_db = -80.0
	_recompute_effective_min_signal_db()


func _update_adaptive_noise_floor(raw_frequency: float, confidence: float) -> void:
	var likely_noise: bool = raw_frequency <= 0.0 or confidence < _min_confidence
	if likely_noise:
		_noise_floor_db = lerp(_noise_floor_db, _input_level_db, NOISE_FLOOR_SMOOTH_ALPHA)
	_recompute_effective_min_signal_db()


func _recompute_effective_min_signal_db() -> void:
	var adaptive_floor: float = _noise_floor_db + ADAPTIVE_NOISE_MARGIN_DB
	_effective_min_signal_db = clamp(max(_min_signal_db, adaptive_floor), -80.0, -10.0)


func _log_note_capture(source: String, frequency: float, note_name: String, confidence: float) -> void:
	_log_event(
		"Note captured source=%s note=%s frequency=%.2fHz confidence=%.2f" % [
			source,
			note_name,
			frequency,
			confidence
		]
	)


func _log_event(message: String) -> void:
	var line: String = "[AudioProcessor] %s" % message
	print(line)
	diagnostic_logged.emit(line)
