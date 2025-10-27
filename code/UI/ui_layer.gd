extends CanvasLayer

@onready var pause_label = $CenterContainer/PauseLabel
@onready var pause_button = $MarginContainer/PauseButton
@onready var crosshair = $Crosshair
@onready var aim_cursor = $AimCursor

var pause_key_primary
var pause_key_secondary

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	pause_label.hide()
	get_tree().paused = false

	var config = ConfigFile.new()
	config.load("res://game_config.cfg")

	# Load control settings
	var primary_key_str = config.get_value("controls", "pause_key_primary", "P")
	var secondary_key_str = config.get_value("controls", "pause_key_secondary", "")
	pause_key_primary = OS.find_keycode_from_string(primary_key_str)
	if secondary_key_str != "":
		pause_key_secondary = OS.find_keycode_from_string(secondary_key_str)

	# Load camera settings for mouse mode
	var control_mode = config.get_value("global", "controller_mode", "first_person")
	if control_mode in ["isometric", "free_camera", "top_down"]:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Update UI visibility based on controller mode
	_update_crosshair_visibility()
	_update_aim_cursor_visibility()

func _unhandled_input(event):
	if event is InputEventKey and event.is_pressed():
		if event.keycode == pause_key_primary or (pause_key_secondary and event.keycode == pause_key_secondary):
			toggle_pause()

func toggle_pause():
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		pause_label.show()
		pause_button.text = "Resume"
		if crosshair:
			crosshair.hide()
		if aim_cursor:
			aim_cursor.hide_cursor()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		pause_label.hide()
		pause_button.text = "Pause"
		_update_crosshair_visibility()
		_update_aim_cursor_visibility()
		var config = ConfigFile.new()
		config.load("res://game_config.cfg")
		var control_mode = config.get_value("global", "controller_mode", "first_person")
		if not control_mode in ["isometric", "free_camera", "top_down"]:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_PauseButton_pressed():
	toggle_pause()

func _update_crosshair_visibility() -> void:
	"""Update crosshair visibility based on controller mode and game config"""
	if not crosshair:
		return

	# Check if crosshair should be shown globally
	var show_crosshair = GameConfig.get_value("ui", "show_crosshair", true)
	if not show_crosshair:
		crosshair.visible = false
		return

	# Get current controller mode
	var mode = GameConfig.get_value("global", "controller_mode", "first_person")

	# Modes that should show crosshair (includes free_camera for aiming)
	var crosshair_modes = ["first_person", "third_person", "over_the_shoulder", "tank", "free_camera"]

	# Show crosshair if in a compatible mode
	crosshair.visible = mode in crosshair_modes

func _update_aim_cursor_visibility() -> void:
	"""Update aim cursor visibility based on controller mode"""
	if not aim_cursor:
		return

	# Get current controller mode
	var mode = GameConfig.get_value("global", "controller_mode", "first_person")

	# Modes that should show aim cursor (top-down and isometric)
	var aim_cursor_modes = ["top_down", "isometric"]

	# Show aim cursor if in a compatible mode
	if mode in aim_cursor_modes:
		aim_cursor.show_cursor()
	else:
		aim_cursor.hide_cursor()
