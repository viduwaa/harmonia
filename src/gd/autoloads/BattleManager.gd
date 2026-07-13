extends Node

signal battle_started(player_hp: int, enemy_hp: int)
signal turn_started(target_note: String, turn_index: int, time_limit_sec: float)
signal turn_resolved(target_note: String, detected_note: String, grade: String, player_hp: int, enemy_hp: int)
signal battle_ended(result: String, turns: int)
signal battle_debug(message: String)
signal note_attempt_payload_ready(payload: Dictionary)
signal game_session_payload_ready(payload: Dictionary)
## Live per-frame feedback for the practice hold-quality grading model.
## Fires while a practice turn is in progress with the current detected note,
## the most-held note this turn, and the proportion of the turn the player has
## held an acceptable note so far (0..1). Drives the "you played X / target Y /
## hold %" indicator in the practice scene.
signal turn_note_live(target_note: String, detected_note: String, mode_note: String, hold_quality: float)

const BATTLE_MODE_STORY: String = "story"
const BATTLE_MODE_PRACTICE: String = "practice"
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

# --- Practice hold-quality grading model (Q1=B, Q5=instant-hit) ----------
# How long a player must hold an acceptable (Perfect/Good) note before the turn
# resolves instantly as a hit (rather than waiting for the timer). 0.20s is
# forgiving to short bursts of correct singing; lower it via
# set_practice_difficulty({"instant_hit_hold_sec": 0.10}) for an easier level.
const PRACTICE_INSTANT_HIT_HOLD_SEC: float = 0.20
# Hold-quality thresholds (held_acceptable_sec / turn_time_limit).
# At/above the higher -> Perfect; between the two -> Good; above the lower but
# below good -> Near; below the lower -> Miss. Near band lowered from 0.15 to
# 0.08 so a ~0.32s burst of correct singing on a 4.0s turn escapes Miss at
# timeout (was 0.6s).
const PRACTICE_HOLD_QUALITY_PERFECT: float = 0.7
const PRACTICE_HOLD_QUALITY_GOOD: float = 0.4
const PRACTICE_HOLD_QUALITY_NEAR: float = 0.08
# Damage scaling on a successful hold-quality hit. Lerp from min to max by
# hold_quality so a clutch last-second hold deals less than a sustained one.
const PRACTICE_DAMAGE_PERFECT_MIN: int = 14
const PRACTICE_DAMAGE_PERFECT_MAX: int = 20
const PRACTICE_DAMAGE_GOOD_MIN: int = 8
const PRACTICE_DAMAGE_GOOD_MAX: int = 14
const PRACTICE_DAMAGE_NEAR: int = 5
# Player punishment on a Miss, scaled by how far the mode-note pitch class was
# from the target (0 semitones = fell off the note entirely near the end, full
# DAMAGE_MISS; distance >= 3 = way off, clamped to DAMAGE_MISS).
const PRACTICE_DAMAGE_PLAYER_MISS_MAX: int = 10
const PRACTICE_MISS_DISTANCE_FULL_PENALTY: int = 3
# Octave matching modes (kept in sync with LocalDataManager constants).
const OCTAVE_MODE_PITCH_CLASS: String = "pitch_class"
const OCTAVE_MODE_EXACT_OCTAVE: String = "exact_octave"
const OCTAVE_MODE_DEFAULT: String = OCTAVE_MODE_PITCH_CLASS
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
# In practice mode, set true at turn start so _process can poll AudioProcessor's
# currently-held note and evaluate it once the time guard elapses. Cleared once
# the poll fires (whether or not it found a valid note) to avoid re-polling.
var _practice_poll_pending: bool = false
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
var _session_profile_name: String = ""
var _battle_mode: String = BATTLE_MODE_STORY
var _practice_target_note: String = ""
# When > 0.0, practice turns use this time limit instead of TURN_TIME_LIMIT_SEC.
var _practice_turn_time_sec: float = 0.0
# Octave matching mode for practice grading ("pitch_class" or "exact_octave").
# Drives both the frequency meter (Phase 2) and gameplay grading so they agree.
var _practice_octave_mode: String = OCTAVE_MODE_DEFAULT
# --- Per-turn hold-quality accumulator (practice hold-quality model) -------
# samples[i] = {"note": String, "freq": float, "confidence": float, "dt": float}
var _turn_note_samples: Array[Dictionary] = []
# Running totals by note string (for mode-note computation).
var _turn_note_time_totals: Dictionary = {}
# Running total of time spent on an acceptable note (target match under the
# current octave mode).
var _turn_acceptable_held_sec: float = 0.0
# Running total of time spent on any valid detected note (confidence >= floor).
var _turn_valid_held_sec: float = 0.0
# When true, an instant hit has been armed (held acceptable note for >= the
# instant-hit threshold); the next frame flips it to _resolve_turn.
var _practice_instant_hit_armed: bool = false
# Diagnostic logging state for _accumulate_practice_frame. Tracks the last
# note name we logged so we only emit one debug line per detection transition
# (avoids per-frame log spam).
var _practice_last_logged_note: String = ""
var _practice_acceptable_logged_state: bool = false
var _practice_last_logged_accept_sec: float = 0.0
# --- Difficulty profile (Q4: scalable per-level) --------------------------
# A Dictionary of the PRACTICE_* constants above. Callers (ExploreWorld,
# level selector) may override via set_practice_difficulty(). Empty = defaults.
var _practice_difficulty: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_audio_processor = get_node_or_null("/root/AudioProcessor")
	if _audio_processor == null:
		push_warning("BattleManager: AudioProcessor not found.")
	else:
		if _audio_processor.has_signal("note_locked"):
			if not _audio_processor.is_connected("note_locked", _on_note_detected):
				_audio_processor.connect("note_locked", _on_note_detected)
		elif not _audio_processor.is_connected("note_detected", _on_note_detected):
			_audio_processor.connect("note_detected", _on_note_detected)
		if _audio_processor.has_signal("note_released") and not _audio_processor.is_connected("note_released", _on_note_released):
			_audio_processor.connect("note_released", _on_note_released)
		if not _audio_processor.is_connected("capture_state_changed", _on_capture_state_changed):
			_audio_processor.connect("capture_state_changed", _on_capture_state_changed)

	call_deferred("_bind_payload_persistence")


