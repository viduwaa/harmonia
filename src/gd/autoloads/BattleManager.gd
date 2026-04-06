extends Node

signal battle_started(player_hp: int, enemy_hp: int)
signal turn_started(target_note: String, turn_index: int, time_limit_sec: float)
signal turn_resolved(target_note: String, detected_note: String, grade: String, player_hp: int, enemy_hp: int)
signal battle_ended(result: String, turns: int)
signal battle_debug(message: String)
signal note_attempt_payload_ready(payload: Dictionary)
signal game_session_payload_ready(payload: Dictionary)

const PLAYER_MAX_HP: int = 100
const ENEMY_MAX_HP: int = 100
const TURN_TIME_LIMIT_SEC: float = 4.0
const MIN_TURN_EVAL_DELAY_SEC: float = 0.35
const MIN_CONFIDENCE_GOOD: float = 0.12
const MIN_CONFIDENCE_PERFECT: float = 0.20
const DAMAGE_PERFECT: int = 20
const DAMAGE_GOOD: int = 12
const DAMAGE_NEAR: int = 5
const DAMAGE_MISS: int = 10
const NOTE_ATTEMPT_VERSION: int = 1
const GAME_SESSION_VERSION: int = 1
# Target pattern syntax for easy editing:
# - Single note: "C4"
# - Sequence in one turn: "C4+E4+G4"
# - Alternatives per step: "A4/A#4+G4"
# Sinhala reference examples: C4=ඩෝ4, D4=රේ4, E4=මි4, G4=සෝ4, A4=ලා4
const TARGET_PATTERNS: PackedStringArray = [
	"C4",
	"D4",
	"E4",
	"G4",
	"A4",
]
# English pitch classes with Sinhala solfege mapping:
# C=ඩෝ, C#=ඩෝ#, D=රේ, D#=රේ#, E=මි, F=ෆා, F#=ෆා#, G=සෝ, G#=සෝ#, A=ලා, A#=ලා#, B=ති
const NOTE_CLASSES: PackedStringArray = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

var _audio_processor: Node
var _local_data_manager: Node
var _battle_active: bool = false
var _turn_resolved: bool = false
var _player_hp: int = PLAYER_MAX_HP
var _enemy_hp: int = ENEMY_MAX_HP
var _turn_index: int = 0
var _target_pattern: String = "C4"
var _target_steps: Array = []
var _current_step_index: int = 0
var _turn_time_left: float = TURN_TIME_LIMIT_SEC
var _turn_elapsed_sec: float = 0.0
var _await_fresh_note_for_turn: bool = true
var _last_detected_note_name: String = "--"
var _turn_gate_logged: bool = false
var _deterministic_mode_enabled: bool = false
var _deterministic_seed: int = 1337
var _forced_target_patterns: PackedStringArray = PackedStringArray()
var _forced_target_index: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _session_id: String = ""
var _session_started_unix_sec: int = 0
var _session_grade_counts: Dictionary = {}
var _session_note_attempt_count: int = 0
var _session_timeout_count: int = 0
var _session_turn_time_total_sec: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_audio_processor = get_node_or_null("/root/AudioProcessor")
	if _audio_processor == null:
		push_warning("BattleManager: AudioProcessor not found.")
	else:
		if not _audio_processor.is_connected("note_detected", _on_note_detected):
			_audio_processor.connect("note_detected", _on_note_detected)
		if not _audio_processor.is_connected("capture_state_changed", _on_capture_state_changed):
			_audio_processor.connect("capture_state_changed", _on_capture_state_changed)

	call_deferred("_bind_payload_persistence")


func _process(delta: float) -> void:
	if not _battle_active or _turn_resolved:
		return
	_turn_elapsed_sec += delta
	_turn_time_left -= delta
	if _turn_time_left <= 0.0:
		_resolve_turn("Miss", "--", "Turn timeout without a valid note", 0.0, true)


func start_battle() -> void:
	if _deterministic_mode_enabled:
		_rng.seed = _deterministic_seed
		_forced_target_index = 0
		_log_debug(
			"Battle start in deterministic mode seed=%d forced_queue=%s" % [
				_deterministic_seed,
				_format_patterns(_forced_target_patterns)
			]
		)
	else:
		_rng.randomize()
		_forced_target_index = 0

	_battle_active = true
	_turn_resolved = false
	_player_hp = PLAYER_MAX_HP
	_enemy_hp = ENEMY_MAX_HP
	_turn_index = 0
	_session_id = _build_session_id()
	_session_started_unix_sec = int(Time.get_unix_time_from_system())
	_session_grade_counts = {
		"Perfect": 0,
		"Good": 0,
		"Near": 0,
		"Miss": 0
	}
	_session_note_attempt_count = 0
	_session_timeout_count = 0
	_session_turn_time_total_sec = 0.0
	_log_debug("Session started id=%s" % _session_id)
	battle_started.emit(_player_hp, _enemy_hp)
	_start_next_turn()


