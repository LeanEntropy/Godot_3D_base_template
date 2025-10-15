extends Node

func _ready():
	var redbox = get_node("/root/Main/RedBox")
	print("=== RedBox Analysis ===")
	print("RedBox type: " + redbox.get_class())
	print("RedBox position: " + str(redbox.global_position))
	print("RedBox children:")
	for child in redbox.get_children():
		print("  - " + child.name + " (" + child.get_class() + ")")
		if child is CollisionShape3D:
			print("    Shape: " + str(child.shape))
	
	# Check collision layers
	if redbox.has_method("get"):
		if redbox.has_property("collision_layer"):
			print("Collision layer: " + str(redbox.collision_layer))
		if redbox.has_property("collision_mask"):
			print("Collision mask: " + str(redbox.collision_mask))
	
	print("=======================")
	get_tree().quit()