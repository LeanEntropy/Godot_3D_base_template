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

const TankProjectile = preload("res://assets/tank_projectile.tscn")

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
		var barrel = player.get_node("Turret/TankGunBarrel")
		if barrel:
			barrel.get_parent().remove_child(barrel)
			barrel_pivot.add_child(barrel)
			barrel.position = Vector3(0, 0, 0)  # Reset position
		barrel_pivot.position = Vector3(0, 0.3, 0)  # Adjust height
	
	# Get or create barrel tip
	if player.has_node("Turret/BarrelPivot/TankGunBarrel/BarrelTip"):
		barrel_tip = player.get_node("Turret/BarrelPivot/TankGunBarrel/BarrelTip")
	elif player.has_node("Turret/TankGunBarrel/BarrelTip"):
		barrel_tip = player.get_node("Turret/TankGunBarrel/BarrelTip")
	else:
		var barrel = player.get_node_or_null("Turret/BarrelPivot/TankGunBarrel")
		if not barrel:
			barrel = player.get_node_or_null("Turret/TankGunBarrel")
		if barrel:
			barrel_tip = Node3D.new()
			barrel_tip.name = "BarrelTip"
			barrel.add_child(barrel_tip)
			barrel_tip.position = Vector3(0, 0, -2.0)
	
	# Load config
	movement_speed = GameConfig.speed
	gravity = GameConfig.gravity
	hull_turn_speed = GameConfig.hull_turn_speed
	mouse_sensitivity = GameConfig.mouse_sensitivity
	
	var config = ConfigFile.new()
	config.load("res://game_config.cfg")
	fire_rate = config.get_value("tank", "fire_rate", 0.5)
	projectile_speed = config.get_value("tank", "projectile_speed", 50.0)
	barrel_pitch_min = config.get_value("tank", "barrel_pitch_min", -10.0)
	barrel_pitch_max = config.get_value("tank", "barrel_pitch_max", 70.0)
	
	# Camera setup
	spring_arm.spring_length = 8.0
	spring_arm.position = Vector3(0, 1.5, 0)
	camera.fov = 75.0
	
	# Reset rotations
	turret.rotation = Vector3.ZERO
	camera_pitch = -10.0
	turret_yaw = 0.0
	
	# Visuals
	player_mesh.hide()
	tank_hull.show()
	
	# Create simple crosshair (deferred)
	call_deferred("_create_crosshair")
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Camera debug
	Logger.info("=== CAMERA DEBUG ===")
	Logger.info("Camera exists: " + str(camera != null))
	if camera:
		Logger.info("Camera position: " + str(camera.global_position))
		Logger.info("Camera rotation: " + str(camera.global_rotation_degrees))
		Logger.info("Camera current: " + str(camera.current))
		Logger.info("Camera cull_mask: " + str(camera.cull_mask))
		Logger.info("Camera near: " + str(camera.near))
		Logger.info("Camera far: " + str(camera.far))
	
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

func handle_physics(delta: float) -> void:
	if not is_active:
		return
	
	# Gravity
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	
	# Input
	var forward_input: float = Input.get_action_strength("forward") - Input.get_action_strength("backward")
	var turn_input: float = Input.get_action_strength("right") - Input.get_action_strength("left")
	
	# Hull rotation (A/D keys)
	player.rotate_y(turn_input * hull_turn_speed * delta)
	
	# Movement (W/S keys) - always relative to hull direction
	var move_direction: Vector3 = -player.transform.basis.z * forward_input
	
	player.velocity.x = move_direction.x * movement_speed
	player.velocity.z = move_direction.z * movement_speed
	
	player.move_and_slide()

func _shoot_projectile() -> void:
	"""Fire real tank projectile"""
	if not can_shoot:
		return
	
	if barrel_tip == null:
		Logger.error("No barrel tip!")
		return
	
	Logger.info("Firing real projectile...")
	
	# Create real projectile from scene
	var projectile = TankProjectile.instantiate()
	get_tree().root.add_child(projectile)
	
	# Position ahead of barrel
	var barrel_forward: Vector3 = -barrel_tip.global_transform.basis.z
	var spawn_pos: Vector3 = barrel_tip.global_position + (barrel_forward * 2.0)
	projectile.global_position = spawn_pos
	
	# Launch
	projectile.launch(barrel_forward, projectile_speed)
	
	Logger.info("Projectile spawned at: " + str(spawn_pos))
	
	# Cooldown
	can_shoot = false
	await get_tree().create_timer(1.0 / fire_rate).timeout
	can_shoot = true

func _create_test_sphere(position: Vector3, direction: Vector3) -> void:
	"""Create a simple test sphere to verify projectile visibility"""
	var test_sphere = CSGSphere3D.new()
	test_sphere.radius = 0.5
	test_sphere.material = StandardMaterial3D.new()
	test_sphere.material.albedo_color = Color.RED
	test_sphere.material.emission_enabled = true
	test_sphere.material.emission = Color.RED
	test_sphere.material.emission_energy = 3.0
	
	get_tree().root.add_child(test_sphere)
	test_sphere.global_position = position
	
	Logger.info("TEST projectile created at: " + str(position))
	
	# Move the test sphere
	var tween = create_tween()
	tween.tween_property(test_sphere, "global_position", position + direction * 20.0, 2.0)
	tween.tween_callback(test_sphere.queue_free)

func _print_scene_tree(node: Node, indent: int) -> void:
	var spaces = ""
	for i in range(indent):
		spaces += "  "
	
	var info = spaces + node.name + " (" + node.get_class() + ")"
	
	if node is MeshInstance3D:
		var mesh_inst = node as MeshInstance3D
		info += " - Mesh: " + str(mesh_inst.mesh != null)
		info += " - Visible: " + str(mesh_inst.visible)
		if mesh_inst.mesh:
			info += " - Material: " + str(mesh_inst.get_surface_override_material(0) != null)
	
	if node is RigidBody3D:
		var rb = node as RigidBody3D
		info += " - Pos: " + str(rb.global_position)
		info += " - Vel: " + str(rb.linear_velocity)
	
	Logger.info(info)
	
	for child in node.get_children():
		_print_scene_tree(child, indent + 1)

func _calculate_movement_direction() -> Vector3:
	return Vector3.ZERO

func cleanup() -> void:
	"""Cleanup"""
	is_active = false
	
	if crosshair_ui and is_instance_valid(crosshair_ui):
		crosshair_ui.queue_free()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	Logger.info("TankController cleaned up")