func stop_battle() -> void:
	_battle_active = false
	_turn_resolved = true


func is_battle_active() -> bool:
	return _battle_active


func get_target_note() -> String:
	if _target_steps.is_empty():
		return _target_pattern
	if _target_steps.size() == 1:
		return _target_pattern
	return "%s [%d/%d]" % [_target_pattern, _current_step_index + 1, _target_steps.size()]


func get_player_hp() -> int:
	return _player_hp


func get_enemy_hp() -> int:
	return _enemy_hp


func get_turn_index() -> int:
	return _turn_index


func get_turn_time_left() -> float:
	return _turn_time_left


func configure_deterministic(enabled: bool, seed_value: int, forced_patterns: PackedStringArray = PackedStringArray()) -> void:
	_deterministic_mode_enabled = enabled
	_deterministic_seed = max(seed_value, 0)
	_forced_target_patterns = _sanitize_patterns(forced_patterns)
	_forced_target_index = 0
	_log_debug(
		"Deterministic config updated enabled=%s seed=%d forced_queue=%s" % [
			str(_deterministic_mode_enabled),
			_deterministic_seed,
			_format_patterns(_forced_target_patterns)
		]
	)


func get_deterministic_mode() -> bool:
	return _deterministic_mode_enabled


func get_deterministic_seed() -> int:
	return _deterministic_seed


func get_forced_target_patterns() -> PackedStringArray:
	return _forced_target_patterns


func _on_capture_state_changed(is_capturing: bool) -> void:
	if is_capturing and not _battle_active:
		start_battle()
	elif not is_capturing and _battle_active:
		stop_battle()


func _on_note_detected(_frequency: float, note_name: String, confidence: float) -> void:
	var previous_note_name: String = _last_detected_note_name
	_last_detected_note_name = note_name

	if not _battle_active or _turn_resolved:
		return
	if note_name == "--":
		return
	if confidence < MIN_CONFIDENCE_GOOD:
		return

	if _await_fresh_note_for_turn:
		if note_name == previous_note_name:
			if not _turn_gate_logged:
				_turn_gate_logged = true
				_log_debug("Turn gate: waiting for fresh note onset (sustained=%s)" % note_name)
			return
		_await_fresh_note_for_turn = false

	if _turn_elapsed_sec < MIN_TURN_EVAL_DELAY_SEC:
		if not _turn_gate_logged:
			_turn_gate_logged = true
			_log_debug("Turn gate: waiting %.2fs before evaluation" % MIN_TURN_EVAL_DELAY_SEC)
		return

	var step_options: PackedStringArray = _get_current_step_options()
	var grade: String = _grade_note(note_name, confidence, step_options)
	_log_debug(
		"Note evaluated target_step=%s detected=%s confidence=%.2f grade=%s" % [
			_step_options_to_text(step_options),
			note_name,
			confidence,
			grade
		]
	)

	if grade == "Perfect" or grade == "Good":
		if _current_step_index < _target_steps.size() - 1:
			_current_step_index += 1
			_await_fresh_note_for_turn = true
			_turn_gate_logged = false
			_log_debug("Step progressed to %d/%d" % [_current_step_index + 1, _target_steps.size()])
			return

	_resolve_turn(grade, note_name, "Detected note evaluated against target pattern", confidence, false)


func _start_next_turn() -> void:
	_turn_resolved = false
	_turn_index += 1
	_turn_time_left = TURN_TIME_LIMIT_SEC
	_turn_elapsed_sec = 0.0
	_turn_gate_logged = false
	_await_fresh_note_for_turn = true
	_target_pattern = _select_next_target_pattern()
	_target_steps = _parse_target_pattern(_target_pattern)
	_current_step_index = 0
	turn_started.emit(_target_pattern, _turn_index, TURN_TIME_LIMIT_SEC)


