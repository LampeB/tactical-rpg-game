@tool
class_name PropScatterZone3D
extends Node3D
## @tool node for scattering props in a defined area on the terrain.
## Shows a wireframe box gizmo in the editor. Provides controls for which
## props to scatter, density, scale, and a Scatter button to generate them.
##
## Workflow: add as sibling of HeightmapTerrain3D, configure, click Scatter.
## Trees/rocks are saved with the scene and can be moved/deleted individually.
## Grass/flowers use MultiMesh for performance.

const _PropRegistry := preload("res://scripts/terrain/prop_registry.gd")

enum PropCategory {
	ALL,           ## Every prop type
	TREES,         ## CommonTree, Pine, DeadTree, TwistedTree
	ROCKS,         ## Rock_Medium, Pebble
	BUSHES,        ## Bush_Common, Bush_Common_Flowers
	GRASS,         ## Grass_Common, Grass_Wispy
	FLOWERS,       ## Flower, Clover, Fern, Plant, Mushroom
	CUSTOM,        ## Use allowed_props list below
}

## Which prop IDs belong to each category
const _CATEGORY_IDS: Dictionary = {
	PropCategory.TREES: [
		"common_tree_1", "common_tree_2", "common_tree_3", "common_tree_4", "common_tree_5",
		"pine_1", "pine_2", "pine_3",
		"dead_tree_1", "dead_tree_2",
		"twisted_tree_1", "twisted_tree_2",
	],
	PropCategory.ROCKS: [
		"rock_medium_1", "rock_medium_2", "rock_medium_3",
		"pebble_1", "pebble_2", "pebble_3",
	],
	PropCategory.BUSHES: [
		"bush_common", "bush_flowers",
	],
	PropCategory.GRASS: [
		"grass_short", "grass_tall", "grass_wispy_short", "grass_wispy_tall",
	],
	PropCategory.FLOWERS: [
		"flower_3_group", "flower_4_group",
		"clover_1", "clover_2", "fern_1", "plant_1", "mushroom",
	],
}


@export var zone_size: Vector2 = Vector2(20, 20):
	set(value):
		zone_size = value
		if is_inside_tree() and Engine.is_editor_hint():
			_rebuild_gizmo()

@export var scatter_seed: int = 42

@export_group("Prop Selection")
## Category of props to scatter. Use CUSTOM + allowed_props for fine control.
@export var prop_category: PropCategory = PropCategory.TREES
## For CUSTOM category: list specific prop IDs to include.
## Available IDs: common_tree_1-5, pine_1-3, dead_tree_1-2, twisted_tree_1-2,
## rock_medium_1-3, bush_common, bush_flowers, grass_short, grass_tall,
## grass_wispy_short, grass_wispy_tall, flower_3_group, flower_4_group,
## clover_1-2, fern_1, plant_1, mushroom, pebble_1-3
@export var allowed_props: PackedStringArray = PackedStringArray()
## Prop IDs to exclude (applied after category/allowed filtering).
@export var excluded_props: PackedStringArray = PackedStringArray()

@export_group("Density & Scale")
## Multiplier applied to each prop's default density. 0.5 = half, 2.0 = double.
@export_range(0.01, 10.0, 0.01) var density_multiplier: float = 1.0
## Override minimum scale for all props (-1 = use each prop's default).
@export var min_scale_override: float = -1.0
## Override maximum scale for all props (-1 = use each prop's default).
@export var max_scale_override: float = -1.0
## Check splatmap layer compatibility (disable to place props anywhere).
@export var check_splatmap: bool = true

@export_group("Actions")
## Click to scatter props within this zone. Replaces any existing scattered props.
@export var do_scatter: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_do_scatter()
## Click to remove all scattered props from this zone.
@export var do_clear: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_do_clear()


var _gizmo_mesh: MeshInstance3D = null
var _label: Label3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_gizmo()
	else:
		# Remove editor-only gizmo nodes that were saved in the .tscn
		_clear_gizmo()


# ---------------------------------------------------------------------------
# Scatter logic
# ---------------------------------------------------------------------------