func _process(delta: float) -> void:
	if not _battle_active or _turn_resolved:
		return
	_turn_elapsed_sec += delta
	_turn_time_left -= delta
	if _turn_time_left <= 0.0:
		if _battle_mode == BATTLE_MODE_PRACTICE:
			_resolve_practice_turn_by_hold_quality(true)
		else:
			_resolve_turn("Miss", "--", "Turn timeout without a valid note", 0.0, true)
		return
	if _battle_mode == BATTLE_MODE_PRACTICE:
		_accumulate_practice_frame(delta)
		if _practice_poll_pending and _turn_elapsed_sec >= MIN_TURN_EVAL_DELAY_SEC:
			_practice_poll_held_note()
		if _practice_instant_hit_armed:
			_resolve_practice_turn_by_hold_quality(false)


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
	_session_profile_name = _resolve_active_profile_name()
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


func start_practice_battle(target_note: String = "") -> void:
	var resolved_note: String = _normalize_practice_note(target_note if not target_note.strip_edges().is_empty() else _practice_target_note)
	if resolved_note.is_empty():
		push_warning("BattleManager: Practice battle requires a valid target note.")
		return
	_battle_mode = BATTLE_MODE_PRACTICE
	_practice_target_note = resolved_note
	start_battle()


func stop_battle() -> void:
	_battle_active = false
	_turn_resolved = true


func is_battle_active() -> bool:
	return _battle_active


func get_battle_mode() -> String:
	return _battle_mode


func get_practice_target_note() -> String:
	return _practice_target_note


func set_practice_turn_time(time_sec: float) -> void:
	# Persisted/clamped by callers (PracticeSetupScene); keep a defensive clamp here too.
	_practice_turn_time_sec = maxf(0.0, float(time_sec))


func get_practice_turn_time() -> float:
	return _practice_turn_time_sec


