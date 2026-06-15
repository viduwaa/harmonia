extends Control

const LEVEL_ONE_SCENE_PATH: String = "res://src/gd/scenes/world/ExploreWorldScene.tscn"
const PLAYER_FLOW_SCENE_PATH: String = "res://src/gd/scenes/player/PlayerFlowScene.tscn"
const DEBUG_SCENE_PATH: String = "res://src/gd/scenes/debug/TestScene.tscn"

@onready var _start_test_level_button: Button = %StartTestLevelButton
@onready var _practice_flow_button: Button = %PracticeFlowButton
@onready var _quit_button: Button = %QuitButton
@onready var _debug_tools_button: Button = %DebugToolsButton


func _ready() -> void:
	UiSkinApplier.apply_to_scene(self, UiSkinApplier.load_default_skin())
	_debug_tools_button.visible = OS.is_debug_build()
	_start_test_level_button.pressed.connect(_on_start_test_level_pressed)
	_practice_flow_button.pressed.connect(_on_practice_flow_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_debug_tools_button.pressed.connect(_on_debug_tools_pressed)


func _on_start_test_level_pressed() -> void:
	var result: Error = get_tree().change_scene_to_file(LEVEL_ONE_SCENE_PATH)
	if result != OK:
		push_warning("MainMenuScene: Failed to open level scene.")


func _on_practice_flow_pressed() -> void:
	var result: Error = get_tree().change_scene_to_file(PLAYER_FLOW_SCENE_PATH)
	if result != OK:
		push_warning("MainMenuScene: Failed to open player flow scene.")


func _on_debug_tools_pressed() -> void:
	var result: Error = get_tree().change_scene_to_file(DEBUG_SCENE_PATH)
	if result != OK:
		push_warning("MainMenuScene: Failed to open debug tools scene.")


func _on_quit_pressed() -> void:
	get_tree().quit()
