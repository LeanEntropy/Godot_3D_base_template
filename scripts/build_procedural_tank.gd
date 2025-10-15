@tool
extends EditorScript

func _run():
	print("=== Building Better Procedural Tank Model ===")
	
	var player = get_scene().get_node("Player")
	if not player:
		print("ERROR: Player node not found!")
		return
	
	# Create materials
	var hull_material = _create_material(Color(0.25, 0.3, 0.2), 0.3, 0.8)  # Olive green
	var turret_material = _create_material(Color(0.4, 0.4, 0.4), 0.5, 0.6)  # Medium gray
	var barrel_material = _create_material(Color(0.3, 0.3, 0.3), 0.6, 0.7)  # Dark gray
	var track_material = _create_material(Color(0.15, 0.2, 0.15), 0.2, 0.9)  # Dark green
	var detail_material = _create_material(Color(0.2, 0.2, 0.2), 0.4, 0.8)  # Almost black
	var headlight_material = _create_emissive_material(Color.YELLOW, 2.0)
	
	print("Materials created")
	
	# === UPGRADE HULL ===
	_upgrade_hull(player, hull_material, track_material, detail_material)
	
	# === UPGRADE TURRET ===
	_upgrade_turret(player, turret_material, detail_material)
	
	# === UPGRADE BARREL ===
	_upgrade_barrel(player, barrel_material)
	
	# === UPGRADE HEADLIGHTS ===
	_upgrade_headlights(player, headlight_material)
	
	print("=== Procedural Tank Model Complete ===")
	print("Tank now has detailed hull, turret, barrel, and accessories")

func _upgrade_hull(player: Node, hull_mat: Material, track_mat: Material, detail_mat: Material):
	print("\n--- Upgrading Hull ---")
	
	var tank_hull = player.get_node_or_null("TankHull")
	if not tank_hull:
		print("ERROR: TankHull not found!")
		return
	
	# Update main hull
	var hull_mesh = BoxMesh.new()
	hull_mesh.size = Vector3(2.0, 0.6, 3.0)
	tank_hull.mesh = hull_mesh
	tank_hull.set_surface_override_material(0, hull_mat)
	print("✓ Main hull updated")
	
	# Clear existing children (except headlights)
	for child in tank_hull.get_children():
		if child.name.begins_with("Headlight"):
			continue  # Keep headlights
		child.queue_free()
	
	# Add hull upper section
	var hull_upper = _create_mesh_node("HullUpper", BoxMesh.new(), hull_mat)
	hull_upper.mesh.size = Vector3(1.5, 0.4, 2.2)
	hull_upper.position = Vector3(0, 0.5, -0.2)
	tank_hull.add_child(hull_upper)
	hull_upper.owner = player.owner
	
	# Add track guards
	var track_left = _create_mesh_node("TrackGuardLeft", BoxMesh.new(), track_mat)
	track_left.mesh.size = Vector3(0.2, 0.3, 3.0)
	track_left.position = Vector3(-1.0, 0, 0)
	tank_hull.add_child(track_left)
	track_left.owner = player.owner
	
	var track_right = _create_mesh_node("TrackGuardRight", BoxMesh.new(), track_mat)
	track_right.mesh.size = Vector3(0.2, 0.3, 3.0)
	track_right.position = Vector3(1.0, 0, 0)
	tank_hull.add_child(track_right)
	track_right.owner = player.owner
	
	# Add front slope
	var front_slope = _create_mesh_node("FrontSlope", BoxMesh.new(), hull_mat)
	front_slope.mesh.size = Vector3(1.5, 0.2, 0.6)
	front_slope.position = Vector3(0, 0.3, -1.8)
	front_slope.rotation_degrees = Vector3(-30, 0, 0)
	tank_hull.add_child(front_slope)
	front_slope.owner = player.owner
	
	# Add engine grille
	var engine_grille = _create_mesh_node("EngineGrille", BoxMesh.new(), detail_mat)
	engine_grille.mesh.size = Vector3(0.8, 0.15, 0.3)
	engine_grille.position = Vector3(0, 0.5, 1.4)
	tank_hull.add_child(engine_grille)
	engine_grille.owner = player.owner
	
	print("✓ Hull details added: upper section, track guards, front slope, engine grille")

