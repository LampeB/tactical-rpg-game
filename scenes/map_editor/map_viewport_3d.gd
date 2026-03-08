class_name MapViewport3D
extends SubViewportContainer
## 3D viewport for map editing. Replaces the 2D MapCanvas.
## Embeds a SubViewport with a 3D world, camera, GridMap terrain,
## and element visualizations. Handles raycasting for paint/select/place tools.

signal cell_painted(grid_pos: Vector2i, block_type: int)
signal element_clicked(element_index: int)
signal element_moved(element_index: int, new_pos: Vector3)
signal element_rotated(element_index: int, new_rotation_y: float)
signal element_placed(world_pos: Vector2)
signal hover_changed(grid_pos: Vector2i)
signal paint_stroke_ended()
signal drag_started(element_index: int, start_pos: Vector3)
signal drag_ended(element_index: int, end_pos: Vector3)
signal scatter_zone_drawn(rect: Rect2)

enum Tool { SELECT, PAINT, PLACE, SCATTER }
enum BrushShape { SQUARE, CIRCLE }

## Current active tool.
var active_tool: Tool = Tool.SELECT
## Block type for terrain painting (-1 = eraser).
var paint_block: int = 0:
	set(value):
		paint_block = value
		if _brush_preview:
			_update_brush_color()
## Brush radius: 1 = single cell, 2 = 3x3, 3 = 5x5, etc.
var brush_size: int = 1:
	set(value):
		brush_size = value
		if _brush_preview:
			_build_brush_preview()
## Brush shape for multi-cell painting.
var brush_shape: BrushShape = BrushShape.SQUARE:
	set(value):
		brush_shape = value
		if _brush_preview:
			_build_brush_preview()
## Element type for placement.
var place_element_type: int = 0
## Currently selected element index (-1 = none).
var selected_element_index: int = -1:
	set(value):
		selected_element_index = value
		_update_selection_highlight()

## Loaded map data reference (owned by map_editor.gd).
var map_data: MapData = null

# --- Camera state ---
const CAM_ORBIT_SPEED := 0.3
const CAM_ZOOM_SPEED := 2.0
const CAM_MIN_DIST := 5.0
const CAM_MAX_DIST := 80.0
const CAM_PITCH_MIN := -85.0
const CAM_PITCH_MAX := -5.0

var _yaw: float = 0.0
var _pitch: float = -45.0
var _distance: float = 30.0
var _target_yaw: float = 0.0
var _target_pitch: float = -45.0
var _target_distance: float = 30.0

# --- Internal nodes ---
var _sub_viewport: SubViewport
var _editor_world: Node3D
var _camera_pivot: Node3D
var _pitch_node: Node3D
var _camera: Camera3D
var _terrain_gridmap: GridMap
var _elements_parent: Node3D
var _ghost_preview: Node3D
var _brush_preview: Node3D
var _brush_preview_mat: StandardMaterial3D
var _selection_highlight: Node3D

# --- Element tracking ---
var _element_nodes: Array[Node3D] = []

# --- Interaction state ---
var _is_orbiting: bool = false
var _is_panning: bool = false
var _is_painting: bool = false
var _is_dragging: bool = false
var _last_painted_cell: Vector2i = Vector2i(-1, -1)
var _drag_start_pos: Vector3 = Vector3.ZERO

# --- Placement asset ---
var _place_asset_path: String = ""
var _place_is_vox: bool = false
var _place_rotation: float = 0.0
var _place_scale: float = 1.0
var _place_random_rotation: bool = false
var _place_random_scale: bool = false
var _place_random_scale_min: float = 0.5
var _place_random_scale_max: float = 1.5
var _rng := RandomNumberGenerator.new()

# --- Scatter state ---
var _scatter_zone_start: Vector3 = Vector3.INF
var _scatter_zone_end: Vector3 = Vector3.INF
var _scatter_zone_rect: Rect2 = Rect2()
var _scatter_drawing_zone: bool = false
var _scatter_zone_defined: bool = false
var _scatter_zone_mesh: MeshInstance3D = null
var _scatter_zone_border: Node3D = null
var _scatter_preview_parent: Node3D = null
var _scatter_preview_items: Array[Dictionary] = []
var _scatter_has_preview: bool = false


