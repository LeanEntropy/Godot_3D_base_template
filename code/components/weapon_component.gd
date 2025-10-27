extends Node3D
class_name WeaponComponent

## Modular weapon system that manages weapon models and muzzle positions
## Add as child of Player node to enable weapons

# Preload the AimingHelper utility
const AimingHelper = preload("res://code/components/aiming_helper.gd")

signal weapon_ready
signal weapon_changed(weapon_scene_path: String)

# References
var _player: CharacterBody3D
var _camera: Camera3D
var _controller_mode: String = ""

# Weapon model management
var _current_weapon: Node3D = null
var _muzzle_marker: Marker3D = null

# Config values
var _show_weapon: bool = true
var _weapon_model_path: String = ""
var _default_muzzle_offset: Vector3 = Vector3(0, 0, -1.0)

# For top-down/isometric: weapon rotation to face target
var _rotation_speed: float = 10.0
var _last_target_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Find player node (parent)
	_player = get_parent() as CharacterBody3D
	if not _player:
		Logger.error("WeaponComponent: Parent must be CharacterBody3D (Player)")
		queue_free()
		return

	# Wait for scene to be ready
	await get_tree().process_frame

	# Detect controller mode and load weapon
	_detect_controller_mode()
	_load_config()
	_find_camera()
	_load_weapon_model()

	weapon_ready.emit()
	Logger.info("WeaponComponent initialized for mode: " + _controller_mode)

func _detect_controller_mode() -> void:
	"""Detect which controller is currently active"""
	_controller_mode = GameConfig.get_value("global", "controller_mode", "first_person")

func _load_config() -> void:
	"""Load weapon configuration for current mode"""
	Logger.info("WeaponComponent: _load_config() called for mode: " + _controller_mode)

	# Check if weapon should be shown for this mode
	var show_key = "show_weapon_" + _controller_mode
	_show_weapon = GameConfig.get_value("weapons", show_key, true)
	Logger.info("WeaponComponent: Config key '" + show_key + "' = " + str(_show_weapon))

	# Get weapon model path for this mode
	var model_key = "weapon_model_" + _controller_mode
	_weapon_model_path = GameConfig.get_value("weapons", model_key, "")
	Logger.info("WeaponComponent: Config key '" + model_key + "' = '" + _weapon_model_path + "'")

	# Get default muzzle offset
	_default_muzzle_offset.x = GameConfig.get_value("weapons", "default_muzzle_offset_x", 0.0)
	_default_muzzle_offset.y = GameConfig.get_value("weapons", "default_muzzle_offset_y", 0.0)
	_default_muzzle_offset.z = GameConfig.get_value("weapons", "default_muzzle_offset_z", -1.0)
	Logger.info("WeaponComponent: Default muzzle offset: " + str(_default_muzzle_offset))

func _find_camera() -> void:
	"""Find the currently active camera in the scene"""
	_camera = _find_active_camera(_player.get_tree().root)

	if not _camera:
		Logger.warning("WeaponComponent: No active camera found")
	else:
		Logger.info("WeaponComponent: Found active camera: " + str(_camera.get_path()))

func _find_active_camera(node: Node) -> Camera3D:
	"""Recursively search for the active Camera3D (current = true)"""
	if node is Camera3D and node.current:
		return node

	for child in node.get_children():
		var result = _find_active_camera(child)
		if result:
			return result

	return null

