extends Node
class_name ShootingComponent

## Modular shooting system that works with any controller
## Requires WeaponComponent to be present on Player node

# Preload the WeaponComponent
const WeaponComponent = preload("res://code/components/weapon_component.gd")

signal shot_fired
signal ammo_changed(current: int, max: int)
signal reload_started
signal reload_finished

# Config values - loaded from [shooting] section
var fire_rate: float = 0.15
var projectile_speed: float = 50.0
var projectile_gravity_scale: float = 0.15

# Ammo system
var max_ammo: int = -1  # -1 for unlimited
var ammo_per_clip: int = 30
var current_ammo: int = 30
var reload_time: float = 2.0
var show_ammo_ui: bool = false

# Internal state
var _can_shoot: bool = true
var _is_reloading: bool = false
var _player: CharacterBody3D
var _weapon_component: WeaponComponent
var _controller_mode: String = ""
var _projectile_scene: PackedScene

func _ready() -> void:
	# Find player node (parent)
	_player = get_parent() as CharacterBody3D
	if not _player:
		Logger.error("ShootingComponent: Parent must be CharacterBody3D (Player)")
		queue_free()
		return

	# Load projectile scene
	_projectile_scene = load("res://assets/tank_projectile.tscn")
	if not _projectile_scene:
		Logger.error("ShootingComponent: Could not load tank_projectile.tscn")
		queue_free()
		return

	# Wait for WeaponComponent to be ready
	await get_tree().process_frame

	# Find WeaponComponent
	_weapon_component = _player.get_node_or_null("WeaponComponent") as WeaponComponent
	if not _weapon_component:
		Logger.error("ShootingComponent: WeaponComponent not found on Player. Add WeaponComponent to use shooting.")
		queue_free()
		return

	# Wait for weapon to be ready
	if not _weapon_component.has_weapon():
		await _weapon_component.weapon_ready

	# Load configuration
	_detect_controller_mode()
	_load_config()

	# Initialize ammo
	if max_ammo > 0:
		current_ammo = ammo_per_clip
		ammo_changed.emit(current_ammo, ammo_per_clip)

	Logger.info("ShootingComponent initialized for mode: " + _controller_mode)

func _detect_controller_mode() -> void:
	"""Detect which controller is currently active"""
	_controller_mode = GameConfig.get_value("global", "controller_mode", "first_person")

func _load_config() -> void:
	"""Load shooting parameters from config"""
	# Determine fire rate based on mode
	if _controller_mode == "tank":
		fire_rate = GameConfig.get_value("shooting", "fire_rate_tank", 0.5)
		projectile_speed = GameConfig.get_value("shooting", "projectile_speed_tank", 40.0)
	else:
		fire_rate = GameConfig.get_value("shooting", "fire_rate_fps", 0.15)
		projectile_speed = GameConfig.get_value("shooting", "projectile_speed_fps", 50.0)

	projectile_gravity_scale = GameConfig.get_value("shooting", "projectile_gravity_scale", 0.15)

	max_ammo = GameConfig.get_value("shooting", "max_ammo", -1)
	ammo_per_clip = GameConfig.get_value("shooting", "ammo_per_clip", 30)
	reload_time = GameConfig.get_value("shooting", "reload_time", 2.0)
	show_ammo_ui = GameConfig.get_value("shooting", "show_ammo_ui", false)

func _unhandled_input(event: InputEvent) -> void:
	"""Handle shooting input"""
	# ShootingComponent now handles ALL modes including tank and free_camera

	# Isometric mode uses RIGHT click for shooting (left click is for movement)
	if _controller_mode == "isometric":
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _can_shoot and not _is_reloading:
				if _check_ammo():
					_shoot()
		return  # Don't process shoot action in isometric mode

	# Top_down and free_camera use LEFT click for shooting
	if _controller_mode in ["top_down", "free_camera"]:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _can_shoot and not _is_reloading:
				if _check_ammo():
					_shoot()
		return  # Don't process shoot action in these modes

	# All other modes use shoot action (usually left click or specific key)
	if event.is_action_pressed("shoot") and _can_shoot and not _is_reloading:
		if _check_ammo():
			_shoot()

func _check_ammo() -> bool:
	"""Check if we have ammo to shoot"""
	if max_ammo == -1:
		return true  # Unlimited ammo

	if current_ammo > 0:
		return true

	# Out of ammo, try to reload
	if not _is_reloading:
		_start_reload()

	return false

func _shoot() -> void:
	"""Fire a projectile using WeaponComponent for positioning and direction"""
	if not _projectile_scene or not _weapon_component:
		return

	# Get muzzle position and fire direction from WeaponComponent
	var muzzle_pos = _weapon_component.get_muzzle_position()
	var fire_direction = _weapon_component.get_fire_direction()

	# Spawn projectile at muzzle position
	var projectile = _projectile_scene.instantiate() as RigidBody3D
	get_tree().root.add_child(projectile)
	projectile.global_position = muzzle_pos

	# Launch projectile with gravity for arc trajectory
	if projectile.has_method("launch"):
		projectile.launch(fire_direction, projectile_speed, projectile_gravity_scale)
	else:
		# Fallback: direct velocity set
		projectile.linear_velocity = fire_direction * projectile_speed
		projectile.gravity_scale = projectile_gravity_scale

	# Update ammo
	if max_ammo > 0:
		current_ammo -= 1
		ammo_changed.emit(current_ammo, ammo_per_clip)

	# Emit signal
	shot_fired.emit()

	# Start cooldown
	_start_cooldown()

	Logger.info("Shot fired from mode: " + _controller_mode + " at position: " + str(muzzle_pos))

func _start_cooldown() -> void:
	"""Start fire rate cooldown"""
	_can_shoot = false
	await get_tree().create_timer(fire_rate).timeout
	_can_shoot = true

func _start_reload() -> void:
	"""Start reloading"""
	if _is_reloading or max_ammo == -1:
		return

	_is_reloading = true
	reload_started.emit()
	Logger.info("Reloading...")

	await get_tree().create_timer(reload_time).timeout

	current_ammo = ammo_per_clip
	_is_reloading = false
	reload_finished.emit()
	ammo_changed.emit(current_ammo, ammo_per_clip)
	Logger.info("Reload complete")

func reload() -> void:
	"""Public method to trigger reload manually"""
	if not _is_reloading and current_ammo < ammo_per_clip:
		_start_reload()
