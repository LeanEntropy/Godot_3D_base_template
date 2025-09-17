extends Node

# AudioManager - Simple wrapper for Resonate audio system
# Provides easy-to-use functions for sound effects and music

signal audio_ready

var is_ready = false

func _ready():
	# Wait for Resonate managers to be ready
	await get_tree().process_frame
	
	# Connect to Resonate managers when they're available
	if SoundManager.has_signal("loaded"):
		SoundManager.loaded.connect(_on_sound_manager_loaded)
	if MusicManager.has_signal("loaded"):
		MusicManager.loaded.connect(_on_music_manager_loaded)
	
	# Set initial volumes from config
	_set_initial_volumes()
	
	# Start background music
	_start_background_music()
	
	is_ready = true
	audio_ready.emit()

func _on_sound_manager_loaded():
	print("SoundManager loaded")

func _on_music_manager_loaded():
	print("MusicManager loaded")

# Sound Effects
func play_sound(sound_name: String, position: Vector3 = Vector3.ZERO, volume_db: float = 0.0):
	"""Play a sound effect by name"""
	if not is_ready:
		print("AudioManager not ready yet")
		return
	
	if SoundManager.has_method("trigger"):
		SoundManager.trigger(sound_name)
	else:
		print("SoundManager not available")

func play_3d_sound(sound_name: String, position: Vector3, volume_db: float = 0.0):
	"""Play a 3D positioned sound effect"""
	if not is_ready:
		print("AudioManager not ready yet")
		return
	
	if SoundManager.has_method("trigger_3d"):
		SoundManager.trigger_3d(sound_name, position)
	else:
		print("SoundManager 3D not available")

# Music
func play_music(track_name: String, fade_in: float = 0.0):
	"""Play background music"""
	if not is_ready:
		print("AudioManager not ready yet")
		return
	
	if MusicManager.has_method("play"):
		MusicManager.play(track_name, fade_in)
	else:
		print("MusicManager not available")

func stop_music(fade_out: float = 0.0):
	"""Stop background music"""
	if not is_ready:
		print("AudioManager not ready yet")
		return
	
	if MusicManager.has_method("stop"):
		MusicManager.stop(fade_out)
	else:
		print("MusicManager not available")

func crossfade_music(track_name: String, fade_time: float = 1.0):
	"""Crossfade to a different music track"""
	if not is_ready:
		print("AudioManager not ready yet")
		return
	
	if MusicManager.has_method("crossfade"):
		MusicManager.crossfade(track_name, fade_time)
	else:
		print("MusicManager not available")

# Volume Controls
func set_master_volume(volume_db: float):
	"""Set master volume"""
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), volume_db)

func set_sfx_volume(volume_db: float):
	"""Set sound effects volume"""
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, volume_db)

func set_music_volume(volume_db: float):
	"""Set music volume"""
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, volume_db)

func _set_initial_volumes():
	"""Set initial volumes from game config"""
	if GameConfig.is_loaded:
		set_master_volume(GameConfig.master_volume)
		set_sfx_volume(GameConfig.sfx_volume)
		set_music_volume(GameConfig.music_volume)

func _start_background_music():
	"""Start playing background music"""
	# Wait a bit for everything to initialize
	await get_tree().create_timer(1.0).timeout
	
	# Play main theme with fade in
	play_music("main_theme", 2.0)
