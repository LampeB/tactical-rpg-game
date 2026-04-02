class_name MapLoader
extends RefCounted
## Static utility that converts a MapData resource into runtime 3D scene nodes.
## Used by overworld.gd to build the world from data instead of hardcoded values.

# Block colors indexed by Enums.Block values
const BLOCK_COLORS: Array[Color] = [
	Color(0.35, 0.55, 0.25, 1.0),  # 0 Grass
	Color(0.45, 0.32, 0.18, 1.0),  # 1 Dirt
	Color(0.5, 0.5, 0.5, 1.0),     # 2 Stone
	Color(0.2, 0.4, 0.8, 0.7),     # 3 Water
	Color(0.6, 0.5, 0.35, 1.0),    # 4 Path
	Color(0.85, 0.77, 0.55, 1.0),  # 5 Sand
	Color(0.25, 0.4, 0.2, 1.0),    # 6 DarkGrass
	Color(0.9, 0.9, 0.95, 1.0),    # 7 Snow
]

const BLOCK_NAMES: Array[String] = [
	"Grass", "Dirt", "Stone", "Water", "Path", "Sand", "DarkGrass", "Snow"
]

# Marker scene paths
const _LOCATION_MARKER := "res://scenes/world/location_marker.tscn"
const _NPC_MARKER := "res://scenes/world/npc_marker.tscn"
const _ROAMING_ENEMY := "res://scenes/world/roaming_enemy.tscn"
const _CHEST_MARKER := "res://scenes/world/chest_marker.tscn"
const _CONNECTION_MARKER := "res://scenes/world/connection_marker.tscn"

# Cached preloads for markers
static var _location_marker_scene: PackedScene
static var _npc_marker_scene: PackedScene
static var _roaming_enemy_scene: PackedScene
static var _chest_marker_scene: PackedScene
static var _connection_marker_scene: PackedScene


static func _ensure_scenes_loaded() -> void:
	if not _location_marker_scene:
		_location_marker_scene = load(_LOCATION_MARKER)
	if not _npc_marker_scene:
		_npc_marker_scene = load(_NPC_MARKER)
	if not _roaming_enemy_scene:
		_roaming_enemy_scene = load(_ROAMING_ENEMY)
	if not _chest_marker_scene:
		_chest_marker_scene = load(_CHEST_MARKER)
	if not _connection_marker_scene:
		_connection_marker_scene = load(_CONNECTION_MARKER)


static func build_terrain(map_data: MapData, parent: Node3D) -> GridMap:
	## Creates and populates a GridMap from map_data terrain cells, adds it to parent.
	var grid: GridMap = build_terrain_node(map_data)
	parent.add_child(grid)
	DebugLogger.log_info("Built GridMap terrain: %dx%d cells" % [map_data.grid_width, map_data.grid_height], "MapLoader")
	return grid


static func build_terrain_node(map_data: MapData) -> GridMap:
	## Creates a detached GridMap from map_data terrain cells (not added to any parent).
	## Used by MapCache for background preloading.
	var lib := _create_mesh_library()
	for i in BLOCK_COLORS.size():
		var col_shape := BoxShape3D.new()
		col_shape.size = Vector3(1, 1, 1)
		lib.set_item_shapes(i, [col_shape, Transform3D.IDENTITY])

	var grid := GridMap.new()
	grid.name = "Terrain"
	grid.mesh_library = lib
	grid.cell_size = Vector3(1, 1, 1)
	grid.collision_layer = 1
	grid.collision_mask = 0
	grid.position.y = -1.0  # cell_center_y offsets by +0.5; box top at Y=0

	var has_heights: bool = not map_data.terrain_heights.is_empty()
	for x in range(map_data.grid_width):
		for z in range(map_data.grid_height):
			var y_level: int = map_data.get_height_at(x, z) if has_heights else 0
			grid.set_cell_item(Vector3i(x, y_level, z), map_data.get_terrain_at(x, z))

	# Load extra terrain blocks (multi-level)
	var extra_keys: Array = map_data.extra_terrain.keys()
	for i in range(extra_keys.size()):
		var k: String = extra_keys[i]
		var parts: PackedStringArray = k.split(",")
		if parts.size() == 3:
			var ex: int = parts[0].to_int()
			var ey: int = parts[1].to_int()
			var ez: int = parts[2].to_int()
			var block_type: int = map_data.extra_terrain[k] as int
			grid.set_cell_item(Vector3i(ex, ey, ez), block_type)

	return grid


