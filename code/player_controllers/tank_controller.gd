extends Node

var player
var spring_arm
var camera
var player_mesh
var selection_ring
var turret
var turret_mesh
var tank_hull
var tank_gun_barrel
var tank_model
var logical_turret

# Turret control variables (inspired by Unity Turret_Control_CS)
var turret_turn_rate = 0.0
var previous_turret_turn_rate = 0.0
var is_turret_turning = false

# Cannon control variables (inspired by Unity Cannon_Control_CS)
var cannon_turn_rate = 0.0
var previous_cannon_turn_rate = 0.0
var is_cannon_turning = false
var cannon_angle = 0.0
var initial_cannon_rotation = Vector3.ZERO

# Recoil system variables (inspired by Unity Barrel_Control_CS)
var is_recoiling = false
var barrel_initial_position = Vector3.ZERO
var recoil_tween: Tween

# Camera obstacle avoidance variables (inspired by Unity Camera_Avoid_Obstacle_CS)
var current_camera_distance = 3.0
var target_camera_distance = 3.0
var is_avoiding_obstacle = false
var hitting_time = 0.0
var stored_distance = 3.0


func initialize(player_node):
	player = player_node
	
	# Get tank model components from the TankModel instance
	tank_model = player.get_node("TankModel")
	turret = tank_model.get_node("Turret")
	turret_mesh = turret.get_node("TurretMesh")
	tank_hull = tank_model.get_node("TankHull")
	tank_gun_barrel = turret.get_node("TankGunBarrel")
	player_mesh = player.get_node("PlayerMesh")
	selection_ring = player.get_node("SelectionRing")
	
	# Create a camera attached to the turret for tank view
	create_tank_camera()
	
	logical_turret = Node3D.new() # Create a new Node3D for logical turret rotation
	player.add_child(logical_turret)

	# Hide all visuals except the tank model
	if player_mesh: player_mesh.hide()
	if selection_ring: selection_ring.hide()
	if turret_mesh: turret_mesh.show()
	if tank_hull: tank_hull.show()
	if tank_gun_barrel: tank_gun_barrel.show()
	if tank_model: tank_model.show()
	
	# Store initial barrel position and rotation for recoil and cannon control
	if tank_gun_barrel:
		barrel_initial_position = tank_gun_barrel.position
		# The gun barrel starts pointing upward (90 degrees on X-axis)
		# We need to correct this to point forward (horizontal)
		initial_cannon_rotation = tank_gun_barrel.rotation
		initial_cannon_rotation.x -= PI/2  # Subtract 90 degrees to make it horizontal
		tank_gun_barrel.rotation = initial_cannon_rotation
		# Set initial cannon angle to 0 (horizontal relative to the tank's forward direction)
		cannon_angle = 0.0
		print("Initial gun barrel rotation: ", initial_cannon_rotation)
		print("Initial gun barrel transform: ", tank_gun_barrel.transform)

func create_tank_camera():
	# Create a SpringArm3D attached to the turret for camera positioning
	spring_arm = SpringArm3D.new()
	spring_arm.name = "TankSpringArm"
	turret.add_child(spring_arm)
	
	# Position the spring arm behind and above the turret
	spring_arm.position = Vector3(0, 0.5, 2.0)  # Behind the turret
	spring_arm.spring_length = 3.0
	spring_arm.collision_mask = 1  # Only collide with ground/objects
	
	# Create the camera
	camera = Camera3D.new()
	camera.name = "TankCamera"
	spring_arm.add_child(camera)
	
	# Set camera properties for tank view
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = GameConfig.default_fov
	
	# Disable the main scene camera first
	var main_camera = player.get_node("Turret/SpringArm3D/Camera3D")
	if main_camera:
		main_camera.current = false
		print("Main camera disabled for tank mode")
	
	# Make this camera the current camera
	camera.current = true
	print("Tank camera enabled: ", camera)
	
	# Update shooting manager with the tank camera
	var shooting_manager = player.get_node("../ShootingManager")
	if shooting_manager:
		shooting_manager.camera = camera
		print("Tank camera set for shooting manager: ", camera)

func _ready():
	pass

