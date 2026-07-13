extends Control

const LEVEL_ONE_SCENE_PATH: String = "res://src/gd/scenes/world/ExploreWorldScene.tscn"
const PLAYER_FLOW_SCENE_PATH: String = "res://src/gd/scenes/player/PlayerFlowScene.tscn"
const MICROPHONE_CALIBRATION_SCENE_PATH: String = "res://src/gd/scenes/audio/MicrophoneCalibrationScene.tscn"
const DEBUG_SCENE_PATH: String = "res://src/gd/scenes/debug/TestScene.tscn"
const PROFILE_SELECT_SCENE_PATH: String = "res://src/gd/scenes/menu/ProfileSelectScene.tscn"
const GAME_STATE_MANAGER_PATH: String = "/root/GameStateManager"
const LOCAL_DATA_MANAGER_PATH: String = "/root/LocalDataManager"

@onready var _start_test_level_button: Button = %StartTestLevelButton
@onready var _practice_flow_button: Button = %PracticeFlowButton
@onready var _switch_profile_button: Button = %SwitchProfileButton
@onready var _calibrate_microphone_button: Button = %CalibrateMicrophoneButton
@onready var _quit_button: Button = %QuitButton
@onready var _debug_tools_button: Button = %DebugToolsButton


func _ready() -> void:
	UiSkinApplier.apply_to_scene(self, UiSkinApplier.load_default_skin())
	_debug_tools_button.visible = OS.is_debug_build()
	_start_test_level_button.pressed.connect(_on_start_test_level_pressed)
	_practice_flow_button.pressed.connect(_on_practice_flow_pressed)
	_switch_profile_button.pressed.connect(_on_switch_profile_pressed)
	_calibrate_microphone_button.pressed.connect(_on_calibrate_microphone_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_debug_tools_button.pressed.connect(_on_debug_tools_pressed)
	_update_start_button_for_active_profile()


func _update_start_button_for_active_profile() -> void:
	var game_state: Node = get_node_or_null(GAME_STATE_MANAGER_PATH)
	if game_state == null or not game_state.has_method("get_active_profile_name"):
		_start_test_level_button.text = "Start Level 01"
		return
	var active_name: String = String(game_state.call("get_active_profile_name"))
	if active_name.is_empty():
		_start_test_level_button.text = "Start Level 01"
		_start_test_level_button.tooltip_text = "Select a profile from Profile Select first."
	else:
		_start_test_level_button.text = "Continue as %s" % active_name
		_start_test_level_button.tooltip_text = "Resume Level 01 as %s." % active_name


func _on_start_test_level_pressed() -> void:
	var game_state: Node = get_node_or_null(GAME_STATE_MANAGER_PATH)
	if game_state != null and game_state.has_method("get_active_profile_name"):
		if String(game_state.call("get_active_profile_name")).is_empty():
			var local_data: Node = get_node_or_null(LOCAL_DATA_MANAGER_PATH)
			if local_data != null and local_data.has_method("get_profile_count") and int(local_data.call("get_profile_count")) > 0:
				get_tree().change_scene_to_file(PROFILE_SELECT_SCENE_PATH)
				return
	var result: Error = get_tree().change_scene_to_file(LEVEL_ONE_SCENE_PATH)
	if result != OK:
		push_warning("MainMenuScene: Failed to open level scene.")


func _on_practice_flow_pressed() -> void:
	var result: Error = get_tree().change_scene_to_file(PLAYER_FLOW_SCENE_PATH)
	if result != OK:
		push_warning("MainMenuScene: Failed to open player flow scene.")


func _on_switch_profile_pressed() -> void:
	var result: Error = get_tree().change_scene_to_file(PROFILE_SELECT_SCENE_PATH)
	if result != OK:
		push_warning("MainMenuScene: Failed to open profile selection scene.")


func _on_calibrate_microphone_pressed() -> void:
	var result: Error = get_tree().change_scene_to_file(MICROPHONE_CALIBRATION_SCENE_PATH)
	if result != OK:
		push_warning("MainMenuScene: Failed to open microphone calibration scene.")


func _on_debug_tools_pressed() -> void:
	var result: Error = get_tree().change_scene_to_file(DEBUG_SCENE_PATH)
	if result != OK:
		push_warning("MainMenuScene: Failed to open debug tools scene.")


func _on_quit_pressed() -> void:
	get_tree().quit()