static func spawn_elements(map_data: MapData, parent: Node3D,
		location_parent: Node3D, enemy_parent: Node3D, chest_parent: Node3D) -> void:
	## Instantiates all MapElement entries as their respective scene types.
	_ensure_scenes_loaded()

	for elem in map_data.elements:
		var etype: int = elem.element_type
		# Fix mismatched types: scene paths stored as NPC (editor bug, Godot default-value quirk)
		if etype == MapElement.ElementType.NPC and not elem.resource_id.is_empty():
			if elem.resource_id.ends_with(".tscn"):
				etype = MapElement.ElementType.DECORATION
		match etype:
			MapElement.ElementType.LOCATION:
				_spawn_location(elem, location_parent)
			MapElement.ElementType.NPC:
				_spawn_npc(elem, parent)
			MapElement.ElementType.ENEMY:
				_spawn_enemy(elem, enemy_parent)
			MapElement.ElementType.CHEST:
				_spawn_chest(elem, chest_parent)
			MapElement.ElementType.DECORATION, MapElement.ElementType.SIGN, MapElement.ElementType.FENCE:
				_spawn_decoration(elem, parent)

	DebugLogger.log_info("Spawned %d elements" % map_data.elements.size(), "MapLoader")


static func spawn_connections(map_data: MapData, parent: Node3D) -> void:
	## Instantiates ConnectionMarker nodes for each MapConnection in the map data.
	_ensure_scenes_loaded()
	for conn in map_data.connections:
		var marker: Node3D = _connection_marker_scene.instantiate()
		marker.position = conn.position
		marker.connection_data = conn
		parent.add_child(marker)
	if map_data.connections.size() > 0:
		DebugLogger.log_info("Spawned %d connections" % map_data.connections.size(), "MapLoader")


static func _spawn_location(elem: MapElement, parent: Node3D) -> void:
	var marker: Node3D = _location_marker_scene.instantiate()
	marker.position = elem.position
	# Load and assign LocationData resource
	if not elem.resource_id.is_empty():
		var loc_data: LocationData = load(elem.resource_id) as LocationData
		if loc_data:
			marker.location_data = loc_data
	parent.add_child(marker)


static func _spawn_npc(elem: MapElement, parent: Node3D) -> void:
	var marker: Node3D = _npc_marker_scene.instantiate()
	marker.position = elem.position
	if elem.rotation_y != 0.0:
		marker.rotation.y = elem.rotation_y
	if elem.scale_factor != 1.0:
		marker.scale = Vector3.ONE * elem.scale_factor
	marker.npc_id = elem.resource_id
	if elem.patrol_distance > 0.0:
		marker.patrol_distance = elem.patrol_distance
	parent.add_child(marker)


static func _spawn_enemy(elem: MapElement, parent: Node3D) -> void:
	var enemy: Node3D = _roaming_enemy_scene.instantiate()
	enemy.position = elem.position
	if not elem.resource_id.is_empty():
		var enc_data: EncounterData = load(elem.resource_id) as EncounterData
		if enc_data:
			enemy.encounter_data = enc_data
	enemy.enemy_color = elem.enemy_color
	enemy.patrol_distance = elem.patrol_distance
	if elem.scale_factor != 1.0:
		enemy.scale = Vector3.ONE * elem.scale_factor
	parent.add_child(enemy)


static func _spawn_chest(elem: MapElement, parent: Node3D) -> void:
	var chest: Node3D = _chest_marker_scene.instantiate()
	chest.position = elem.position
	if elem.rotation_y != 0.0:
		chest.rotation.y = elem.rotation_y
	chest.chest_id = elem.resource_id
	if elem.scale_factor != 1.0:
		chest.scale = Vector3.ONE * elem.scale_factor
	parent.add_child(chest)


static func _spawn_decoration(elem: MapElement, parent: Node3D) -> void:
	if elem.resource_id.is_empty() or not ResourceLoader.exists(elem.resource_id):
		return
	var scene: PackedScene = load(elem.resource_id) as PackedScene
	if not scene:
		return
	var obj: Node3D = scene.instantiate()
	obj.position = elem.position
	if elem.rotation_y != 0.0:
		obj.rotation.y = elem.rotation_y
	if elem.scale_factor != 1.0:
		obj.scale = Vector3.ONE * elem.scale_factor
	obj.add_to_group("occludable")
	parent.add_child(obj)


