extends Node
# Tank Controller - Proper tank combat with turret-controlled camera
#
# Controls:
# - W/S: Forward/backward movement
# - A/D: Hull rotation (turn tank body)
# - Mouse: Aim turret (camera follows turret)
# - Left Click: Fire projectile
#
# Camera follows turret rotation for aiming

const TankProjectileScene = preload("res://assets/tank_projectile.tscn")

# Player references
var player: CharacterBody3D
var camera: Camera3D
var spring_arm: SpringArm3D
var turret: Node3D
var barrel_tip: Node3D
var barrel_pivot: Node3D  # For vertical barrel rotation

# Visual elements
var player_mesh: MeshInstance3D
var tank_hull: Node3D

# Configuration
var mouse_sensitivity: float = 0.002
var movement_speed: float = 5.0
var gravity: float = 9.8
var fire_rate: float = 0.5
var projectile_speed: float = 50.0
var hull_turn_speed: float = 2.0

# State
var is_active: bool = false
var can_shoot: bool = true
var camera_pitch: float = 0.0
var turret_yaw: float = 0.0
var barrel_pitch: float = 0.0
var barrel_pitch_min: float = -10.0  # Can aim down 10°
var barrel_pitch_max: float = 70.0   # Can aim up 70°

# UI
var crosshair_ui: Control = null

func initialize(player_node: CharacterBody3D) -> void:
	Logger.info("TankController initializing...")
	
	if player_node == null:
		Logger.error("TankController: Player node is null!")
		return
	
	player = player_node
	is_active = true
	
	# Get nodes
	turret = player.get_node("Turret")
	player_mesh = player.get_node("PlayerMesh")
	tank_hull = player.get_node("TankHull")
	
	# Setup camera on turret (camera follows turret rotation)
	if player.has_node("Turret/SpringArm3D"):
		spring_arm = player.get_node("Turret/SpringArm3D")
		camera = spring_arm.get_node("Camera3D")
		
		
	else:
		Logger.error("TankController: Missing SpringArm3D under Turret!")
		return
	
	# Setup barrel pivot for elevation
	if player.has_node("Turret/BarrelPivot"):
		barrel_pivot = player.get_node("Turret/BarrelPivot")
		Logger.info("Found existing BarrelPivot")
	else:
		Logger.warning("No BarrelPivot found - creating one")
		barrel_pivot = Node3D.new()
		barrel_pivot.name = "BarrelPivot"
		turret.add_child(barrel_pivot)
		
		# Move barrel under pivot
		var barrel_to_move = player.get_node("Turret/TankGunBarrel")
		if barrel_to_move:
			barrel_to_move.get_parent().remove_child(barrel_to_move)
			barrel_pivot.add_child(barrel_to_move)
			barrel_to_move.position = Vector3(0, 0, 0)  # Reset position
		barrel_pivot.position = Vector3(0, 0.3, 0)  # Adjust height
	
	# Get or create barrel tip - AUTO-CALCULATED from mesh
	var barrel = player.get_node_or_null("Turret/BarrelPivot/TankGunBarrel")
	if not barrel:
		barrel = player.get_node_or_null("Turret/TankGunBarrel")
	
	if barrel:
		# Find the barrel mesh to measure its actual length
		var barrel_mesh_instance: MeshInstance3D = null
		if barrel is MeshInstance3D:
			barrel_mesh_instance = barrel
		else:
			for child in barrel.get_children():
				if child is MeshInstance3D:
					barrel_mesh_instance = child
					break
		
		var barrel_tip_z: float = -2.0  # Default fallback
		
		if barrel_mesh_instance and barrel_mesh_instance.mesh:
			# Get mesh bounding box in local space
			var mesh_aabb = barrel_mesh_instance.mesh.get_aabb()
			
			# Account for mesh instance's local transform if it's a child
			var mesh_local_pos = Vector3.ZERO
			if barrel_mesh_instance != barrel:
				mesh_local_pos = barrel_mesh_instance.position
			
			# Calculate tip position: mesh position + mesh extent in -Z direction
			barrel_tip_z = mesh_local_pos.z + mesh_aabb.position.z - mesh_aabb.size.z / 2.0
			
			Logger.info("=== AUTO BARREL TIP CALCULATION ===")
			Logger.info("Barrel node: " + barrel.name)
			Logger.info("Barrel mesh found: " + barrel_mesh_instance.name)
			Logger.info("Barrel mesh AABB: " + str(mesh_aabb))
			Logger.info("Barrel mesh size: " + str(mesh_aabb.size))
			Logger.info("Barrel mesh local position: " + str(mesh_local_pos))
			Logger.info("Calculated barrel tip Z: " + str(barrel_tip_z))
			Logger.info("===================================")
		else:
			Logger.warning("No barrel mesh found - using default tip position")
		
		# Get or create BarrelTip node
		if barrel.has_node("BarrelTip"):
			barrel_tip = barrel.get_node("BarrelTip")
			Logger.info("Found existing BarrelTip - repositioning")
		else:
			barrel_tip = Node3D.new()
			barrel_tip.name = "BarrelTip"
			barrel.add_child(barrel_tip)
			Logger.info("Created new BarrelTip")
		
		# Position at calculated tip
		barrel_tip.position = Vector3(0, 0, barrel_tip_z)
		Logger.info("BarrelTip positioned at: " + str(barrel_tip.position))
	else:
		Logger.error("Could not find barrel node!")
	
	# Load config
	movement_speed = GameConfig.speed
	gravity = GameConfig.gravity
	hull_turn_speed = GameConfig.hull_turn_speed
	mouse_sensitivity = GameConfig.mouse_sensitivity
	
	var config = ConfigFile.new()
	config.load("res://game_config.cfg")
	var fire_cooldown_ms = config.get_value("tank", "fire_cooldown_ms", 500)
	fire_rate = 1000.0 / fire_cooldown_ms  # Convert ms to shots per second
	projectile_speed = config.get_value("tank", "projectile_speed", 50.0)
	barrel_pitch_min = config.get_value("tank", "barrel_pitch_min", -10.0)
	barrel_pitch_max = config.get_value("tank", "barrel_pitch_max", 70.0)
	
	# Ensure player doesn't collide with its own projectiles
	player.collision_layer = 1  # Player on layer 1
	player.collision_mask = 1   # Player only collides with layer 1
	
	# Camera setup - use scene file values
	camera.current = true
	Logger.info("Using scene camera settings - SpringArm length: " + str(spring_arm.spring_length) + ", position: " + str(spring_arm.position) + ", FOV: " + str(camera.fov))
	
	# Reset rotations
	turret.rotation = Vector3.ZERO
	camera_pitch = -10.0
	turret_yaw = 0.0
	
	# Visuals
	player_mesh.hide()
	tank_hull.show()
	turret.show()  # Show turret node (includes all turret components and barrel)
	
	# Hide selection ring in tank mode
	var selection_ring = player.get_node_or_null("SelectionRing")
	if selection_ring:
		selection_ring.hide()
	
	# Create simple crosshair (deferred)
	call_deferred("_create_crosshair")
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	
	Logger.info("TankController initialized")

