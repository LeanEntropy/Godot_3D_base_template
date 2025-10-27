extends Node

const Projectile = preload("res://assets/projectile.tscn")

var player
var camera
var fire_timer = 0.0
var can_fire = true
var crosshair
var config

func initialize(player_node, camera_node):
	player = player_node
	camera = camera_node
	
	# Load config file once
	config = ConfigFile.new()
	config.load("res://game_config.cfg")
	
	# Get crosshair reference
	crosshair = get_node("../UILayer/Crosshair")
	update_crosshair_visibility()

func _ready():
	pass

func update_crosshair_visibility():
	if not crosshair:
		return
	
	# Get control mode from cached config
	var control_mode = config.get_value("global", "controller_mode", "first_person")
	
	var supported_modes = ["first_person", "third_person_follow", "over_the_shoulder", "top_down", "tank"]
	
	# Show crosshair only for supported modes and if enabled
	var should_show = config.get_value("shooting", "crosshair_enabled", true) and control_mode in supported_modes
	crosshair.visible = should_show

func update_crosshair_visibility_for_mode(control_mode):
	if not crosshair:
		return
	
	var supported_modes = ["first_person", "third_person_follow", "over_the_shoulder", "top_down", "tank"]
	
	# Show crosshair only for supported modes and if enabled
	var should_show = config.get_value("shooting", "crosshair_enabled", true) and control_mode in supported_modes
	crosshair.visible = should_show

func _process(delta):
	# Update fire timer
	if not can_fire:
		fire_timer += delta
		if fire_timer >= config.get_value("shooting", "fire_rate", 0.5):
			can_fire = true
			fire_timer = 0.0
	
	# Update aiming marker for tank mode
	var control_mode = config.get_value("global", "controller_mode", "first_person")
	if control_mode == "tank":
		update_tank_aiming_marker()
	
	# Handle shooting input
	if config.get_value("shooting", "shooting_enabled", true) and Input.is_action_just_pressed("shoot"):
		if can_fire:
			fire_projectile()

func handle_input(event):
	# This function is kept for compatibility but shooting is now handled in _process
	pass

func fire_projectile():
	if not can_fire:
		return
	
	# Play cannon fire sound
	AudioManager.play_3d_sound("cannon_fire", player.global_position)
	
	# Create projectile
	var projectile = Projectile.instantiate()
	player.get_parent().add_child(projectile)
	
	# Set projectile position and velocity based on control mode
	var control_mode = config.get_value("global", "controller_mode", "first_person")
	
	match control_mode:
		"first_person":
			fire_first_person(projectile)
		"third_person_follow":
			fire_third_person(projectile)
		"over_the_shoulder":
			fire_over_the_shoulder(projectile)
		"top_down":
			fire_top_down(projectile)
		"tank":
			fire_tank(projectile)
		_:
			# Unsupported modes - don't fire
			projectile.queue_free()
			return
	
	# Reset fire timer
	can_fire = false
	fire_timer = 0.0

func fire_first_person(projectile):
	# Fire from camera position directly forward
	projectile.global_position = camera.global_position
	var direction = -camera.global_transform.basis.z
	projectile.linear_velocity = direction * config.get_value("shooting", "flying_speed", 20.0)

func fire_third_person(projectile):
	# Fire from player position towards screen center
	projectile.global_position = player.global_position + Vector3(0, 1, 0)  # Slightly above player
	
	# Get screen center position
	var viewport = player.get_viewport()
	var screen_center = Vector2(viewport.size.x * 0.5, viewport.size.y * 0.5)
	
	# Raycast from camera to screen center to find target
	var ray_length = 1000
	var from = camera.project_ray_origin(screen_center)
	var to = from + camera.project_ray_normal(screen_center) * ray_length
	
	var space_state = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player]  # Exclude player from raycast
	var result = space_state.intersect_ray(query)
	
	var target_position
	if result:
		target_position = result.position
	else:
		# If no hit, fire forward from camera direction at a reasonable distance
		target_position = camera.global_position + (-camera.global_transform.basis.z * 50)
	
	var direction = (target_position - projectile.global_position).normalized()
	projectile.linear_velocity = direction * config.get_value("shooting", "flying_speed", 20.0)

