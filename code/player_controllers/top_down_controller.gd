extends Node
# Top Down Controller - Fixed overhead camera for arcade-style gameplay
#
# This controller provides top-down gameplay with the following features:
# - Camera: Fixed overhead camera with configurable height and angle
# - Movement: Screen-relative WASD movement (W = up on screen)
# - Input: Mouse aiming rotates player, zoom controls with mouse wheel
#
# Required Player Scene Structure:
# - Player/Turret/SpringArm3D/Camera3D
# - Player/PlayerMesh (MeshInstance3D)
# - Player/SelectionRing (MeshInstance3D)
# - Player/TankHull (Node3D)
# - Player/Turret (Node3D)
#
# Configuration Parameters Used:
# - top_down.movement_speed - Player movement speed
# - top_down.gravity - Gravity force
# - top_down.lerp_weight - Movement smoothing (uses default if not in config)
# - top_down.zoom_speed - Camera zoom speed
# - top_down.min_zoom - Minimum camera distance
# - top_down.max_zoom - Maximum camera distance
# - top_down.default_zoom - Starting camera distance

# Player references
var player: CharacterBody3D
var camera: Camera3D

# Visual elements
var player_mesh: MeshInstance3D
var selection_ring: MeshInstance3D
var tank_hull: MeshInstance3D
var turret: Node3D

# Configuration values (loaded from GameConfig)
var movement_speed: float
var gravity: float
var lerp_weight: float
var zoom_speed: float
var min_zoom: float
var max_zoom: float
var default_zoom: float
var camera_height: float

# Controller state
var is_active: bool = false

func initialize(player_node: CharacterBody3D) -> void:
	Logger.info("TopDownController initializing...")

	# Validate player node
	if player_node == null:
		Logger.error("TopDownController: Player node is null!")
		return

	player = player_node
	is_active = true

	# Get and validate ObserverCamera
	camera = player.get_node_or_null("ObserverCamera")
	if not camera:
		Logger.error("TopDownController: Missing ObserverCamera node!")
		return

	# Get visual elements
	player_mesh = player.get_node_or_null("PlayerMesh")
	selection_ring = player.get_node_or_null("SelectionRing")
	turret = player.get_node_or_null("Turret")
	tank_hull = player.get_node_or_null("TankHull")

	# Load configuration from [top_down] section
	movement_speed = GameConfig.get_value("top_down", "movement_speed", 8.0)
	gravity = GameConfig.get_value("top_down", "gravity", 9.8)
	lerp_weight = 10.0  # Not in config, using default
	zoom_speed = GameConfig.get_value("top_down", "zoom_speed", 2.0)
	min_zoom = GameConfig.get_value("top_down", "min_zoom", 10.0)
	max_zoom = GameConfig.get_value("top_down", "max_zoom", 40.0)
	default_zoom = GameConfig.get_value("top_down", "default_zoom", 20.0)
	camera_height = GameConfig.get_value("top_down", "camera_height", 20.0)

	# Setup camera for top-down view
	camera.current = true
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 75.0

	# Position camera overhead
	camera.global_position = player.global_position + Vector3(0, camera_height, 0)
	camera.rotation_degrees = Vector3(-80, 0, 0)  # Look down

	# Deactivate other cameras
	var player_camera = player.get_node_or_null("PlayerCamera/SpringArm3D/Camera3D")
	if player_camera:
		player_camera.current = false

	var tank_camera = player.get_node_or_null("Turret/SpringArm3D/TankCamera")
	if tank_camera:
		tank_camera.current = false

	# Setup visuals (show player mesh, hide tank parts)
	if player_mesh: player_mesh.show()
	if selection_ring: selection_ring.hide()
	if tank_hull: tank_hull.hide()
	if turret: turret.hide()  # Hide entire turret node (includes barrel and all tank turret components)

	Logger.info("TopDownController initialized successfully")

func _ready() -> void:
	pass

