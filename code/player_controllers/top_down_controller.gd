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


func initialize(player_node):
	player = player_node
	spring_arm = player.get_node("Turret/SpringArm3D")
	camera = spring_arm.get_node("Camera3D")
	player_mesh = player.get_node("PlayerMesh")
	selection_ring = player.get_node("SelectionRing")
	turret = player.get_node("Turret")
	turret_mesh = turret.get_node("TurretMesh")
	tank_hull = player.get_node("TankHull")
	tank_gun_barrel = turret.get_node("TankGunBarrel")

	# Hide all visuals except the player capsule
	if player_mesh: player_mesh.show()
	if selection_ring: selection_ring.hide()
	if turret_mesh: turret_mesh.hide()
	if tank_hull: tank_hull.hide()
	if tank_gun_barrel: tank_gun_barrel.hide()

	# Set camera to top down
	spring_arm.spring_length = 10.0
	spring_arm.position = Vector3.ZERO
	spring_arm.rotation.x = deg_to_rad(-70)
	spring_arm.top_level = true
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = GameConfig.default_zoom


func _ready():
	pass

func handle_input(event):
	if Input.is_action_just_pressed("zoom_in"):
		spring_arm.spring_length = clamp(spring_arm.spring_length - GameConfig.zoom_speed, GameConfig.min_zoom, GameConfig.max_zoom)
	if Input.is_action_just_pressed("zoom_out"):
		spring_arm.spring_length = clamp(spring_arm.spring_length + GameConfig.zoom_speed, GameConfig.min_zoom, GameConfig.max_zoom)

	# Mouse motion is used for aiming, not camera control, which is handled in physics_process
	pass

func handle_physics(delta):
	if not player.is_on_floor():
		player.velocity.y -= GameConfig.gravity * delta

	# Player rotates to face the mouse cursor on the ground plane
	var mouse_pos = player.get_viewport().get_mouse_position()
	var ray_length = 1000
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * ray_length

	var space_state = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	Logger.start_performance_check("top_down_raycast")
	var result = space_state.intersect_ray(query)
	Logger.end_performance_check("top_down_raycast")

	# In top_level mode, the spring arm's position needs to be manually updated
	spring_arm.global_position = player.global_position

	if result:
		var target_position = result.position
		player.look_at(Vector3(target_position.x, player.global_transform.origin.y, target_position.z))

	# Player moves relative to the screen, not where it's facing
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	var target_velocity = Vector3(direction.x, 0, direction.z) * GameConfig.speed
	player.velocity.x = lerp(player.velocity.x, target_velocity.x, GameConfig.lerp_weight * delta)
	player.velocity.z = lerp(player.velocity.z, target_velocity.z, GameConfig.lerp_weight * delta)

	player.move_and_slide()
