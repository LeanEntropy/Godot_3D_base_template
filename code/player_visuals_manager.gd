extends Node

var player_mesh
var selection_ring
var tank_model

func _ready():
	await get_tree().process_frame
	player_mesh = get_parent().get_node("PlayerMesh")
	selection_ring = get_parent().get_node("SelectionRing")
	tank_model = get_parent().get_node("TankModel")


func set_visuals_for_mode(mode_name):
	# Default to hiding everything for a clean slate
	player_mesh.hide()
	selection_ring.hide()
	tank_model.hide()

	# Show only what's needed for the active mode
	match mode_name:
		"first_person":
			pass # Everything remains hidden
		"third_person_follow":
			player_mesh.show()
		"top_down":
			player_mesh.show()
		"isometric":
			player_mesh.show()
			selection_ring.show()
		"free_camera":
			player_mesh.show()
		"tank":
			tank_model.show()