func handle_input(event: InputEvent) -> void:
	if not is_active:
		return
	
	# Mouse button handling for zoom
	if event is InputEventMouseButton:
		_handle_mouse_button(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if Input.is_action_just_pressed("zoom_in"):
		camera_height = clamp(camera_height - zoom_speed, min_zoom, max_zoom)
		if camera:
			camera.global_position = player.global_position + Vector3(0, camera_height, 0)
	if Input.is_action_just_pressed("zoom_out"):
		camera_height = clamp(camera_height + zoom_speed, min_zoom, max_zoom)
		if camera:
			camera.global_position = player.global_position + Vector3(0, camera_height, 0)

func handle_physics(delta: float) -> void:
	if not is_active:
		return

	# ========================================
	# CAMERA UPDATE - No rotation, ever
	# ========================================
	if camera:
		camera.global_position = player.global_position + Vector3(0, camera_height, 0)
		camera.rotation_degrees = Vector3(-80, 0, 0)  # Lock to top-down

	# ========================================
	# WEAPON ROTATION - Independent of player
	# ========================================
	var weapon_component = player.get_node_or_null("WeaponComponent")
	if weapon_component and weapon_component.has_method("has_weapon") and weapon_component.has_weapon():
		var weapon = weapon_component.get_node_or_null("TopDownGun")
		if not weapon:
			# Try generic weapon name
			for child in weapon_component.get_children():
				if child is Node3D:
					weapon = child
					break

		if weapon:
			# Get mouse world position via raycast
			var mouse_pos: Vector2 = player.get_viewport().get_mouse_position()
			var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
			var ray_direction: Vector3 = camera.project_ray_normal(mouse_pos)
			var ray_end: Vector3 = ray_origin + ray_direction * 1000.0

			# Raycast to ground
			var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
			query.collide_with_areas = false
			var result: Dictionary = space_state.intersect_ray(query)

			if result:
				var target_pos: Vector3 = result.position
				var weapon_pos: Vector3 = weapon.global_position

				# Calculate angle on ground plane (Y-axis rotation only)
				var dx: float = target_pos.x - weapon_pos.x
				var dz: float = target_pos.z - weapon_pos.z

				# Only rotate if mouse is far enough (prevent jitter)
				if abs(dx) > 0.1 or abs(dz) > 0.1:
					var target_angle: float = atan2(dx, dz)
					weapon.rotation.y = target_angle

				# Keep weapon flat
				weapon.rotation.x = 0
				weapon.rotation.z = 0

	# ========================================
	# PLAYER MOVEMENT - NO ROTATION
	# ========================================
	var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "backward")
	var direction: Vector3 = Vector3(input_dir.x, 0, input_dir.y).normalized()

	if direction != Vector3.ZERO:
		player.velocity.x = direction.x * movement_speed
		player.velocity.z = direction.z * movement_speed
	else:
		player.velocity.x = 0
		player.velocity.z = 0

	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta

	# Move player - THIS DOES NOT ROTATE THE PLAYER
	player.move_and_slide()

	# ========================================
	# CRITICAL: Lock player rotation to zero
	# ========================================
	player.rotation = Vector3.ZERO

	# ========================================
	# DIAGNOSTIC: Print every 60 frames
	# ========================================
	if Engine.get_frames_drawn() % 60 == 0:
		Logger.info("=== TOP-DOWN DIAGNOSTIC ===")
		Logger.info("Player rotation: " + str(player.rotation_degrees))
		Logger.info("Camera rotation: " + str(camera.rotation_degrees))
		if weapon_component and weapon_component.has_method("has_weapon") and weapon_component.has_weapon():
			var weapon = weapon_component.get_node_or_null("TopDownGun")
			if weapon:
				Logger.info("Weapon rotation: " + str(weapon.rotation_degrees))
		Logger.info("========================")

# REMOVED: Old _handle_mouse_aiming() function
# This function rotated the player with look_at(), causing camera spin
# Weapon rotation is now handled directly in handle_physics()
# func _handle_mouse_aiming() -> void:
# 	var mouse_pos: Vector2 = player.get_viewport().get_mouse_position()
# 	var ray_length: float = 1000
# 	var from: Vector3 = camera.project_ray_origin(mouse_pos)
# 	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * ray_length
#
# 	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
# 	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
# 	var result: Dictionary = space_state.intersect_ray(query)
#
# 	if result:
# 		var target_position: Vector3 = result.position
# 		player.look_at(Vector3(target_position.x, player.global_transform.origin.y, target_position.z))

func _calculate_movement_direction(input_dir: Vector2) -> Vector3:
	# Screen-relative movement (W = up on screen, not where player faces)
	return Vector3(input_dir.x, 0, input_dir.y).normalized()

func cleanup() -> void:
	"""Called when switching to a different controller"""
	is_active = false
	Logger.info("TopDownController cleaned up")
