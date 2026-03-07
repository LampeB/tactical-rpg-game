class_name CSGCharacterFactory
## Builds simple humanoid figures from CSG primitives at runtime.
## Falls back to CSG when no voxel model is available.
## Prefers multi-part articulated voxel models (with limb pivots) when present.


## Create a 3D model for any data resource that has model_scene/model_scale.
## Falls back to CSG generation when model_scene is null.
static func create_model_for(data: Resource) -> Node3D:
	if data is CharacterData:
		return create_from_character(data as CharacterData)
	elif data is EnemyData:
		return create_from_enemy(data as EnemyData)
	elif data is NpcData:
		return create_from_npc(data as NpcData)
	return create_humanoid(Constants.CHARACTER_DEFAULT_COLOR)


static func create_from_character(char_data: CharacterData) -> Node3D:
	if char_data.model_scene:
		var model: Node3D = char_data.model_scene.instantiate()
		model.scale = Vector3.ONE * char_data.model_scale
		return model
	# Try multi-part articulated voxel model (limbs + pivots)
	var multipart := _try_load_multipart_vox("res://assets/voxels/characters/%s" % char_data.id)
	if multipart:
		_add_name_label(multipart, char_data.display_name, 2.0)
		return multipart
	# Try single-file voxel model
	var vox_model := _try_load_vox("res://assets/voxels/characters/%s.vox" % char_data.id)
	if vox_model:
		_add_name_label(vox_model, char_data.display_name, 2.0)
		return vox_model
	var color: Color = Constants.CHARACTER_CLASS_COLORS.get(
		char_data.character_class, Constants.CHARACTER_DEFAULT_COLOR
	)
	var model := create_humanoid(color)
	_add_name_label(model, char_data.display_name, 2.0)
	return model


static func create_from_enemy(enemy_data: EnemyData) -> Node3D:
	if enemy_data.model_scene:
		var model: Node3D = enemy_data.model_scene.instantiate()
		model.scale = Vector3.ONE * enemy_data.model_scale
		return model
	# Try multi-part articulated voxel model
	var multipart := _try_load_multipart_vox("res://assets/voxels/enemies/%s" % enemy_data.id)
	if multipart:
		multipart.scale = Vector3.ONE * enemy_data.model_scale
		_add_name_label(multipart, enemy_data.display_name, _get_model_top(multipart) + 0.3)
		return multipart
	# Try single-file voxel model
	var vox_model := _try_load_vox("res://assets/voxels/enemies/%s.vox" % enemy_data.id)
	if vox_model:
		vox_model.scale = Vector3.ONE * enemy_data.model_scale
		_add_name_label(vox_model, enemy_data.display_name, _get_model_top(vox_model) + 0.3)
		return vox_model
	var model: Node3D
	# Special shapes for specific enemy types
	if enemy_data.id.begins_with("slime"):
		model = _create_slime(enemy_data.model_color)
	else:
		# Vary height by enemy type
		var height := 1.8
		if enemy_data.id.begins_with("goblin"):
			height = 1.2
		elif enemy_data.id.begins_with("minotaur"):
			height = 2.5
		model = create_humanoid(enemy_data.model_color, height)
	model.scale = Vector3.ONE * enemy_data.model_scale
	_add_name_label(model, enemy_data.display_name, _get_model_top(model) + 0.3)
	return model


static func create_from_npc(npc_data: NpcData) -> Node3D:
	if npc_data.model_scene:
		var model: Node3D = npc_data.model_scene.instantiate()
		return model
	# Try multi-part articulated voxel model
	var multipart := _try_load_multipart_vox("res://assets/voxels/npcs/%s" % npc_data.id)
	if multipart:
		_add_name_label(multipart, npc_data.display_name, 2.0)
		return multipart
	# Try single-file voxel model
	var vox_model := _try_load_vox("res://assets/voxels/npcs/%s.vox" % npc_data.id)
	if vox_model:
		_add_name_label(vox_model, npc_data.display_name, 2.0)
		return vox_model
	var color: Color = npc_data.model_color
	# Role-based color hints
	match npc_data.role:
		NpcData.NpcRole.SHOPKEEPER:
			color = Color(0.55, 0.35, 0.2)   # Brown apron
		NpcData.NpcRole.CRAFTSMAN:
			color = Color(0.4, 0.3, 0.25)    # Dark leather
		NpcData.NpcRole.QUEST_GIVER:
			color = Color(0.8, 0.7, 0.2)     # Gold accent
	var model := create_humanoid(color)
	_add_name_label(model, npc_data.display_name, 2.0)
	return model


