@tool
extends Node3D
## @tool editor for battle formations.
## Drag the player (green) and enemy (red) markers to set positions.
## Click "Save to Formation" to write back to the resource.

@export var formation: Resource:  # BattleFormation
	set(value):
		formation = value
		if Engine.is_editor_hint() and _built:
			_load_formation()

@export_range(1, 4) var player_count: int = 4:
	set(value):
		player_count = value
		if Engine.is_editor_hint() and _built:
			_rebuild_markers()

@export_range(1, 4) var enemy_count: int = 4:
	set(value):
		enemy_count = value
		if Engine.is_editor_hint() and _built:
			_rebuild_markers()

@export_group("Actions")
@export var save_to_formation: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_save_formation()
@export var load_from_formation: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_load_formation()

var _player_markers: Array[Node3D] = []
var _enemy_markers: Array[Node3D] = []
var _built: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		_build_arena()
		_rebuild_markers()
		_load_formation()


func _build_arena() -> void:
	if _built:
		return
	_built = true

	# Arena floor
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "ArenaFloor"
	var disc := CylinderMesh.new()
	disc.top_radius = 10.0
	disc.bottom_radius = 10.0
	disc.height = 0.05
	disc.radial_segments = 32
	floor_mesh.mesh = disc
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.5, 0.2)
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)

	# Center marker
	var center := MeshInstance3D.new()
	center.name = "Center"
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	center.mesh = sm
	center.position = Vector3(0, 0.15, 0)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(1, 1, 0)
	center.material_override = cm
	add_child(center)

	# Divider line
	var divider := MeshInstance3D.new()
	divider.name = "Divider"
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.05, 0.02, 20.0)
	divider.mesh = line_mesh
	divider.position.y = 0.03
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(1, 1, 1, 0.3)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	divider.material_override = line_mat
	add_child(divider)

	# Light
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.0
	add_child(light)


func _rebuild_markers() -> void:
	_player_markers.clear()
	_enemy_markers.clear()

	var scene_root: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	var default_player: Array[Vector3] = [
		Vector3(-3.0, 0, 0.0), Vector3(-4.0, 0, 1.0),
		Vector3(-3.5, 0, -1.0), Vector3(-5.0, 0, 0.5),
	]
	var default_enemy: Array[Vector3] = [
		Vector3(3.0, 0, 0.0), Vector3(4.0, 0, 1.0),
		Vector3(3.5, 0, -1.0), Vector3(5.0, 0, 0.5),
	]

	for i in range(player_count):
		var marker_name: String = "Player_%d" % i
		var existing: Node3D = get_node_or_null(marker_name) as Node3D
		if existing:
			# Reuse saved node, add visuals if missing
			if existing.get_child_count() == 0:
				_add_marker_visuals(existing, Color(0.2, 0.5, 0.9), "P%d" % i)
			_player_markers.append(existing)
		else:
			var pos: Vector3 = default_player[i] if i < default_player.size() else Vector3(-3.0 - i, 0, 0)
			var marker: Node3D = _create_marker(marker_name, pos, Color(0.2, 0.5, 0.9), "P%d" % i)
			add_child(marker)
			marker.owner = scene_root
			_player_markers.append(marker)

	for i in range(enemy_count):
		var marker_name: String = "Enemy_%d" % i
		var existing: Node3D = get_node_or_null(marker_name) as Node3D
		if existing:
			if existing.get_child_count() == 0:
				_add_marker_visuals(existing, Color(0.9, 0.2, 0.2), "E%d" % i)
			_enemy_markers.append(existing)
		else:
			var pos: Vector3 = default_enemy[i] if i < default_enemy.size() else Vector3(3.0 + i, 0, 0)
			var marker: Node3D = _create_marker(marker_name, pos, Color(0.9, 0.2, 0.2), "E%d" % i)
			add_child(marker)
			marker.owner = scene_root
			_enemy_markers.append(marker)

	_load_formation()


func _create_marker(marker_name: String, pos: Vector3, color: Color, label_text: String) -> Node3D:
	var root := Node3D.new()
	root.name = marker_name
	root.position = pos
	_add_marker_visuals(root, color, label_text)
	return root


func _add_marker_visuals(root: Node3D, color: Color, label_text: String) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.6
	body.mesh = capsule
	body.position.y = 0.8
	body.material_override = mat
	root.add_child(body)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	head.mesh = sphere
	head.position.y = 1.7
	head.material_override = mat
	root.add_child(head)

	var label := Label3D.new()
	label.text = label_text
	label.position.y = 2.2
	label.font_size = 36
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	root.add_child(label)


func _load_formation() -> void:
	if not formation:
		return
	for i in range(_player_markers.size()):
		if i < formation.player_positions.size():
			_player_markers[i].position = formation.player_positions[i]
	for i in range(_enemy_markers.size()):
		if i < formation.enemy_positions.size():
			_enemy_markers[i].position = formation.enemy_positions[i]
	print("[FormationEditor] Loaded formation '%s'" % formation.formation_name)


func _save_formation() -> void:
	if not formation:
		print("[FormationEditor] No formation assigned!")
		return
	var player_pos: Array[Vector3] = []
	for m in _player_markers:
		if is_instance_valid(m):
			player_pos.append(m.position)
	var enemy_pos: Array[Vector3] = []
	for m in _enemy_markers:
		if is_instance_valid(m):
			enemy_pos.append(m.position)
	formation.player_positions.assign(player_pos)
	formation.enemy_positions.assign(enemy_pos)
	if not formation.resource_path.is_empty():
		ResourceSaver.save(formation, formation.resource_path)
	print("[FormationEditor] Saved %d players + %d enemies to '%s'" % [
		player_pos.size(), enemy_pos.size(), formation.formation_name])