func _do_scatter() -> void:
	_do_clear()

	var terrain_node: Node3D = _find_terrain_node()
	if not terrain_node:
		printerr("[PropScatterZone3D] No HeightmapTerrain3D with data found — generate terrain first")
		return

	var hdata: HeightmapData = terrain_node.get("heightmap_data") as HeightmapData
	var terrain_pos: Vector3 = terrain_node.global_position
	# Terrain may be rotated/scaled — inverse transform converts world → terrain local
	var terrain_inv: Transform3D = terrain_node.global_transform.affine_inverse()

	var filtered_props: Array = _get_filtered_props()
	if filtered_props.is_empty():
		printerr("[PropScatterZone3D] No props match the current category/filters")
		return

	var scene_root: Node = get_tree().edited_scene_root
	var scattered := Node3D.new()
	scattered.name = "Scattered"
	add_child(scattered)
	scattered.owner = scene_root

	var tscale: Vector3 = hdata.terrain_scale
	var half_x: float = zone_size.x * 0.5
	var half_z: float = zone_size.y * 0.5
	var zone_area: float = zone_size.x * zone_size.y
	var zone_center: Vector3 = global_position
	var zone_xform: Transform3D = global_transform
	var zone_scale_y: float = zone_xform.basis.y.length()

	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed

	var blocking_count: int = 0
	var visual_groups: int = 0

	for pi in range(filtered_props.size()):
		var prop: PropDefinition = filtered_props[pi]

		if not ResourceLoader.exists(prop.scene_path):
			continue

		# Calculate instance count
		var expected: float = prop.density * density_multiplier * zone_area
		var count: int = int(expected)
		if rng.randf() < (expected - float(count)):
			count += 1
		if count <= 0:
			continue

		var min_s: float = prop.min_scale if min_scale_override < 0.0 else min_scale_override
		var max_s: float = prop.max_scale if max_scale_override < 0.0 else max_scale_override

		# Blocking props: individual scene instances (selectable/moveable)
		if prop.collision_type == PropDefinition.CollisionType.BLOCKING:
			var scene: PackedScene = load(prop.scene_path) as PackedScene
			if not scene:
				continue

			# Cache the model's bottom Y offset (mesh origin may not be at base)
			var bottom_y: float = _get_cached_bottom_y(prop.scene_path, scene)

			for _i in range(count):
				var local_x: float = rng.randf_range(-half_x, half_x)
				var local_z: float = rng.randf_range(-half_z, half_z)
				# Convert local position to world space (accounts for zone scale/rotation)
				var world_pt: Vector3 = zone_xform * Vector3(local_x, 0.0, local_z)
				# Convert world point to terrain local space (accounts for terrain rotation)
				var terrain_local: Vector3 = terrain_inv * world_pt

				# Splatmap check (in terrain local coords)
				var vx: int = clampi(roundi(terrain_local.x / tscale.x), 0, hdata.width - 1)
				var vz: int = clampi(roundi(terrain_local.z / tscale.z), 0, hdata.height - 1)
				if check_splatmap:
					var weights: Color = hdata.get_splatmap_weights(vx, vz)
					var layer: int = _get_dominant_layer(weights)
					if not (prop.allowed_layers & (1 << layer)):
						continue

				# Skip river channels
				if hdata.is_river_at(vx, vz):
					continue

				# Terrain height in terrain local space, then convert to world Y
				var h_local: float = _sample_height(hdata, terrain_local.x, terrain_local.z)
				# Transform terrain-local height back to world Y (handles rotation + position)
				var h_world: float = (terrain_node.global_transform * Vector3(terrain_local.x, h_local, terrain_local.z)).y
				var s: float = rng.randf_range(min_s, max_s)
				var rot_y: float = rng.randf_range(0.0, TAU) if prop.random_rotation_y else 0.0
				var y_offset: float = (h_world - global_position.y) / zone_scale_y - bottom_y * s

				var instance: Node3D = scene.instantiate() as Node3D
				if not instance:
					continue

				instance.name = "%s_%d" % [prop.id, blocking_count]
				# Position relative to zone (children inherit zone's transform)
				instance.position = Vector3(local_x, y_offset, local_z)
				instance.rotation.y = rot_y
				instance.scale = Vector3(s, s, s)
				scattered.add_child(instance)
				# Set scene_file_path so Godot saves as external scene reference.
				# Then set owner so it's included in the .tscn.
				# Children keep their original names within their own instance
				# scope, preventing name-conflict warnings on reload.
				instance.scene_file_path = prop.scene_path
				instance.owner = scene_root
				blocking_count += 1

		# Visual props (grass, flowers): MultiMesh for performance
		else:
			# Cache bottom Y for this visual prop mesh
			var bottom_y: float = _get_cached_bottom_y(prop.scene_path, null)
			var transforms: Array[Transform3D] = []
			for _i in range(count):
				var local_x: float = rng.randf_range(-half_x, half_x)
				var local_z: float = rng.randf_range(-half_z, half_z)
				# Convert local position to world space (accounts for zone scale/rotation)
				var world_pt: Vector3 = zone_xform * Vector3(local_x, 0.0, local_z)
				# Convert world point to terrain local space (accounts for terrain rotation)
				var terrain_local: Vector3 = terrain_inv * world_pt

				var vx: int = clampi(roundi(terrain_local.x / tscale.x), 0, hdata.width - 1)
				var vz: int = clampi(roundi(terrain_local.z / tscale.z), 0, hdata.height - 1)
				if check_splatmap:
					var weights: Color = hdata.get_splatmap_weights(vx, vz)
					var layer: int = _get_dominant_layer(weights)
					if not (prop.allowed_layers & (1 << layer)):
						continue

				# Skip river channels
				if hdata.is_river_at(vx, vz):
					continue

				var h_local: float = _sample_height(hdata, terrain_local.x, terrain_local.z)
				# Transform terrain-local height back to world Y (handles rotation + position)
				var h_world: float = (terrain_node.global_transform * Vector3(terrain_local.x, h_local, terrain_local.z)).y
				var s: float = rng.randf_range(min_s, max_s)
				var rot_y: float = rng.randf_range(0.0, TAU) if prop.random_rotation_y else 0.0
				var y_offset: float = (h_world - global_position.y) / zone_scale_y - bottom_y * s

				var xform := Transform3D.IDENTITY
				xform = xform.scaled(Vector3(s, s, s))
				xform = xform.rotated(Vector3.UP, rot_y)
				# Position relative to zone (MultiMesh is child of zone)
				xform.origin = Vector3(local_x, y_offset, local_z)
				transforms.append(xform)

			if transforms.is_empty():
				continue

			var mmi: MultiMeshInstance3D = _create_multimesh(prop.scene_path, transforms)
			if mmi:
				mmi.name = "mm_%s" % prop.id
				scattered.add_child(mmi)
				mmi.owner = scene_root
				visual_groups += 1

	print("[PropScatterZone3D] '%s': %d trees/rocks, %d grass groups (terrain at %s, zone at %s)" % [
		name, blocking_count, visual_groups, terrain_pos, global_position])


