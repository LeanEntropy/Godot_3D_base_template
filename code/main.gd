extends Node3D

## Main scene controller
## Handles game initialization and mouse mode setup

@onready var ui_layer: CanvasLayer = $UILayer
@onready var player: CharacterBody3D = $Player

func _ready() -> void:
	# Wait for GameConfig to load
	if not GameConfig.is_loaded:
		await GameConfig.config_loaded

	# Set appropriate mouse mode for current controller
	_set_mouse_mode_for_controller()

	Logger.info("Main game scene ready")

func _set_mouse_mode_for_controller() -> void:
	"""Set correct mouse mode based on active controller"""
	var control_mode = GameConfig.get_value("global", "controller_mode", "first_person")

	# Controllers that need captured mouse (hidden, locked to center)
	var captured_modes = ["first_person", "third_person", "over_the_shoulder", "tank"]

	# Controllers that need visible mouse (free movement)
	var visible_modes = ["isometric", "free_camera", "top_down"]

	if control_mode in captured_modes:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		Logger.info("Mouse mode set to CAPTURED for controller: " + control_mode)
	elif control_mode in visible_modes:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		Logger.info("Mouse mode set to VISIBLE for controller: " + control_mode)
	else:
		# Default to captured for unknown modes
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		Logger.warning("Unknown controller mode: " + control_mode + ", defaulting to CAPTURED")
