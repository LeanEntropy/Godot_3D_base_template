extends Node
class_name AimingHelper

## Utility class for calculating aim targets in different controller modes
## Provides static methods for raycasting and trajectory calculation

## Get the target point for screen-center aiming (FPS/TPS/OTS/Tank modes)
static func get_screen_center_target(camera: Camera3D, max_distance: float, exclude_bodies: Array = []) -> Vector3:
	"""
	Raycast from camera through screen center to find aim point.
	Used by: first_person, third_person, over_the_shoulder, tank

	Returns: World position where player is aiming, or distant point if no hit
	"""
	if not camera:
		Logger.warning("AimingHelper: No camera provided for screen center target")
		return Vector3.ZERO

	var viewport = camera.get_viewport()
	if not viewport:
		return camera.global_position + (-camera.global_transform.basis.z * max_distance)

	# Get screen center point
	var screen_center = viewport.get_visible_rect().size / 2.0

	# Project ray from camera through screen center
	var ray_origin = camera.project_ray_origin(screen_center)
	var ray_direction = camera.project_ray_normal(screen_center)

	# Perform physics raycast
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * max_distance
	)

	# Exclude player and other specified bodies
	query.exclude = exclude_bodies

	var result = space_state.intersect_ray(query)

	if result:
		return result.position
	else:
		# No hit - return point far in the distance
		return ray_origin + ray_direction * max_distance

## Get target point for mouse-based ground aiming (top-down/isometric modes)
static func get_mouse_ground_target(camera: Camera3D, mouse_position: Vector2, ground_y: float = 0.0, exclude_bodies: Array = []) -> Vector3:
	"""
	Raycast from camera through mouse position to ground plane.
	Used by: top_down, isometric

	Returns: World position on ground plane where mouse is pointing
	"""
	if not camera:
		Logger.warning("AimingHelper: No camera provided for mouse ground target")
		return Vector3.ZERO

	# Project ray from camera through mouse position
	var ray_origin = camera.project_ray_origin(mouse_position)
	var ray_direction = camera.project_ray_normal(mouse_position)

	# First try physics raycast (to hit objects on the ground)
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * 1000.0
	)
	query.exclude = exclude_bodies

	var result = space_state.intersect_ray(query)

	if result:
		return result.position

	# No physics hit - intersect with ground plane mathematically
	var ground_plane = Plane(Vector3.UP, ground_y)
	var intersection = ground_plane.intersects_ray(ray_origin, ray_direction)

	if intersection:
		return intersection
	else:
		# Fallback: return point in front of camera
		Logger.warning("AimingHelper: Failed to find ground intersection")
		return ray_origin + ray_direction * 10.0

## Get target point for forward aiming (free camera mode)
static func get_forward_target(camera: Camera3D, distance: float) -> Vector3:
	"""
	Simple forward aiming from camera position.
	Used by: free_camera

	Returns: Point straight ahead of camera at specified distance
	"""
	if not camera:
		Logger.warning("AimingHelper: No camera provided for forward target")
		return Vector3.ZERO

	return camera.global_position + (-camera.global_transform.basis.z * distance)

## Calculate direction from muzzle to target
static func calculate_fire_direction(muzzle_position: Vector3, target_position: Vector3) -> Vector3:
	"""
	Calculate normalized direction vector from muzzle to target.
	Universal function used by all modes.

	Returns: Normalized direction vector
	"""
	var direction = (target_position - muzzle_position).normalized()

	if direction.length() < 0.01:
		Logger.warning("AimingHelper: Invalid fire direction calculated")
		return Vector3.FORWARD

	return direction

## Calculate leading target for moving targets (future feature)
static func calculate_lead_target(target_position: Vector3, target_velocity: Vector3, projectile_speed: float, muzzle_position: Vector3) -> Vector3:
	"""
	Calculate where to aim to hit a moving target.
	Currently returns target_position, but can be enhanced for moving targets.

	Returns: Position to aim at
	"""
	# Simple implementation - no leading yet
	# TODO: Implement proper leading calculation for moving targets
	return target_position

## Check if line of sight is clear between two points
static func has_clear_line_of_sight(from_position: Vector3, to_position: Vector3, world_3d: World3D, exclude_bodies: Array = []) -> bool:
	"""
	Check if there are obstacles between two positions.
	Useful for AI and weapon systems.

	Returns: true if line of sight is clear, false if blocked
	"""
	var direction = (to_position - from_position)
	var distance = direction.length()
	direction = direction.normalized()

	var space_state = PhysicsServer3D.space_get_direct_state(world_3d.space)

	var query = PhysicsRayQueryParameters3D.create(
		from_position,
		from_position + direction * distance
	)
	query.exclude = exclude_bodies

	var result = space_state.intersect_ray(query)

	return result.is_empty()

## Get appropriate target based on controller mode
static func get_target_for_mode(mode: String, camera: Camera3D, player: Node3D, config_max_distance: float) -> Vector3:
	"""
	Convenience function that returns appropriate target based on controller mode.

	Returns: Target position in world space
	"""
	match mode:
		"first_person", "third_person", "over_the_shoulder", "tank":
			return get_screen_center_target(camera, config_max_distance, [player])

		"top_down", "isometric", "free_camera":
			var mouse_pos = camera.get_viewport().get_mouse_position()
			return get_mouse_ground_target(camera, mouse_pos, 0.0, [player])

		_:
			Logger.warning("AimingHelper: Unknown controller mode: " + mode)
			return get_forward_target(camera, config_max_distance)