func _ready() -> void:
	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_sub_viewport = SubViewport.new()
	_sub_viewport.transparent_bg = false
	_sub_viewport.handle_input_locally = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub_viewport)

	_editor_world = Node3D.new()
	_editor_world.name = "EditorWorld"
	_sub_viewport.add_child(_editor_world)

	# Environment (sky + lighting)
	var env_scene: PackedScene = load("res://scenes/shared/environment_3d.tscn")
	if env_scene:
		_editor_world.add_child(env_scene.instantiate())

	# Camera hierarchy: pivot (yaw + position) -> pitch -> camera (distance)
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_editor_world.add_child(_camera_pivot)

	_pitch_node = Node3D.new()
	_pitch_node.name = "PitchNode"
	_camera_pivot.add_child(_pitch_node)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 50.0
	_camera.near = 0.5
	_camera.far = 200.0
	_pitch_node.add_child(_camera)

	_apply_camera_transform()

	# Element parent
	_elements_parent = Node3D.new()
	_elements_parent.name = "Elements"
	_editor_world.add_child(_elements_parent)

	# Ghost preview
	_ghost_preview = Node3D.new()
	_ghost_preview.name = "GhostPreview"
	_ghost_preview.visible = false
	_editor_world.add_child(_ghost_preview)

	# Scatter preview parent
	_scatter_preview_parent = Node3D.new()
	_scatter_preview_parent.name = "ScatterPreview"
	_editor_world.add_child(_scatter_preview_parent)

	# Brush preview (paint tool cursor)
	_brush_preview_mat = StandardMaterial3D.new()
	_brush_preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_brush_preview_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_brush_preview_mat.no_depth_test = true
	_update_brush_color()
	_brush_preview = Node3D.new()
	_brush_preview.name = "BrushPreview"
	_brush_preview.visible = false
	_editor_world.add_child(_brush_preview)
	_build_brush_preview()

	# Sync viewport size
	item_rect_changed.connect(_on_resized)
	_on_resized()


func _is_text_field_focused() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit


func _process(delta: float) -> void:
	# Arrow key / ZQSD panning (skip when typing in text fields)
	var pan_dir := Vector2.ZERO
	if not _is_text_field_focused():
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q):
			pan_dir.x -= 1.0
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			pan_dir.x += 1.0
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_Z):
			pan_dir.y -= 1.0
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			pan_dir.y += 1.0
	if pan_dir != Vector2.ZERO:
		var speed: float = _distance * 0.8 * delta
		var cam_right: Vector3 = _camera.global_transform.basis.x
		var cam_forward: Vector3 = _camera.global_transform.basis.z
		cam_right.y = 0.0
		cam_forward.y = 0.0
		cam_right = cam_right.normalized()
		cam_forward = cam_forward.normalized()
		_camera_pivot.position += cam_right * pan_dir.x * speed
		_camera_pivot.position += cam_forward * pan_dir.y * speed

	# Smooth camera interpolation
	var weight: float = minf(delta * 10.0, 1.0)
	_yaw = lerp(_yaw, _target_yaw, weight)
	_pitch = lerp(_pitch, _target_pitch, weight)
	_distance = lerp(_distance, _target_distance, weight)
	_apply_camera_transform()


func _apply_camera_transform() -> void:
	_camera_pivot.rotation_degrees.y = _yaw
	_pitch_node.rotation_degrees.x = _pitch
	_camera.position = Vector3(0, 0, _distance)


func _on_resized() -> void:
	if _sub_viewport and size.x > 0 and size.y > 0:
		_sub_viewport.size = Vector2i(int(size.x), int(size.y))


# === Map loading ===

func set_map(data: MapData) -> void:
	map_data = data
	selected_element_index = -1
	_clear_3d_world()
	if not map_data:
		return

	# Build terrain via MapLoader
	_terrain_gridmap = MapLoader.build_terrain(map_data, _editor_world)

	# Spawn element visuals
	_rebuild_elements()

	# Center camera on map
	var cx: float = map_data.grid_width * 0.5
	var cz: float = map_data.grid_height * 0.5
	_camera_pivot.position = Vector3(cx, 0, cz)
	_target_distance = maxf(map_data.grid_width, map_data.grid_height) * 0.6
	_distance = _target_distance


func _clear_3d_world() -> void:
	# Remove terrain
	if _terrain_gridmap and is_instance_valid(_terrain_gridmap):
		_terrain_gridmap.queue_free()
		_terrain_gridmap = null

	# Clear scatter state
	clear_scatter_zone()

	# Remove elements
	for node in _element_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_element_nodes.clear()

	# Clear ghost
	for child in _ghost_preview.get_children():
		child.queue_free()
	_ghost_preview.visible = false

	# Clear selection highlight
	if _selection_highlight and is_instance_valid(_selection_highlight):
		_selection_highlight.queue_free()
		_selection_highlight = null


# === Element visualization ===

func _rebuild_elements() -> void:
	for node in _element_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_element_nodes.clear()

	if not map_data:
		return

	for i in range(map_data.elements.size()):
		var elem: MapElement = map_data.elements[i]
		var node: Node3D = _create_element_visual(elem, i)
		_elements_parent.add_child(node)
		_element_nodes.append(node)


