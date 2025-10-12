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
# - physics.speed - Player movement speed
# - physics.gravity - Gravity force
# - physics.lerp_weight - Movement smoothing
# - physics.zoom_speed - Camera zoom speed
# - physics.min_zoom - Minimum camera size
# - physics.max_zoom - Maximum camera size
# - physics.default_zoom - Starting camera size

const DestinationMarker = preload("res://assets/destination_marker.tscn")

# Player references
var player: CharacterBody3D
var camera: Camera3D
var spring_arm: SpringArm3D

# Visual elements
var player_mesh: MeshInstance3D
var selection_ring: MeshInstance3D
var tank_hull: MeshInstance3D
var turret: Node3D
var turret_mesh: MeshInstance3D
var tank_gun_barrel: MeshInstance3D

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
	if not player.has_node("Turret/SpringArm3D/Camera3D"):
		Logger.error("IsometricController: Missing Camera3D node!")
		return
	camera = player.get_node("Turret/SpringArm3D/Camera3D")
	spring_arm = player.get_node("Turret/SpringArm3D")
	player_mesh = player.get_node("PlayerMesh")
	selection_ring = player.get_node("SelectionRing")
	turret = player.get_node("Turret")
	turret_mesh = turret.get_node("TurretMesh")
	tank_hull = player.get_node("TankHull")
	tank_gun_barrel = turret.get_node("TankGunBarrel")
	
	# Load configuration
	movement_speed = GameConfig.speed
	gravity = GameConfig.gravity
	lerp_weight = GameConfig.lerp_weight
	zoom_speed = GameConfig.zoom_speed
	min_zoom = GameConfig.min_zoom
	max_zoom = GameConfig.max_zoom
	default_zoom = GameConfig.default_zoom
	
	# Setup camera for isometric view
	spring_arm.spring_length = 20.0
	spring_arm.position = Vector3.ZERO
	spring_arm.rotation = Vector3(deg_to_rad(-35.264), deg_to_rad(45), 0)  # Classic isometric angles
	spring_arm.top_level = true  # Camera doesn't rotate with player
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = default_zoom
	
	# Setup visuals (show player mesh and selection ring, hide tank parts)
	if player_mesh: player_mesh.show()
	if selection_ring: selection_ring.show()  # Always visible in isometric mode
	if turret_mesh: turret_mesh.hide()
	if tank_hull: tank_hull.hide()
	if tank_gun_barrel: tank_gun_barrel.hide()
	
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
	
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	
	# Update camera position to follow player
	spring_arm.global_position = player.global_position
	
	# Calculate movement toward target
	var direction: Vector3 = _calculate_movement_direction()
	
	# Apply movement with lerping
	player.velocity.x = lerp(player.velocity.x, direction.x, lerp_weight * delta)
	player.velocity.z = lerp(player.velocity.z, direction.z, lerp_weight * delta)
	
	# Execute movement
	player.move_and_slide()

func _calculate_movement_direction() -> Vector3:
	var current_position: Vector3 = player.global_position
	var move_direction: Vector3 = (target_position - current_position).normalized()
	var target_velocity: Vector3 = Vector3.ZERO
	
	if current_position.distance_to(target_position) > 0.1:
		target_velocity = move_direction * movement_speed
		player.look_at(Vector3(target_position.x, player.global_position.y, target_position.z))
	
	return target_velocity

func cleanup() -> void:
	"""Called when switching to a different controller"""
	is_active = false
	Logger.info("IsometricController cleaned up")