func cleanup():
	# Re-enable the main scene camera
	var main_camera = player.get_node("Turret/SpringArm3D/Camera3D")
	if main_camera:
		main_camera.current = true
		print("Main camera re-enabled after tank mode")
	
	# Remove the tank camera when switching away from tank mode
	if spring_arm and is_instance_valid(spring_arm):
		spring_arm.queue_free()
		spring_arm = null
		camera = null

func handle_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Horizontal mouse movement rotates the turret
		var turret_input = -event.relative.x * GameConfig.turret_turn_speed
		handle_turret_rotation(turret_input)
		
		# Vertical mouse movement controls cannon elevation
		var cannon_input = -event.relative.y * GameConfig.turret_turn_speed * 10.0  # Increase sensitivity
		handle_cannon_elevation(cannon_input)

func handle_turret_rotation(input_value):
	# Based on Unity Turret_Control_CS Manual_Turn()
	if input_value != 0.0:
		is_turret_turning = true
	
	if not is_turret_turning:
		return
	
	# Calculate turn rate with acceleration/deceleration
	var target_turn_rate = input_value
	if target_turn_rate != 0.0:
		turret_turn_rate = move_toward(turret_turn_rate, target_turn_rate, 1.0 / GameConfig.turret_acceleration_time * get_physics_process_delta_time())
	else:
		turret_turn_rate = move_toward(turret_turn_rate, target_turn_rate, 1.0 / GameConfig.turret_deceleration_time * get_physics_process_delta_time())
	
	if turret_turn_rate == 0.0:
		is_turret_turning = false
	
	# Rotate turret
	var rotation_amount = GameConfig.turret_rotation_speed * turret_turn_rate * get_physics_process_delta_time()
	logical_turret.rotate_y(rotation_amount)
	turret.rotate_y(rotation_amount)

func handle_cannon_elevation(input_value):
	# Based on Unity Cannon_Control_CS Manual_Turn()
	if input_value != 0.0:
		is_cannon_turning = true
		print("Cannon input received: ", input_value)
	
	if not is_cannon_turning:
		return
	
	# Calculate turn rate with acceleration/deceleration
	var target_turn_rate = input_value
	if target_turn_rate != 0.0:
		cannon_turn_rate = move_toward(cannon_turn_rate, target_turn_rate, 1.0 / GameConfig.cannon_acceleration_time * get_physics_process_delta_time())
	else:
		cannon_turn_rate = move_toward(cannon_turn_rate, target_turn_rate, 1.0 / GameConfig.cannon_deceleration_time * get_physics_process_delta_time())
	
	if cannon_turn_rate == 0.0:
		is_cannon_turning = false
	
	# Rotate cannon with angle limits
	var rotation_amount = GameConfig.cannon_rotation_speed * cannon_turn_rate * get_physics_process_delta_time()
	cannon_angle += rotation_amount
	cannon_angle = clamp(cannon_angle, -GameConfig.max_elevation, GameConfig.max_depression)
	
	# Apply rotation to the gun barrel
	# For tank gun elevation, we rotate around the X-axis
	if tank_gun_barrel:
		# Reset to original rotation and add elevation around X-axis
		tank_gun_barrel.rotation = initial_cannon_rotation
		tank_gun_barrel.rotate_x(deg_to_rad(cannon_angle))
		print("Cannon angle: ", cannon_angle, " Gun barrel rotation: ", tank_gun_barrel.rotation)

func start_recoil():
	# Based on Unity Barrel_Control_CS Fire_Linkage()
	if is_recoiling:
		return
	
	is_recoiling = true
	
	# Stop any existing tween
	if recoil_tween:
		recoil_tween.kill()
	
	recoil_tween = create_tween()
	recoil_tween.set_parallel(true)
	
	# Move barrel backward
	var recoil_position = barrel_initial_position + Vector3(0, 0, -GameConfig.recoil_length)
	recoil_tween.tween_property(tank_gun_barrel, "position", recoil_position, GameConfig.recoil_time)
	
	# Return barrel to initial position
	recoil_tween.tween_delay(GameConfig.recoil_time)
	recoil_tween.tween_property(tank_gun_barrel, "position", barrel_initial_position, GameConfig.return_time)
	
	# Also restore the current cannon angle during recoil
	var current_rotation = initial_cannon_rotation
	current_rotation.x += deg_to_rad(cannon_angle)
	recoil_tween.tween_property(tank_gun_barrel, "rotation", current_rotation, GameConfig.recoil_time)
	
	# Reset recoil flag when done
	recoil_tween.tween_callback(func(): is_recoiling = false)

