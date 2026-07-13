extends Control

## Launch router. First-run (no saved mic calibration) -> Microphone Calibration.
## Subsequent launches (calibration present) -> Profile Selection.
## Minimal scene; defers routing to LocalDataManager via call_deferred to ensure
## autoloads have completed their _ready() wiring before we query them.

const LOCAL_DATA_MANAGER_PATH: String = "/root/LocalDataManager"
const MICROPHONE_CALIBRATION_SCENE_PATH: String = "res://src/gd/scenes/audio/MicrophoneCalibrationScene.tscn"
const PROFILE_SELECT_SCENE_PATH: String = "res://src/gd/scenes/menu/ProfileSelectScene.tscn"

var _local_data_manager: Node
var _routed: bool = false


func _ready() -> void:
	call_deferred("_route")


func _route() -> void:
	if _routed:
		return
	_routed = true

	_local_data_manager = get_node_or_null(LOCAL_DATA_MANAGER_PATH)
	if _local_data_manager == null or not _local_data_manager.has_method("has_audio_calibration"):
		push_warning("BootScene: LocalDataManager missing; defaulting to profile selection.")
		_change_scene(PROFILE_SELECT_SCENE_PATH, "profile selection")
		return

	if bool(_local_data_manager.call("has_audio_calibration")):
		_change_scene(PROFILE_SELECT_SCENE_PATH, "profile selection")
	else:
		_change_scene(MICROPHONE_CALIBRATION_SCENE_PATH, "microphone calibration")


func _change_scene(scene_path: String, scene_label: String) -> void:
	var result: Error = get_tree().change_scene_to_file(scene_path)
	if result != OK:
		push_warning("BootScene: Failed to open %s scene." % scene_label)