func _create_element_visual(elem: MapElement, idx: int) -> Node3D:
	var wrapper := Node3D.new()
	wrapper.name = "Element_%d" % idx
	wrapper.position = elem.position
	if elem.rotation_y != 0.0:
		wrapper.rotation.y = elem.rotation_y
	if elem.scale_factor != 1.0:
		wrapper.scale = Vector3.ONE * elem.scale_factor
	wrapper.set_meta("editor_element_index", idx)

	var visual: Node3D = null

	match elem.element_type:
		MapElement.ElementType.DECORATION, MapElement.ElementType.SIGN, MapElement.ElementType.FENCE:
			visual = _load_decoration_visual(elem.resource_id)
		MapElement.ElementType.NPC:
			visual = _load_npc_visual(elem.resource_id)
		MapElement.ElementType.ENEMY:
			visual = _load_enemy_visual(elem.resource_id, elem.enemy_color)
		MapElement.ElementType.CHEST:
			visual = _load_chest_visual(elem.resource_id)
		MapElement.ElementType.LOCATION:
			visual = _load_location_visual(elem.resource_id)

	if visual:
		wrapper.add_child(visual)

	# Add editor collision for raycasting (layer 16 = bit 15)
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 15
	body.collision_mask = 0
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 2.0, 1.5)
	col_shape.shape = box
	col_shape.position = Vector3(0, 1.0, 0)
	body.add_child(col_shape)
	wrapper.add_child(body)

	# Patrol zone circle for enemies
	if elem.element_type == MapElement.ElementType.ENEMY and elem.patrol_distance > 0.0:
		var zone_mesh := MeshInstance3D.new()
		zone_mesh.name = "PatrolZone"
		var torus := TorusMesh.new()
		torus.inner_radius = elem.patrol_distance - 0.04
		torus.outer_radius = elem.patrol_distance + 0.04
		torus.rings = 32
		torus.ring_segments = 4
		zone_mesh.mesh = torus
		zone_mesh.position = Vector3(0, 0.05, 0)
		var zone_mat := StandardMaterial3D.new()
		zone_mat.albedo_color = Color(1.0, 0.3, 0.3, 0.3)
		zone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		zone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		zone_mat.no_depth_test = true
		zone_mesh.material_override = zone_mat
		wrapper.add_child(zone_mesh)

	return wrapper


func _load_decoration_visual(resource_id: String) -> Node3D:
	if resource_id.is_empty():
		return _create_box_marker(Color(0.5, 0.8, 0.4), Vector3(0.5, 0.5, 0.5))

	if resource_id.ends_with(".vox"):
		var vox := VoxModel.new()
		vox.vox_path = resource_id
		return vox

	var scene: PackedScene = load(resource_id) as PackedScene
	if scene:
		return scene.instantiate()

	return _create_box_marker(Color(0.5, 0.8, 0.4), Vector3(0.5, 0.5, 0.5))


func _load_npc_visual(resource_id: String) -> Node3D:
	# Scene/vox path from palette
	if resource_id.ends_with(".tscn") or resource_id.ends_with(".vox"):
		return _load_decoration_visual(resource_id)
	# NPC database lookup → character factory model
	if not resource_id.is_empty():
		var npc_data: NpcData = NpcDatabase.get_npc(resource_id)
		if npc_data:
			var model: Node3D = CSGCharacterFactory.create_from_npc(npc_data)
			if model:
				return model
	return _create_capsule_marker(Color(0.3, 0.5, 1.0), 0.4, 1.2)


func _load_enemy_visual(resource_id: String, fallback_color: Color) -> Node3D:
	if resource_id.ends_with(".tscn") or resource_id.ends_with(".vox"):
		return _load_decoration_visual(resource_id)
	# Load encounter data → first enemy → character factory model
	if not resource_id.is_empty() and ResourceLoader.exists(resource_id):
		var encounter: EncounterData = load(resource_id) as EncounterData
		if encounter and not encounter.enemies.is_empty():
			var enemy_data: EnemyData = encounter.enemies[0]
			var model: Node3D = CSGCharacterFactory.create_from_enemy(enemy_data)
			if model:
				return model
	return _create_capsule_marker(fallback_color, 0.4, 1.2)


