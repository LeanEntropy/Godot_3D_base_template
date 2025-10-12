extends Node
# Tank Controller - Vehicle-style tank controls with proper turret aiming and shooting
#
# This controller provides realistic tank gameplay with the following features:
# - Camera: SpringArm camera positioned behind tank for optimal gameplay view
# - Movement: Tank-style movement (A/D = hull rotation, W/S = forward/reverse)
# - Input: Mouse controls turret rotation independent of hull, left-click shoots
# - Aiming: 3D raycast system with visual aim marker for precise targeting
# - Shooting: Physics-based projectiles fired from barrel tip toward crosshair
#
# Required Player Scene Structure:
# - Player/Turret/SpringArm3D/Camera3D
# - Player/TankHull (MeshInstance3D)
# - Player/Turret/TurretMesh (MeshInstance3D)
# - Player/Turret/TankGunBarrel (MeshInstance3D)
# - Player/Turret/TankGunBarrel/BarrelTip (Node3D) - created automatically if missing
# - Player/PlayerMesh (MeshInstance3D) - hidden for tank mode
#
# Configuration Parameters Used:
# - tank.fire_rate - Shots per second
# - tank.projectile_speed - Projectile velocity
# - tank.turret_rotation_speed - Turret aiming speed
# - tank.aim_ray_length - Maximum aiming distance
# - physics.hull_turn_speed - Hull rotation speed
# - physics.forward_speed - Forward movement speed
# - physics.reverse_speed - Reverse movement speed
# - physics.gravity - Gravity force
# - physics.lerp_weight - Movement smoothing

# Preload resources
const TankProjectile = preload("res://assets/tank_projectile.tscn")
const AimMarker = preload("res://assets/tank_aim_marker.tscn")

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

# Tank-specific elements
var logical_turret: Node3D
var barrel_tip: Node3D
var aim_marker: Node3D

# Configuration values (loaded from GameConfig)
var hull_turn_speed: float
var forward_speed: float
var reverse_speed: float
var gravity: float
var lerp_weight: float

# Turret aiming configuration
var fire_rate: float
var projectile_speed: float
var turret_rotation_speed: float
var aim_ray_length: float

# Turret aiming state
var turret_target_position: Vector3 = Vector3.ZERO
var can_shoot: bool = true

# Controller state
var is_active: bool = false

func initialize(player_node: CharacterBody3D) -> void:
	Logger.info("TankController initializing...")
	
	# Validate player node
	if player_node == null:
		Logger.error("TankController: Player node is null!")
		return
	
	player = player_node
	is_active = true
	
	# Get and validate node references
	if not player.has_node("Turret/SpringArm3D/Camera3D"):
		Logger.error("TankController: Missing Camera3D node!")
		return
	camera = player.get_node("Turret/SpringArm3D/Camera3D")
	spring_arm = player.get_node("Turret/SpringArm3D")
	player_mesh = player.get_node("PlayerMesh")
	selection_ring = player.get_node("SelectionRing")
	turret = player.get_node("Turret")
	turret_mesh = turret.get_node("TurretMesh")
	tank_hull = player.get_node("TankHull")
	tank_gun_barrel = turret.get_node("TankGunBarrel")
	
	# Create logical turret for independent rotation tracking
	logical_turret = Node3D.new()
	player.add_child(logical_turret)
	
	# Get or create barrel tip node (where projectiles spawn)
	if tank_gun_barrel.has_node("BarrelTip"):
		barrel_tip = tank_gun_barrel.get_node("BarrelTip")
		Logger.info("TankController: Found existing BarrelTip node")
	else:
		Logger.warning("TankController: No BarrelTip node found, creating at barrel end")
		barrel_tip = Node3D.new()
		barrel_tip.name = "BarrelTip"
		tank_gun_barrel.add_child(barrel_tip)
		barrel_tip.position = Vector3(0, 0, -1.5)  # Position at barrel tip
	
	# Create aim marker (deferred to avoid tree issues during initialization)
	call_deferred("_create_aim_marker")
	
	# Load configuration from GameConfig and config file
	hull_turn_speed = GameConfig.hull_turn_speed
	forward_speed = GameConfig.forward_speed
	reverse_speed = GameConfig.reverse_speed
	gravity = GameConfig.gravity
	lerp_weight = GameConfig.lerp_weight
	
	# Load tank-specific configuration
	var config = ConfigFile.new()
	config.load("res://game_config.cfg")
	fire_rate = config.get_value("tank", "fire_rate", 0.5)
	projectile_speed = config.get_value("tank", "projectile_speed", 50.0)
	turret_rotation_speed = config.get_value("tank", "turret_rotation_speed", 3.0)
	aim_ray_length = config.get_value("tank", "aim_ray_length", 1000.0)
	
	# Setup camera for optimal tank gameplay view
	spring_arm.spring_length = 12.0  # Further back for tank view
	spring_arm.position = Vector3(0, 3.0, 0)  # Higher up for better visibility
	spring_arm.top_level = false
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.rotation_degrees.x = -15  # Look down slightly
	camera.fov = 70.0
	
	# Setup visuals (show tank parts, hide player mesh)
	if player_mesh: player_mesh.hide()
	if selection_ring: selection_ring.hide()
	if turret_mesh: turret_mesh.show()
	if tank_hull: tank_hull.show()
	if tank_gun_barrel: tank_gun_barrel.show()
	
	Logger.info("TankController initialized successfully")

func _ready() -> void:
	pass