func _create_crosshair() -> void:
	"""Create simple crosshair UI"""
	Logger.info("Creating crosshair UI...")
	
	crosshair_ui = Control.new()
	crosshair_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_ui.z_index = 100  # Ensure it's on top
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair_ui.add_child(center)
	
	var label = Label.new()
	label.text = "+"
	label.add_theme_font_size_override("font_size", 48)  # Bigger
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)  # Thicker outline
	center.add_child(label)
	
	# Add to scene
	get_tree().root.add_child(crosshair_ui)
	
	Logger.info("Crosshair created and added to scene tree")
	Logger.info("Crosshair visible: " + str(crosshair_ui.visible))
	Logger.info("Crosshair z_index: " + str(crosshair_ui.z_index))

func handle_input(event: InputEvent) -> void:
	if not is_active:
		return
	
	# Mouse look - rotates turret and barrel
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Horizontal: rotate turret (Y axis)
		turret_yaw -= event.relative.x * mouse_sensitivity
		turret.rotation.y = turret_yaw
		
		# Vertical: pitch barrel AND camera together
		var pitch_delta = -event.relative.y * mouse_sensitivity
		
		# Update barrel pitch
		barrel_pitch += pitch_delta
		barrel_pitch = clamp(barrel_pitch, deg_to_rad(barrel_pitch_min), deg_to_rad(barrel_pitch_max))
		
		if barrel_pivot:
			barrel_pivot.rotation.x = barrel_pitch
		
		# Camera follows barrel pitch (but with different limits)
		camera_pitch = rad_to_deg(barrel_pitch)
		camera_pitch = clamp(camera_pitch, -15.0, 60.0)  # Camera doesn't look as extreme
		camera.rotation_degrees.x = camera_pitch
	
	# Shooting - ADD DEBUG
	if event is InputEventMouseButton:
		Logger.info("Mouse button event: " + str(event.button_index) + " pressed: " + str(event.pressed))
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Logger.info("Left click detected, calling shoot")
			_shoot_projectile()
	
	# Release mouse on ESC
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# MINIMAL MAGENTA SPHERE TEST - Press T key
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		Logger.info("Creating MINIMAL MAGENTA SPHERE TEST")
		_create_minimal_magenta_sphere_test()