## Set the octave match mode used by practice grading ("pitch_class" or
## "exact_octave"). Should match the frequency meter's setting so the visual
## feedback and gameplay grading agree. Persisted/loaded by the caller via
## LocalDataManager.load_practice_settings / save_practice_settings.
func set_practice_octave_mode(mode: String) -> void:
	if mode == OCTAVE_MODE_EXACT_OCTAVE:
		_practice_octave_mode = OCTAVE_MODE_EXACT_OCTAVE
	else:
		_practice_octave_mode = OCTAVE_MODE_PITCH_CLASS


func get_practice_octave_mode() -> String:
	return _practice_octave_mode


## Override the practice hold-quality grading constants per difficulty/level.
## profile keys (all optional — missing keys fall back to the PRACTICE_* defaults):
##   "instant_hit_hold_sec", "hold_quality_perfect", "hold_quality_good",
##   "hold_quality_near", "damage_perfect_min", "damage_perfect_max",
##   "damage_good_min", "damage_good_max", "damage_near",
##   "damage_player_miss_max", "miss_distance_full_penalty"
## Per-frame confidence floor is NOT in this profile — it is synced at runtime
## from AudioProcessor.get_min_confidence() (calibration slider) so a level can't
## silently disagree with the microphone calibration.
func set_practice_difficulty(profile: Dictionary) -> void:
	_practice_difficulty = profile.duplicate(true)


func get_practice_difficulty() -> Dictionary:
	return _practice_difficulty.duplicate(true)


func _difficulty_value(key: String, default_value: float) -> float:
	if _practice_difficulty.has(key):
		return float(_practice_difficulty[key])
	return default_value


func _difficulty_value_int(key: String, default_value: int) -> int:
	if _practice_difficulty.has(key):
		return int(_practice_difficulty[key])
	return default_value



func configure_practice_mode(target_note: String) -> bool:
	var resolved_note: String = _normalize_practice_note(target_note)
	if resolved_note.is_empty():
		push_warning("BattleManager: Invalid practice target note '%s'." % target_note)
		return false
	_battle_mode = BATTLE_MODE_PRACTICE
	_practice_target_note = resolved_note
	return true


func clear_practice_mode() -> void:
	_battle_mode = BATTLE_MODE_STORY
	_practice_target_note = ""
	_practice_turn_time_sec = 0.0
	_practice_octave_mode = OCTAVE_MODE_DEFAULT
	_practice_difficulty.clear()
	_reset_turn_note_samples()


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
		if _battle_mode == BATTLE_MODE_PRACTICE and not _practice_target_note.is_empty():
			start_practice_battle(_practice_target_note)
		else:
			start_battle()
	elif not is_capturing and _battle_active:
		stop_battle()


func _on_note_released(_note_name: String) -> void:
	_last_detected_note_name = "--"


# ---------------------------------------------------------------------------
# Practice hold-quality grading model (Q1=B, Q5=instant-hit)
# ---------------------------------------------------------------------------

## One-shot poll flag cleared once MIN_TURN_EVAL_DELAY_SEC has elapsed for a
## practice turn. _process already runs _accumulate_practice_frame every frame
## (above this call), so the held note the player is sustaining at turn start
## is sampled automatically once the time guard elapses. This function just
## clears the pending flag so we don't keep re-marking the poll. We don't call
## _accumulate_practice_frame here because _process has already done it this
## frame; calling it again would double-sample with dt=0.0.
func _practice_poll_held_note() -> void:
	_practice_poll_pending = false
	_log_debug("Practice initial poll fired at %.2fs" % _turn_elapsed_sec)