static func spawn_decoration_zones(map_data: MapData, parent: Node3D,
		exclusions: Array[Vector3]) -> Node3D:
	## Procedurally scatters decorations from zone definitions using seeded RNG.
	## Returns the Decorations parent node.
	var decorations := Node3D.new()
	decorations.name = "Decorations"

	var rng := RandomNumberGenerator.new()
	rng.seed = map_data.decoration_seed
	var all_placed: Array[Vector3] = []

	for zone in map_data.decoration_zones:
		if zone.decoration_scenes.is_empty():
			continue

		var placed_in_zone: int = 0
		var attempts: int = 0
		var max_attempts: int = zone.count * 10

		while placed_in_zone < zone.count and attempts < max_attempts:
			attempts += 1
			var x: float = rng.randf_range(zone.rect.position.x, zone.rect.position.x + zone.rect.size.x)
			var z: float = rng.randf_range(zone.rect.position.y, zone.rect.position.y + zone.rect.size.y)
			var pos := Vector3(x, 0, z)

			if _is_valid_placement(pos, exclusions, all_placed, zone.min_spacing):
				var scene_path: String = zone.decoration_scenes[rng.randi_range(0, zone.decoration_scenes.size() - 1)]
				var scene: PackedScene = load(scene_path) as PackedScene
				if scene:
					var obj: Node3D = scene.instantiate()
					obj.position = pos
					obj.rotation.y = rng.randf_range(0, TAU)
					obj.add_to_group("occludable")
					decorations.add_child(obj)
					all_placed.append(pos)
					placed_in_zone += 1

	parent.add_child(decorations)
	DebugLogger.log_info("Scattered %d decorations across %d zones" % [decorations.get_child_count(), map_data.decoration_zones.size()], "MapLoader")
	return decorations


static func _is_valid_placement(pos: Vector3, exclusions: Array[Vector3],
		placed_list: Array[Vector3], min_spacing: float) -> bool:
	const EXCLUSION_RADIUS := 2.5
	var excl_sq: float = EXCLUSION_RADIUS * EXCLUSION_RADIUS
	var spacing_sq: float = min_spacing * min_spacing

	for excl in exclusions:
		var dx: float = pos.x - excl.x
		var dz: float = pos.z - excl.z
		if dx * dx + dz * dz < excl_sq:
			return false

	for p in placed_list:
		var dx: float = pos.x - p.x
		var dz: float = pos.z - p.z
		if dx * dx + dz * dz < spacing_sq:
			return false

	return true


static func get_safe_zones(map_data: MapData) -> Array[Rect2]:
	## Returns enemy safe zones from map data.
	return map_data.enemy_safe_zones


# === Battle Background ===

## Scene path substrings for blocking decorations removed from the battle arena circle.
const _BATTLE_BLOCKING_PATTERNS: Array[String] = [
	"trunk", "canop", "tree_", "rock", "bush",
	"house", "fence", "door", "roof", "window",
	"chest", "lamppost", "statue",
	"table", "chair", "bed", "couch", "desk", "wardrobe",
]