func _load_chest_visual(resource_id: String) -> Node3D:
	if resource_id.ends_with(".tscn") or resource_id.ends_with(".vox"):
		return _load_decoration_visual(resource_id)
	var base_color := Color(0.55, 0.35, 0.17)
	if not resource_id.is_empty():
		var chest_data: ChestData = ChestDatabase.get_chest(resource_id)
		if chest_data:
			match chest_data.visual_type:
				"iron": base_color = Color(0.55, 0.55, 0.58)
				"gold": base_color = Color(0.85, 0.70, 0.20)
				"ornate": base_color = Color(0.55, 0.25, 0.65)
	# Build CSG chest (body + lid)
	var root := Node3D.new()
	var body := CSGBox3D.new()
	body.size = Vector3(0.8, 0.5, 0.5)
	body.position = Vector3(0, 0.25, 0)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = base_color
	body.material = body_mat
	root.add_child(body)
	var lid := CSGBox3D.new()
	lid.size = Vector3(0.82, 0.1, 0.52)
	lid.position = Vector3(0, 0.55, 0)
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = base_color.lightened(0.15)
	lid.material = lid_mat
	root.add_child(lid)
	return root


func _load_location_visual(resource_id: String) -> Node3D:
	if resource_id.ends_with(".tscn") or resource_id.ends_with(".vox"):
		return _load_decoration_visual(resource_id)
	# Golden beacon pillar
	var root := Node3D.new()
	var pillar := CSGCylinder3D.new()
	pillar.radius = 0.3
	pillar.height = 3.0
	pillar.position = Vector3(0, 1.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 0.5
	pillar.material = mat
	root.add_child(pillar)
	# Try to add name label
	if not resource_id.is_empty() and ResourceLoader.exists(resource_id):
		var loc_data: Resource = load(resource_id)
		if loc_data and "display_name" in loc_data:
			var lbl := Label3D.new()
			lbl.text = loc_data.display_name
			lbl.font_size = 48
			lbl.position = Vector3(0, 3.5, 0)
			lbl.modulate = Color(1.0, 0.9, 0.5)
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.outline_size = 8
			root.add_child(lbl)
	return root


func _create_capsule_marker(color: Color, radius: float, height: float) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	mesh_inst.mesh = capsule
	mesh_inst.position.y = height * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	return mesh_inst


func _create_box_marker(color: Color, box_size: Vector3) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_inst.mesh = box
	mesh_inst.position.y = box_size.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	return mesh_inst


func _create_cylinder_marker(color: Color, radius: float, height: float) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mesh_inst.mesh = cyl
	mesh_inst.position.y = height * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.3
	mesh_inst.material_override = mat
	return mesh_inst


func add_element_visual(elem: MapElement, idx: int) -> void:
	## Add a visual for a newly placed element.
	var node: Node3D = _create_element_visual(elem, idx)
	_elements_parent.add_child(node)
	_element_nodes.append(node)


func refresh_elements() -> void:
	## Full rebuild after deletion or reordering.
	_rebuild_elements()
	_update_selection_highlight()


# === Selection highlight ===

func _update_selection_highlight() -> void:
	if _selection_highlight and is_instance_valid(_selection_highlight):
		_selection_highlight.queue_free()
		_selection_highlight = null

	if selected_element_index < 0 or selected_element_index >= _element_nodes.size():
		return

	var node: Node3D = _element_nodes[selected_element_index]
	if not is_instance_valid(node):
		return

	# Create a wireframe-style highlight box
	_selection_highlight = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 2.5, 2.0)
	(_selection_highlight as MeshInstance3D).mesh = box
	_selection_highlight.position = Vector3(0, 1.25, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.15)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	(_selection_highlight as MeshInstance3D).material_override = mat
	node.add_child(_selection_highlight)


# === Ghost preview ===

func set_place_asset(path: String, is_vox: bool) -> void:
	_place_asset_path = path
	_place_is_vox = is_vox
	_place_rotation = 0.0
	_update_ghost()
	_apply_ghost_scale()


func get_place_asset_path() -> String:
	return _place_asset_path


func update_ghost_visibility() -> void:
	_ghost_preview.visible = not _place_asset_path.is_empty() and active_tool == Tool.PLACE
	if active_tool != Tool.PAINT:
		_brush_preview.visible = false


func _update_ghost() -> void:
	for child in _ghost_preview.get_children():
		child.queue_free()

	if _place_asset_path.is_empty():
		_ghost_preview.visible = false
		return

	var preview: Node3D = null
	if _place_is_vox:
		var vox := VoxModel.new()
		vox.vox_path = _place_asset_path
		preview = vox
	else:
		var scene: PackedScene = load(_place_asset_path) as PackedScene
		if scene:
			preview = scene.instantiate()

	if preview:
		# Disable collision/physics on preview
		_disable_collisions(preview)
		# Make semi-transparent while keeping actual appearance
		_apply_ghost_transparency(preview)
		_ghost_preview.add_child(preview)
	_ghost_preview.visible = not _place_asset_path.is_empty() and active_tool == Tool.PLACE


