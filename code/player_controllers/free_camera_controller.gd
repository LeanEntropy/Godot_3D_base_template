extends Node

const DestinationMarker = preload("res://assets/destination_marker.tscn")

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

var is_player_selected = false
var target_position

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
	
	target_position = player.global_transform.origin

	# Hide all visuals except the player capsule
	if player_mesh: player_mesh.show()
	if selection_ring: selection_ring.hide()
	if turret_mesh: turret_mesh.hide()
	if tank_hull: tank_hull.hide()
	if tank_gun_barrel: tank_gun_barrel.hide()
	if tank_model: tank_model.hide()

	# Set camera to free camera
	spring_arm.spring_length = 15.0
	spring_arm.position = Vector3.ZERO
	spring_arm.top_level = true
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = GameConfig.default_fov


func _ready():
	pass

func handle_input(event):
	if Input.is_action_just_pressed("zoom_in"):
		spring_arm.spring_length = clamp(spring_arm.spring_length - GameConfig.zoom_speed, GameConfig.min_zoom, GameConfig.max_zoom)
	if Input.is_action_just_pressed("zoom_out"):
		spring_arm.spring_length = clamp(spring_arm.spring_length + GameConfig.zoom_speed, GameConfig.min_zoom, GameConfig.max_zoom)

	# Camera Look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		spring_arm.rotate_y(-event.relative.x * GameConfig.mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * GameConfig.mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/2, PI/2)

	# Capture/Release mouse for looking
	if event.is_action("ui_mouse_right"):
		if event.is_pressed():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


	# Selection and Destination
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var mouse_pos = event.position
		var ray_length = 1000
		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * ray_length
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = player.get_world_3d().direct_space_state.intersect_ray(query)

		if result:
			var collider = result.collider
			if collider == player:
				is_player_selected = true
				selection_ring.show()
				target_position = player.global_position
			elif is_player_selected:
				target_position = result.position
				var marker = DestinationMarker.instantiate()
				player.get_parent().add_child(marker)
				marker.global_position = target_position
				marker.get_node("AnimationPlayer").connect("animation_finished", Callable(marker, "queue_free"))
			else:
				is_player_selected = false
				selection_ring.hide()

func handle_physics(delta):
	# Camera Movement
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (spring_arm.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	spring_arm.global_position += direction * GameConfig.camera_speed * delta

	# Character Movement
	if not player.is_on_floor():
		player.velocity.y -= GameConfig.gravity * delta

	if is_player_selected:
		var current_pos = player.global_position
		var move_direction = (target_position - current_pos).normalized()
		var target_velocity = Vector3.ZERO
		
		if current_pos.distance_to(target_position) > 0.5:
			target_velocity = move_direction * GameConfig.character_speed
			player.look_at(Vector3(target_position.x, current_pos.y, target_position.z))
		
		player.velocity.x = lerp(player.velocity.x, target_velocity.x, GameConfig.lerp_weight * delta)
		player.velocity.z = lerp(player.velocity.z, target_velocity.z, GameConfig.lerp_weight * delta)
	else:
		player.velocity.x = lerp(player.velocity.x, 0.0, GameConfig.lerp_weight * delta)
		player.velocity.z = lerp(player.velocity.z, 0.0, GameConfig.lerp_weight * delta)

	player.move_and_slide()
