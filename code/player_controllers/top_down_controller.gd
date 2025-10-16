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
# - physics.speed - Player movement speed
# - physics.gravity - Gravity force
# - physics.lerp_weight - Movement smoothing
# - physics.zoom_speed - Camera zoom speed
# - physics.min_zoom - Minimum camera distance
# - physics.max_zoom - Maximum camera distance
# - physics.default_zoom - Starting camera distance

# Player references
var player: CharacterBody3D
var camera: Camera3D
var spring_arm: SpringArm3D

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
	
	# Get and validate node references
	if not player.has_node("Turret/SpringArm3D/Camera3D"):
		Logger.error("TopDownController: Missing Camera3D node!")
		return
	camera = player.get_node("Turret/SpringArm3D/Camera3D")
	spring_arm = player.get_node("Turret/SpringArm3D")
	player_mesh = player.get_node("PlayerMesh")
	selection_ring = player.get_node("SelectionRing")
	turret = player.get_node("Turret")
	tank_hull = player.get_node("TankHull")
	
	# Load configuration
	movement_speed = GameConfig.speed
	gravity = GameConfig.gravity
	lerp_weight = GameConfig.lerp_weight
	zoom_speed = GameConfig.zoom_speed
	min_zoom = GameConfig.min_zoom
	max_zoom = GameConfig.max_zoom
	default_zoom = GameConfig.default_zoom
	
	# Setup camera for top-down view
	spring_arm.spring_length = 10.0
	spring_arm.position = Vector3.ZERO
	spring_arm.rotation.x = deg_to_rad(-70)  # Look down at 70 degree angle
	spring_arm.top_level = true  # Camera doesn't rotate with player
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = default_zoom
	
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
		spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_speed, min_zoom, max_zoom)
	if Input.is_action_just_pressed("zoom_out"):
		spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_speed, min_zoom, max_zoom)

func handle_physics(delta: float) -> void:
	if not is_active:
		return
	
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	
	# Update camera position to follow player
	spring_arm.global_position = player.global_position
	
	# Handle mouse aiming (rotate player toward mouse cursor)
	_handle_mouse_aiming()
	
	# Get input direction
	var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "backward")
	
	# Calculate movement direction (screen-relative)
	var direction: Vector3 = _calculate_movement_direction(input_dir)
	
	# Apply movement with lerping
	var target_velocity: Vector3 = Vector3(direction.x, 0, direction.z) * movement_speed
	player.velocity.x = lerp(player.velocity.x, target_velocity.x, lerp_weight * delta)
	player.velocity.z = lerp(player.velocity.z, target_velocity.z, lerp_weight * delta)
	
	# Execute movement
	player.move_and_slide()

func _handle_mouse_aiming() -> void:
	# Cast ray from camera to ground plane to find mouse world position
	var mouse_pos: Vector2 = player.get_viewport().get_mouse_position()
	var ray_length: float = 1000
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * ray_length
	
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	var result: Dictionary = space_state.intersect_ray(query)
	
	if result:
		var target_position: Vector3 = result.position
		player.look_at(Vector3(target_position.x, player.global_transform.origin.y, target_position.z))

func _calculate_movement_direction(input_dir: Vector2) -> Vector3:
	# Screen-relative movement (W = up on screen, not where player faces)
	return Vector3(input_dir.x, 0, input_dir.y).normalized()

func cleanup() -> void:
	"""Called when switching to a different controller"""
	is_active = false
	Logger.info("TopDownController cleaned up")