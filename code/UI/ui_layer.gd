extends CanvasLayer

@onready var pause_label = $CenterContainer/PauseLabel
@onready var pause_button = $MarginContainer/PauseButton
@onready var start_game_container = $StartGameContainer
@onready var start_game_button = $StartGameContainer/StartGameButton

var pause_key_primary
var pause_key_secondary
var game_started = false

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	pause_label.hide()
	
	# Pause the game immediately on load and show start button
	get_tree().paused = true
	start_game_container.show()
	start_game_button.show()
	game_started = false

	var config = ConfigFile.new()
	config.load("res://game_config.cfg")

	# Load control settings
	var primary_key_str = config.get_value("controls", "pause_key_primary", "P")
	var secondary_key_str = config.get_value("controls", "pause_key_secondary", "")
	pause_key_primary = OS.find_keycode_from_string(primary_key_str)
	if secondary_key_str != "":
		pause_key_secondary = OS.find_keycode_from_string(secondary_key_str)

	# Set mouse mode to visible for the start button
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event):
	if event is InputEventKey and event.is_pressed():
		if event.keycode == pause_key_primary or (pause_key_secondary and event.keycode == pause_key_secondary):
			toggle_pause()

func toggle_pause():
	# Only allow pause toggle if game has started
	if not game_started:
		return
		
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		pause_label.show()
		pause_button.text = "Resume"
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		pause_label.hide()
		pause_button.text = "Pause"
		var config = ConfigFile.new()
		config.load("res://game_config.cfg")
		var control_mode = config.get_value("camera", "control_mode", "first_person")
		if not control_mode in ["isometric", "free_camera"]:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_PauseButton_pressed():
	toggle_pause()

func _on_StartGameButton_pressed():
	# Hide the start game button and container
	start_game_container.hide()
	start_game_button.hide()
	
	# Unpause the game
	get_tree().paused = false
	game_started = true
	
	# Set appropriate mouse mode based on camera control mode
	var config = ConfigFile.new()
	config.load("res://game_config.cfg")
	var control_mode = config.get_value("camera", "control_mode", "first_person")
	if control_mode in ["isometric", "free_camera"]:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