func handle_physics(delta: float) -> void:
	if not is_active:
		return
	
	# Gravity
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	
	# Input
	var forward_input: float = Input.get_action_strength("forward") - Input.get_action_strength("backward")
	var turn_input: float = Input.get_action_strength("right") - Input.get_action_strength("left")
	
	# Hull rotation (A/D keys) - negate to fix reversed controls
	player.rotate_y(-turn_input * hull_turn_speed * delta)
	
	# Movement (W/S keys) - always relative to hull direction
	var move_direction: Vector3 = -player.transform.basis.z * forward_input
	
	player.velocity.x = move_direction.x * movement_speed
	player.velocity.z = move_direction.z * movement_speed
	
	player.move_and_slide()

func _shoot_projectile() -> void:
	"""Fire projectile - DIRECT NODE CREATION WITH EXTREME DIAGNOSTICS"""
	if not can_shoot:
		Logger.warning("Can't shoot - cooldown active")
		return
	
	if barrel_tip == null:
		Logger.error("No barrel tip!")
		return
	
	Logger.info("Barrel tip position: " + str(barrel_tip.global_position))
	
	# Create RigidBody3D projectile directly
	var projectile = RigidBody3D.new()
	projectile.name = "TankProjectile"
	projectile.gravity_scale = 0.15  # Reduced gravity for proper arc
	projectile.contact_monitor = true
	projectile.max_contacts_reported = 4
	projectile.collision_layer = 2  # Projectile on layer 2
	projectile.collision_mask = 1   # Only collides with layer 1 (environment)
	
	# Add CollisionShape3D
	var collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.5
	collision.shape = sphere_shape
	projectile.add_child(collision)
	
	# Add MeshInstance3D with visible material
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	mesh_instance.mesh = sphere_mesh
	mesh_instance.name = "ProjectileMesh"
	projectile.add_child(mesh_instance)
	
	# Create black material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.BLACK
	material.emission_enabled = false  # No glow for black
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.set_surface_override_material(0, material)
	
	# Add subtle white light
	var light = OmniLight3D.new()
	light.light_color = Color.WHITE
	light.light_energy = 5.0  # Subtle light
	light.omni_range = 10.0
	light.name = "ProjectileLight"
	projectile.add_child(light)
	
	# Screen-center raycast to find where crosshair is aiming
	var viewport = get_viewport()
	var screen_center = viewport.get_visible_rect().size / 2
	var ray_origin = camera.project_ray_origin(screen_center)
	var ray_direction = camera.project_ray_normal(screen_center)
	var ray_length = 1000.0  # Max distance to check
	var aim_point = ray_origin + (ray_direction * ray_length)
	
	# Raycast to find actual hit point in world
	var space_state = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, aim_point)
	query.collision_mask = 1  # Only hit layer 1 (environment)
	query.exclude = [player]  # Don't hit the tank itself
	
	var result = space_state.intersect_ray(query)
	if result:
		aim_point = result.position
		Logger.info("Aim point from raycast: " + str(aim_point))
	else:
		Logger.info("No raycast hit - using far aim point")
	
	# Calculate fire direction from barrel to aim point
	var fire_direction: Vector3 = (aim_point - barrel_tip.global_position).normalized()
	
	# Spawn slightly in front of barrel tip
	var spawn_pos: Vector3 = barrel_tip.global_position + (fire_direction * 0.5)
	Logger.info("Calculated spawn position: " + str(spawn_pos))
	Logger.info("Fire direction: " + str(fire_direction))
	
	# Add to scene
	get_tree().root.add_child(projectile)
	projectile.global_position = spawn_pos
	
	# Prevent projectile from colliding with the tank that fired it
	projectile.add_collision_exception_with(player)
	
	# Launch with velocity
	projectile.linear_velocity = fire_direction * projectile_speed
	
	# Connect collision signal for hit effects
	projectile.body_entered.connect(func(body): _on_projectile_hit(projectile, body))
	
	# Auto-cleanup after 10 seconds
	await get_tree().create_timer(10.0).timeout
	if is_instance_valid(projectile):
		projectile.queue_free()
	
	# Cooldown
	can_shoot = false
	var cooldown_seconds = 1.0 / fire_rate
	await get_tree().create_timer(cooldown_seconds).timeout
	can_shoot = true

func _create_test_sphere(position: Vector3, direction: Vector3) -> void:
	"""Create a simple test sphere to verify projectile visibility"""
	var test_sphere = CSGSphere3D.new()
	test_sphere.radius = 0.5
	test_sphere.material = StandardMaterial3D.new()
	test_sphere.material.albedo_color = Color.RED
	test_sphere.material.emission_enabled = true
	test_sphere.material.emission = Color.RED
	test_sphere.material.emission_energy_multiplier = 3.0
	
	get_tree().root.add_child(test_sphere)
	test_sphere.global_position = position
	
	Logger.info("TEST projectile created at: " + str(position))
	
	# Move the test sphere
	var tween = create_tween()
	tween.tween_property(test_sphere, "global_position", position + direction * 20.0, 2.0)
	tween.tween_callback(test_sphere.queue_free)