func fire_over_the_shoulder(projectile):
	# Fire from player position towards screen center (similar to third person but with different positioning)
	projectile.global_position = player.global_position + Vector3(0, 1.2, 0)  # Slightly higher for over-the-shoulder
	
	# Get screen center position
	var viewport = player.get_viewport()
	var screen_center = Vector2(viewport.size.x * 0.5, viewport.size.y * 0.5)
	
	# Raycast from camera to screen center to find target
	var ray_length = 1000
	var from = camera.project_ray_origin(screen_center)
	var to = from + camera.project_ray_normal(screen_center) * ray_length
	
	var space_state = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player]  # Exclude player from raycast
	var result = space_state.intersect_ray(query)
	
	var target_position
	if result:
		target_position = result.position
	else:
		# If no hit, fire forward from camera direction at a reasonable distance
		target_position = camera.global_position + (-camera.global_transform.basis.z * 50)
	
	var direction = (target_position - projectile.global_position).normalized()
	projectile.linear_velocity = direction * config.get_value("shooting", "flying_speed", 20.0)

func fire_top_down(projectile):
	# Fire from player position towards mouse cursor on ground
	projectile.global_position = player.global_position + Vector3(0, 1, 0)
	
	# Get mouse position and raycast to ground
	var mouse_pos = player.get_viewport().get_mouse_position()
	var ray_length = 1000
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * ray_length
	
	var space_state = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player]  # Exclude player from raycast
	var result = space_state.intersect_ray(query)
	
	var target_position
	if result:
		target_position = result.position
	else:
		# If no hit, fire forward from player at a reasonable distance
		target_position = player.global_position + (-player.global_transform.basis.z * 50)
	
	var direction = (target_position - projectile.global_position).normalized()
	projectile.linear_velocity = direction * config.get_value("shooting", "flying_speed", 20.0)

func fire_tank(projectile):
	# Fire from tank turret barrel in the direction the gun barrel is pointing
	var tank_model = player.get_node("TankModel")
	var turret = tank_model.get_node("Turret")
	var gun_barrel = turret.get_node("TankGunBarrel")
	
	# Position projectile at the end of the barrel
	projectile.global_position = gun_barrel.global_position + (-gun_barrel.global_transform.basis.z * 1.0)
	
	# Fire in the direction the gun barrel is pointing (180 degrees opposite horizontally)
	var direction = -gun_barrel.global_transform.basis.z  # Tank gun barrel forward direction
	projectile.linear_velocity = direction * config.get_value("shooting", "flying_speed", 20.0)
	
	# Trigger recoil animation
	var player_controller = player.get_node("PlayerController")
	if player_controller and player_controller.current_controller and player_controller.current_controller.has_method("start_recoil"):
		player_controller.current_controller.start_recoil()

func update_tank_aiming_marker():
	# Based on Unity AimMarker_Control_CS Marker_Control()
	if not crosshair or not camera:
		return
	
	# Cast ray from camera to find target point
	var space_state = player.get_world_3d().direct_space_state
	var from = camera.global_position
	var to = camera.global_position + (-camera.global_transform.basis.z * 1000.0)
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player]  # Exclude player from raycast
	var result = space_state.intersect_ray(query)
	
	var target_position
	if result:
		target_position = result.position
	else:
		# If no hit, use a point far ahead
		target_position = camera.global_position + (-camera.global_transform.basis.z * 100.0)
	
	# Convert world position to screen position
	var screen_pos = camera.unproject_position(target_position)
	
	# Check if target is behind camera by checking if the point is in front of the camera
	var camera_to_target = target_position - camera.global_position
	var camera_forward = -camera.global_transform.basis.z
	var dot_product = camera_to_target.dot(camera_forward)
	
	if dot_product < 0.0:
		# Target is behind camera
		crosshair.visible = false
		return
	
	# Update crosshair position
	var viewport = player.get_viewport()
	var screen_center = Vector2(viewport.size.x * 0.5, viewport.size.y * 0.5)
	crosshair.position = screen_center
	crosshair.visible = true