func _do_clear() -> void:
	var scattered: Node = get_node_or_null("Scattered")
	if scattered:
		scattered.queue_free()


func _get_filtered_props() -> Array:
	## Returns PropDefinitions matching the current category and filters.
	var all_props: Array[PropDefinition] = _PropRegistry.get_all()
	var result: Array = []

	# Build allowed ID set based on category
	var category_ids: Array = []
	if prop_category == PropCategory.ALL:
		pass  # No category filter
	elif prop_category == PropCategory.CUSTOM:
		for i in range(allowed_props.size()):
			category_ids.append(allowed_props[i])
	elif _CATEGORY_IDS.has(prop_category):
		category_ids = _CATEGORY_IDS[prop_category]

	for pi in range(all_props.size()):
		var prop: PropDefinition = all_props[pi]

		# Category filter
		if prop_category != PropCategory.ALL:
			var found: bool = false
			for ci in range(category_ids.size()):
				if category_ids[ci] == prop.id:
					found = true
					break
			if not found:
				continue

		# Exclusion filter
		var excluded: bool = false
		for ei in range(excluded_props.size()):
			if excluded_props[ei] == prop.id:
				excluded = true
				break
		if excluded:
			continue

		result.append(prop)

	return result


func _find_terrain_node() -> Node3D:
	## Searches siblings and ancestors for a HeightmapTerrain3D node.
	var parent: Node = get_parent()
	while parent:
		for i in range(parent.get_child_count()):
			var sibling: Node = parent.get_child(i)
			if sibling == self:
				continue
			var script: Script = sibling.get_script() as Script
			if script and script.get_global_name() == "HeightmapTerrain3D":
				if sibling.get("heightmap_data"):
					return sibling as Node3D
		parent = parent.get_parent()
	return null