func _upgrade_turret(player: Node, turret_mat: Material, detail_mat: Material):
	print("\n--- Upgrading Turret ---")
	
	var turret = player.get_node_or_null("Turret")
	if not turret:
		print("ERROR: Turret not found!")
		return
	
	var turret_mesh = turret.get_node_or_null("TurretMesh")
	if not turret_mesh:
		print("ERROR: TurretMesh not found!")
		return
	
	# Update main turret
	var turret_box = BoxMesh.new()
	turret_box.size = Vector3(1.2, 0.5, 1.4)
	turret_mesh.mesh = turret_box
	turret_mesh.set_surface_override_material(0, turret_mat)
	print("✓ Main turret updated")
	
	# Clear existing children
	for child in turret_mesh.get_children():
		child.queue_free()
	
	# Add turret top
	var turret_top = _create_mesh_node("TurretTop", BoxMesh.new(), turret_mat)
	turret_top.mesh.size = Vector3(0.9, 0.15, 1.1)
	turret_top.position = Vector3(0, 0.25, 0)
	turret_mesh.add_child(turret_top)
	turret_top.owner = player.owner
	
	# Add commander hatch
	var hatch = _create_mesh_node("CommanderHatch", CylinderMesh.new(), turret_mat)
	hatch.mesh.top_radius = 0.15
	hatch.mesh.bottom_radius = 0.15
	hatch.mesh.height = 0.1
	hatch.position = Vector3(-0.2, 0.35, 0.2)
	turret_mesh.add_child(hatch)
	hatch.owner = player.owner
	
	# Add turret ring
	var turret_ring = _create_mesh_node("TurretRing", CylinderMesh.new(), detail_mat)
	turret_ring.mesh.top_radius = 0.65
	turret_ring.mesh.bottom_radius = 0.65
	turret_ring.mesh.height = 0.05
	turret_ring.position = Vector3(0, -0.25, 0)
	turret_mesh.add_child(turret_ring)
	turret_ring.owner = player.owner
	
	# Add machine gun
	var mg = _create_mesh_node("MachineGun", CylinderMesh.new(), detail_mat)
	mg.mesh.top_radius = 0.03
	mg.mesh.bottom_radius = 0.03
	mg.mesh.height = 0.3
	mg.position = Vector3(0.4, 0.1, -0.5)
	mg.rotation_degrees = Vector3(90, 0, 0)
	turret_mesh.add_child(mg)
	mg.owner = player.owner
	
	print("✓ Turret details added: top section, commander hatch, turret ring, machine gun")

func _upgrade_barrel(player: Node, barrel_mat: Material):
	print("\n--- Upgrading Barrel ---")
	
	# Find barrel - could be in different locations
	var barrel = player.get_node_or_null("Turret/BarrelPivot/TankGunBarrel")
	if not barrel:
		barrel = player.get_node_or_null("Turret/TankGunBarrel")
	
	if not barrel:
		print("ERROR: TankGunBarrel not found!")
		return
	
	# Update main barrel
	var barrel_mesh = CylinderMesh.new()
	barrel_mesh.top_radius = 0.09
	barrel_mesh.bottom_radius = 0.09
	barrel_mesh.height = 2.0
	barrel.mesh = barrel_mesh
	barrel.set_surface_override_material(0, barrel_mat)
	print("✓ Main barrel updated")
	
	# Clear existing children except BarrelTip
	for child in barrel.get_children():
		if child.name != "BarrelTip":
			child.queue_free()
	
	# Add muzzle brake
	var muzzle_brake = _create_mesh_node("MuzzleBrake", CylinderMesh.new(), barrel_mat)
	muzzle_brake.mesh.top_radius = 0.12
	muzzle_brake.mesh.bottom_radius = 0.12
	muzzle_brake.mesh.height = 0.2
	muzzle_brake.position = Vector3(0, 0, -1.1)
	barrel.add_child(muzzle_brake)
	muzzle_brake.owner = player.owner
	
	print("✓ Barrel details added: muzzle brake")

func _upgrade_headlights(player: Node, headlight_mat: Material):
	print("\n--- Upgrading Headlights ---")
	
	var hull = player.get_node_or_null("TankHull")
	if not hull:
		return
	
	# Update headlight meshes
	var headlights = ["HeadlightLeft", "HeadlightRight"]
	for light_name in headlights:
		var light = hull.get_node_or_null(light_name)
		if light:
			var light_mesh = CylinderMesh.new()
			light_mesh.top_radius = 0.08
			light_mesh.bottom_radius = 0.08
			light_mesh.height = 0.08
			light.mesh = light_mesh
			light.rotation_degrees = Vector3(90, 0, 0)
			light.set_surface_override_material(0, headlight_mat)
			print("✓ Updated " + light_name)

func _create_mesh_node(name: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.set_surface_override_material(0, material)
	return node

func _create_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _create_emissive_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	return material
