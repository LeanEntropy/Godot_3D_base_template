extends Control
class_name TitleScreen

## Standalone title screen scene with PLAY button
## Supports transparent, image, or solid color backgrounds
## Controlled via [title_screen] section in game_config.cfg
## Uses SceneManager to transition to main game

@onready var background_image: TextureRect = $BackgroundImage
@onready var background_color: ColorRect = $BackgroundColor
@onready var play_button: Button = $MainContainer/ButtonContainer/PlayButton
@onready var title_image: TextureRect = $MainContainer/TitleContainer/GameTitle

func _ready() -> void:
	# Ensure mouse is visible for clicking button
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Connect button signal
	play_button.pressed.connect(_on_play_pressed)

	# Apply config settings
	_apply_background()
	_apply_button_colors()

	# Check if title image exists
	_check_title_image()

	Logger.info("TitleScreen initialized - standalone scene ready")

func _apply_background() -> void:
	"""Apply background based on config: transparent, image, or solid color"""
	var have_background: bool = GameConfig.get_value("title_screen", "have_background", true)

	if not have_background:
		# Transparent background - show game scene through title screen
		background_image.visible = false
		background_color.visible = false
		Logger.info("Title screen: Transparent background")
	else:
		# Check for background image first
		var bg_image_path: String = GameConfig.get_value("title_screen", "background_image", "")

		if bg_image_path != "" and ResourceLoader.exists(bg_image_path):
			# Use background image
			var texture = load(bg_image_path)
			if texture:
				background_image.texture = texture
				background_image.visible = true
				background_color.visible = false
				Logger.info("Title screen: Using background image: " + bg_image_path)
			else:
				# Failed to load image, fall back to color
				_use_background_color()
		else:
			# Use solid color background
			_use_background_color()

func _use_background_color() -> void:
	"""Apply solid color background with configurable opacity"""
	var bg_color_hex: String = GameConfig.get_value("title_screen", "background_color", "1A1A2E")
	var bg_opacity: float = GameConfig.get_value("title_screen", "background_color_opacity", 1.0)

	# Parse color from hex and apply opacity
	var color = Color.from_string(bg_color_hex, Color(0.1, 0.1, 0.18))
	color.a = clamp(bg_opacity, 0.0, 1.0)  # Clamp opacity between 0.0 and 1.0

	background_color.color = color
	background_color.visible = true
	background_image.visible = false
	Logger.info("Title screen: Using solid color background: " + bg_color_hex + " with opacity: " + str(bg_opacity))

func _apply_button_colors() -> void:
	"""Apply config-driven button styling with rounded corners"""
	# Get colors from config
	var button_color_hex: String = GameConfig.get_value("title_screen", "button_color", "16213E")
	var button_hover_hex: String = GameConfig.get_value("title_screen", "button_hover_color", "0F3460")
	var button_text_hex: String = GameConfig.get_value("title_screen", "button_text_color", "FFFFFF")

	# Create StyleBox for normal state
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color.from_string(button_color_hex, Color(0.09, 0.13, 0.24))
	normal_style.corner_radius_top_left = 10
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_left = 10
	normal_style.corner_radius_bottom_right = 10
	normal_style.border_width_left = 3
	normal_style.border_width_top = 3
	normal_style.border_width_right = 3
	normal_style.border_width_bottom = 3
	normal_style.border_color = Color.from_string(button_text_hex, Color.WHITE)

	# Create StyleBox for hover state
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color.from_string(button_hover_hex, Color(0.06, 0.2, 0.38))
	hover_style.corner_radius_top_left = 10
	hover_style.corner_radius_top_right = 10
	hover_style.corner_radius_bottom_left = 10
	hover_style.corner_radius_bottom_right = 10
	hover_style.border_width_left = 3
	hover_style.border_width_top = 3
	hover_style.border_width_right = 3
	hover_style.border_width_bottom = 3
	hover_style.border_color = Color.from_string(button_text_hex, Color.WHITE)

	# Create StyleBox for pressed state
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color.from_string(button_hover_hex, Color(0.06, 0.2, 0.38)).darkened(0.2)
	pressed_style.corner_radius_top_left = 10
	pressed_style.corner_radius_top_right = 10
	pressed_style.corner_radius_bottom_left = 10
	pressed_style.corner_radius_bottom_right = 10
	pressed_style.border_width_left = 3
	pressed_style.border_width_top = 3
	pressed_style.border_width_right = 3
	pressed_style.border_width_bottom = 3
	pressed_style.border_color = Color.from_string(button_text_hex, Color.WHITE)

	# Apply styles to button
	play_button.add_theme_stylebox_override("normal", normal_style)
	play_button.add_theme_stylebox_override("hover", hover_style)
	play_button.add_theme_stylebox_override("pressed", pressed_style)
	play_button.add_theme_color_override("font_color", Color.from_string(button_text_hex, Color.WHITE))

	Logger.info("Title screen: Button colors applied from config")

func _check_title_image() -> void:
	"""Load title image or show fallback text if missing"""
	var image_path = "res://assets/UI/GameTitle.png"

	if ResourceLoader.exists(image_path):
		var texture = load(image_path)
		if texture:
			title_image.texture = texture
			Logger.info("Title image loaded: " + image_path)
		else:
			_show_fallback_title()
	else:
		_show_fallback_title()

func _show_fallback_title() -> void:
	"""Display fallback text when GameTitle.png is missing"""
	Logger.warning("GameTitle.png not found, using text fallback")
	title_image.visible = false

	# Create a Label as fallback
	var title_label = Label.new()
	title_label.text = "GAME TEMPLATE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color.WHITE)

	# Add shadow effect
	title_label.add_theme_constant_override("shadow_offset_x", 4)
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))

	var title_container = $MainContainer/TitleContainer
	title_container.add_child(title_label)

func _on_play_pressed() -> void:
	"""Handle PLAY button click - transition to main game via SceneManager"""
	Logger.info("PLAY button pressed - transitioning to main game")
	SceneManager.change_scene("main_game")