static func build_battle_background(map_data: MapData, battle_area: BattleAreaData) -> Node3D:
	## Builds the full map as a 3D battle background, clearing large decorations
	## within the arena circle around the battle area position.
	var root := Node3D.new()
	root.name = "BattleBackground"

	var arena_pos: Vector3 = battle_area.position
	var arena_radius_sq: float = BattleAreaData.ARENA_RADIUS * BattleAreaData.ARENA_RADIUS

	# --- Full terrain GridMap ---
	var lib := _create_mesh_library()
	var grid := GridMap.new()
	grid.name = "BattleTerrain"
	grid.mesh_library = lib
	grid.cell_size = Vector3(1, 1, 1)
	grid.collision_layer = 0
	grid.collision_mask = 0

	var battle_has_heights: bool = not map_data.terrain_heights.is_empty()
	for x in range(map_data.grid_width):
		for z in range(map_data.grid_height):
			var y_level: int = map_data.get_height_at(x, z) if battle_has_heights else 0
			grid.set_cell_item(Vector3i(x, y_level, z), map_data.get_terrain_at(x, z))

	grid.position.y = -1.0  # cell top at Y=0
	root.add_child(grid)

	# --- Placed decorations (skip blocking ones inside arena) ---
	for elem in map_data.elements:
		var etype: int = elem.element_type
		if etype == MapElement.ElementType.NPC and not elem.resource_id.is_empty():
			if elem.resource_id.ends_with(".tscn"):
				etype = MapElement.ElementType.DECORATION
		if etype != MapElement.ElementType.DECORATION and etype != MapElement.ElementType.SIGN and etype != MapElement.ElementType.FENCE:
			continue
		# Inside arena circle: skip blocking decorations
		if _is_in_arena(elem.position, arena_pos, arena_radius_sq) and _is_blocking_decoration(elem.resource_id):
			continue
		var obj: Node3D = _instantiate_decoration(elem.resource_id)
		if not obj:
			continue
		obj.position = elem.position
		if elem.rotation_y != 0.0:
			obj.rotation.y = elem.rotation_y
		if elem.scale_factor != 1.0:
			obj.scale = Vector3.ONE * elem.scale_factor
		root.add_child(obj)

	# --- Procedural decorations (skip blocking ones inside arena) ---
	var rng := RandomNumberGenerator.new()
	rng.seed = map_data.decoration_seed
	for zone in map_data.decoration_zones:
		if zone.decoration_scenes.is_empty():
			continue
		var placed_in_zone: int = 0
		var attempts: int = 0
		var max_attempts: int = zone.count * 10
		while placed_in_zone < zone.count and attempts < max_attempts:
			attempts += 1
			var x: float = rng.randf_range(zone.rect.position.x, zone.rect.position.x + zone.rect.size.x)
			var z: float = rng.randf_range(zone.rect.position.y, zone.rect.position.y + zone.rect.size.y)
			var scene_path: String = zone.decoration_scenes[rng.randi_range(0, zone.decoration_scenes.size() - 1)]
			var rot_y: float = rng.randf_range(0, TAU)
			# Inside arena circle: skip blocking decorations
			var pos := Vector3(x, 0, z)
			if _is_in_arena(pos, arena_pos, arena_radius_sq) and _is_blocking_decoration(scene_path):
				placed_in_zone += 1
				continue
			if ResourceLoader.exists(scene_path):
				var scene: PackedScene = load(scene_path) as PackedScene
				if scene:
					var obj: Node3D = scene.instantiate()
					obj.position = pos
					obj.rotation.y = rot_y
					root.add_child(obj)
			placed_in_zone += 1

	return root


static func find_nearest_battle_area(map_data: MapData, fight_pos: Vector3) -> BattleAreaData:
	## Returns the battle area closest to the fight position, or null if none exist.
	if map_data.battle_areas.is_empty():
		return null
	var best: BattleAreaData = null
	var best_dist: float = INF
	for area in map_data.battle_areas:
		var dist: float = fight_pos.distance_squared_to(area.position)
		if dist < best_dist:
			best_dist = dist
			best = area
	return best


static func _create_mesh_library() -> MeshLibrary:
	## Creates the standard terrain MeshLibrary (shared between overworld and battle).
	var lib := MeshLibrary.new()
	for i in BLOCK_COLORS.size():
		lib.create_item(i)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1, 1, 1)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = BLOCK_COLORS[i]
		if BLOCK_COLORS[i].a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = mat
		lib.set_item_mesh(i, mesh)
	return lib


static func _is_in_arena(pos: Vector3, arena_center: Vector3, radius_sq: float) -> bool:
	var dx: float = pos.x - arena_center.x
	var dz: float = pos.z - arena_center.z
	return dx * dx + dz * dz <= radius_sq


static func _is_blocking_decoration(scene_path: String) -> bool:
	## Returns true if the decoration is large enough to block combat view.
	var lower: String = scene_path.to_lower()
	for pattern in _BATTLE_BLOCKING_PATTERNS:
		if lower.contains(pattern):
			return true
	return false


static func _instantiate_decoration(resource_id: String) -> Node3D:
	## Loads and instantiates a decoration from its resource path.
	if resource_id.is_empty() or not ResourceLoader.exists(resource_id):
		return null
	var scene: PackedScene = load(resource_id) as PackedScene
	if not scene:
		return null
	return scene.instantiate()


