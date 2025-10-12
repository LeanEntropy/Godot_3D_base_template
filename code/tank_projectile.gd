extends RigidBody3D
class_name TankProjectile

@export var speed: float = 30.0
@export var lifetime: float = 8.0
@export var damage: int = 25

var direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
	# Force settings
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	
	# Set velocity
	linear_velocity = direction * speed
	
	Logger.info("TankProjectile ready - pos: " + str(global_position) + " vel: " + str(linear_velocity))
	
	# Auto-destroy
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		Logger.info("Projectile despawning after lifetime")
		queue_free()

func launch(launch_direction: Vector3, launch_speed: float = 30.0) -> void:
	direction = launch_direction.normalized()
	speed = launch_speed
	linear_velocity = direction * speed
	Logger.info("Projectile launched: direction=" + str(direction) + " velocity=" + str(linear_velocity))

func _on_body_entered(body: Node) -> void:
	Logger.info("Projectile hit: " + body.name)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()