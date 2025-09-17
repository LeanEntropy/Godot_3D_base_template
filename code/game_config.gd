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

# Shooting
var shooting_enabled
var crosshair_enabled
var projectile_mass
var flying_speed
var fire_rate

# Tank advanced parameters
var turret_rotation_speed
var turret_acceleration_time
var turret_deceleration_time
var cannon_rotation_speed
var cannon_acceleration_time
var cannon_deceleration_time
var max_elevation
var max_depression
var recoil_time
var return_time
var recoil_length
var camera_avoid_lag
var camera_avoid_min_dist
var camera_avoid_max_dist
var camera_avoid_move_speed

# Tank physics parameters
var hover_height
var hover_force
var max_vertical_velocity
var min_vertical_velocity

# Audio settings
var master_volume
var sfx_volume
var music_volume
var audio_enabled

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

	# Shooting
	shooting_enabled = config.get_value("shooting", "shooting_enabled", true)
	crosshair_enabled = config.get_value("shooting", "crosshair_enabled", true)
	projectile_mass = config.get_value("shooting", "projectile_mass", 0.1)
	flying_speed = config.get_value("shooting", "flying_speed", 20.0)
	fire_rate = config.get_value("shooting", "fire_rate", 0.5)
	
	# Tank advanced parameters
	turret_rotation_speed = config.get_value("tank", "turret_rotation_speed", 15.0)
	turret_acceleration_time = config.get_value("tank", "turret_acceleration_time", 0.2)
	turret_deceleration_time = config.get_value("tank", "turret_deceleration_time", 0.2)
	cannon_rotation_speed = config.get_value("tank", "cannon_rotation_speed", 10.0)
	cannon_acceleration_time = config.get_value("tank", "cannon_acceleration_time", 0.2)
	cannon_deceleration_time = config.get_value("tank", "cannon_deceleration_time", 0.2)
	max_elevation = config.get_value("tank", "max_elevation", 15.0)
	max_depression = config.get_value("tank", "max_depression", 10.0)
	recoil_time = config.get_value("tank", "recoil_time", 0.2)
	return_time = config.get_value("tank", "return_time", 1.0)
	recoil_length = config.get_value("tank", "recoil_length", 0.3)
	camera_avoid_lag = config.get_value("tank", "camera_avoid_lag", 0.1)
	camera_avoid_min_dist = config.get_value("tank", "camera_avoid_min_dist", 1.0)
	camera_avoid_max_dist = config.get_value("tank", "camera_avoid_max_dist", 5.0)
	camera_avoid_move_speed = config.get_value("tank", "camera_avoid_move_speed", 10.0)
	
	# Tank physics parameters
	hover_height = config.get_value("tank", "hover_height", 0.2)
	hover_force = config.get_value("tank", "hover_force", 5.0)
	max_vertical_velocity = config.get_value("tank", "max_vertical_velocity", 10.0)
	min_vertical_velocity = config.get_value("tank", "min_vertical_velocity", -2.0)
	
	# Audio settings
	master_volume = config.get_value("audio", "master_volume", 0.0)
	sfx_volume = config.get_value("audio", "sfx_volume", 0.0)
	music_volume = config.get_value("audio", "music_volume", 0.0)
	audio_enabled = config.get_value("audio", "audio_enabled", true)

	is_loaded = true
	config_loaded.emit()