func _create_minimal_magenta_sphere_test() -> void:
	"""MINIMAL TEST: Create GIANT magenta sphere 15m in front of camera"""
	Logger.info("=== MINIMAL MAGENTA SPHERE TEST START ===")
	
	if camera == null:
		Logger.error("Camera is null!")
		return
	
	# Calculate position 15m in front of camera
	var camera_forward = -camera.global_transform.basis.z
	var test_position = camera.global_position + (camera_forward * 15.0)
	
	Logger.info("Camera position: " + str(camera.global_position))
	Logger.info("Camera forward: " + str(camera_forward))
	Logger.info("Test sphere position: " + str(test_position))
	
	# Create GIANT sphere using MeshInstance3D (simplest approach)
	var sphere_node = MeshInstance3D.new()
	sphere_node.name = "MINIMAL_MAGENTA_TEST_SPHERE"
	
	# Create giant sphere mesh
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 5.0  # GIANT 5 meter radius
	sphere_mesh.height = 10.0
	sphere_node.mesh = sphere_mesh
	
	# Create EXTREME magenta material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.MAGENTA
	material.emission_enabled = true
	material.emission = Color.MAGENTA
	material.emission_energy_multiplier = 50.0  # EXTREME brightness
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.flags_unshaded = true
	sphere_node.set_surface_override_material(0, material)
	
	# Add to scene
	get_tree().root.add_child(sphere_node)
	sphere_node.global_position = test_position
	
	Logger.info("Created GIANT magenta sphere at: " + str(sphere_node.global_position))
	Logger.info("Sphere visible: " + str(sphere_node.visible))
	Logger.info("Sphere parent: " + str(sphere_node.get_parent().name))
	Logger.info("Material emission: " + str(material.emission_energy_multiplier))
	Logger.info("Distance from camera: " + str(camera.global_position.distance_to(sphere_node.global_position)))
	
	# Auto cleanup after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(sphere_node):
		Logger.info("Cleaning up test sphere")
		sphere_node.queue_free()
	
	Logger.info("=== MINIMAL MAGENTA SPHERE TEST END ===")


func _on_projectile_hit(projectile: RigidBody3D, body: Node) -> void:
	"""Handle projectile collision - create hit effects directly"""
	
	# Ignore if projectile is moving too slow (stuck)
	if projectile.linear_velocity.length() < 5.0:
		return
	
	Logger.info("Projectile hit: " + body.name + " at " + str(projectile.global_position))
	
	# Apply impact force if hit a RigidBody3D
	if body is RigidBody3D:
		# Use horizontal velocity only (ignore Y gravity effect)
		var horizontal_velocity = projectile.linear_velocity
		horizontal_velocity.y = abs(horizontal_velocity.y) * 0.3  # Small upward lift
		
		var impact_force = horizontal_velocity * 3.0  # Triple for strong push
		var impact_point = projectile.global_position
		
		# Apply force at contact point (creates realistic tumbling)
		body.apply_impulse(impact_force, impact_point - body.global_position)
		Logger.info("Applied impact force: " + str(impact_force) + " to " + body.name)
	
	var hit_position = projectile.global_position
	
	# Create hit particles directly
	var particles = GPUParticles3D.new()
	particles.name = "HitParticles"
	particles.emitting = false
	particles.amount = 15
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.3
	
	# Create ParticleProcessMaterial
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.initial_velocity_min = 3.0
	particle_material.initial_velocity_max = 8.0
	particle_material.gravity = Vector3(0, -9.8, 0)
	particle_material.scale_min = 0.2
	particle_material.scale_max = 0.2
	particles.process_material = particle_material
	
	# Create particle mesh
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.1
	particles.draw_pass_1 = particle_mesh
	
	# Add to scene at hit position
	get_tree().root.add_child(particles)
	particles.global_position = hit_position
	particles.emitting = true
	
	# Create hit light
	var hit_light = OmniLight3D.new()
	hit_light.light_color = Color.ORANGE
	hit_light.light_energy = 10.0
	hit_light.omni_range = 5.0
	get_tree().root.add_child(hit_light)
	hit_light.global_position = hit_position
	
	# Fade out light over 0.2 seconds
	var tween = create_tween()
	tween.tween_property(hit_light, "light_energy", 0.0, 0.2)
	tween.tween_callback(hit_light.queue_free)
	
	# Cleanup particles after 1 second
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()
	
	# Destroy projectile
	if is_instance_valid(projectile):
		projectile.queue_free()

func _calculate_movement_direction() -> Vector3:
	return Vector3.ZERO

func cleanup() -> void:
	"""Cleanup"""
	is_active = false
	
	if crosshair_ui and is_instance_valid(crosshair_ui):
		crosshair_ui.queue_free()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	Logger.info("TankController cleaned up")
