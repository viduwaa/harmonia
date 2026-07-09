extends CharacterBody2D

class_name Player

# --- Movement Properties ---
@export_group("Movement")
@export var speed: float = 220.0
@export var acceleration: float = 1200.0
@export var friction: float = 1200.0

# --- Camera Properties ---
@export_group("Camera Settings")
## Enable auto-setup of a Camera2D child if none exists.
@export var auto_create_camera: bool = true
@export var camera_zoom: Vector2 = Vector2(1.5, 1.5)
@export var camera_position_smoothing_enabled: bool = true
@export var camera_position_smoothing_speed: float = 5.0

const ANIMATION_IDLE: StringName = &"idle"
const ANIMATION_STATE_IDLE: String = "idle"
const ANIMATION_STATE_WALK: String = "walk"

# --- Node References ---
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var _camera: Camera2D

# Track last movement direction for directional walk animations (default to down).
var _last_direction: String = "down"
var _current_animation: StringName = &""


func _ready() -> void:
	_setup_camera()
	_update_animation(ANIMATION_STATE_IDLE)


func _physics_process(delta: float) -> void:
	# Prefer the project's movement actions, then allow Godot's built-in UI actions as fallback.
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector == Vector2.ZERO:
		input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if input_vector.length_squared() > 0.0:
		input_vector = input_vector.normalized()
		# Accelerate towards max speed in target direction
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
		_determine_direction(input_vector)
		_update_animation(ANIMATION_STATE_WALK)
	else:
		# Decelerate to stop
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		_update_animation(ANIMATION_STATE_IDLE)

	move_and_slide()


## Configures the Camera2D settings. Creates a new Camera2D if requested and not found.
func _setup_camera() -> void:
	# Check if a Camera2D child already exists
	for child in get_children():
		if child is Camera2D:
			_camera = child as Camera2D
			break

	# Create a Camera2D if none exists and auto-creation is enabled
	if _camera == null and auto_create_camera:
		_camera = Camera2D.new()
		add_child(_camera)
		_camera.name = "PlayerCamera"

	# Apply configuration to the camera
	if _camera != null:
		_camera.zoom = camera_zoom
		_camera.position_smoothing_enabled = camera_position_smoothing_enabled
		_camera.position_smoothing_speed = camera_position_smoothing_speed


## Determines string suffix based on movement direction vector.
func _determine_direction(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		if direction.x > 0:
			_last_direction = "right"
		else:
			_last_direction = "left"
	else:
		if direction.y > 0:
			_last_direction = "down"
		else:
			_last_direction = "up"


## Updates the AnimatedSprite2D animation state.
func _update_animation(state: String) -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return

	var animation_name: StringName = _resolve_animation_name(state)
	if animation_name == &"":
		return
	if animation_name == _current_animation and _animated_sprite.is_playing():
		return

	_current_animation = animation_name
	_animated_sprite.play(animation_name)


## Resolves the requested animation against the SpriteFrames resource.
func _resolve_animation_name(state: String) -> StringName:
	var directional_animation: StringName = StringName("%s_%s" % [state, _last_direction])
	if _animated_sprite.sprite_frames.has_animation(directional_animation):
		return directional_animation

	if state == ANIMATION_STATE_IDLE and _animated_sprite.sprite_frames.has_animation(ANIMATION_IDLE):
		return ANIMATION_IDLE

	push_warning("Player: Animation not found for state '%s' direction '%s'." % [state, _last_direction])
	return &""
