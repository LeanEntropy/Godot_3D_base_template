extends CharacterBody3D

var current_controller

func _ready():
	if GameConfig.is_loaded:
		initialize_controller()
	else:
		GameConfig.config_loaded.connect(initialize_controller)


func initialize_controller():
	# Cleanup previous controller if exists
	if current_controller:
		Logger.info("Cleaning up previous controller")
		if current_controller.has_method("cleanup"):
			current_controller.cleanup()
		current_controller.queue_free()
		current_controller = null
	
	var config = ConfigFile.new()
	config.load("res://game_config.cfg")
	var control_mode = config.get_value("camera", "control_mode", "first_person")
	
	Logger.info("Initializing player controller in mode: '%s'" % control_mode)
	
	match control_mode:
		"first_person":
			current_controller = load("res://code/player_controllers/first_person_controller.gd").new()
		"third_person_follow":
			current_controller = load("res://code/player_controllers/third_person_controller.gd").new()
		"over_the_shoulder":
			current_controller = load("res://code/player_controllers/over_the_shoulder_controller.gd").new()
		"top_down":
			current_controller = load("res://code/player_controllers/top_down_controller.gd").new()
		"isometric":
			current_controller = load("res://code/player_controllers/isometric_controller.gd").new()
		"free_camera":
			current_controller = load("res://code/player_controllers/free_camera_controller.gd").new()
		"tank":
			current_controller = load("res://code/player_controllers/tank_controller.gd").new()
		_:
			Logger.warning("Invalid control mode '%s' set in game_config.cfg. Defaulting to first_person." % control_mode)
			current_controller = load("res://code/player_controllers/first_person_controller.gd").new()
	
	if current_controller:
		add_child(current_controller)
		current_controller.initialize(self)


func _unhandled_input(event):
	if get_tree().paused:
		return
	if current_controller:
		# Logger.start_performance_check("unhandled_input")
		current_controller.handle_input(event)
		# Logger.end_performance_check("unhandled_input")

func _physics_process(delta):
	if get_tree().paused:
		return
	if current_controller:
		# Logger.start_performance_check("physics_process")
		current_controller.handle_physics(delta)
		# Logger.end_performance_check("physics_process")