func _sample_height(hdata: HeightmapData, local_x: float, local_z: float) -> float:
	## Triangle interpolation of terrain height matching HeightmapChunk mesh topology.
	## Uses the same diagonal split (top_right → bot_left) as the terrain mesh triangles.
	var tscale: Vector3 = hdata.terrain_scale
	var lx: float = local_x / tscale.x
	var lz: float = local_z / tscale.z
	var ix: int = clampi(floori(lx), 0, hdata.width - 2)
	var iz: int = clampi(floori(lz), 0, hdata.height - 2)
	var fx: float = clampf(lx - float(ix), 0.0, 1.0)
	var fz: float = clampf(lz - float(iz), 0.0, 1.0)
	var h00: float = hdata.get_height_at(ix, iz) * tscale.y
	var h10: float = hdata.get_height_at(ix + 1, iz) * tscale.y
	var h01: float = hdata.get_height_at(ix, iz + 1) * tscale.y
	var h11: float = hdata.get_height_at(ix + 1, iz + 1) * tscale.y
	# Match HeightmapChunk triangle split: diagonal from (ix+1,iz) to (ix,iz+1)
	if fx + fz <= 1.0:
		# Lower-left triangle: vertices h00, h10, h01
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	else:
		# Upper-right triangle: vertices h10, h11, h01
		return h10 + (fx + fz - 1.0) * (h11 - h10) + (1.0 - fx) * (h01 - h10)


static func _get_dominant_layer(weights: Color) -> int:
	var max_w: float = weights.r
	var layer: int = 0
	if weights.g > max_w:
		max_w = weights.g
		layer = 1
	if weights.b > max_w:
		max_w = weights.b
		layer = 2
	if weights.a > max_w:
		layer = 3
	return layer


var _bottom_y_cache: Dictionary = {}  ## scene_path -> float


func _get_cached_bottom_y(scene_path: String, scene: PackedScene) -> float:
	## Returns the minimum Y of the model's mesh AABB (how far below origin the base is).
	## Cached per scene_path so each model is only inspected once.
	if _bottom_y_cache.has(scene_path):
		return _bottom_y_cache[scene_path]

	var loaded_scene: PackedScene = scene if scene else load(scene_path) as PackedScene
	if not loaded_scene:
		_bottom_y_cache[scene_path] = 0.0
		return 0.0

	var temp: Node3D = loaded_scene.instantiate() as Node3D
	if not temp:
		_bottom_y_cache[scene_path] = 0.0
		return 0.0

	var min_y: float = _find_mesh_min_y(temp, Transform3D.IDENTITY)
	temp.queue_free()
	_bottom_y_cache[scene_path] = min_y
	return min_y


func _find_mesh_min_y(node: Node, parent_xform: Transform3D) -> float:
	## Recursively finds the lowest Y point across all meshes in a scene.
	var xform: Transform3D = parent_xform
	if node is Node3D:
		xform = parent_xform * (node as Node3D).transform

	var min_y: float = 0.0
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh:
			var aabb: AABB = mi.mesh.get_aabb()
			# Check all 4 bottom corners of the AABB in root space
			var corners: Array[Vector3] = [
				xform * Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
				xform * Vector3(aabb.end.x, aabb.position.y, aabb.position.z),
				xform * Vector3(aabb.position.x, aabb.position.y, aabb.end.z),
				xform * Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
			]
			for ci in range(corners.size()):
				if corners[ci].y < min_y:
					min_y = corners[ci].y

	for i in range(node.get_child_count()):
		var child_min: float = _find_mesh_min_y(node.get_child(i), xform)
		if child_min < min_y:
			min_y = child_min
	return min_y