func _load_weapon_model() -> void:
	"""Load and setup the weapon model for current mode"""
	Logger.info("WeaponComponent: _load_weapon_model() called")

	# Clear existing weapon
	if _current_weapon:
		Logger.info("WeaponComponent: Clearing existing weapon")
		_current_weapon.queue_free()
		_current_weapon = null
		_muzzle_marker = null

	# Check if weapon should be visible
	if not _show_weapon:
		Logger.info("WeaponComponent: Weapon disabled for mode: " + _controller_mode)
		return

	# Tank mode uses built-in turret, not separate weapon
	if _controller_mode == "tank":
		Logger.info("WeaponComponent: Tank mode detected, using built-in turret")
		_setup_tank_weapon()
		return

	# Load weapon model from path
	if _weapon_model_path.is_empty():
		Logger.warning("WeaponComponent: No weapon model path configured for mode: " + _controller_mode)
		return

	Logger.info("WeaponComponent: Attempting to load weapon from: " + _weapon_model_path)

	# Check if resource exists
	if not ResourceLoader.exists(_weapon_model_path):
		Logger.error("WeaponComponent: Weapon file does not exist: " + _weapon_model_path)
		return

	Logger.info("WeaponComponent: Resource exists, loading scene")
	var weapon_scene = load(_weapon_model_path)
	if not weapon_scene:
		Logger.error("WeaponComponent: Failed to load weapon scene: " + _weapon_model_path)
		return

	Logger.info("WeaponComponent: Scene loaded successfully, instantiating")
	_current_weapon = weapon_scene.instantiate()

	if not _current_weapon:
		Logger.error("WeaponComponent: Failed to instantiate weapon")
		return

	Logger.info("WeaponComponent: Weapon instantiated: " + str(_current_weapon.name))

	# Attach weapon to appropriate parent based on mode
	_attach_weapon_to_parent()

	# Find muzzle marker
	_find_muzzle_marker()

	weapon_changed.emit(_weapon_model_path)
	Logger.info("WeaponComponent: Weapon fully loaded and attached: " + _weapon_model_path)
	Logger.info("WeaponComponent: Weapon global_position: " + str(_current_weapon.global_position))
	Logger.info("WeaponComponent: Weapon visible: " + str(_current_weapon.visible))

func _setup_tank_weapon() -> void:
	"""Setup weapon for tank mode using existing turret barrel"""
	# Tank uses the TankGunBarrel node as the muzzle
	var turret = _player.get_node_or_null("Turret")
	if not turret:
		Logger.warning("WeaponComponent: Tank turret not found")
		return

	var barrel_pivot = turret.get_node_or_null("BarrelPivot")
	if not barrel_pivot:
		Logger.warning("WeaponComponent: Tank barrel pivot not found")
		return

	var barrel = barrel_pivot.get_node_or_null("TankGunBarrel")
	if not barrel:
		Logger.warning("WeaponComponent: Tank gun barrel not found")
		return

	# The barrel itself is the weapon, so we create a marker at its tip
	if not barrel.has_node("Muzzle"):
		var muzzle = Marker3D.new()
		muzzle.name = "Muzzle"
		barrel.add_child(muzzle)
		# Position at barrel tip (barrel is a mesh, position relative to its length)
		muzzle.position = Vector3(0, 0, -1.0)

	_muzzle_marker = barrel.get_node("Muzzle")
	Logger.info("WeaponComponent: Tank weapon setup complete")

func _attach_weapon_to_parent() -> void:
	"""Attach weapon to appropriate parent node based on controller mode"""
	Logger.info("WeaponComponent: _attach_weapon_to_parent() for mode: " + _controller_mode)

	match _controller_mode:
		"first_person":
			# Attach to camera or head node
			if _camera:
				Logger.info("WeaponComponent: Attaching to camera for first_person")
				_camera.add_child(_current_weapon)
				_current_weapon.position = Vector3(0.3, -0.2, -0.5)  # Right-handed offset
				Logger.info("WeaponComponent: Weapon attached to: " + str(_camera.get_path()))
			else:
				Logger.warning("WeaponComponent: No camera found, attaching to WeaponComponent")
				add_child(_current_weapon)

		"third_person", "over_the_shoulder":
			# Attach to player's right side
			Logger.info("WeaponComponent: Attaching to WeaponComponent for " + _controller_mode)
			add_child(_current_weapon)
			_current_weapon.position = Vector3(0.2, 1.1, -0.3)  # Center mass, slightly forward and right
			Logger.info("WeaponComponent: Weapon attached at center mass position")

		"free_camera":
			# Attach to player body at center mass
			Logger.info("WeaponComponent: Attaching to WeaponComponent for free_camera")
			add_child(_current_weapon)
			_current_weapon.position = Vector3(0.4, 0.5, 0.3)  # Y lowered to 0.5 for center mass
			_current_weapon.rotation = Vector3.ZERO
			_current_weapon.scale = Vector3(1.0, 1.0, 1.0)

		"top_down", "isometric":
			# Attach to player, will rotate to face target
			Logger.info("WeaponComponent: Attaching to WeaponComponent for " + _controller_mode)
			add_child(_current_weapon)
			_current_weapon.position = Vector3(0.3, 0.6, 0.3)  # Slightly above and forward for visibility
			_current_weapon.scale = Vector3(1.2, 1.2, 1.2)  # Slightly larger for better visibility
			Logger.info("WeaponComponent: Isometric weapon setup - pos: " + str(_current_weapon.position) + " scale: " + str(_current_weapon.scale))

		_:
			# Default: attach to component
			Logger.info("WeaponComponent: Default attachment to WeaponComponent")
			add_child(_current_weapon)