## Build a humanoid figure from CSG primitives. Y=0 is at the feet.
static func create_humanoid(color: Color, height: float = 1.8) -> Node3D:
	var root := Node3D.new()
	root.name = "CSGCharacter"

	var scale_factor := height / 1.8
	var mat := _make_material(color)

	# Body (torso)
	var body := CSGBox3D.new()
	body.name = "Body"
	body.size = Vector3(0.6, 0.8, 0.3) * scale_factor
	body.position = Vector3(0, 0.9 * scale_factor, 0)
	body.material = mat
	root.add_child(body)

	# Head
	var head := CSGBox3D.new()
	head.name = "Head"
	head.size = Vector3(0.4, 0.4, 0.4) * scale_factor
	head.position = Vector3(0, 1.5 * scale_factor, 0)
	head.material = mat
	root.add_child(head)

	# Attachment point for helmet
	var helmet_attach := Marker3D.new()
	helmet_attach.name = "HelmetAttach"
	helmet_attach.position = Vector3(0, 0.2 * scale_factor, 0)
	head.add_child(helmet_attach)

	# Arms
	var arm_mat := _make_material(color.darkened(0.15))
	for side in [-1.0, 1.0]:
		var arm := CSGCylinder3D.new()
		arm.name = "LeftArm" if side < 0 else "RightArm"
		arm.radius = 0.1 * scale_factor
		arm.height = 0.7 * scale_factor
		arm.position = Vector3(side * 0.45 * scale_factor, 0.95 * scale_factor, 0)
		arm.material = arm_mat
		root.add_child(arm)

		# Hand attachment
		var hand_attach := Marker3D.new()
		hand_attach.name = "LeftHandAttach" if side < 0 else "RightHandAttach"
		hand_attach.position = Vector3(0, -0.35 * scale_factor, 0)
		arm.add_child(hand_attach)

	# Legs
	var leg_mat := _make_material(color.darkened(0.25))
	for side in [-1.0, 1.0]:
		var leg := CSGCylinder3D.new()
		leg.name = "LeftLeg" if side < 0 else "RightLeg"
		leg.radius = 0.12 * scale_factor
		leg.height = 0.8 * scale_factor
		leg.position = Vector3(side * 0.15 * scale_factor, 0.4 * scale_factor, 0)
		leg.material = leg_mat
		root.add_child(leg)

		# Boot attachment
		var boot_attach := Marker3D.new()
		boot_attach.name = "LeftBootAttach" if side < 0 else "RightBootAttach"
		boot_attach.position = Vector3(0, -0.4 * scale_factor, 0)
		leg.add_child(boot_attach)

	# Equipment overlay attachment points on root
	var chest_attach := Marker3D.new()
	chest_attach.name = "ChestAttach"
	chest_attach.position = Vector3(0, 0.9 * scale_factor, 0)
	root.add_child(chest_attach)

	var legs_attach := Marker3D.new()
	legs_attach.name = "LegsAttach"
	legs_attach.position = Vector3(0, 0.4 * scale_factor, 0)
	root.add_child(legs_attach)

	var neck_attach := Marker3D.new()
	neck_attach.name = "NeckAttach"
	neck_attach.position = Vector3(0, 1.3 * scale_factor, 0)
	root.add_child(neck_attach)

	return root


# --- Private helpers ---

