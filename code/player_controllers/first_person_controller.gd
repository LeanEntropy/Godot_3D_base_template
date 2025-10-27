extends Node
# First Person Controller - Classic FPS camera view
#
# This controller provides first-person gameplay with the following features:
# - Camera: Camera positioned at player head level (SpringArm length = 0)
# - Movement: Player-relative WASD movement (W = camera forward)
# - Input: Mouse look for camera and player rotation, pitch clamping
#
# Required Player Scene Structure:
# - Player/PlayerCamera/SpringArm3D/Camera3D (POV camera for FPS/TPS/OTS)
# - Player/PlayerMesh (MeshInstance3D) - hidden in FPS mode
# - Player/SelectionRing (MeshInstance3D)
# - Player/TankHull (Node3D)
# - Player/Turret (Node3D)
#
# Configuration Parameters Used:
# - physics.mouse_sensitivity - Mouse look sensitivity
# - physics.speed - Player movement speed
# - physics.gravity - Gravity force
# - physics.lerp_weight - Movement smoothing

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
var mouse_sensitivity: float
var movement_speed: float
var gravity: float
var lerp_weight: float

# Controller state
var is_active: bool = false

func initialize(player_node: CharacterBody3D) -> void:
	Logger.info("FirstPersonController initializing...")
	
	# Validate player node
	if player_node == null:
		Logger.error("FirstPersonController: Player node is null!")
		return
	
	player = player_node
	is_active = true
	
	# Get node references
	player_mesh = player.get_node("PlayerMesh")
	selection_ring = player.get_node("SelectionRing")
	turret = player.get_node("Turret")
	tank_hull = player.get_node("TankHull")

	# Camera management - use PlayerCamera
	var player_camera_rig = player.get_node_or_null("PlayerCamera")
	if player_camera_rig:
		spring_arm = player_camera_rig.get_node_or_null("SpringArm3D")
		if spring_arm:
			camera = spring_arm.get_node_or_null("Camera3D")
			if camera:
				camera.current = true
				# Configure for first person
				spring_arm.spring_length = 0.0  # No distance, at eyes
				spring_arm.position = Vector3(0, 1.7, 0)  # Eye height
				spring_arm.top_level = false
				camera.projection = Camera3D.PROJECTION_PERSPECTIVE
				Logger.info("FirstPersonController: PlayerCamera activated")

	if not camera:
		Logger.error("FirstPersonController: Failed to find PlayerCamera!")
		return

	# Deactivate other cameras
	var observer_camera = player.get_node_or_null("ObserverCamera")
	if observer_camera:
		observer_camera.current = false

	var tank_camera = player.get_node_or_null("Turret/SpringArm3D/TankCamera")
	if tank_camera:
		tank_camera.current = false

	# Load configuration from first_person section
	mouse_sensitivity = GameConfig.get_value("first_person", "mouse_sensitivity", 0.002)
	movement_speed = GameConfig.get_value("first_person", "movement_speed", 5.0)
	gravity = GameConfig.get_value("first_person", "gravity", 9.8)
	lerp_weight = 10.0  # Not in config, using default

	# Hide tank visual components (NOT the turret node itself)
	var turret_mesh = player.get_node_or_null("Turret/TurretMesh")
	var barrel_pivot = player.get_node_or_null("Turret/BarrelPivot")
	if turret_mesh:
		turret_mesh.hide()
	if barrel_pivot:
		barrel_pivot.hide()

	# Setup visuals (hide player mesh - FPS standard, hide tank parts)
	if player_mesh: player_mesh.hide()  # Intentional: FPS mode hides body
	if selection_ring: selection_ring.hide()
	if tank_hull: tank_hull.hide()
	
	Logger.info("FirstPersonController: Player mesh hidden (FPS standard)")
	Logger.info("FirstPersonController initialized successfully")

func _ready() -> void:
	pass

func handle_input(event: InputEvent) -> void:
	if not is_active:
		return
	
	# Mouse motion handling
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_motion(event)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	player.rotate_y(-event.relative.x * mouse_sensitivity)
	camera.rotate_x(-event.relative.y * mouse_sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func handle_physics(delta: float) -> void:
	if not is_active:
		return
	
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	
	# Get input direction
	var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "backward")
	
	# Calculate movement direction (player-relative)
	var direction: Vector3 = _calculate_movement_direction(input_dir)
	
	# Apply movement with lerping
	var target_velocity: Vector3 = Vector3(direction.x, 0, direction.z) * movement_speed
	player.velocity.x = lerp(player.velocity.x, target_velocity.x, lerp_weight * delta)
	player.velocity.z = lerp(player.velocity.z, target_velocity.z, lerp_weight * delta)
	
	# Execute movement
	player.move_and_slide()

func _calculate_movement_direction(input_dir: Vector2) -> Vector3:
	# Player-relative movement (W = where player is facing)
	return (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

func cleanup() -> void:
	"""Called when switching to a different controller"""
	is_active = false
	Logger.info("FirstPersonController cleaned up")