func _resolve_turn(
	grade: String,
	detected_note: String,
	reason: String,
	confidence: float = 0.0,
	timed_out: bool = false
) -> void:
	_turn_resolved = true
	var enemy_damage: int = 0
	var player_damage: int = 0
	var hp_reason: String = reason
	var target_note_snapshot: String = get_target_note()

	match grade:
		"Perfect":
			enemy_damage = DAMAGE_PERFECT
			hp_reason = "Exact note match with high confidence"
		"Good":
			enemy_damage = DAMAGE_GOOD
			hp_reason = "Exact note match with moderate confidence"
		"Near":
			enemy_damage = DAMAGE_NEAR
			hp_reason = "Adjacent semitone match"
		_:
			player_damage = DAMAGE_MISS

	_enemy_hp = max(_enemy_hp - enemy_damage, 0)
	_player_hp = max(_player_hp - player_damage, 0)

	_log_debug(
		"HP update grade=%s target_pattern=%s detected=%s enemy_damage=%d player_damage=%d reason=%s -> player_hp=%d enemy_hp=%d" % [
			grade,
			_target_pattern,
			detected_note,
			enemy_damage,
			player_damage,
			hp_reason,
			_player_hp,
			_enemy_hp
		]
	)

	_emit_note_attempt_payload(
		target_note_snapshot,
		detected_note,
		grade,
		confidence,
		enemy_damage,
		player_damage,
		hp_reason,
		timed_out
	)

	turn_resolved.emit(target_note_snapshot, detected_note, grade, _player_hp, _enemy_hp)

	if _enemy_hp <= 0:
		_battle_active = false
		_log_debug("Battle ended with result=Win turns=%d" % _turn_index)
		_emit_game_session_payload("Win")
		battle_ended.emit("Win", _turn_index)
		return

	if _player_hp <= 0:
		_battle_active = false
		_log_debug("Battle ended with result=Lose turns=%d" % _turn_index)
		_emit_game_session_payload("Lose")
		battle_ended.emit("Lose", _turn_index)
		return

	_start_next_turn()


func _grade_note(detected_note: String, confidence: float, target_step_options: PackedStringArray) -> String:
	if target_step_options.has(detected_note):
		if confidence >= MIN_CONFIDENCE_PERFECT:
			return "Perfect"
		return "Good"

	var distance: int = _pitch_class_distance_to_options(target_step_options, detected_note)
	if distance == 1:
		return "Near"
	return "Miss"


func _get_current_step_options() -> PackedStringArray:
	if _target_steps.is_empty():
		return PackedStringArray(["C4"])
	var options: PackedStringArray = _target_steps[_current_step_index] as PackedStringArray
	if options == null or options.is_empty():
		return PackedStringArray(["C4"])
	return options


func _parse_target_pattern(pattern: String) -> Array:
	var steps: Array = []
	var step_tokens: PackedStringArray = pattern.split("+", false)
	for step_token: String in step_tokens:
		var cleaned_step: String = step_token.strip_edges()
		if cleaned_step.is_empty():
			continue
		var options: PackedStringArray = PackedStringArray()
		var option_tokens: PackedStringArray = cleaned_step.split("/", false)
		for option_token: String in option_tokens:
			var cleaned_option: String = option_token.strip_edges()
			if cleaned_option.is_empty():
				continue
			options.append(cleaned_option)
		if not options.is_empty():
			steps.append(options)

	if steps.is_empty():
		steps.append(PackedStringArray(["C4"]))

	return steps


func _step_options_to_text(options: PackedStringArray) -> String:
	if options.is_empty():
		return "--"
	return "/".join(options)


func _select_next_target_pattern() -> String:
	if _deterministic_mode_enabled and not _forced_target_patterns.is_empty():
		var pattern: String = _forced_target_patterns[_forced_target_index % _forced_target_patterns.size()]
		_forced_target_index += 1
		return pattern
	return TARGET_PATTERNS[_rng.randi_range(0, TARGET_PATTERNS.size() - 1)]


func _sanitize_patterns(raw_patterns: PackedStringArray) -> PackedStringArray:
	var sanitized: PackedStringArray = PackedStringArray()
	for raw_pattern: String in raw_patterns:
		var cleaned: String = raw_pattern.strip_edges()
		if cleaned.is_empty():
			continue
		sanitized.append(cleaned)
	return sanitized


func _format_patterns(patterns: PackedStringArray) -> String:
	if patterns.is_empty():
		return "[]"
	return "[%s]" % ", ".join(patterns)


func _pitch_class_distance_to_options(target_options: PackedStringArray, detected_note: String) -> int:
	var best_distance: int = 99
	for option_note: String in target_options:
		var distance: int = _pitch_class_distance(option_note, detected_note)
		if distance < best_distance:
			best_distance = distance
	return best_distance


func _pitch_class_distance(target_note: String, detected_note: String) -> int:
	var target_class: String = _extract_pitch_class(target_note)
	var detected_class: String = _extract_pitch_class(detected_note)
	var target_index: int = NOTE_CLASSES.find(target_class)
	var detected_index: int = NOTE_CLASSES.find(detected_class)
	if target_index == -1 or detected_index == -1:
		return 99

	var absolute_delta: int = abs(target_index - detected_index)
	return min(absolute_delta, 12 - absolute_delta)


