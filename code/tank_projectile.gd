extends RigidBody3D
class_name TankProjectile

# Preload hit effect
const HitEffectScene = preload("res://assets/projectile_hit_effect.tscn")

@export var speed: float = 30.0
@export var lifetime: float = 8.0
@export var damage: int = 25

var direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
	# Force settings
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 4

	# Apply color from config
	_apply_projectile_color()

	# Set velocity
	linear_velocity = direction * speed

	Logger.info("TankProjectile ready - pos: " + str(global_position) + " vel: " + str(linear_velocity))
	
	# Auto-destroy
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		Logger.info("Projectile despawning after lifetime")
		queue_free()

func launch(launch_direction: Vector3, launch_speed: float = 30.0, launch_gravity_scale: float = 0.15) -> void:
	direction = launch_direction.normalized()
	speed = launch_speed
	linear_velocity = direction * speed
	gravity_scale = launch_gravity_scale  # Apply gravity for arc trajectory

	# Exclude player from collision to prevent self-hit
	var player = get_tree().get_first_node_in_group("player")
	if player:
		add_collision_exception_with(player)
		Logger.info("Projectile: Added collision exception for player")
	else:
		Logger.warning("Projectile: Player not found in 'player' group")

	Logger.info("Projectile launched: direction=" + str(direction) + " velocity=" + str(linear_velocity) + " gravity_scale=" + str(gravity_scale))

func _apply_projectile_color() -> void:
	"""Apply color from config to projectile mesh"""
	# Get color from config (hex string like "FF0000" for red or "000000" for black)
	var color_hex: String = GameConfig.get_value("projectile", "mesh_color", "FF6B35")

	# Convert hex to Color using Color constructor with hex string
	var color: Color = Color(color_hex) if color_hex.length() == 6 else Color.ORANGE

	Logger.info("Projectile color from config: " + color_hex + " = " + str(color))

	# Find all MeshInstance3D children and apply color
	_apply_color_to_meshes(self, color)

func _apply_color_to_meshes(node: Node, color: Color) -> void:
	"""Recursively find and color all mesh instances"""
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D

		# Create or get material
		var material: StandardMaterial3D
		if mesh_instance.get_surface_override_material_count() > 0:
			material = mesh_instance.get_surface_override_material(0)
			if not material or not material is StandardMaterial3D:
				material = StandardMaterial3D.new()
		else:
			material = StandardMaterial3D.new()

		# Set color with emission
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.0

		mesh_instance.set_surface_override_material(0, material)
		Logger.info("Projectile mesh colored: " + mesh_instance.name + " -> " + str(color))

	# Recursively check children
	for child in node.get_children():
		_apply_color_to_meshes(child, color)

func _on_body_entered(body: Node) -> void:
	Logger.info("Projectile hit: " + body.name)

	# STOP MOTION IMMEDIATELY to prevent bouncing/sliding
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true  # Freeze physics to ensure no movement

	# Create hit effect at impact point
	var hit_effect = HitEffectScene.instantiate()
	get_tree().root.add_child(hit_effect)
	hit_effect.global_position = global_position

	# Deal damage
	if body.has_method("take_damage"):
		body.take_damage(damage)

	# Destroy projectile
	queue_free()