func _find_muzzle_marker() -> void:
	"""Find the Muzzle marker in the weapon model"""
	if not _current_weapon:
		return

	_muzzle_marker = _find_node_by_name(_current_weapon, "Muzzle") as Marker3D

	if not _muzzle_marker:
		Logger.warning("WeaponComponent: No Muzzle marker found in weapon, using default offset")
		# Create a default muzzle marker
		_muzzle_marker = Marker3D.new()
		_muzzle_marker.name = "Muzzle"
		_current_weapon.add_child(_muzzle_marker)
		_muzzle_marker.position = _default_muzzle_offset

func _find_node_by_name(node: Node, node_name: String) -> Node:
	"""Recursively search for a node by name"""
	if node.name == node_name:
		return node

	for child in node.get_children():
		var result = _find_node_by_name(child, node_name)
		if result:
			return result

	return null

func _process(delta: float) -> void:
	"""Update weapon rotation for top-down/isometric/free_camera modes"""
	if _controller_mode in ["top_down", "isometric", "free_camera"] and _current_weapon and _camera:
		_update_weapon_rotation(delta)

func _update_weapon_rotation(delta: float) -> void:
	"""Rotate weapon to face mouse cursor for top-down/isometric"""
	var mouse_pos = get_viewport().get_mouse_position()
	var target = AimingHelper.get_mouse_ground_target(_camera, mouse_pos, 0.0, [_player])

	# Only rotate if target changed significantly
	if target.distance_to(_last_target_position) > 0.1:
		_last_target_position = target

		# Calculate direction to target (in XZ plane)
		var direction = (target - _current_weapon.global_position)
		direction.y = 0  # Keep rotation in horizontal plane

		if direction.length() > 0.1:
			direction = direction.normalized()

			# Calculate target rotation (add PI to flip 180 degrees for correct facing)
			var target_rotation = atan2(direction.x, direction.z) + PI

			# Smoothly interpolate rotation
			var current_rotation = _current_weapon.rotation.y
			_current_weapon.rotation.y = lerp_angle(current_rotation, target_rotation, _rotation_speed * delta)

## Public API

func get_muzzle_position() -> Vector3:
	"""Get the world position of the weapon's muzzle"""
	var base_position: Vector3

	if _muzzle_marker:
		base_position = _muzzle_marker.global_position
	else:
		# Fallback when no weapon loaded: use camera for POV modes, player position for others
		# POV camera modes: spawn from camera with forward offset
		if _controller_mode in ["first_person", "third_person", "over_the_shoulder"]:
			if _camera:
				# Spawn further in front for TPS/OTS to avoid player collision
				var offset = 2.5 if _controller_mode in ["third_person", "over_the_shoulder"] else 1.5
				return _camera.global_position + (-_camera.global_transform.basis.z * offset)

		# Top-down/isometric/tank: use player position with height offset
		base_position = _player.global_position + Vector3(0, 1.5, 0) + _default_muzzle_offset

	# For TPS/OTS modes: add extra forward offset to prevent player collision
	if _controller_mode in ["third_person", "over_the_shoulder"] and _camera:
		var forward = -_camera.global_transform.basis.z
		base_position += forward * 1.5  # Push spawn point 1.5m forward
		Logger.info("WeaponComponent: Added 1.5m forward offset for " + _controller_mode + " mode")

	return base_position

func get_target_position() -> Vector3:
	"""Get the target position where the weapon is aiming"""
	if not _camera:
		return get_muzzle_position() + Vector3.FORWARD * 10.0

	var max_distance = GameConfig.get_value("shooting", "aim_ray_length", 1000.0)
	return AimingHelper.get_target_for_mode(_controller_mode, _camera, _player, max_distance)

func get_fire_direction() -> Vector3:
	"""Get the normalized direction vector from muzzle to target"""
	var muzzle_pos = get_muzzle_position()
	var target_pos = get_target_position()
	return AimingHelper.calculate_fire_direction(muzzle_pos, target_pos)

func has_weapon() -> bool:
	"""Check if weapon is currently loaded and visible"""
	return _current_weapon != null or _controller_mode == "tank"

func reload_weapon() -> void:
	"""Reload the weapon model (useful for hot-reloading during development)"""
	_load_weapon_model()