func _create_multimesh(scene_path: String, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	## Creates a MultiMeshInstance3D from a scene and transforms.
	var scene: PackedScene = load(scene_path) as PackedScene
	if not scene:
		return null

	var temp: Node3D = scene.instantiate() as Node3D
	if not temp:
		return null
	var source_mesh: Mesh = _find_mesh_in_node(temp)
	if not source_mesh:
		temp.queue_free()
		return null

	var mesh_copy: Mesh = source_mesh.duplicate()
	temp.queue_free()

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = transforms.size()
	mm.mesh = mesh_copy

	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.extra_cull_margin = 16.0
	return mmi


static func _find_mesh_in_node(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return node.mesh
	for i in range(node.get_child_count()):
		var result: Mesh = _find_mesh_in_node(node.get_child(i))
		if result:
			return result
	return null


func _uniquify_children(node: Node, idx: int) -> void:
	## Appends an index suffix to all children of a scene instance to prevent
	## Godot name-conflict warnings when multiple copies of the same .gltf exist.
	for i in range(node.get_child_count()):
		var child: Node = node.get_child(i)
		child.name = "%s_%d" % [child.name, idx]
		_uniquify_children(child, idx)


# ---------------------------------------------------------------------------
# Runtime API
# ---------------------------------------------------------------------------

func get_zone_rect() -> Rect2:
	## Returns the world-space XZ rectangle of this zone.
	var center_xz := Vector2(global_position.x, global_position.z)
	var half := zone_size * 0.5
	return Rect2(center_xz - half, zone_size)


func contains_world_pos(world_pos: Vector3) -> bool:
	var dx: float = absf(world_pos.x - global_position.x)
	var dz: float = absf(world_pos.z - global_position.z)
	return dx <= zone_size.x * 0.5 and dz <= zone_size.y * 0.5


func is_prop_allowed(prop_id: String) -> bool:
	## Returns true if the given prop is allowed by this zone's filters.
	if not excluded_props.is_empty():
		for i in range(excluded_props.size()):
			if excluded_props[i] == prop_id:
				return false
	if not allowed_props.is_empty():
		for i in range(allowed_props.size()):
			if allowed_props[i] == prop_id:
				return true
		return false  # Not in allowed list
	return true  # No filters = allow all


# ---------------------------------------------------------------------------
# Editor gizmo
# ---------------------------------------------------------------------------

func _rebuild_gizmo() -> void:
	if not Engine.is_editor_hint():
		return
	_clear_gizmo()

	# Wireframe box outline using ImmediateMesh
	var im := ImmediateMesh.new()
	var hx: float = zone_size.x * 0.5
	var hz: float = zone_size.y * 0.5
	var h: float = 2.0  # Visual height of the box

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	# Bottom rectangle
	im.surface_add_vertex(Vector3(-hx, 0, -hz))
	im.surface_add_vertex(Vector3(hx, 0, -hz))
	im.surface_add_vertex(Vector3(hx, 0, -hz))
	im.surface_add_vertex(Vector3(hx, 0, hz))
	im.surface_add_vertex(Vector3(hx, 0, hz))
	im.surface_add_vertex(Vector3(-hx, 0, hz))
	im.surface_add_vertex(Vector3(-hx, 0, hz))
	im.surface_add_vertex(Vector3(-hx, 0, -hz))
	# Top rectangle
	im.surface_add_vertex(Vector3(-hx, h, -hz))
	im.surface_add_vertex(Vector3(hx, h, -hz))
	im.surface_add_vertex(Vector3(hx, h, -hz))
	im.surface_add_vertex(Vector3(hx, h, hz))
	im.surface_add_vertex(Vector3(hx, h, hz))
	im.surface_add_vertex(Vector3(-hx, h, hz))
	im.surface_add_vertex(Vector3(-hx, h, hz))
	im.surface_add_vertex(Vector3(-hx, h, -hz))
	# Vertical edges
	im.surface_add_vertex(Vector3(-hx, 0, -hz))
	im.surface_add_vertex(Vector3(-hx, h, -hz))
	im.surface_add_vertex(Vector3(hx, 0, -hz))
	im.surface_add_vertex(Vector3(hx, h, -hz))
	im.surface_add_vertex(Vector3(hx, 0, hz))
	im.surface_add_vertex(Vector3(hx, h, hz))
	im.surface_add_vertex(Vector3(-hx, 0, hz))
	im.surface_add_vertex(Vector3(-hx, h, hz))
	im.surface_end()

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.9, 0.3, 0.6)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true

	_gizmo_mesh = MeshInstance3D.new()
	_gizmo_mesh.mesh = im
	_gizmo_mesh.material_override = mat
	_gizmo_mesh.name = "EditorGizmo"
	add_child(_gizmo_mesh)

	var cat_name: String = PropCategory.keys()[prop_category]
	_label = Label3D.new()
	_label.text = "Prop Zone: %s (%.0fx%.0f, x%.1f)" % [cat_name, zone_size.x, zone_size.y, density_multiplier]
	_label.font_size = 20
	_label.modulate = Color(0.4, 1.0, 0.4)
	_label.position.y = h + 0.5
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.name = "EditorLabel"
	add_child(_label)


func _clear_gizmo() -> void:
	if _gizmo_mesh and is_instance_valid(_gizmo_mesh):
		_gizmo_mesh.queue_free()
		_gizmo_mesh = null
	# Also remove by name — variables are null after scene load but nodes persist in .tscn
	var saved_gizmo: Node = get_node_or_null("EditorGizmo")
	if saved_gizmo:
		saved_gizmo.queue_free()
	if _label and is_instance_valid(_label):
		_label.queue_free()
		_label = null
	var saved_label: Node = get_node_or_null("EditorLabel")
	if saved_label:
		saved_label.queue_free()
