extends Control
class_name AimCursor

## Visual cursor that follows mouse in top-down/isometric modes
## Shows where the player is aiming

@onready var center_container: CenterContainer = $CenterContainer

func _ready() -> void:
	# Start hidden - controller will show/hide
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Make sure child elements also ignore mouse
	if center_container:
		center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for child in center_container.get_children():
			if child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	# Update position to follow mouse
	if visible:
		var mouse_pos = get_viewport().get_mouse_position()
		update_position(mouse_pos)

func update_position(screen_pos: Vector2) -> void:
	"""Center the cursor on the given screen position"""
	# Center the cursor (size is 40x40 from scene)
	global_position = screen_pos - Vector2(20, 20)

func show_cursor() -> void:
	"""Show the aim cursor"""
	visible = true

func hide_cursor() -> void:
	"""Hide the aim cursor"""
	visible = false