## Per-frame accumulation for the practice hold-quality model. Called from
## _process each frame while a practice turn is active. Samples the
## AudioProcessor's currently-detected note, records a weighted sample, and
## accumulates hold-quality metrics. Emits turn_note_live and arms the
## instant-hit once the acceptable-hold threshold is crossed.
func _accumulate_practice_frame(delta: float) -> void:
	if _audio_processor == null:
		return
	var detected_note: String = "--"
	var detected_freq: float = 0.0
	var detected_conf: float = 0.0
	if _audio_processor.has_method("get_detected_note"):
		detected_note = String(_audio_processor.call("get_detected_note")).strip_edges()
	if _audio_processor.has_method("get_detected_frequency"):
		detected_freq = float(_audio_processor.call("get_detected_frequency"))
	if _audio_processor.has_method("get_detected_confidence"):
		detected_conf = float(_audio_processor.call("get_detected_confidence"))

	if detected_note.is_empty() or detected_note == "--":
		# No valid note this frame; still emit live signal with the running totals.
		if _practice_last_logged_note != "--":
			_log_debug("PracFrame no-note (silent/invalid) accept_sec=%.2f time_left=%.2f" % [_turn_acceptable_held_sec, _turn_time_left])
			_practice_last_logged_note = "--"
			_practice_acceptable_logged_state = false
			_practice_last_logged_accept_sec = _turn_acceptable_held_sec
		turn_note_live.emit(get_target_note(), "--", _compute_mode_note(), _current_hold_quality())
		return
	if detected_conf < _practice_confidence_floor():
		# Below floor -- not "valid held" time but still display for the user.
		if _practice_last_logged_note != (detected_note + "@lowconf"):
			_log_debug("PracFrame low-conf note=%s conf=%.3f < floor=%.3f accept_sec=%.2f" % [detected_note, detected_conf, _practice_confidence_floor(), _turn_acceptable_held_sec])
			_practice_last_logged_note = detected_note + "@lowconf"
			_practice_acceptable_logged_state = false
			_practice_last_logged_accept_sec = _turn_acceptable_held_sec
		turn_note_live.emit(get_target_note(), detected_note, _compute_mode_note(), _current_hold_quality())
		return

	# Record a weighted sample and accumulate totals.
	_turn_note_samples.append({
		"note": detected_note,
		"freq": detected_freq,
		"confidence": detected_conf,
		"dt": float(delta)
	})
	_turn_valid_held_sec += delta
	_turn_note_time_totals[detected_note] = float(_turn_note_time_totals.get(detected_note, 0.0)) + delta
	_last_detected_note_name = detected_note

	# If the detected note is acceptable under the current octave mode, credit it.
	if _is_acceptable_practice_note(detected_note, get_target_note()):
		_turn_acceptable_held_sec += delta
		if not _practice_instant_hit_armed and _turn_acceptable_held_sec >= _difficulty_value("instant_hit_hold_sec", PRACTICE_INSTANT_HIT_HOLD_SEC):
			_practice_instant_hit_armed = true
			_log_debug("Practice instant-hit armed at %.2fs acceptable hold" % _turn_acceptable_held_sec)

	turn_note_live.emit(get_target_note(), detected_note, _compute_mode_note(), _current_hold_quality())

	# --- DIAGNOSTIC LOGGING (practice hold model) ---------------------------
	# Log once per detection note-change plus a periodic progress tick while a
	# steady note is held. The editor Output panel then shows both the
	# what-the-meter-reads and what-grading-is-crediting so a practice session
	# can be diagnosed end-to-end.
	var acceptable_now: bool = _is_acceptable_practice_note(detected_note, get_target_note())
	var note_changed: bool = detected_note != _practice_last_logged_note
	var acceptable_changed: bool = acceptable_now != _practice_acceptable_logged_state
	var progress_tick: bool = (_turn_acceptable_held_sec - _practice_last_logged_accept_sec) >= 0.1
	if note_changed or acceptable_changed or progress_tick:
		_log_debug(
			"PracFrame note=%s freq=%.1f conf=%.3f target=%s octave_mode=%s acceptable=%s accept_sec=%.2f target_sec=%.2f time_left=%.2f" % [
				detected_note,
				detected_freq,
				detected_conf,
				get_target_note(),
				_practice_octave_mode,
				str(acceptable_now),
				_turn_acceptable_held_sec,
				_difficulty_value("instant_hit_hold_sec", PRACTICE_INSTANT_HIT_HOLD_SEC),
				_turn_time_left
			]
		)
		_practice_last_logged_note = detected_note
		_practice_acceptable_logged_state = acceptable_now
		_practice_last_logged_accept_sec = _turn_acceptable_held_sec


