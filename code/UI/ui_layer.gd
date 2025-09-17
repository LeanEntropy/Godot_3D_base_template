extends CanvasLayer

@onready var pause_label = $CenterContainer/PauseLabel
@onready var pause_button = $MarginContainer/PauseButton
@onready var start_game_container = $StartGameContainer
@onready var start_game_button = $StartGameContainer/StartGameButton
@onready var audio_settings_container = $AudioSettingsContainer
@onready var audio_button = $MarginContainer/AudioButton

# Audio controls
@onready var master_volume_slider = $AudioSettingsContainer/VBoxContainer/MasterVolumeContainer/MasterVolumeSlider
@onready var master_volume_value = $AudioSettingsContainer/VBoxContainer/MasterVolumeContainer/MasterVolumeValue
@onready var sfx_volume_slider = $AudioSettingsContainer/VBoxContainer/SFXVolumeContainer/SFXVolumeSlider
@onready var sfx_volume_value = $AudioSettingsContainer/VBoxContainer/SFXVolumeContainer/SFXVolumeValue
@onready var music_volume_slider = $AudioSettingsContainer/VBoxContainer/MusicVolumeContainer/MusicVolumeSlider
@onready var music_volume_value = $AudioSettingsContainer/VBoxContainer/MusicVolumeContainer/MusicVolumeValue
@onready var music_option_button = $AudioSettingsContainer/VBoxContainer/MusicSelectionContainer/MusicOptionButton

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
	
	# Initialize audio controls
	_initialize_audio_controls()

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

func _initialize_audio_controls():
	"""Initialize audio control UI elements"""
	# Set initial values from config
	if GameConfig.is_loaded:
		master_volume_slider.value = GameConfig.master_volume
		sfx_volume_slider.value = GameConfig.sfx_volume
		music_volume_slider.value = GameConfig.music_volume
		
		_update_volume_labels()
	
	# Populate music selection
	music_option_button.add_item("Main Theme", 0)
	music_option_button.add_item("Combat Theme", 1)
	music_option_button.add_item("Ambient Theme", 2)
	music_option_button.selected = 0

func _update_volume_labels():
	"""Update volume value labels"""
	master_volume_value.text = str(int(master_volume_slider.value)) + " dB"
	sfx_volume_value.text = str(int(sfx_volume_slider.value)) + " dB"
	music_volume_value.text = str(int(music_volume_slider.value)) + " dB"

func _on_AudioButton_pressed():
	"""Toggle audio settings panel"""
	audio_settings_container.visible = not audio_settings_container.visible
	AudioManager.play_sound("ui_click")

func _on_CloseButton_pressed():
	"""Close audio settings panel"""
	audio_settings_container.visible = false
	AudioManager.play_sound("ui_click")

func _on_TestSoundButton_pressed():
	"""Play test sound"""
	AudioManager.play_sound("ui_click")

func _on_MasterVolumeSlider_value_changed(value):
	"""Handle master volume change"""
	AudioManager.set_master_volume(value)
	_update_volume_labels()
	
	# Save to config
	GameConfig.master_volume = value
	_save_audio_config()

func _on_SFXVolumeSlider_value_changed(value):
	"""Handle SFX volume change"""
	AudioManager.set_sfx_volume(value)
	_update_volume_labels()
	
	# Save to config
	GameConfig.sfx_volume = value
	_save_audio_config()

func _on_MusicVolumeSlider_value_changed(value):
	"""Handle music volume change"""
	AudioManager.set_music_volume(value)
	_update_volume_labels()
	
	# Save to config
	GameConfig.music_volume = value
	_save_audio_config()

func _on_MusicOptionButton_item_selected(index):
	"""Handle music track selection"""
	var track_names = ["main_theme", "combat_theme", "ambient_theme"]
	if index < track_names.size():
		AudioManager.crossfade_music(track_names[index], 1.0)
		AudioManager.play_sound("ui_click")

func _save_audio_config():
	"""Save audio settings to config file"""
	var config = ConfigFile.new()
	config.load("res://game_config.cfg")
	
	config.set_value("audio", "master_volume", GameConfig.master_volume)
	config.set_value("audio", "sfx_volume", GameConfig.sfx_volume)
	config.set_value("audio", "music_volume", GameConfig.music_volume)
	
	config.save("res://game_config.cfg")
