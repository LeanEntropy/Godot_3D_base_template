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
	spring_arm = player.get_node_or_null("Turret/SpringArm3D")
	if spring_arm:
		camera = spring_arm.get_node_or_null("TankCamera")
		if not camera:
			# Fallback: try "Camera3D" as generic name
			camera = spring_arm.get_node_or_null("Camera3D")

		if camera:
			Logger.info("TankController: Found camera at Turret/SpringArm3D/TankCamera")
		else:
			Logger.error("TankController: Camera not found under SpringArm3D!")
			return
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
	
	# Shooting - DISABLED (ShootingComponent handles all shooting now)
	# if event is InputEventMouseButton:
	# 	Logger.info("Mouse button event: " + str(event.button_index) + " pressed: " + str(event.pressed))
	# 	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
	# 		Logger.info("Left click detected, calling shoot")
	# 		_shoot_projectile()
	
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
	
	# Hull rotation (A/D keys) - negate to fix reversed controls
	player.rotate_y(-turn_input * hull_turn_speed * delta)
	
	# Movement (W/S keys) - always relative to hull direction
	var move_direction: Vector3 = -player.transform.basis.z * forward_input
	
	player.velocity.x = move_direction.x * movement_speed
	player.velocity.z = move_direction.z * movement_speed
	
	player.move_and_slide()

# OLD SHOOTING SYSTEM - REMOVED
# ShootingComponent now handles all shooting for tank mode
# The old system had a bug where projectiles wouldn't explode (velocity check prevented destruction)

func _calculate_movement_direction() -> Vector3:
	return Vector3.ZERO

func cleanup() -> void:
	"""Cleanup"""
	is_active = false
	
	if crosshair_ui and is_instance_valid(crosshair_ui):
		crosshair_ui.queue_free()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	Logger.info("TankController cleaned up")