## Returns the most-held note across all practice samples this turn (String).
## Falls back to "--" if no samples recorded. Used as the canonical "what the
## player played" for feedback framing (per Q3 recommendation: mode, not mean).
func _compute_mode_note() -> String:
	var best_note: String = "--"
	var best_time: float = 0.0
	for note_key: Variant in _turn_note_time_totals.keys():
		var note_str: String = String(note_key)
		var note_time: float = float(_turn_note_time_totals[note_key])
		if note_time > best_time or (is_equal_approx(note_time, best_time) and best_note == "--"):
			best_note = note_str
			best_time = note_time
	return best_note


## Returns the proportion of the turn limit the player has held an acceptable
## note so far (0..1). Used by the live indicator and by timeout grading.
func _current_hold_quality() -> float:
	var limit: float = _effective_turn_time_limit()
	if limit <= 0.0:
		return 0.0
	return clampf(_turn_acceptable_held_sec / limit, 0.0, 1.0)


## Returns the time limit for the current turn (practice override or default).
func _effective_turn_time_limit() -> float:
	if _battle_mode == BATTLE_MODE_PRACTICE and _practice_turn_time_sec > 0.0:
		return _practice_turn_time_sec
	return TURN_TIME_LIMIT_SEC


## Practice per-frame confidence floor. Synced from AudioProcessor.get_min_confidence()
## at runtime so the calibration slider (MicrophoneCalibrationScene) flows into
## gameplay grading without needing a BattleManager-side constant. Falls back to
## MIN_CONFIDENCE_GOOD if AudioProcessor is missing or doesn't expose the getter.
## This keeps the meter (`PracticeBattleScene` uses AudioProcessor directly) and
## the gameplay accumulator agreeing on what counts as a confident frame.
func _practice_confidence_floor() -> float:
	if _audio_processor != null and _audio_processor.has_method("get_min_confidence"):
		return float(_audio_processor.call("get_min_confidence"))
	return MIN_CONFIDENCE_GOOD


## True if `detected_note` counts as a hit against `target_note` under the
## current octave match mode. Mirrors the frequency meter's matching rule so
## gameplay grading and visual feedback agree (Q2).
func _is_acceptable_practice_note(detected_note: String, target_note: String) -> bool:
	if detected_note.is_empty() or detected_note == "--" or target_note.is_empty():
		return false
	if _practice_octave_mode == OCTAVE_MODE_EXACT_OCTAVE:
		return detected_note == target_note
	# pitch_class: same pitch class is acceptable regardless of octave.
	var detected_class: String = _extract_pitch_class(detected_note)
	var target_class: String = _extract_pitch_class(target_note)
	return (not detected_class.is_empty()) and detected_class == target_class


