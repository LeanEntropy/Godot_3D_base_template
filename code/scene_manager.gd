# code/scene_manager.gd
extends Node
## Simple scene manager with fade transitions and optional loading bar
## Uses config-driven scene paths from [scenes] section in game_config.cfg

signal scene_changing(from_scene: String, to_scene: String)
signal scene_changed(scene_name: String)

var current_scene_path: String = ""
var _is_transitioning: bool = false

# UI elements (created internally)
var _fade_overlay: ColorRect = null
var _loading_bar: ProgressBar = null
var _loading_container: CenterContainer = null

# Config values
var _fade_duration: float = 0.5
var _show_loading_bar: bool = true
var _show_loading_bar_on_title_screen: bool = false
var _loading_bar_color: Color = Color.hex(0x4A90E2FF)
var _loading_bar_width: int = 400
var _loading_bar_height: int = 20

func _ready() -> void:
	# Wait for GameConfig to load
	if not GameConfig.is_loaded:
		await GameConfig.config_loaded

	# Load config values
	_load_config()

	# Create UI elements
	_create_fade_overlay()
	_create_loading_bar()

	# Store initial scene path
	var root = get_tree().root
	var current_scene = root.get_child(root.get_child_count() - 1)
	current_scene_path = current_scene.scene_file_path

	Logger.info("SceneManager initialized. Current scene: " + current_scene_path)

func _load_config() -> void:
	"""Load configuration from game_config.cfg"""
	_fade_duration = GameConfig.get_value("scene_manager", "fade_duration", 0.5)
	_show_loading_bar = GameConfig.get_value("scene_manager", "show_loading_bar", true)
	_show_loading_bar_on_title_screen = GameConfig.get_value("scene_manager", "show_loading_bar_on_title_screen", false)

	var color_hex = GameConfig.get_value("scene_manager", "loading_bar_color", "4A90E2")
	_loading_bar_color = Color("#" + color_hex)

	_loading_bar_width = GameConfig.get_value("scene_manager", "loading_bar_width", 400)
	_loading_bar_height = GameConfig.get_value("scene_manager", "loading_bar_height", 20)

func _create_fade_overlay() -> void:
	"""Create a full-screen black overlay for fade transitions"""
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color.BLACK
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.z_index = 1000  # Always on top
	_fade_overlay.modulate.a = 0.0  # Start transparent
	add_child(_fade_overlay)

func _create_loading_bar() -> void:
	"""Create loading bar UI (centered on screen)"""
	# Container for centering
	_loading_container = CenterContainer.new()
	_loading_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_container.z_index = 1001  # Above fade overlay
	_loading_container.visible = false
	add_child(_loading_container)

	# Progress bar
	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(_loading_bar_width, _loading_bar_height)
	_loading_bar.max_value = 100
	_loading_bar.value = 0
	_loading_bar.show_percentage = false
	_loading_container.add_child(_loading_bar)

	# Style the progress bar
	_style_loading_bar()

func _style_loading_bar() -> void:
	"""Apply custom styling to the loading bar"""
	# Create StyleBoxFlat for background
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4

	# Create StyleBoxFlat for fill (progress)
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = _loading_bar_color
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3

	_loading_bar.add_theme_stylebox_override("background", bg_style)
	_loading_bar.add_theme_stylebox_override("fill", fill_style)

# === Public API ===

