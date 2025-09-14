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
	tank_model = player.get_node("TankModel")

	# Hide all visuals except the player capsule
	if player_mesh: player_mesh.show()
	if selection_ring: selection_ring.hide()
	if turret_mesh: turret_mesh.hide()
	if tank_hull: tank_hull.hide()
	if tank_gun_barrel: tank_gun_barrel.hide()
	if tank_model: tank_model.hide()

	# Set camera to first person
	spring_arm.spring_length = 0
	spring_arm.position = Vector3.ZERO
	spring_arm.top_level = false
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = GameConfig.default_fov

func _ready():
	pass

func handle_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * GameConfig.mouse_sensitivity)
		camera.rotate_x(-event.relative.y * GameConfig.mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func handle_physics(delta):
	if not player.is_on_floor():
		player.velocity.y -= GameConfig.gravity * delta

	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var target_velocity = Vector3(direction.x, 0, direction.z) * GameConfig.speed
	player.velocity.x = lerp(player.velocity.x, target_velocity.x, GameConfig.lerp_weight * delta)
	player.velocity.z = lerp(player.velocity.z, target_velocity.z, GameConfig.lerp_weight * delta)
	
	player.move_and_slide()
