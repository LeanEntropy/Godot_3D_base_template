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
	
	# Use existing SpringArm3D and Camera3D from main scene
	spring_arm = player.get_node("Turret/SpringArm3D")
	camera = spring_arm.get_node("Camera3D")
	
	# Set camera properties for tank view
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = GameConfig.default_fov
	
	logical_turret = Node3D.new() # Create a new Node3D for logical turret rotation
	player.add_child(logical_turret)

	# Hide all visuals except the tank model
	if player_mesh: player_mesh.hide()
	if selection_ring: selection_ring.hide()
	if turret_mesh: turret_mesh.show()
	if tank_hull: tank_hull.show()
	if tank_gun_barrel: tank_gun_barrel.show()
	if tank_model: tank_model.show()

func _ready():
	pass

func handle_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		logical_turret.rotate_y(-event.relative.x * GameConfig.turret_turn_speed)
		turret.rotate_y(-event.relative.x * GameConfig.turret_turn_speed)
		spring_arm.rotate_x(-event.relative.y * GameConfig.turret_turn_speed)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/4, PI/4)

func handle_physics(delta):
	if not player.is_on_floor():
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