func change_scene(scene_key: String) -> void:
	"""Change to a new scene with fade transition"""
	if _is_transitioning:
		Logger.warning("SceneManager: Already transitioning, ignoring request")
		return

	var scene_path = get_scene_path(scene_key)
	if scene_path.is_empty():
		Logger.error("SceneManager: Scene key '" + scene_key + "' not found in config")
		return

	_is_transitioning = true
	Logger.start_performance_check("scene_change")
	Logger.info("SceneManager: Changing scene to '" + scene_key + "' (" + scene_path + ")")

	# Emit signal with old and new scene info
	var old_scene_name = current_scene_path.get_file().get_basename()
	scene_changing.emit(old_scene_name, scene_key)

	# Check if we should show loading bar on title screen (no fade)
	var is_from_title_screen = (old_scene_name == "title_screen")
	var skip_fade = _show_loading_bar_on_title_screen and is_from_title_screen

	# Fade out (unless showing loading bar on title screen)
	var tween: Tween
	if not skip_fade:
		tween = create_tween()
		tween.tween_property(_fade_overlay, "modulate:a", 1.0, _fade_duration)
		await tween.finished

	# Show and animate loading bar
	if _show_loading_bar:
		_loading_container.visible = true
		_loading_bar.value = 0

		# Animate to 70% before scene change
		tween = create_tween()
		tween.tween_property(_loading_bar, "value", 70.0, _fade_duration * 0.7)
		await tween.finished

	# Change scene
	_change_scene_internal(scene_path)

	# Wait one frame for new scene to be added
	await get_tree().process_frame

	# Complete loading bar animation
	if _show_loading_bar:
		tween = create_tween()
		tween.tween_property(_loading_bar, "value", 100.0, _fade_duration * 0.3)
		await tween.finished

	# Hide loading bar
	if _show_loading_bar:
		_loading_container.visible = false

	# Fade in
	tween = create_tween()
	tween.tween_property(_fade_overlay, "modulate:a", 0.0, _fade_duration)
	await tween.finished

	_is_transitioning = false
	scene_changed.emit(scene_key)

	Logger.end_performance_check("scene_change")
	Logger.info("SceneManager: Scene change complete")

func change_scene_instant(scene_key: String) -> void:
	"""Change to a new scene immediately without transition"""
	if _is_transitioning:
		Logger.warning("SceneManager: Already transitioning, ignoring request")
		return

	var scene_path = get_scene_path(scene_key)
	if scene_path.is_empty():
		Logger.error("SceneManager: Scene key '" + scene_key + "' not found in config")
		return

	Logger.info("SceneManager: Instant scene change to '" + scene_key + "' (" + scene_path + ")")

	var old_scene_name = current_scene_path.get_file().get_basename()
	scene_changing.emit(old_scene_name, scene_key)

	_change_scene_internal(scene_path)

	scene_changed.emit(scene_key)

func reload_current_scene() -> void:
	"""Reload the current scene with fade transition"""
	if current_scene_path.is_empty():
		Logger.error("SceneManager: No current scene to reload")
		return

	_is_transitioning = true
	Logger.info("SceneManager: Reloading current scene")

	var scene_name = current_scene_path.get_file().get_basename()
	scene_changing.emit(scene_name, scene_name)

	# Fade out
	var tween = create_tween()
	tween.tween_property(_fade_overlay, "modulate:a", 1.0, _fade_duration)
	await tween.finished

	# Show and animate loading bar
	if _show_loading_bar:
		_loading_container.visible = true
		_loading_bar.value = 0

		tween = create_tween()
		tween.tween_property(_loading_bar, "value", 70.0, _fade_duration * 0.7)
		await tween.finished

	# Reload
	_change_scene_internal(current_scene_path)

	# Wait one frame
	await get_tree().process_frame

	# Complete loading bar
	if _show_loading_bar:
		tween = create_tween()
		tween.tween_property(_loading_bar, "value", 100.0, _fade_duration * 0.3)
		await tween.finished
		_loading_container.visible = false

	# Fade in
	tween = create_tween()
	tween.tween_property(_fade_overlay, "modulate:a", 0.0, _fade_duration)
	await tween.finished

	_is_transitioning = false
	scene_changed.emit(scene_name)

func get_scene_path(scene_key: String) -> String:
	"""Get scene file path from config [scenes] section"""
	var path = GameConfig.get_value("scenes", scene_key, "")

	Logger.info("SceneManager.get_scene_path: section='scenes', key='" + scene_key + "', returned value='" + str(path) + "'")

	if path.is_empty():
		return ""

	# Validate path exists
	if not ResourceLoader.exists(path):
		Logger.error("SceneManager: Scene file does not exist: " + path)
		return ""

	return path

func is_transitioning() -> bool:
	"""Check if a scene transition is currently in progress"""
	return _is_transitioning

# === Private Methods ===

func _change_scene_internal(scene_path: String) -> void:
	"""Internal method to perform the actual scene change"""
	var err = get_tree().change_scene_to_file(scene_path)

	if err != OK:
		Logger.error("SceneManager: Failed to change scene: " + scene_path)
		_is_transitioning = false
		return

	current_scene_path = scene_path
