extends Node

# AudioSetup - Sets up Resonate sound and music banks
# This script configures the audio system with sound effects and music tracks

func _ready():
	# Wait for Resonate managers to be ready
	await get_tree().process_frame
	
	# Setup sound effects
	_setup_sound_effects()
	
	# Setup background music
	_setup_background_music()
	
	print("Audio setup complete")

func _setup_sound_effects():
	"""Configure sound effects for the game"""
	var sound_bank = $SoundBank
	
	# Tank engine sound (looping)
	var engine_sound = preload("res://addons/resonate/sound_manager/sound_event_resource.gd").new()
	engine_sound.label = "tank_engine"
	# Add actual audio file when available
	# engine_sound.add_stream(preload("res://audio/sounds/tank_engine.wav"))
	sound_bank.add_sound_event(engine_sound)
	
	# Tank movement sound
	var movement_sound = preload("res://addons/resonate/sound_manager/sound_event_resource.gd").new()
	movement_sound.label = "tank_movement"
	# movement_sound.add_stream(preload("res://audio/sounds/tank_movement.wav"))
	sound_bank.add_sound_event(movement_sound)
	
	# Cannon fire sound
	var cannon_sound = preload("res://addons/resonate/sound_manager/sound_event_resource.gd").new()
	cannon_sound.label = "cannon_fire"
	# cannon_sound.add_stream(preload("res://audio/sounds/cannon_fire.wav"))
	sound_bank.add_sound_event(cannon_sound)
	
	# Projectile impact sound
	var impact_sound = preload("res://addons/resonate/sound_manager/sound_event_resource.gd").new()
	impact_sound.label = "projectile_impact"
	# impact_sound.add_stream(preload("res://audio/sounds/projectile_impact.wav"))
	sound_bank.add_sound_event(impact_sound)
	
	# UI click sound
	var ui_click = preload("res://addons/resonate/sound_manager/sound_event_resource.gd").new()
	ui_click.label = "ui_click"
	# ui_click.add_stream(preload("res://audio/sounds/ui_click.wav"))
	sound_bank.add_sound_event(ui_click)
	
	# UI hover sound
	var ui_hover = preload("res://addons/resonate/sound_manager/sound_event_resource.gd").new()
	ui_hover.label = "ui_hover"
	# ui_hover.add_stream(preload("res://audio/sounds/ui_hover.wav"))
	sound_bank.add_sound_event(ui_hover)

func _setup_background_music():
	"""Configure background music tracks"""
	var music_bank = $MusicBank
	
	# Main theme
	var main_theme = preload("res://addons/resonate/music_manager/music_track_resource.gd").new()
	main_theme.label = "main_theme"
	# main_theme.add_stem(preload("res://audio/music/main_theme.ogg"))
	music_bank.add_music_track(main_theme)
	
	# Combat theme
	var combat_theme = preload("res://addons/resonate/music_manager/music_track_resource.gd").new()
	combat_theme.label = "combat_theme"
	# combat_theme.add_stem(preload("res://audio/music/combat_theme.ogg"))
	music_bank.add_music_track(combat_theme)
	
	# Ambient theme
	var ambient_theme = preload("res://addons/resonate/music_manager/music_track_resource.gd").new()
	ambient_theme.label = "ambient_theme"
	# ambient_theme.add_stem(preload("res://audio/music/ambient_theme.ogg"))
	music_bank.add_music_track(ambient_theme)