func _extract_pitch_class(note_name: String) -> String:
	var pitch_class: String = ""
	for i: int in range(note_name.length()):
		var ch: String = note_name.substr(i, 1)
		if ch >= "0" and ch <= "9":
			break
		pitch_class += ch
	return pitch_class


func _log_debug(message: String) -> void:
	var line: String = "[BattleManager] %s" % message
	print(line)
	battle_debug.emit(line)


func _emit_note_attempt_payload(
	target_note: String,
	detected_note: String,
	grade: String,
	confidence: float,
	enemy_damage: int,
	player_damage: int,
	reason: String,
	timed_out: bool
) -> void:
	_session_note_attempt_count += 1
	_session_turn_time_total_sec += _turn_elapsed_sec
	_session_grade_counts[grade] = int(_session_grade_counts.get(grade, 0)) + 1
	if timed_out:
		_session_timeout_count += 1

	var payload: Dictionary = {
		"schema": "NOTE_ATTEMPT",
		"version": NOTE_ATTEMPT_VERSION,
		"attempt_id": "%s-%d" % [_session_id, _turn_index],
		"session_id": _session_id,
		"turn_index": _turn_index,
		"target_pattern": _target_pattern,
		"target_note": target_note,
		"detected_note": detected_note,
		"grade": grade,
		"confidence": confidence,
		"enemy_damage": enemy_damage,
		"player_damage": player_damage,
		"player_hp_after": _player_hp,
		"enemy_hp_after": _enemy_hp,
		"turn_elapsed_sec": _turn_elapsed_sec,
		"timed_out": timed_out,
		"deterministic_enabled": _deterministic_mode_enabled,
		"deterministic_seed": _deterministic_seed,
		"reason": reason,
		"created_unix_sec": int(Time.get_unix_time_from_system())
	}

	note_attempt_payload_ready.emit(payload)


func _emit_game_session_payload(result: String) -> void:
	var ended_unix_sec: int = int(Time.get_unix_time_from_system())
	var duration_sec: int = max(ended_unix_sec - _session_started_unix_sec, 0)
	var avg_turn_sec: float = 0.0
	if _session_note_attempt_count > 0:
		avg_turn_sec = _session_turn_time_total_sec / float(_session_note_attempt_count)

	var payload: Dictionary = {
		"schema": "GAME_SESSION",
		"version": GAME_SESSION_VERSION,
		"session_id": _session_id,
		"result": result,
		"turns": _turn_index,
		"started_unix_sec": _session_started_unix_sec,
		"ended_unix_sec": ended_unix_sec,
		"duration_sec": duration_sec,
		"note_attempt_count": _session_note_attempt_count,
		"timeout_count": _session_timeout_count,
		"average_turn_elapsed_sec": avg_turn_sec,
		"grade_counts": _session_grade_counts.duplicate(true),
		"player_hp_final": _player_hp,
		"enemy_hp_final": _enemy_hp,
		"deterministic_enabled": _deterministic_mode_enabled,
		"deterministic_seed": _deterministic_seed,
		"forced_target_patterns": _packed_strings_to_array(_forced_target_patterns)
	}

	game_session_payload_ready.emit(payload)


func _packed_strings_to_array(values: PackedStringArray) -> Array:
	var out: Array = []
	for value: String in values:
		out.append(value)
	return out


func _build_session_id() -> String:
	var unix_sec: int = int(Time.get_unix_time_from_system())
	var nonce: int = int(Time.get_ticks_usec() % 1000000)
	return "session_%d_%06d" % [unix_sec, nonce]


func _bind_payload_persistence() -> void:
	_local_data_manager = get_node_or_null("/root/LocalDataManager")
	if _local_data_manager == null:
		push_warning("BattleManager: LocalDataManager not found. Payload persistence disabled.")
		return

	if _local_data_manager.has_method("append_note_attempt"):
		var note_attempt_callable: Callable = Callable(_local_data_manager, "append_note_attempt")
		if not is_connected("note_attempt_payload_ready", note_attempt_callable):
			connect("note_attempt_payload_ready", note_attempt_callable)
	else:
		push_warning("BattleManager: LocalDataManager missing append_note_attempt.")

	if _local_data_manager.has_method("append_game_session"):
		var game_session_callable: Callable = Callable(_local_data_manager, "append_game_session")
		if not is_connected("game_session_payload_ready", game_session_callable):
			connect("game_session_payload_ready", game_session_callable)
	else:
		push_warning("BattleManager: LocalDataManager missing append_game_session.")