# === Heightmap Battle Background ===

const _BATTLE_PATCH_RADIUS := 50.0  ## Half-size of terrain patch around arena (world units)
const _BATTLE_TERRAIN_SHADER := "res://shaders/terrain_splatmap.gdshader"


static func build_heightmap_battle_background(
	heightmap: HeightmapData, arena_pos: Vector3, _arena_rotation_y: float
) -> Node3D:
	## Builds a battle background from heightmap terrain around the arena position.
	## Returns a Node3D containing a terrain mesh patch and scattered props.
	var root := Node3D.new()
	root.name = "BattleBackground"

	var arena_radius_sq: float = BattleAreaData.ARENA_RADIUS * BattleAreaData.ARENA_RADIUS

	# --- Terrain mesh patch ---
	var terrain_mesh: MeshInstance3D = _build_battle_terrain_patch(heightmap, arena_pos)
	if terrain_mesh:
		root.add_child(terrain_mesh)

	# --- Scatter props (visual only, no collision) ---
	var props_node: Node3D = _scatter_battle_props(
		heightmap, arena_pos, arena_radius_sq
	)
	if props_node:
		root.add_child(props_node)

	return root


static func _build_battle_terrain_patch(data: HeightmapData, center: Vector3) -> MeshInstance3D:
	## Creates an ArrayMesh terrain patch centered on the given world position.
	var tscale: Vector3 = data.terrain_scale

	# Convert world center to heightmap coords
	var cx_f: float = center.x / tscale.x
	var cz_f: float = center.z / tscale.z
	var patch_r: float = _BATTLE_PATCH_RADIUS / tscale.x

	# Heightmap index bounds for the patch
	var min_x: int = maxi(0, int(cx_f - patch_r))
	var max_x: int = mini(data.width - 1, int(cx_f + patch_r))
	var min_z: int = maxi(0, int(cz_f - patch_r))
	var max_z: int = mini(data.height - 1, int(cz_f + patch_r))

	var verts_x: int = max_x - min_x + 1
	var verts_z: int = max_z - min_z + 1
	if verts_x < 2 or verts_z < 2:
		return null

	var quads_x: int = verts_x - 1
	var quads_z: int = verts_z - 1

	# Build vertex arrays
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var vert_count: int = verts_x * verts_z
	vertices.resize(vert_count)
	normals.resize(vert_count)
	uvs.resize(vert_count)
	colors.resize(vert_count)

	# Fill vertices
	for iz in range(verts_z):
		var gz: int = min_z + iz
		for ix in range(verts_x):
			var gx: int = min_x + ix
			var h: float = data.get_height_at(gx, gz)
			var idx: int = iz * verts_x + ix

			vertices[idx] = Vector3(
				float(gx) * tscale.x,
				h * tscale.y,
				float(gz) * tscale.z
			)
			uvs[idx] = Vector2(
				float(ix) / float(quads_x) if quads_x > 0 else 0.0,
				float(iz) / float(quads_z) if quads_z > 0 else 0.0
			)
			colors[idx] = data.get_splatmap_weights(gx, gz)

	# Normals via central differencing
	for iz in range(verts_z):
		var gz: int = min_z + iz
		for ix in range(verts_x):
			var gx: int = min_x + ix
			var idx: int = iz * verts_x + ix

			var h_left: float = data.get_height_at(gx - 1, gz) * tscale.y
			var h_right: float = data.get_height_at(gx + 1, gz) * tscale.y
			var h_down: float = data.get_height_at(gx, gz - 1) * tscale.y
			var h_up: float = data.get_height_at(gx, gz + 1) * tscale.y

			normals[idx] = Vector3(
				h_left - h_right,
				2.0 * tscale.x,
				h_down - h_up
			).normalized()

	# Triangle indices
	indices.resize(quads_x * quads_z * 6)
	var tri_idx: int = 0
	for iz in range(quads_z):
		for ix in range(quads_x):
			var tl: int = iz * verts_x + ix
			var top_r: int = tl + 1
			var bl: int = (iz + 1) * verts_x + ix
			var br: int = bl + 1
			indices[tri_idx] = tl
			indices[tri_idx + 1] = top_r
			indices[tri_idx + 2] = bl
			indices[tri_idx + 3] = top_r
			indices[tri_idx + 4] = br
			indices[tri_idx + 5] = bl
			tri_idx += 6

	# Create ArrayMesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Apply splatmap shader material
	var material: ShaderMaterial = _create_battle_splatmap_material(data)
	if material:
		mesh.surface_set_material(0, material)

	var mmi := MeshInstance3D.new()
	mmi.mesh = mesh
	mmi.name = "BattleTerrain"
	return mmi