## Resolve a practice turn under the hold-quality model. Called either on
## timeout (timed_out=true) or when an instant-hit arms and the next _process
## frame fires (timed_out=false). For instant-hits the proportional-quality
## math (which divides accept_sec by the full turn limit) would always read as
## a Miss because the player can never reach e.g. 70% of a 4s turn in 0.35s.
## Instant-hits therefore grade as Perfect/Good directly from their latest
## sample's confidence; the proportional grading is only used at timeout.
func _resolve_practice_turn_by_hold_quality(timed_out: bool) -> void:
	var mode_note: String = _compute_mode_note()
	var quality: float = _current_hold_quality()
	var target_note: String = get_target_note()
	var detected_freq: float = 0.0
	var latest_conf: float = 0.0
	if not _turn_note_samples.is_empty():
		var latest: Dictionary = _turn_note_samples[_turn_note_samples.size() - 1]
		detected_freq = float(latest.get("freq", 0.0))
		latest_conf = float(latest.get("confidence", 0.0))

	var grade: String = "Miss"
	var enemy_damage: int = 0
	var player_damage: int = 0
	var reason: String = ""

	if not timed_out:
		# Instant-hit: the player sustained an acceptable note past the
		# instant_hit_hold_sec threshold. Grade from confidence (the Q5 "I nailed
		# it, hit lands now" path) rather than the turn-fraction quality (which is
		# always tiny at instant-hit time and would otherwise read as a Miss).
		grade = "Perfect" if latest_conf >= MIN_CONFIDENCE_PERFECT else "Good"
		enemy_damage = _difficulty_value_int("damage_perfect_min", PRACTICE_DAMAGE_PERFECT_MIN) if grade == "Perfect" else _difficulty_value_int("damage_good_min", PRACTICE_DAMAGE_GOOD_MIN)
		reason = "Held target note cleanly for %.2fs (instant-hit)" % _turn_acceptable_held_sec
	elif quality >= _difficulty_value("hold_quality_perfect", PRACTICE_HOLD_QUALITY_PERFECT):
		grade = "Perfect"
		enemy_damage = _lerp_int(_difficulty_value_int("damage_perfect_min", PRACTICE_DAMAGE_PERFECT_MIN), _difficulty_value_int("damage_perfect_max", PRACTICE_DAMAGE_PERFECT_MAX), quality)
		reason = "Held target note for %.0f%% of turn" % [quality * 100.0]
	elif quality >= _difficulty_value("hold_quality_good", PRACTICE_HOLD_QUALITY_GOOD):
		grade = "Good"
		enemy_damage = _lerp_int(_difficulty_value_int("damage_good_min", PRACTICE_DAMAGE_GOOD_MIN), _difficulty_value_int("damage_good_max", PRACTICE_DAMAGE_GOOD_MAX), quality)
		reason = "Held target note for %.0f%% of turn" % [quality * 100.0]
	elif quality >= _difficulty_value("hold_quality_near", PRACTICE_HOLD_QUALITY_NEAR):
		grade = "Near"
		enemy_damage = _difficulty_value_int("damage_near", PRACTICE_DAMAGE_NEAR)
		reason = "Brief target hold (%.0f%% of turn)" % [quality * 100.0]
	else:
		grade = "Miss"
		var distance: int = 0
		if not mode_note.is_empty() and mode_note != "--":
			distance = _pitch_class_distance(target_note, mode_note)
		var miss_max: int = _difficulty_value_int("damage_player_miss_max", PRACTICE_DAMAGE_PLAYER_MISS_MAX)
		var full_penalty_at: int = _difficulty_value_int("miss_distance_full_penalty", PRACTICE_MISS_DISTANCE_FULL_PENALTY)
		var miss_ratio: float = clampf(float(distance) / float(max(full_penalty_at, 1)), 0.0, 1.0)
		player_damage = int(round(lerpf(0.0, float(miss_max), miss_ratio)))
		if player_damage <= 0:
			player_damage = 1 if miss_max > 0 else 0
		reason = "Played %s, target %s (microtime Miss)" % [mode_note, target_note]

	_log_debug(
		"Practice resolved timed_out=%s mode_note=%s quality=%.2f grade=%s enemy_damage=%d player_damage=%d" % [
			str(timed_out), mode_note, quality, grade, enemy_damage, player_damage
		]
	)

	# Apply directly (we have pre-computed damage; bypass _grade_note logic).
	_apply_practice_resolution(grade, mode_note, enemy_damage, player_damage, reason, quality, timed_out, detected_freq)


## Internal: applies the practice resolution including HP updates, payload
## emission, and turn_resolved signal. Mirrors _resolve_turn's contract but
## with explicit damage values instead of matching on grade.
func _apply_practice_resolution(
	grade: String,
	detected_note: String,
	enemy_damage: int,
	player_damage: int,
	reason: String,
	quality: float,
	timed_out: bool,
	detected_frequency: float
) -> void:
	_turn_resolved = true
	var target_note_snapshot: String = get_target_note()
	_enemy_hp = max(_enemy_hp - enemy_damage, 0)
	_player_hp = max(_player_hp - player_damage, 0)

	_log_debug(
		"HP update grade=%s target_pattern=%s detected=%s enemy_damage=%d player_damage=%d reason=%s -> player_hp=%d enemy_hp=%d" % [
			grade,
			_target_pattern,
			detected_note,
			enemy_damage,
			player_damage,
			reason,
			_player_hp,
			_enemy_hp
		]
	)

	_emit_note_attempt_payload(target_note_snapshot, detected_note, grade, 0.0, enemy_damage, player_damage, reason, timed_out)
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


