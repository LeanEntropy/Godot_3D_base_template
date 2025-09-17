extends RigidBody3D

var lifetime = 5.0  # Projectile will be destroyed after 5 seconds
var age = 0.0

func _ready():
	# Connect to body_entered signal for collision detection
	body_entered.connect(_on_body_entered)
	
	# Set up physics properties
	gravity_scale = 1.0
	mass = GameConfig.projectile_mass
	
	# Start the lifetime timer
	age = 0.0

func _physics_process(delta):
	age += delta
	
	# Destroy projectile after lifetime expires
	if age >= lifetime:
		destroy()

func _on_body_entered(body):
	# Don't collide with the player who fired it
	if body.name == "Player":
		return
	
	# Play impact sound
	AudioManager.play_3d_sound("projectile_impact", global_position)
	
	# Handle collision
	Logger.info("Projectile hit: " + str(body.name))
	destroy()

func destroy():
	# Create a small explosion effect or particle system here if desired
	queue_free()

