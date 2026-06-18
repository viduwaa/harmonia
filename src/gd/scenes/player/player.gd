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

# --- Node References ---
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var _camera: Camera2D

# Track last movement direction for idle animations (default to down)
var _last_direction: String = "down"


func _ready() -> void:
	_setup_camera()
	_update_animation("idle")


func _physics_process(delta: float) -> void:
	# Get input vector using standard UI actions
	var input_vector: Vector2 = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	
	if input_vector.length_squared() > 0.0:
		input_vector = input_vector.normalized()
		# Accelerate towards max speed in target direction
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
		_determine_direction(input_vector)
		_update_animation("walk")
	else:
		# Decelerate to stop
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		_update_animation("idle")

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
	var anim_name: String = "%s_%s" % [state, _last_direction]
	if _animated_sprite != null and _animated_sprite.sprite_frames.has_animation(anim_name):
		_animated_sprite.play(anim_name)
	else:
		push_warning("Player: Animation not found: %s" % anim_name)