func _reset_turn_note_samples() -> void:
	_turn_note_samples.clear()
	_turn_note_time_totals.clear()
	_turn_acceptable_held_sec = 0.0
	_turn_valid_held_sec = 0.0
	_practice_instant_hit_armed = false
	_practice_last_logged_note = ""
	_practice_acceptable_logged_state = false
	_practice_last_logged_accept_sec = 0.0


func _lerp_int(from_value: int, to_value: int, t: float) -> int:
	return int(round(lerpf(float(from_value), float(to_value), clampf(t, 0.0, 1.0))))


func _on_note_detected(_frequency: float, note_name: String, confidence: float) -> void:
	var previous_note_name: String = _last_detected_note_name
	_last_detected_note_name = note_name

	if not _battle_active or _turn_resolved:
		return
	if note_name == "--":
		return
	if confidence < MIN_CONFIDENCE_GOOD:
		return

	# Practice mode uses the hold-quality model driven by per-frame polling in
	# _process (which has delta time for accurate hold accumulation). The
	# note_locked signal fires only on note change, so it would under-count held
	# time if used as the accumulator. Let _process drive practice grading.
	if _battle_mode == BATTLE_MODE_PRACTICE:
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
	var time_limit: float = TURN_TIME_LIMIT_SEC
	if _battle_mode == BATTLE_MODE_PRACTICE and _practice_turn_time_sec > 0.0:
		time_limit = _practice_turn_time_sec
	_turn_time_left = time_limit
	_turn_elapsed_sec = 0.0
	_turn_gate_logged = false
	_await_fresh_note_for_turn = true
	# Reset the per-turn onset gate baseline so a sustained note can register as a
	# fresh onset for the new turn. Without this, holding the same note across
	# turns (common in practice mode with a single repeated target) leaves
	# _last_detected_note_name equal to the held note and the gate at line ~266
	# blocks evaluation until the user stops and restarts the note.
	_last_detected_note_name = "--"
	_target_pattern = _select_next_target_pattern()
	_target_steps = _parse_target_pattern(_target_pattern)
	_current_step_index = 0
	_practice_poll_pending = (_battle_mode == BATTLE_MODE_PRACTICE)
	# Reset the per-turn hold-quality accumulator so each turn starts from zero.
	# Without this, the previous turn's acceptable_held_sec and instant-hit
	# armed flag leak into the new turn (the new turn would resolve as an
	# instant-hit immediately regardless of what the player sings).
	_reset_turn_note_samples()
	turn_started.emit(_target_pattern, _turn_index, time_limit)


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
	if _battle_mode == BATTLE_MODE_PRACTICE and not _practice_target_note.is_empty():
		return _practice_target_note
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
		"mode": _battle_mode,
		"attempt_id": "%s-%d" % [_session_id, _turn_index],
		"session_id": _session_id,
		"profile_name": _session_profile_name,
		"practice_target_note": _practice_target_note if _battle_mode == BATTLE_MODE_PRACTICE else "",
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
		"mode": _battle_mode,
		"session_id": _session_id,
		"profile_name": _session_profile_name,
		"practice_target_note": _practice_target_note if _battle_mode == BATTLE_MODE_PRACTICE else "",
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


func _resolve_active_profile_name() -> String:
	var game_state: Node = get_node_or_null("/root/GameStateManager")
	if game_state == null:
		return ""
	if game_state.has_method("get_active_profile_name"):
		return String(game_state.call("get_active_profile_name"))
	return ""


func _normalize_practice_note(target_note: String) -> String:
	var cleaned: String = String(target_note).strip_edges().to_upper()
	if cleaned.is_empty():
		return ""
	var has_octave: bool = false
	for index: int in range(cleaned.length()):
		var ch: String = cleaned.substr(index, 1)
		if ch >= "0" and ch <= "9":
			has_octave = true
			break
	if not has_octave:
		cleaned += "4"
	var pitch_class: String = _extract_pitch_class(cleaned)
	if NOTE_CLASSES.find(pitch_class) == -1:
		return ""
	return cleaned


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