func handle_physics(delta):
	# Tank gravity and hovering system
	var ground_distance = 0.0
	var is_grounded = false
	
	# Cast ray downward to detect ground
	var space_state = player.get_world_3d().direct_space_state
	var from = player.global_position
	var to = player.global_position + Vector3(0, -10, 0)  # Cast 10 units down
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player, tank_model]  # Exclude tank from raycast
	var result = space_state.intersect_ray(query)
	
	if result:
		ground_distance = player.global_position.y - result.position.y
		is_grounded = ground_distance < GameConfig.hover_height + 0.5  # Within hover range
	
	# Apply gravity and hovering
	if is_grounded:
		# Hover above ground
		var target_y = result.position.y + GameConfig.hover_height
		var current_y = player.global_position.y
		var height_error = target_y - current_y
		
		# Apply upward force to maintain hover height
		player.velocity.y += height_error * GameConfig.hover_force * delta
		player.velocity.y = clamp(player.velocity.y, GameConfig.min_vertical_velocity, GameConfig.max_vertical_velocity)
	else:
		# Apply gravity when not grounded
		player.velocity.y -= GameConfig.gravity * delta

	# Hull Rotation
	var turn_input = Input.get_action_strength("left") - Input.get_action_strength("right")
	player.rotate_y(turn_input * GameConfig.hull_turn_speed * delta)

	# Hull Movement
	var target_velocity = Vector3.ZERO
	if Input.is_action_pressed("forward"):
		target_velocity = -player.transform.basis.z * GameConfig.forward_speed
	elif Input.is_action_pressed("backward"):
		target_velocity = player.transform.basis.z * GameConfig.reverse_speed

	player.velocity.x = lerp(player.velocity.x, target_velocity.x, GameConfig.lerp_weight * delta)
	player.velocity.z = lerp(player.velocity.z, target_velocity.z, GameConfig.lerp_weight * delta)
	
	player.move_and_slide()
	
	# Camera obstacle avoidance
	handle_camera_obstacle_avoidance(delta)

func handle_camera_obstacle_avoidance(delta):
	# Based on Unity Camera_Avoid_Obstacle_CS
	if not spring_arm or not camera:
		return
	
	# Cast ray from spring arm to camera
	var space_state = player.get_world_3d().direct_space_state
	var from = spring_arm.global_position
	var to = camera.global_position
	var direction = (to - from).normalized()
	var distance = from.distance_to(to) + 1.0
	
	var query = PhysicsRayQueryParameters3D.create(from, from + direction * distance)
	query.exclude = [player, tank_model]  # Exclude tank from raycast
	var result = space_state.intersect_ray(query)
	
	if result:
		# Hit an obstacle
		if not is_avoiding_obstacle:
			hitting_time += delta
			if hitting_time > GameConfig.camera_avoid_lag:
				# Start avoiding obstacle
				hitting_time = 0.0
				is_avoiding_obstacle = true
				stored_distance = target_camera_distance
				target_camera_distance = result.distance
				target_camera_distance = clamp(target_camera_distance, GameConfig.camera_avoid_min_dist, GameConfig.camera_avoid_max_dist)
		else:
			# Already avoiding, check for closer obstacle
			if result.distance < stored_distance:
				target_camera_distance = result.distance
				target_camera_distance = clamp(target_camera_distance, GameConfig.camera_avoid_min_dist, GameConfig.camera_avoid_max_dist)
	else:
		# No obstacle, return to stored position
		if is_avoiding_obstacle:
			is_avoiding_obstacle = false
			target_camera_distance = stored_distance
	
	# Move camera to target distance
	if current_camera_distance != target_camera_distance:
		current_camera_distance = move_toward(current_camera_distance, target_camera_distance, GameConfig.camera_avoid_move_speed * delta)
		spring_arm.spring_length = current_camera_distance