func _apply_ghost_scale() -> void:
	_ghost_preview.scale = Vector3.ONE * _place_scale


func _disable_collisions(node: Node) -> void:
	if node is CollisionShape3D or node is CollisionPolygon3D:
		node.disabled = true
	elif node is StaticBody3D or node is RigidBody3D or node is CharacterBody3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_disable_collisions(child)


func _apply_ghost_transparency(node: Node3D) -> void:
	if node is MeshInstance3D:
		var mesh_inst: MeshInstance3D = node
		# Duplicate existing materials and add transparency
		var mesh: Mesh = mesh_inst.mesh
		if mesh:
			for surface_idx in range(mesh.get_surface_count()):
				var orig_mat: Material = mesh_inst.get_active_material(surface_idx)
				if orig_mat and orig_mat is StandardMaterial3D:
					var ghost_mat: StandardMaterial3D = orig_mat.duplicate() as StandardMaterial3D
					ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					ghost_mat.albedo_color.a = 0.5
					mesh_inst.set_surface_override_material(surface_idx, ghost_mat)
				else:
					# Fallback for non-standard materials
					var fallback := StandardMaterial3D.new()
					fallback.albedo_color = Color(0.5, 0.7, 1.0, 0.5)
					fallback.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mesh_inst.set_surface_override_material(surface_idx, fallback)
	if node is Light3D:
		node.visible = false
	for child in node.get_children():
		if child is Node3D:
			_apply_ghost_transparency(child)


# === Brush preview ===

func _build_brush_preview() -> void:
	## Rebuild brush preview meshes based on current brush_size and brush_shape.
	for child in _brush_preview.get_children():
		child.queue_free()
	var radius: int = brush_size - 1
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			if brush_shape == BrushShape.CIRCLE and dx * dx + dz * dz > radius * radius:
				continue
			var mesh_inst := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.96, 0.05, 0.96)
			mesh_inst.mesh = box
			mesh_inst.material_override = _brush_preview_mat
			mesh_inst.position = Vector3(dx, 0, dz)
			_brush_preview.add_child(mesh_inst)


func _update_brush_color() -> void:
	## Update brush preview color based on paint_block.
	var color: Color
	if paint_block == -1:
		color = Color(1.0, 0.2, 0.2, 0.35)
	elif paint_block < MapLoader.BLOCK_COLORS.size():
		color = MapLoader.BLOCK_COLORS[paint_block]
		color.a = 0.35
	else:
		color = Color(0.5, 0.5, 0.5, 0.35)
	_brush_preview_mat.albedo_color = color


# === Raycasting ===

func _raycast_terrain(screen_pos: Vector2) -> Dictionary:
	## Cast a ray to the terrain GridMap (collision layer 1).
	if not _camera or not _editor_world:
		return {}
	var from: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)
	var space: PhysicsDirectSpaceState3D = _editor_world.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	query.collision_mask = 1  # Terrain layer
	return space.intersect_ray(query)


func _raycast_elements(screen_pos: Vector2) -> int:
	## Cast a ray to editor elements (collision layer 16). Returns element index or -1.
	if not _camera or not _editor_world:
		return -1
	var from: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)
	var space: PhysicsDirectSpaceState3D = _editor_world.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	query.collision_mask = 1 << 15  # Editor element layer
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return -1

	var hit_node: Node = result.get("collider")
	while hit_node and not hit_node.has_meta("editor_element_index"):
		hit_node = hit_node.get_parent()
	if hit_node and hit_node.has_meta("editor_element_index"):
		return hit_node.get_meta("editor_element_index") as int
	return -1


func _raycast_ground_plane(screen_pos: Vector2) -> Vector3:
	## Intersect ray with Y=0 plane. Returns Vector3.INF on miss.
	if not _camera:
		return Vector3.INF
	var from: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.001:
		return Vector3.INF
	var t: float = -from.y / dir.y
	if t < 0:
		return Vector3.INF
	return from + dir * t


func _get_grid_cell(world_pos: Vector3) -> Vector2i:
	## Convert world position to grid cell (clamped to map bounds).
	# GridMap is at Y=-1, cells at integer X,Z positions
	# The hit position from raycast hits the TOP of the cell, so floor() gives the cell
	var gx: int = int(floorf(world_pos.x))
	var gz: int = int(floorf(world_pos.z))
	return Vector2i(gx, gz)


# === Input handling ===

