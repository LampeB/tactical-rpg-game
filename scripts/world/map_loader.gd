class_name MapLoader
extends RefCounted
## Static utility that converts a MapData resource into runtime 3D scene nodes.
## Used by overworld.gd to build the world from data instead of hardcoded values.

# Block colors (must match overworld.gd Block enum order)
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
	## Creates and populates a GridMap from map_data terrain cells.
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

	for x in range(map_data.grid_width):
		for z in range(map_data.grid_height):
			grid.set_cell_item(Vector3i(x, 0, z), map_data.get_terrain_at(x, z))

	parent.add_child(grid)
	DebugLogger.log_info("Built GridMap terrain: %dx%d cells" % [map_data.grid_width, map_data.grid_height], "MapLoader")
	return grid


static func spawn_elements(map_data: MapData, parent: Node3D,
		location_parent: Node3D, enemy_parent: Node3D, chest_parent: Node3D) -> void:
	## Instantiates all MapElement entries as their respective scene types.
	_ensure_scenes_loaded()

	for elem in map_data.elements:
		var etype: int = elem.element_type
		# Fix mismatched types: scene/vox paths stored as NPC (editor bug, Godot default-value quirk)
		if etype == MapElement.ElementType.NPC and not elem.resource_id.is_empty():
			if elem.resource_id.ends_with(".tscn") or elem.resource_id.ends_with(".vox"):
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
	if elem.resource_id.is_empty():
		return
	var obj: Node3D
	if elem.resource_id.ends_with(".vox"):
		obj = VoxModel.new()
		obj.vox_path = elem.resource_id
	else:
		var scene: PackedScene = load(elem.resource_id) as PackedScene
		if not scene:
			DebugLogger.log_warn("Failed to load decoration scene: %s" % elem.resource_id, "MapLoader")
			return
		obj = scene.instantiate()
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
