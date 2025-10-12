extends Node
# Free Camera Controller - RTS-style camera with click-to-select and move
#
# This controller provides RTS-style gameplay with the following features:
# - Camera: Free-moving camera controlled by WASD, independent of player
# - Movement: Click to select player, click to move (RTS pattern)
# - Input: Right-click and drag for camera look, mouse wheel zoom
#
# Required Player Scene Structure:
# - Player/Turret/SpringArm3D/Camera3D
# - Player/PlayerMesh (MeshInstance3D)
# - Player/SelectionRing (MeshInstance3D)
# - Player/TankHull (Node3D)
# - Player/Turret (Node3D)
#
# Configuration Parameters Used:
# - physics.camera_speed - Camera movement speed
# - physics.character_speed - Player movement speed
# - physics.gravity - Gravity force
# - physics.lerp_weight - Movement smoothing
# - physics.zoom_speed - Camera zoom speed
# - physics.min_zoom - Minimum camera distance
# - physics.max_zoom - Maximum camera distance
# - physics.default_zoom - Starting camera distance

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
var camera_speed: float
var character_speed: float
var gravity: float
var lerp_weight: float
var zoom_speed: float
var min_zoom: float
var max_zoom: float
var default_zoom: float

# Controller state
var is_active: bool = false
var is_player_selected: bool = false
var target_position: Vector3

func initialize(player_node: CharacterBody3D) -> void:
	Logger.info("FreeCameraController initializing...")
	
	# Validate player node
	if player_node == null:
		Logger.error("FreeCameraController: Player node is null!")
		return
	
	player = player_node
	is_active = true
	target_position = player.global_transform.origin
	
	# Get and validate node references
	if not player.has_node("Turret/SpringArm3D/Camera3D"):
		Logger.error("FreeCameraController: Missing Camera3D node!")
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
	camera_speed = GameConfig.camera_speed
	character_speed = GameConfig.character_speed
	gravity = GameConfig.gravity
	lerp_weight = GameConfig.lerp_weight
	zoom_speed = GameConfig.zoom_speed
	min_zoom = GameConfig.min_zoom
	max_zoom = GameConfig.max_zoom
	default_zoom = GameConfig.default_zoom
	
	# Setup camera for free camera mode
	spring_arm.spring_length = 15.0
	spring_arm.position = Vector3.ZERO
	spring_arm.top_level = true  # Camera independent of player rotation
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = default_zoom
	
	# Setup visuals (show player mesh, hide tank parts)
	if player_mesh: player_mesh.show()
	if selection_ring: selection_ring.hide()  # Show when selected
	if turret_mesh: turret_mesh.hide()
	if tank_hull: tank_hull.hide()
	if tank_gun_barrel: tank_gun_barrel.hide()
	
	Logger.info("FreeCameraController initialized successfully")

func _ready() -> void:
	pass

func handle_input(event: InputEvent) -> void:
	if not is_active:
		return
	
	# Mouse motion handling
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_motion(event)
	
	# Mouse button handling
	if event is InputEventMouseButton:
		_handle_mouse_button(event)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	spring_arm.rotate_y(-event.relative.x * GameConfig.mouse_sensitivity)
	spring_arm.rotate_x(-event.relative.y * GameConfig.mouse_sensitivity)
	spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/2, PI/2)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# Zoom controls
	if Input.is_action_just_pressed("zoom_in"):
		spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_speed, min_zoom, max_zoom)
	if Input.is_action_just_pressed("zoom_out"):
		spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_speed, min_zoom, max_zoom)
	
	# Camera look controls (right mouse button)
	if event.is_action("ui_mouse_right"):
		if event.is_pressed():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Selection and movement (left mouse button)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		_handle_left_click(event.position)

func _handle_left_click(mouse_pos: Vector2) -> void:
	var ray_length: float = 1000
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * ray_length
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	var result: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		if collider == player:
			# Player clicked - select
			is_player_selected = true
			selection_ring.show()
			target_position = player.global_position
		elif is_player_selected:
			# Ground clicked while player selected - move
			target_position = result.position
			var marker = DestinationMarker.instantiate()
			player.get_parent().add_child(marker)
			marker.global_position = target_position
			if marker.has_node("AnimationPlayer"):
				marker.get_node("AnimationPlayer").connect("animation_finished", Callable(marker, "queue_free"))
		else:
			# Clicked elsewhere - deselect
			is_player_selected = false
			selection_ring.hide()

func handle_physics(delta: float) -> void:
	if not is_active:
		return
	
	# Move camera with WASD
	_handle_camera_movement(delta)
	
	# Apply gravity to player
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	
	# Move player if selected and has target
	_handle_player_movement(delta)
	
	# Execute player movement
	player.move_and_slide()

func _handle_camera_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "backward")
	var direction: Vector3 = (spring_arm.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	spring_arm.global_position += direction * camera_speed * delta

func _handle_player_movement(delta: float) -> void:
	if is_player_selected:
		var current_pos: Vector3 = player.global_position
		var move_direction: Vector3 = (target_position - current_pos).normalized()
		var target_velocity: Vector3 = Vector3.ZERO
		
		if current_pos.distance_to(target_position) > 0.5:
			target_velocity = move_direction * character_speed
			player.look_at(Vector3(target_position.x, current_pos.y, target_position.z))
		
		player.velocity.x = lerp(player.velocity.x, target_velocity.x, lerp_weight * delta)
		player.velocity.z = lerp(player.velocity.z, target_velocity.z, lerp_weight * delta)
	else:
		player.velocity.x = lerp(player.velocity.x, 0.0, lerp_weight * delta)
		player.velocity.z = lerp(player.velocity.z, 0.0, lerp_weight * delta)

func _calculate_movement_direction(input_dir: Vector2) -> Vector3:
	# Not used in this controller - movement handled by camera and selection
	return Vector3.ZERO

func cleanup() -> void:
	"""Called when switching to a different controller"""
	is_active = false
	is_player_selected = false
	if selection_ring:
		selection_ring.hide()
	Logger.info("FreeCameraController cleaned up")