static func _create_battle_splatmap_material(data: HeightmapData) -> ShaderMaterial:
	## Creates a splatmap shader material for the battle terrain patch.
	if not ResourceLoader.exists(_BATTLE_TERRAIN_SHADER):
		return null
	var shader: Shader = load(_BATTLE_TERRAIN_SHADER) as Shader
	if not shader:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader

	for i in range(mini(data.texture_layers.size(), 4)):
		var layer: TerrainTextureLayer = data.texture_layers[i]
		var suffix: String = str(i)
		if layer.albedo_texture:
			mat.set_shader_parameter("albedo_" + suffix, layer.albedo_texture)
		if layer.normal_texture:
			mat.set_shader_parameter("normal_" + suffix, layer.normal_texture)
		mat.set_shader_parameter("uv_scale_" + suffix, layer.uv_scale)

	return mat


static func _scatter_battle_props(
	data: HeightmapData, arena_pos: Vector3, arena_radius_sq: float
) -> Node3D:
	## Scatters visual-only props around the battle area (no collision, no blocking in arena).
	var root := Node3D.new()
	root.name = "BattleProps"

	var tscale: Vector3 = data.terrain_scale
	var patch_r: float = _BATTLE_PATCH_RADIUS

	# World bounds of the patch
	var min_wx: float = arena_pos.x - patch_r
	var max_wx: float = arena_pos.x + patch_r
	var min_wz: float = arena_pos.z - patch_r
	var max_wz: float = arena_pos.z + patch_r
	var patch_area: float = (patch_r * 2.0) * (patch_r * 2.0)

	var all_props: Array[PropDefinition] = PropRegistry.get_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2(arena_pos.x, arena_pos.z))

	for pi in range(all_props.size()):
		var prop: PropDefinition = all_props[pi]
		if not ResourceLoader.exists(prop.scene_path):
			continue

		# Only visual props for battle (skip blocking ones, they'd obstruct combat)
		var skip_in_arena: bool = (prop.collision_type == PropDefinition.CollisionType.BLOCKING)

		var expected: float = prop.density * patch_area
		var count: int = int(expected)
		if rng.randf() < (expected - float(count)):
			count += 1
		if count <= 0:
			continue

		# Collect transforms
		var transforms: Array[Transform3D] = []
		for _i in range(count):
			var wx: float = rng.randf_range(min_wx, max_wx)
			var wz: float = rng.randf_range(min_wz, max_wz)

			# Skip blocking props inside arena circle
			if skip_in_arena:
				var dx: float = wx - arena_pos.x
				var dz: float = wz - arena_pos.z
				if dx * dx + dz * dz <= arena_radius_sq:
					continue

			# Check splatmap layer compatibility
			var gx: int = clampi(roundi(wx / tscale.x), 0, data.width - 1)
			var gz: int = clampi(roundi(wz / tscale.z), 0, data.height - 1)
			var weights: Color = data.get_splatmap_weights(gx, gz)
			var dominant: int = _get_dominant_splat_layer(weights)
			if not (prop.allowed_layers & (1 << dominant)):
				continue

			var h: float = data.get_height_at(gx, gz) * tscale.y
			var s: float = rng.randf_range(prop.min_scale, prop.max_scale)
			var rot_y: float = rng.randf_range(0.0, TAU) if prop.random_rotation_y else 0.0

			var xform := Transform3D.IDENTITY
			xform = xform.scaled(Vector3(s, s, s))
			xform = xform.rotated(Vector3.UP, rot_y)
			xform.origin = Vector3(wx, h, wz)
			transforms.append(xform)

		if transforms.is_empty():
			continue

		# Create MultiMeshInstance3D for visual props
		var mmi: MultiMeshInstance3D = PropScatter._create_multimesh(prop.scene_path, transforms)
		if mmi:
			root.add_child(mmi)

	return root


static func _get_dominant_splat_layer(weights: Color) -> int:
	## Returns the splatmap layer index with the highest weight.
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