func _gui_input(event: InputEvent) -> void:
	if not map_data:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_left_press(event.position)
			else:
				_on_left_release(event.position)
			accept_event()
		MOUSE_BUTTON_RIGHT:
			_is_orbiting = event.pressed
			accept_event()
		MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
			accept_event()
		MOUSE_BUTTON_WHEEL_UP:
			if event.ctrl_pressed:
				if active_tool == Tool.PLACE:
					_place_rotation -= PI / 8.0
					_ghost_preview.rotation.y = _place_rotation
				elif selected_element_index >= 0:
					_rotate_selected_element(-PI / 8.0)
			else:
				_target_distance = clampf(_target_distance - CAM_ZOOM_SPEED, CAM_MIN_DIST, CAM_MAX_DIST)
			accept_event()
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.ctrl_pressed:
				if active_tool == Tool.PLACE:
					_place_rotation += PI / 8.0
					_ghost_preview.rotation.y = _place_rotation
				elif selected_element_index >= 0:
					_rotate_selected_element(PI / 8.0)
			else:
				_target_distance = clampf(_target_distance + CAM_ZOOM_SPEED, CAM_MIN_DIST, CAM_MAX_DIST)
			accept_event()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _is_orbiting:
		_target_yaw -= event.relative.x * CAM_ORBIT_SPEED
		_target_pitch -= event.relative.y * CAM_ORBIT_SPEED
		_target_pitch = clampf(_target_pitch, CAM_PITCH_MIN, CAM_PITCH_MAX)
		accept_event()
		return

	if _is_panning:
		var cam_right: Vector3 = _camera.global_transform.basis.x
		var cam_forward: Vector3 = _camera.global_transform.basis.z
		cam_right.y = 0.0
		cam_forward.y = 0.0
		cam_right = cam_right.normalized()
		cam_forward = cam_forward.normalized()
		var pan_speed: float = _distance * 0.002
		_camera_pivot.position += cam_right * -event.relative.x * pan_speed
		_camera_pivot.position += cam_forward * -event.relative.y * pan_speed
		accept_event()
		return

	# Tool-specific hover
	match active_tool:
		Tool.PAINT:
			_handle_paint_hover(event.position)
		Tool.PLACE:
			_handle_place_hover(event.position)
		Tool.SELECT:
			if _is_dragging and selected_element_index >= 0:
				_handle_drag(event.position)
		Tool.SCATTER:
			if _scatter_drawing_zone:
				var gp: Vector3 = _raycast_ground_plane(event.position)
				if gp != Vector3.INF:
					_scatter_zone_end = gp
					_compute_scatter_rect()
					_update_scatter_zone_visual()

	# Emit hover position for status bar
	var hit: Dictionary = _raycast_terrain(event.position)
	if not hit.is_empty():
		var cell: Vector2i = _get_grid_cell(hit["position"])
		hover_changed.emit(cell)
	else:
		# Try ground plane
		var gp: Vector3 = _raycast_ground_plane(event.position)
		if gp != Vector3.INF:
			hover_changed.emit(Vector2i(int(floorf(gp.x)), int(floorf(gp.z))))


func _on_left_press(screen_pos: Vector2) -> void:
	match active_tool:
		Tool.PAINT:
			_is_painting = true
			_last_painted_cell = Vector2i(-1, -1)
			_paint_at(screen_pos)
		Tool.SELECT:
			var hit_idx: int = _raycast_elements(screen_pos)
			if hit_idx >= 0:
				selected_element_index = hit_idx
				element_clicked.emit(hit_idx)
				_is_dragging = true
				var elem_pos: Vector3 = _element_nodes[hit_idx].position
				drag_started.emit(hit_idx, elem_pos)
				var gp: Vector3 = _raycast_ground_plane(screen_pos)
				_drag_start_pos = gp if gp != Vector3.INF else Vector3.ZERO
			else:
				selected_element_index = -1
				element_clicked.emit(-1)
		Tool.PLACE:
			_place_at(screen_pos)
		Tool.SCATTER:
			if not _scatter_has_preview:
				var gp: Vector3 = _raycast_ground_plane(screen_pos)
				if gp != Vector3.INF:
					_scatter_drawing_zone = true
					_scatter_zone_start = gp
					_scatter_zone_end = gp
					_scatter_zone_defined = true
					_compute_scatter_rect()
					_update_scatter_zone_visual()


func _on_left_release(screen_pos: Vector2) -> void:
	if _is_painting:
		_is_painting = false
		_last_painted_cell = Vector2i(-1, -1)
		paint_stroke_ended.emit()
	if _is_dragging and selected_element_index >= 0 and selected_element_index < _element_nodes.size():
		drag_ended.emit(selected_element_index, _element_nodes[selected_element_index].position)
	_is_dragging = false
	if _scatter_drawing_zone:
		_scatter_drawing_zone = false
		var gp: Vector3 = _raycast_ground_plane(screen_pos)
		if gp != Vector3.INF:
			_scatter_zone_end = gp
			_compute_scatter_rect()
			_update_scatter_zone_visual()
		scatter_zone_drawn.emit(_scatter_zone_rect)


