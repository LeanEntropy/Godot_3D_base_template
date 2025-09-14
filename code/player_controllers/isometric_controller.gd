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

var target_position

func initialize(player_node):
	player = player_node
	spring_arm = player.get_node("Turret/SpringArmD")
	camera = spring_arm.get_node("Camera3D")
	player_mesh = player.get_node("PlayerMesh")
	selection_ring = player.get_node("SelectionRing")
	turret = player.get_node("Turret")
	turret_mesh = turret.get_node("TurretMesh")
	tank_hull = player.get_node("TankHull")
	tank_gun_barrel = turret.get_node("TankGunBarrel")
	
	target_position = player.global_transform.origin

	# Hide all visuals except the player capsule
	if player_mesh: player_mesh.show()
	if selection_ring: selection_ring.show()
	if turret_mesh: turret_mesh.hide()
	if tank_hull: tank_hull.hide()
	if tank_gun_barrel: tank_gun_barrel.hide()

	# Set camera to isometric
	spring_arm.spring_length = 20.0
	spring_arm.position = Vector3.ZERO
	spring_arm.rotation = Vector3(deg_to_rad(-35.264), deg_to_rad(45), 0)
	spring_arm.top_level = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = GameConfig.default_zoom


func _ready():
	pass

func handle_input(event):
	if Input.is_action_just_pressed("zoom_in"):
		camera.size = clamp(camera.size - GameConfig.zoom_speed, GameConfig.min_zoom, GameConfig.max_zoom)
	if Input.is_action_just_pressed("zoom_out"):
		camera.size = clamp(camera.size + GameConfig.zoom_speed, GameConfig.min_zoom, GameConfig.max_zoom)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var mouse_pos = event.position
		var ray_length = 1000
		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * ray_length

		var space_state = player.get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)

		if result:
			target_position = result.position
			var marker = DestinationMarker.instantiate()
			player.get_parent().add_child(marker)
			marker.global_position = target_position
			marker.get_node("AnimationPlayer").connect("animation_finished", Callable(marker, "queue_free"))


func handle_physics(_delta):
	if not player.is_on_floor():
		player.velocity.y -= GameConfig.gravity * _delta

	spring_arm.global_position = player.global_position

	var current_position = player.global_position
	var direction = (target_position - current_position).normalized()
	var target_velocity = Vector3.ZERO
	
	if current_position.distance_to(target_position) > 0.1:
		target_velocity = direction * GameConfig.speed
		player.look_at(Vector3(target_position.x, player.global_position.y, target_position.z))
	
	player.velocity.x = lerp(player.velocity.x, target_velocity.x, GameConfig.lerp_weight * _delta)
	player.velocity.z = lerp(player.velocity.z, target_velocity.z, GameConfig.lerp_weight * _delta)
	
	player.move_and_slide()
