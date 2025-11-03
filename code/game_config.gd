extends Node

signal config_loaded
var is_loaded = false

var config = ConfigFile.new()

# Convenience method to get values from config
func get_value(section: String, key: String, default = null):
	return config.get_value(section, key, default)

# Legacy variables for backwards compatibility
# These load from appropriate sections based on current controller mode
var speed: float
var forward_speed: float
var reverse_speed: float
var gravity: float
var lerp_weight: float
var character_speed: float

# Camera
var camera_speed: float
var zoom_speed: float
var min_zoom: float
var max_zoom: float
var default_zoom: float
var mouse_sensitivity: float

# Tank
var hull_turn_speed: float
var turret_turn_speed: float

func _ready():
	var err = config.load("res://game_config.cfg")
	if err != OK:
		Logger.error("Failed to load game_config.cfg")
		return

	# Load common/default values from first_person section as fallback
	# Controllers should load from their own sections directly
	speed = config.get_value("first_person", "movement_speed", 5.0)
	gravity = config.get_value("first_person", "gravity", 9.8)
	mouse_sensitivity = config.get_value("first_person", "mouse_sensitivity", 0.002)
	lerp_weight = 10.0  # Default value, not in config

	# Top-down specific
	camera_speed = config.get_value("top_down", "movement_speed", 10.0)
	zoom_speed = config.get_value("top_down", "zoom_speed", 1.0)
	min_zoom = config.get_value("top_down", "min_zoom", 5.0)
	max_zoom = config.get_value("top_down", "max_zoom", 20.0)
	default_zoom = 15.0  # Default value

	# Free camera
	character_speed = config.get_value("free_camera", "movement_speed", 5.0)

	# Tank specific
	forward_speed = config.get_value("tank", "forward_speed", 5.0)
	reverse_speed = config.get_value("tank", "reverse_speed", 2.0)
	hull_turn_speed = config.get_value("tank", "hull_turn_speed", 2.0)
	turret_turn_speed = config.get_value("tank", "mouse_sensitivity", 0.003)

	# Debug: Print all keys from [weapons] section
	_debug_print_weapons_config()

	is_loaded = true
	config_loaded.emit()

func _debug_print_weapons_config() -> void:
	"""Debug function to print all keys loaded from [weapons] section"""
	Logger.info("=== GameConfig: Debugging config file ===")

	# First, show ALL sections that were loaded (not just hardcoded list)
	var all_sections = config.get_sections()
	Logger.info("GameConfig: ALL sections in config file: " + str(all_sections))

	# Also check specifically for the sections we care about
	Logger.info("GameConfig: Has [scenes] section? " + str(config.has_section("scenes")))
	if config.has_section("scenes"):
		var scenes_keys = config.get_section_keys("scenes")
		Logger.info("GameConfig: Keys in [scenes] section: " + str(scenes_keys))
		for key in scenes_keys:
			var value = config.get_value("scenes", key, "NOT_FOUND")
			Logger.info("GameConfig: [scenes] " + key + " = '" + str(value) + "'")
	Logger.info("GameConfig: Has [scene_manager] section? " + str(config.has_section("scene_manager")))
	Logger.info("GameConfig: Has [title_screen] section? " + str(config.has_section("title_screen")))

	if not config.has_section("weapons"):
		Logger.error("GameConfig: [weapons] section does not exist!")
		Logger.info("=== End config debug ===")
		return

	var keys = config.get_section_keys("weapons")
	Logger.info("GameConfig: Found " + str(keys.size()) + " keys in [weapons] section")

	for key in keys:
		var value = config.get_value("weapons", key, "DEFAULT_NOT_FOUND")
		Logger.info("GameConfig: [weapons] " + key + " = '" + str(value) + "'")

	Logger.info("=== End config debug ===")
