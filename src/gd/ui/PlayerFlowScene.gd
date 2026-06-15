extends Control

const _DEBUG_SCENE_PATH: String = "res://src/gd/scenes/debug/TestScene.tscn"
const _EXPLORE_WORLD_SCENE_PATH: String = "res://src/gd/scenes/world/ExploreWorldScene.tscn"
const _AUDIO_PROCESSOR_PATH: String = "/root/AudioProcessor"
const _BATTLE_MANAGER_PATH: String = "/root/BattleManager"

@onready var _debug_tools_button: Button = %DebugToolsButton
@onready var _explore_world_button: Button = %ExploreWorldButton
@onready var _toggle_listening_button: Button = %ToggleListeningButton
@onready var _reset_battle_button: Button = %ResetBattleButton
@onready var _action_status_label: Label = %ActionStatusLabel

var _audio_processor: Node
var _battle_manager: Node


func _ready() -> void:
	UiSkinApplier.apply_to_scene(self, UiSkinApplier.load_default_skin())
	_debug_tools_button.visible = OS.is_debug_build()
	_debug_tools_button.pressed.connect(_on_debug_tools_button_pressed)
	_explore_world_button.pressed.connect(_on_explore_world_button_pressed)
	_toggle_listening_button.pressed.connect(_on_toggle_listening_button_pressed)
	_reset_battle_button.pressed.connect(_on_reset_battle_button_pressed)

	_audio_processor = _resolve_audio_processor()
	_battle_manager = _resolve_battle_manager()
	_connect_audio_signals()
	_connect_battle_signals()
	_sync_action_strip_state()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F8:
			_open_explore_world()


func _process(_delta: float) -> void:
	if _audio_processor == null:
		_audio_processor = _resolve_audio_processor()
		if _audio_processor != null:
			_connect_audio_signals()
			_sync_action_strip_state()

	if _battle_manager == null:
		_battle_manager = _resolve_battle_manager()
		if _battle_manager != null:
			_connect_battle_signals()
			_sync_action_strip_state()


func _resolve_audio_processor() -> Node:
	return get_node_or_null(_AUDIO_PROCESSOR_PATH)


func _resolve_battle_manager() -> Node:
	return get_node_or_null(_BATTLE_MANAGER_PATH)


func _connect_audio_signals() -> void:
	if _audio_processor == null:
		return
	if not _audio_processor.is_connected("capture_state_changed", _on_capture_state_changed):
		_audio_processor.connect("capture_state_changed", _on_capture_state_changed)


func _connect_battle_signals() -> void:
	if _battle_manager == null:
		return
	if not _battle_manager.is_connected("battle_started", _on_battle_started):
		_battle_manager.connect("battle_started", _on_battle_started)
	if not _battle_manager.is_connected("battle_ended", _on_battle_ended):
		_battle_manager.connect("battle_ended", _on_battle_ended)


func _sync_action_strip_state() -> void:
	if _audio_processor == null:
		_toggle_listening_button.text = "Start Listening"
		_toggle_listening_button.disabled = true
		_reset_battle_button.disabled = true
		_action_status_label.text = "Audio unavailable"
		return

	var is_capturing: bool = bool(_audio_processor.call("is_capturing"))
	_toggle_listening_button.disabled = false
	_toggle_listening_button.text = "Stop Listening" if is_capturing else "Start Listening"
	_reset_battle_button.disabled = (not is_capturing) or (_battle_manager == null)
	if is_capturing:
		_action_status_label.text = "Listening active"
	else:
		_action_status_label.text = "Listening idle"


func _on_debug_tools_button_pressed() -> void:
	var result: Error = get_tree().change_scene_to_file(_DEBUG_SCENE_PATH)
	if result != OK:
		push_warning("PlayerFlowScene: Failed to open debug tools scene.")


func _on_explore_world_button_pressed() -> void:
	_open_explore_world()


func _open_explore_world() -> void:
	var result: Error = get_tree().change_scene_to_file(_EXPLORE_WORLD_SCENE_PATH)
	if result != OK:
		push_warning("PlayerFlowScene: Failed to open explore world scene.")


func _on_toggle_listening_button_pressed() -> void:
	if _audio_processor == null:
		_action_status_label.text = "Audio unavailable"
		_sync_action_strip_state()
		return

	var is_capturing: bool = bool(_audio_processor.call("is_capturing"))
	if is_capturing:
		_audio_processor.call("stop_capture")
		_action_status_label.text = "Listening stopped"
	else:
		_audio_processor.call("start_capture")
		_action_status_label.text = "Listening started"
	_sync_action_strip_state()


func _on_reset_battle_button_pressed() -> void:
	if _battle_manager == null:
		_action_status_label.text = "Battle manager unavailable"
		_sync_action_strip_state()
		return

	if _audio_processor != null and not bool(_audio_processor.call("is_capturing")):
		_audio_processor.call("start_capture")
		_action_status_label.text = "Listening started; battle reset"
		_sync_action_strip_state()
		return

	_battle_manager.call("stop_battle")
	_battle_manager.call("start_battle")
	_action_status_label.text = "Battle reset"
	_sync_action_strip_state()


func _on_capture_state_changed(_is_capturing: bool) -> void:
	_sync_action_strip_state()


func _on_battle_started(_player_hp: int, _enemy_hp: int) -> void:
	_action_status_label.text = "Battle started"
	_sync_action_strip_state()


func _on_battle_ended(result: String, _turns: int) -> void:
	_action_status_label.text = "Battle %s" % result
	_sync_action_strip_state()