static func _try_load_multipart_vox(base_dir: String) -> Node3D:
	## Loads an articulated multi-part voxel model from a directory.
	## Expects per-limb .vox files and a parts.json assembly metadata file.
	var meta_path := base_dir + "/parts.json"
	if not FileAccess.file_exists(meta_path):
		return null

	var file := FileAccess.open(meta_path, FileAccess.READ)
	if not file:
		return null
	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
		push_error("CSGCharacterFactory: Failed to parse %s" % meta_path)
		return null

	var assembly: Dictionary = json.data
	if assembly.is_empty():
		return null

	# Read optional voxel_size (HD models use 0.06, legacy uses default 0.1)
	var vox_size: float = assembly.get("voxel_size", 0.1)

	var root := Node3D.new()
	root.name = "VoxCharacter"

	# First pass: create all pivot nodes and attach to root
	var pivot_nodes: Dictionary = {}  # node_name -> Node3D
	for part_key in assembly:
		var part_value: Variant = assembly[part_key]
		if not part_value is Dictionary:
			continue  # Skip metadata keys like "voxel_size"
		var part_data: Dictionary = part_value

		var vox_path: String = base_dir + "/" + str(part_key) + ".vox"
		var mesh: ArrayMesh = VoxImporter.load_vox(vox_path, vox_size)
		if not mesh:
			continue

		var node_name: String = part_data.get("node_name", part_key)
		var pivot: Array = part_data.get("pivot", [0.0, 0.0, 0.0])
		var top_pivot: bool = part_data.get("top_pivot", false)

		# Create pivot Node3D at the joint position
		var pivot_node := Node3D.new()
		pivot_node.name = node_name
		pivot_node.position = Vector3(float(pivot[0]), float(pivot[1]), float(pivot[2]))
		root.add_child(pivot_node)

		# Create mesh instance inside the pivot
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "Mesh"
		mesh_inst.mesh = mesh

		# For top-pivot parts (arms, legs), offset mesh so it hangs below the pivot
		if top_pivot:
			var aabb: AABB = mesh.get_aabb()
			mesh_inst.position.y = -(aabb.position.y + aabb.size.y)

		pivot_node.add_child(mesh_inst)
		pivot_nodes[node_name] = pivot_node

	# Second pass: re-parent child parts (hands -> arms, feet -> legs)
	for part_key in assembly:
		var part_value: Variant = assembly[part_key]
		if not part_value is Dictionary:
			continue
		var part_data: Dictionary = part_value
		var parent_name: String = part_data.get("parent", "")
		if parent_name.is_empty():
			continue

		var node_name: String = part_data.get("node_name", part_key)
		var child_node: Node3D = pivot_nodes.get(node_name)
		var parent_node: Node3D = pivot_nodes.get(parent_name)
		if child_node and parent_node:
			root.remove_child(child_node)
			parent_node.add_child(child_node)

	return root


static func _try_load_vox(path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		return null
	var mesh: ArrayMesh = VoxImporter.load_vox(path)
	if not mesh:
		return null
	var root := Node3D.new()
	root.name = "VoxModel"
	var inst := MeshInstance3D.new()
	inst.name = "Mesh"
	inst.mesh = mesh
	root.add_child(inst)
	return root


static func _create_slime(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "CSGSlime"
	var sphere := CSGSphere3D.new()
	sphere.name = "Body"
	sphere.radius = 0.5
	sphere.position = Vector3(0, 0.5, 0)
	sphere.material = _make_material(color)
	root.add_child(sphere)

	# Eyes (two small dark spheres)
	for side in [-1.0, 1.0]:
		var eye := CSGSphere3D.new()
		eye.name = "LeftEye" if side < 0 else "RightEye"
		eye.radius = 0.08
		eye.position = Vector3(side * 0.15, 0.65, 0.35)
		eye.material = _make_material(Color(0.1, 0.1, 0.1))
		root.add_child(eye)

	return root


static func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


static func _add_name_label(root: Node3D, display_name: String, y_offset: float) -> void:
	var label := Label3D.new()
	label.name = "NameLabel"
	label.text = display_name
	label.position = Vector3(0, y_offset, 0)
	label.pixel_size = 0.01
	label.font_size = 32
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1, 1, 1, 0.9)
	root.add_child(label)


static func _get_model_top(model: Node3D) -> float:
	var max_y := 1.0
	for child in model.get_children():
		if child is MeshInstance3D and child.mesh:
			var aabb: AABB = child.mesh.get_aabb()
			var top: float = child.position.y + aabb.position.y + aabb.size.y
			if top > max_y:
				max_y = top
		elif child is CSGShape3D:
			var top: float = child.position.y
			if child is CSGSphere3D:
				top += (child as CSGSphere3D).radius
			elif child is CSGBox3D:
				top += (child as CSGBox3D).size.y * 0.5
			elif child is CSGCylinder3D:
				top += (child as CSGCylinder3D).height * 0.5
			if top > max_y:
				max_y = top
		elif child is Node3D:
			# Check grandchildren (multi-part voxel models: root > pivot > Mesh)
			for grandchild in child.get_children():
				if grandchild is MeshInstance3D and grandchild.mesh:
					var aabb: AABB = grandchild.mesh.get_aabb()
					var top: float = child.position.y + grandchild.position.y + aabb.position.y + aabb.size.y
					if top > max_y:
						max_y = top
	return max_y
