extends GPUParticles3D
class_name ProjectileHitEffect

func _ready() -> void:
	Logger.info("Hit effect spawned at: " + str(global_position))
	
	# Start particle emission
	emitting = true
	
	# Auto-destroy after particles finish
	await get_tree().create_timer(lifetime + 0.5).timeout
	if is_instance_valid(self):
		queue_free()