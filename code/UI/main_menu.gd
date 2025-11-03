# code/UI/main_menu.gd
extends Control
## Main menu scene demonstrating SceneManager transitions

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel

func _ready() -> void:
	# Ensure mouse is visible in menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Connect button signals
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	Logger.info("Main menu ready")

func _on_play_pressed() -> void:
	Logger.info("Play button pressed - transitioning to main game")
	# Use SceneManager to transition to main game with fade + loading bar
	SceneManager.change_scene("main_game")

func _on_quit_pressed() -> void:
	Logger.info("Quit button pressed - exiting game")
	get_tree().quit()
