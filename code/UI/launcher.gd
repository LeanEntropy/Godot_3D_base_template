extends Control

## Launcher scene - decides whether to show title screen or start main game
## Controlled by [global] use_title_screen in game_config.cfg

func _ready() -> void:
	# Check if title screen should be shown
	var use_title_screen: bool = GameConfig.get_value("global", "use_title_screen", true)

	if use_title_screen:
		Logger.info("Launcher: Starting with title screen")
		SceneManager.change_scene_instant("title_screen")
	else:
		Logger.info("Launcher: Starting directly to main game")
		SceneManager.change_scene_instant("main_game")
