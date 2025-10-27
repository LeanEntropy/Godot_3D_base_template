extends Node
# Free Camera Controller - Orbit camera for observation and debugging
#
# This controller provides an orbiting camera with the following features:
# - Camera: Orbits around player at fixed distance, always looking at player
# - Movement: Right-click drag to orbit, mouse wheel to zoom
# - Input: Camera stays parallel to ground, WASD moves player (optional)
#
# Required Player Scene Structure:
# - Player/ObserverCamera (Camera3D)
# - Player/PlayerMesh (MeshInstance3D)
# - Player/SelectionRing (MeshInstance3D)
# - Player/TankHull (Node3D)
# - Player/Turret (Node3D)
#
# Configuration Parameters Used:
# - free_camera.movement_speed - Player movement speed (optional)
# - free_camera.mouse_sensitivity - Orbit rotation sensitivity
# - free_camera.fov - Camera field of view

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
var mouse_sensitivity: float
var gravity: float

# Orbit camera state
var is_active: bool = false
var orbit_distance: float = 10.0  # Current distance from player
var orbit_angle: float = 45.0  # Horizontal angle (degrees)
var min_distance: float = 3.0
var max_distance: float = 30.0
var zoom_speed: float = 1.0

# Input state
var is_orbiting: bool = false

func initialize(player_node: CharacterBody3D) -> void:
	Logger.info("FreeCameraController (Orbit Mode) initializing...")

	# Validate player node
	if player_node == null:
		Logger.error("FreeCameraController: Player node is null!")
		return

	player = player_node
	is_active = true

	# Get and validate ObserverCamera
	camera = player.get_node_or_null("ObserverCamera")
	if not camera:
		Logger.error("FreeCameraController: Missing ObserverCamera node!")
		return

	# Get visual elements
	player_mesh = player.get_node_or_null("PlayerMesh")
	selection_ring = player.get_node_or_null("SelectionRing")
	turret = player.get_node_or_null("Turret")
	tank_hull = player.get_node_or_null("TankHull")

	# Load configuration from [free_camera] section
	movement_speed = GameConfig.get_value("free_camera", "movement_speed", 5.0)
	mouse_sensitivity = GameConfig.get_value("free_camera", "mouse_sensitivity", 0.002)
	gravity = GameConfig.get_value("global", "gravity", 9.8)

	# Setup camera for orbit mode
	camera.current = true
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = GameConfig.get_value("free_camera", "fov", 75.0)

	# Position camera at initial orbit position
	_update_camera_position()

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

	Logger.info("FreeCameraController (Orbit Mode) initialized successfully")

func _ready() -> void:
	pass

func handle_input(event: InputEvent) -> void:
	if not is_active:
		return
	if not camera:
		return

	# Right mouse button drag for orbiting
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_orbiting = true
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				is_orbiting = false
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Mouse wheel for zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			orbit_distance = clamp(orbit_distance - zoom_speed, min_distance, max_distance)
			_update_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			orbit_distance = clamp(orbit_distance + zoom_speed, min_distance, max_distance)
			_update_camera_position()

	# Mouse motion for orbit rotation (only when right mouse button is held)
	if event is InputEventMouseMotion and is_orbiting:
		_handle_orbit_rotation(event)

func _handle_orbit_rotation(event: InputEventMouseMotion) -> void:
	# Rotate orbit angle based on horizontal mouse movement
	orbit_angle -= event.relative.x * mouse_sensitivity * 50.0  # Scale for degrees

	# Keep angle in 0-360 range
	if orbit_angle < 0:
		orbit_angle += 360
	elif orbit_angle >= 360:
		orbit_angle -= 360

	_update_camera_position()

func _update_camera_position() -> void:
	"""Position camera in orbit around player, always looking at player, parallel to ground"""
	if not camera or not player:
		return

	# Convert angle to radians
	var angle_rad: float = deg_to_rad(orbit_angle)

	# Calculate orbit position (parallel to ground - only XZ rotation)
	var offset: Vector3 = Vector3(
		sin(angle_rad) * orbit_distance,
		orbit_distance * 0.4,  # Fixed height above player (40% of distance)
		cos(angle_rad) * orbit_distance
	)

	# Position camera
	camera.global_position = player.global_position + offset

	# Always look at player
	camera.look_at(player.global_position, Vector3.UP)

func handle_physics(delta: float) -> void:
	if not is_active:
		return
	if not camera:
		return

	# ========================================
	# CAMERA UPDATE - Follow player in orbit
	# ========================================
	_update_camera_position()

	# ========================================
	# PLAYER MOVEMENT - Optional WASD control
	# ========================================
	var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "backward")

	if input_dir != Vector2.ZERO:
		# Calculate movement direction relative to current camera view (screen-relative)
		var forward: Vector3 = -camera.global_transform.basis.z
		var right: Vector3 = camera.global_transform.basis.x

		# Flatten to horizontal plane
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()

		var move_direction: Vector3 = (forward * -input_dir.y + right * input_dir.x).normalized()

		# Apply movement
		player.velocity.x = move_direction.x * movement_speed
		player.velocity.z = move_direction.z * movement_speed
	else:
		# Stop horizontal movement
		player.velocity.x = 0
		player.velocity.z = 0

	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta

	# Move player
	player.move_and_slide()

	# ========================================
	# CRITICAL: Lock player rotation to zero
	# ========================================
	player.rotation = Vector3.ZERO

	# ========================================
	# DIAGNOSTIC: Print every 120 frames
	# ========================================
	if Engine.get_frames_drawn() % 120 == 0:
		Logger.info("=== FREE CAMERA ORBIT DIAGNOSTIC ===")
		Logger.info("Orbit angle: " + str(orbit_angle))
		Logger.info("Orbit distance: " + str(orbit_distance))
		Logger.info("Camera position: " + str(camera.global_position))
		Logger.info("Player position: " + str(player.global_position))
		Logger.info("Player rotation: " + str(player.rotation_degrees))
		Logger.info("===================================")

func cleanup() -> void:
	"""Called when switching to a different controller"""
	is_active = false

	# Restore mouse mode if we were orbiting
	if is_orbiting:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		is_orbiting = false

	Logger.info("FreeCameraController cleaned up")
