class_name EditorGizmoBuilder
extends RefCounted
## Creates lightweight editor-only gizmo visuals for map elements.


static func build_enemy_gizmo(marker: Node3D, enc_path: String, color: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 1.4, 0.6)
	mesh_inst.mesh = box
	mesh_inst.position.y = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat
	marker.add_child(mesh_inst)

	var label := Label3D.new()
	label.text = enc_path.get_file().trim_suffix(".tres").trim_prefix("encounter_")
	label.position.y = 2.0
	label.font_size = 32
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	marker.add_child(label)


static func build_battle_area_gizmo(marker: Node3D) -> void:
	var mesh_inst := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 7.0
	disc.bottom_radius = 7.0
	disc.height = 0.1
	disc.radial_segments = 24
	mesh_inst.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2, 0.15)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat
	marker.add_child(mesh_inst)

	var label := Label3D.new()
	label.text = "BATTLE AREA"
	label.position.y = 1.5
	label.font_size = 40
	label.modulate = Color(1.0, 0.3, 0.3)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	marker.add_child(label)


static func build_connection_gizmo(marker: Node3D, conn: MapConnection) -> void:
	var mesh_inst := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.3
	cylinder.bottom_radius = 0.3
	cylinder.height = 3.0
	mesh_inst.mesh = cylinder
	mesh_inst.position.y = 1.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.5, 1.0)
	mat.emission_energy_multiplier = 0.5
	mesh_inst.material_override = mat
	marker.add_child(mesh_inst)

	var label := Label3D.new()
	label.text = conn.display_name if not conn.display_name.is_empty() else conn.connection_id
	label.position.y = 3.5
	label.font_size = 40
	label.modulate = Color(0.5, 0.8, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	marker.add_child(label)

	var target_label := Label3D.new()
	target_label.text = "-> %s" % conn.target_map_id
	target_label.position.y = 3.0
	target_label.font_size = 24
	target_label.modulate = Color(0.4, 0.6, 0.8)
	target_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	target_label.no_depth_test = true
	marker.add_child(target_label)


static func build_river_point_gizmo(g: Node3D, color: Color) -> void:
	var sm := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.0
	sphere.height = 4.0
	sm.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material_override = mat
	g.add_child(sm)

	var lbl := Label3D.new()
	lbl.text = g.name.to_upper().replace("_", " ")
	lbl.position.y = 3.0
	lbl.font_size = 32
	lbl.modulate = Color(color.r, color.g, color.b, 1.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	g.add_child(lbl)