func handle_input(event: InputEvent) -> void:
	if not is_active:
		return
	
	# Mouse button for shooting
	if event is InputEventMouseButton:
		_handle_mouse_button(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# Left click to shoot
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_shoot_projectile()

func handle_physics(delta: float) -> void:
	if not is_active:
		return
	
	# Update turret aiming every frame
	_update_turret_aiming()
	_rotate_turret_to_target(delta)
	
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	
	# Tank movement - use proper tank controls
	_handle_tank_movement(delta)
	
	# Execute movement
	player.move_and_slide()

func _handle_tank_movement(delta: float) -> void:
	"""Handle tank-style movement: WASD for forward/back and hull rotation"""
	# Get input for movement and rotation
	var forward_input: float = Input.get_action_strength("forward") - Input.get_action_strength("backward")
	var rotation_input: float = Input.get_action_strength("right") - Input.get_action_strength("left")
	
	# Hull rotation (left/right turns the entire tank)
	if abs(rotation_input) > 0.1:
		player.rotate_y(rotation_input * hull_turn_speed * delta)
	
	# Forward/backward movement along hull direction
	var target_velocity: Vector3 = Vector3.ZERO
	if forward_input > 0.1:
		# Forward movement
		target_velocity = -player.transform.basis.z * forward_speed * forward_input
	elif forward_input < -0.1:
		# Reverse movement
		target_velocity = player.transform.basis.z * reverse_speed * abs(forward_input)
	
	# Apply movement with lerping for smooth acceleration/deceleration
	player.velocity.x = lerp(player.velocity.x, target_velocity.x, lerp_weight * delta)
	player.velocity.z = lerp(player.velocity.z, target_velocity.z, lerp_weight * delta)

func _update_turret_aiming() -> void:
	"""Raycast from camera to find 3D point where turret should aim"""
	if camera == null or not camera.is_inside_tree():
		return
	
	# Get mouse position in viewport
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	
	# Raycast from camera through mouse position
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_pos)
	var ray_end: Vector3 = ray_origin + ray_direction * aim_ray_length
	
	# Perform raycast to find aim point
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [player]  # Don't hit own tank
	
	var result: Dictionary = space_state.intersect_ray(query)
	
	if result:
		# Hit something - aim at impact point
		turret_target_position = result.position
	else:
		# Hit nothing - aim at maximum distance point
		turret_target_position = ray_end
	
	# Update aim marker position
	if aim_marker and aim_marker.is_inside_tree():
		aim_marker.global_position = turret_target_position
		aim_marker.show()

func _rotate_turret_to_target(delta: float) -> void:
	"""Smoothly rotate turret to face target position independently of hull"""
	if turret == null:
		return
	
	# Get direction from turret to target (in world space)
	var turret_pos: Vector3 = turret.global_position
	var direction_to_target: Vector3 = turret_target_position - turret_pos
	direction_to_target.y = 0  # Keep turret rotation only on Y axis (horizontal)
	
	if direction_to_target.length() < 0.1:
		return  # Too close, don't rotate
	
	# Calculate target angle in world space
	var target_angle: float = atan2(direction_to_target.x, direction_to_target.z)
	
	# Get turret's current global Y rotation
	var current_angle: float = turret.global_rotation.y
	
	# Smooth rotation using lerp_angle for proper angle interpolation
	var new_angle: float = lerp_angle(current_angle, target_angle, delta * turret_rotation_speed)
	
	# Apply rotation (set global rotation to maintain independent aiming)
	turret.global_rotation.y = new_angle

func _shoot_projectile() -> void:
	"""Spawn and launch projectile from barrel tip toward aim point"""
	if not can_shoot:
		Logger.info("TankController: Cannot shoot - rate limit active")
		return
	
	if barrel_tip == null:
		Logger.error("TankController: Cannot shoot - no barrel tip!")
		return
	
	# Create projectile
	var projectile: RigidBody3D = TankProjectile.instantiate()
	get_tree().root.add_child(projectile)
	
	# Position at barrel tip
	projectile.global_position = barrel_tip.global_position
	
	# Calculate direction from barrel to aim point
	var shoot_direction: Vector3 = (turret_target_position - barrel_tip.global_position).normalized()
	
	# Launch projectile
	if projectile.has_method("launch"):
		projectile.launch(shoot_direction, projectile_speed)
	else:
		# Fallback if launch method doesn't exist
		projectile.linear_velocity = shoot_direction * projectile_speed
	
	Logger.info("TankController: Projectile fired toward %s" % turret_target_position)
	
	# Start fire rate cooldown
	can_shoot = false
	_start_fire_cooldown()

func _create_aim_marker() -> void:
	"""Create aim marker after controller is properly initialized"""
	aim_marker = AimMarker.instantiate()
	get_tree().root.add_child(aim_marker)
	aim_marker.hide()  # Start hidden, show when aiming

func _start_fire_cooldown() -> void:
	"""Start cooldown timer for fire rate limiting"""
	await get_tree().create_timer(1.0 / fire_rate).timeout
	can_shoot = true

func _calculate_movement_direction() -> Vector3:
	# Not used in this controller - movement handled by tank-specific logic
	return Vector3.ZERO

func cleanup() -> void:
	"""Called when switching to a different controller"""
	is_active = false
	
	# Clean up tank-specific elements
	if logical_turret:
		logical_turret.queue_free()
		logical_turret = null
	
	# Remove aim marker
	if aim_marker:
		aim_marker.queue_free()
		aim_marker = null
	
	Logger.info("TankController cleaned up")