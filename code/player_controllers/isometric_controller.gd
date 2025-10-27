extends Node
# Isometric Controller - Classic isometric view with click-to-move
#
# This controller provides isometric gameplay with the following features:
# - Camera: Fixed isometric angle (35.264°, 45°) with orthogonal projection
# - Movement: Click-to-move pathfinding style gameplay
# - Input: Left-click to move, mouse wheel zoom, shows selection ring
#
# Required Player Scene Structure:
# - Player/Turret/SpringArm3D/Camera3D
# - Player/PlayerMesh (MeshInstance3D)
# - Player/SelectionRing (MeshInstance3D)
# - Player/TankHull (Node3D)
# - Player/Turret (Node3D)
#
# Configuration Parameters Used:
# - isometric.movement_speed - Player movement speed
# - isometric.gravity - Gravity force
# - isometric.lerp_weight - Movement smoothing (uses default if not in config)
# - isometric.zoom_speed - Camera zoom speed
# - isometric.min_zoom - Minimum camera size
# - isometric.max_zoom - Maximum camera size
# - isometric.default_zoom - Starting camera size

const DestinationMarker = preload("res://assets/destination_marker.tscn")

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
var camera_distance: float
var camera_angle_deg: float
var rotation_angle_deg: float

# Controller state
var is_active: bool = false
var target_position: Vector3

func initialize(player_node: CharacterBody3D) -> void:
	Logger.info("IsometricController initializing...")
	
	# Validate player node
	if player_node == null:
		Logger.error("IsometricController: Player node is null!")
		return
	
	player = player_node
	is_active = true
	target_position = player.global_transform.origin
	
	# Get and validate node references
	camera = player.get_node_or_null("ObserverCamera")
	if not camera:
		Logger.error("IsometricController: Missing ObserverCamera node!")
		return

	player_mesh = player.get_node_or_null("PlayerMesh")
	selection_ring = player.get_node_or_null("SelectionRing")
	turret = player.get_node_or_null("Turret")
	tank_hull = player.get_node_or_null("TankHull")

	# Load configuration from [isometric] section
	movement_speed = GameConfig.get_value("isometric", "movement_speed", 6.0)
	gravity = GameConfig.get_value("isometric", "gravity", 9.8)
	lerp_weight = 10.0  # Not in config, using default
	zoom_speed = GameConfig.get_value("isometric", "zoom_speed", 1.0)
	min_zoom = GameConfig.get_value("isometric", "min_zoom", 5.0)
	max_zoom = GameConfig.get_value("isometric", "max_zoom", 20.0)
	default_zoom = GameConfig.get_value("isometric", "default_zoom", 10.0)

	# Setup camera for isometric view
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = default_zoom

	# Position camera at isometric angle
	camera_distance = GameConfig.get_value("isometric", "camera_distance", 15.0)
	camera_angle_deg = GameConfig.get_value("isometric", "camera_angle", 45.0)
	rotation_angle_deg = GameConfig.get_value("isometric", "rotation_angle", 45.0)

	# Calculate isometric position (above and to the side)
	camera.global_position = player.global_position + Vector3(camera_distance * 0.707, camera_distance, camera_distance * 0.707)
	camera.look_at(player.global_position)
	
	# Setup visuals (show player mesh and selection ring, hide tank parts)
	if player_mesh: player_mesh.show()
	if selection_ring: selection_ring.show()  # Always visible in isometric mode
	if tank_hull: tank_hull.hide()
	if turret: turret.hide()  # Hide entire turret node (includes barrel and all tank turret components)
	
	Logger.info("IsometricController initialized successfully")

func _ready() -> void:
	pass

func handle_input(event: InputEvent) -> void:
	if not is_active:
		return
	
	# Mouse button handling
	if event is InputEventMouseButton:
		_handle_mouse_button(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# Zoom controls
	if Input.is_action_just_pressed("zoom_in"):
		camera.size = clamp(camera.size - zoom_speed, min_zoom, max_zoom)
	if Input.is_action_just_pressed("zoom_out"):
		camera.size = clamp(camera.size + zoom_speed, min_zoom, max_zoom)
	
	# Movement controls (left mouse button)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		_handle_left_click(event.position)

func _handle_left_click(mouse_pos: Vector2) -> void:
	var ray_length: float = 1000
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * ray_length
	
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	var result: Dictionary = space_state.intersect_ray(query)
	
	if result:
		target_position = result.position
		var marker = DestinationMarker.instantiate()
		player.get_parent().add_child(marker)
		marker.global_position = target_position
		if marker.has_node("AnimationPlayer"):
			marker.get_node("AnimationPlayer").connect("animation_finished", Callable(marker, "queue_free"))

func handle_physics(delta: float) -> void:
	if not is_active:
		return

	# ========================================
	# CAMERA UPDATE - Follow player at isometric angle
	# ========================================
	if camera:
		var camera_offset = Vector3(camera_distance * 0.707, camera_distance, camera_distance * 0.707)
		var target_camera_pos = player.global_position + camera_offset
		camera.global_position = camera.global_position.lerp(target_camera_pos, 5.0 * delta)
		camera.look_at(player.global_position)

	# ========================================
	# PLAYER MOVEMENT - Move to target (NO ROTATION)
	# ========================================
	var direction: Vector3 = _calculate_movement_direction()

	# Apply movement with lerping
	player.velocity.x = lerp(player.velocity.x, direction.x, lerp_weight * delta)
	player.velocity.z = lerp(player.velocity.z, direction.z, lerp_weight * delta)

	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta

	# Execute movement
	player.move_and_slide()

	# ========================================
	# CRITICAL: Lock player rotation to zero
	# ========================================
	player.rotation = Vector3.ZERO

	# ========================================
	# ENSURE PLAYER MESH IS VISIBLE
	# ========================================
	if player_mesh and not player_mesh.visible:
		player_mesh.visible = true

	# ========================================
	# DIAGNOSTIC: Print every 120 frames
	# ========================================
	if Engine.get_frames_drawn() % 120 == 0:
		Logger.info("=== ISOMETRIC DIAGNOSTIC ===")
		Logger.info("Player position: " + str(player.global_position))
		Logger.info("Player rotation: " + str(player.rotation_degrees))
		Logger.info("Camera position: " + str(camera.global_position))
		if player_mesh:
			Logger.info("PlayerMesh visible: " + str(player_mesh.visible))
		Logger.info("========================")

func _calculate_movement_direction() -> Vector3:
	# Calculate direction to target WITHOUT rotating player
	var current_position: Vector3 = player.global_position
	var move_direction: Vector3 = (target_position - current_position).normalized()
	var target_velocity: Vector3 = Vector3.ZERO

	# Only move if we're not close enough to target
	if current_position.distance_to(target_position) > 0.1:
		target_velocity = move_direction * movement_speed
	# REMOVED: player.look_at() - this was causing rotation issues

	return target_velocity

func cleanup() -> void:
	"""Called when switching to a different controller"""
	is_active = false
	Logger.info("IsometricController cleaned up")