func _handle_paint_hover(screen_pos: Vector2) -> void:
	if _is_painting:
		_paint_at(screen_pos)
	# Update brush preview position
	var preview_hit: Dictionary = _raycast_terrain(screen_pos)
	if not preview_hit.is_empty():
		var cell: Vector2i = _get_grid_cell(preview_hit["position"])
		_brush_preview.position = Vector3(cell.x + 0.5, 0.02, cell.y + 0.5)
		_brush_preview.visible = true
	else:
		var gp: Vector3 = _raycast_ground_plane(screen_pos)
		if gp != Vector3.INF:
			var cell := Vector2i(int(floorf(gp.x)), int(floorf(gp.z)))
			_brush_preview.position = Vector3(cell.x + 0.5, 0.02, cell.y + 0.5)
			_brush_preview.visible = true
		else:
			_brush_preview.visible = false


func _handle_place_hover(screen_pos: Vector2) -> void:
	if _ghost_preview.visible:
		var gp: Vector3 = _raycast_ground_plane(screen_pos)
		if gp != Vector3.INF:
			_ghost_preview.position = Vector3(snappedf(gp.x, 0.5), 0, snappedf(gp.z, 0.5))


func _handle_drag(screen_pos: Vector2) -> void:
	var gp: Vector3 = _raycast_ground_plane(screen_pos)
	if gp == Vector3.INF:
		return
	var snapped_pos := Vector3(snappedf(gp.x, 0.5), 0, snappedf(gp.z, 0.5))
	if selected_element_index >= 0 and selected_element_index < _element_nodes.size():
		_element_nodes[selected_element_index].position = snapped_pos
		element_moved.emit(selected_element_index, snapped_pos)


func _rotate_selected_element(angle_delta: float) -> void:
	if selected_element_index < 0 or selected_element_index >= _element_nodes.size():
		return
	var node: Node3D = _element_nodes[selected_element_index]
	node.rotation.y += angle_delta
	element_rotated.emit(selected_element_index, node.rotation.y)


func _paint_at(screen_pos: Vector2) -> void:
	# Raycast terrain first; fall back to ground plane (needed for erased areas)
	var center: Vector2i
	var hit: Dictionary = _raycast_terrain(screen_pos)
	if not hit.is_empty():
		center = _get_grid_cell(hit["position"])
	else:
		var gp: Vector3 = _raycast_ground_plane(screen_pos)
		if gp == Vector3.INF:
			return
		center = Vector2i(int(floorf(gp.x)), int(floorf(gp.z)))

	if center == _last_painted_cell:
		return
	_last_painted_cell = center

	var radius: int = brush_size - 1
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			if brush_shape == BrushShape.CIRCLE and dx * dx + dz * dz > radius * radius:
				continue
			var cx: int = center.x + dx
			var cz: int = center.y + dz
			if _terrain_gridmap:
				_terrain_gridmap.set_cell_item(Vector3i(cx, 0, cz), paint_block)
			cell_painted.emit(Vector2i(cx, cz), paint_block)


func _place_at(screen_pos: Vector2) -> void:
	var gp: Vector3 = _raycast_ground_plane(screen_pos)
	if gp == Vector3.INF:
		return
	var snapped := Vector2(snappedf(gp.x, 0.5), snappedf(gp.z, 0.5))
	element_placed.emit(snapped)


func set_terrain_cell(grid_pos: Vector2i, block_type: int) -> void:
	## Update a single terrain cell visually (used by undo/redo).
	if _terrain_gridmap:
		_terrain_gridmap.set_cell_item(Vector3i(grid_pos.x, 0, grid_pos.y), block_type)


# === Scatter tool ===

func _compute_scatter_rect() -> void:
	var min_x: float = minf(_scatter_zone_start.x, _scatter_zone_end.x)
	var max_x: float = maxf(_scatter_zone_start.x, _scatter_zone_end.x)
	var min_z: float = minf(_scatter_zone_start.z, _scatter_zone_end.z)
	var max_z: float = maxf(_scatter_zone_start.z, _scatter_zone_end.z)
	_scatter_zone_rect = Rect2(min_x, min_z, max_x - min_x, max_z - min_z)


