extends Node

signal config_loaded
var is_loaded = false

var config = ConfigFile.new()

# General
var speed
var forward_speed
var reverse_speed
var gravity
var lerp_weight
var character_speed

# Camera
var camera_speed
var zoom_speed
var min_zoom
var max_zoom
var default_zoom
var default_fov
var mouse_sensitivity

# Tank
var hull_turn_speed
var turret_turn_speed

func _ready():
	config.load("res://game_config.cfg")

	# General
	speed = config.get_value("physics", "speed", 5.0)
	forward_speed = config.get_value("physics", "forward_speed", 5.0)
	reverse_speed = config.get_value("physics", "reverse_speed", 2.0)
	gravity = config.get_value("physics", "gravity", 9.8)
	lerp_weight = config.get_value("physics", "lerp_weight", 10.0)
	character_speed = config.get_value("physics", "character_speed", 5.0)

	# Camera
	camera_speed = config.get_value("physics", "camera_speed", 10.0)
	zoom_speed = config.get_value("physics", "zoom_speed", 1.0)
	min_zoom = config.get_value("physics", "min_zoom", 5.0)
	max_zoom = config.get_value("physics", "max_zoom", 20.0)
	default_zoom = config.get_value("physics", "default_zoom", 15.0)
	default_fov = config.get_value("physics", "default_fov", 60.0)
	mouse_sensitivity = config.get_value("physics", "mouse_sensitivity", 0.002)

	# Tank
	hull_turn_speed = config.get_value("physics", "hull_turn_speed", 2.0)
	turret_turn_speed = config.get_value("physics", "turret_turn_speed", 0.003)

	is_loaded = true
	config_loaded.emit()
