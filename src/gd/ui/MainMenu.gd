extends Control

const NEW_GAME_SCENE_PATH: String = "res://src/gd/scenes/world/ExploreWorldScene.tscn"
const PRACTICE_MODE_SCENE_PATH: String = "res://src/gd/scenes/player/PlayerFlowScene.tscn"
const FLOAT_ANIMATION_NAME: StringName = &"menu_float"
const FADE_IN_ANIMATION_NAME: StringName = &"fade_in"

@onready var _new_game_button: Button = %NewGameButton
@onready var _load_game_button: Button = %LoadGameButton
@onready var _options_button: Button = %OptionsButton
@onready var _practice_mode_button: Button = %PracticeModeButton
@onready var _exit_button: Button = %ExitButton
@onready var _options_popup: PanelContainer = %OptionsPopup
@onready var _close_options_button: Button = %CloseOptionsButton
@onready var _menu_float_animation_player: AnimationPlayer = %MenuFloatAnimationPlayer
@onready var _fade_animation_player: AnimationPlayer = %FadeAnimationPlayer


func _ready() -> void:
	_configure_menu_float_animation()
	_configure_fade_in_animation()

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_load_game_button.pressed.connect(_on_load_game_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_practice_mode_button.pressed.connect(_on_practice_mode_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_close_options_button.pressed.connect(_on_close_options_pressed)

	_load_game_button.disabled = true
	_load_game_button.tooltip_text = "Save/load flow is reserved for the final persistence hookup."
	_options_popup.visible = false
	_new_game_button.grab_focus()
	_play_intro_animations()


func _configure_menu_float_animation() -> void:
	var animation_library: AnimationLibrary = AnimationLibrary.new()
	var animation: Animation = Animation.new()
	animation.length = 3.2
	animation.loop_mode = Animation.LOOP_LINEAR

	var position_track: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(position_track, NodePath("MenuSafeArea:position:y"))
	animation.value_track_set_update_mode(position_track, Animation.UPDATE_CONTINUOUS)
	animation.track_insert_key(position_track, 0.0, 0.0)
	animation.track_insert_key(position_track, 1.6, -4.0)
	animation.track_insert_key(position_track, 3.2, 0.0)

	animation_library.add_animation(FLOAT_ANIMATION_NAME, animation)
	_menu_float_animation_player.add_animation_library(&"", animation_library)


func _configure_fade_in_animation() -> void:
	var animation_library: AnimationLibrary = AnimationLibrary.new()
	var animation: Animation = Animation.new()
	animation.length = 0.7
	animation.loop_mode = Animation.LOOP_NONE

	var alpha_track: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(alpha_track, NodePath(".:modulate:a"))
	animation.value_track_set_update_mode(alpha_track, Animation.UPDATE_CONTINUOUS)
	animation.track_insert_key(alpha_track, 0.0, 0.0)
	animation.track_insert_key(alpha_track, 0.7, 1.0)

	animation_library.add_animation(FADE_IN_ANIMATION_NAME, animation)
	_fade_animation_player.add_animation_library(&"", animation_library)


func _play_intro_animations() -> void:
	modulate = Color(modulate.r, modulate.g, modulate.b, 0.0)
	_menu_float_animation_player.play(FLOAT_ANIMATION_NAME)
	_fade_animation_player.play(FADE_IN_ANIMATION_NAME)


func _on_new_game_pressed() -> void:
	_change_scene(NEW_GAME_SCENE_PATH, "new game")


func _on_load_game_pressed() -> void:
	push_warning("MainMenu: Load Game is not connected yet.")


func _on_options_pressed() -> void:
	_options_popup.visible = true
	_close_options_button.grab_focus()


func _on_practice_mode_pressed() -> void:
	_change_scene(PRACTICE_MODE_SCENE_PATH, "practice mode")


func _on_close_options_pressed() -> void:
	_options_popup.visible = false
	_options_button.grab_focus()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _change_scene(scene_path: String, scene_label: String) -> void:
	var result: Error = get_tree().change_scene_to_file(scene_path)
	if result != OK:
		push_warning("MainMenu: Failed to open %s scene." % scene_label)