func _update_scatter_zone_visual() -> void:
	# Remove old visuals
	if _scatter_zone_mesh and is_instance_valid(_scatter_zone_mesh):
		_scatter_zone_mesh.queue_free()
		_scatter_zone_mesh = null
	if _scatter_zone_border and is_instance_valid(_scatter_zone_border):
		_scatter_zone_border.queue_free()
		_scatter_zone_border = null
	if not _scatter_zone_defined:
		return

	var rect_w: float = _scatter_zone_rect.size.x
	var rect_d: float = _scatter_zone_rect.size.y
	if rect_w < 0.1 and rect_d < 0.1:
		return

	# Semi-transparent fill plane
	_scatter_zone_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(rect_w, rect_d)
	_scatter_zone_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 1.0, 0.15)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	_scatter_zone_mesh.material_override = mat
	var cx: float = _scatter_zone_rect.position.x + rect_w * 0.5
	var cz: float = _scatter_zone_rect.position.y + rect_d * 0.5
	_scatter_zone_mesh.position = Vector3(cx, 0.05, cz)
	_editor_world.add_child(_scatter_zone_mesh)

	# Border strips (4 thin boxes)
	_scatter_zone_border = Node3D.new()
	_scatter_zone_border.name = "ScatterZoneBorder"
	var border_mat := StandardMaterial3D.new()
	border_mat.albedo_color = Color(0.3, 0.7, 1.0, 0.6)
	border_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	border_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	border_mat.no_depth_test = true
	const BORDER_W := 0.08
	const BORDER_H := 0.15
	# Top edge (along X at min Z)
	_add_border_strip(rect_w, BORDER_W, BORDER_H, Vector3(cx, BORDER_H * 0.5, _scatter_zone_rect.position.y), border_mat)
	# Bottom edge (along X at max Z)
	_add_border_strip(rect_w, BORDER_W, BORDER_H, Vector3(cx, BORDER_H * 0.5, _scatter_zone_rect.position.y + rect_d), border_mat)
	# Left edge (along Z at min X)
	_add_border_strip(BORDER_W, rect_d, BORDER_H, Vector3(_scatter_zone_rect.position.x, BORDER_H * 0.5, cz), border_mat)
	# Right edge (along Z at max X)
	_add_border_strip(BORDER_W, rect_d, BORDER_H, Vector3(_scatter_zone_rect.position.x + rect_w, BORDER_H * 0.5, cz), border_mat)
	_editor_world.add_child(_scatter_zone_border)


func _add_border_strip(width: float, depth: float, height: float, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, depth)
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	mesh_inst.position = pos
	_scatter_zone_border.add_child(mesh_inst)


func generate_scatter_preview(seed_val: int, count: int, min_spacing: float,
		asset_paths: Array[String]) -> Array[Dictionary]:
	## Generate preview decorations within the scatter zone.
	clear_scatter_preview()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var placed: Array[Vector3] = []
	var result: Array[Dictionary] = []

	# Collect existing element positions as exclusions
	var exclusions: Array[Vector3] = []
	if map_data:
		for elem in map_data.elements:
			exclusions.append(elem.position)

	var attempts: int = 0
	var max_attempts: int = count * 10
	while result.size() < count and attempts < max_attempts:
		attempts += 1
		var x: float = rng.randf_range(_scatter_zone_rect.position.x,
			_scatter_zone_rect.position.x + _scatter_zone_rect.size.x)
		var z: float = rng.randf_range(_scatter_zone_rect.position.y,
			_scatter_zone_rect.position.y + _scatter_zone_rect.size.y)
		var pos := Vector3(x, 0, z)

		if MapLoader._is_valid_placement(pos, exclusions, placed, min_spacing):
			var path: String = asset_paths[rng.randi_range(0, asset_paths.size() - 1)]
			var rot_y: float = rng.randf_range(0, TAU)
			result.append({"position": pos, "rotation_y": rot_y, "asset_path": path})
			placed.append(pos)

	# Create semi-transparent preview visuals
	for item_data in result:
		var visual: Node3D = _load_decoration_visual(item_data["asset_path"])
		if visual:
			_disable_collisions(visual)
			_apply_ghost_transparency(visual)
			visual.position = item_data["position"]
			visual.rotation.y = item_data["rotation_y"]
			_scatter_preview_parent.add_child(visual)

	_scatter_preview_items = result
	_scatter_has_preview = true
	return result


func clear_scatter_preview() -> void:
	for child in _scatter_preview_parent.get_children():
		child.queue_free()
	_scatter_preview_items.clear()
	_scatter_has_preview = false


func clear_scatter_zone() -> void:
	_scatter_zone_defined = false
	_scatter_zone_rect = Rect2()
	_scatter_drawing_zone = false
	clear_scatter_preview()
	if _scatter_zone_mesh and is_instance_valid(_scatter_zone_mesh):
		_scatter_zone_mesh.queue_free()
		_scatter_zone_mesh = null
	if _scatter_zone_border and is_instance_valid(_scatter_zone_border):
		_scatter_zone_border.queue_free()
		_scatter_zone_border = null


func get_scatter_preview_items() -> Array[Dictionary]:
	return _scatter_preview_items
