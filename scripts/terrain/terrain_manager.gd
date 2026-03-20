class_name TerrainManager
extends Node3D
## Manages heightmap terrain chunk loading/unloading based on player distance.
## Assigns LOD levels: 0 (full) for nearby, 1 (half) for mid, 2 (quarter) for far.

const _OverworldPropRegistry := preload("res://scripts/terrain/overworld_prop_registry.gd")

signal loading_progress(done: int, total: int)  ## Emitted each frame during preload
signal loading_complete                          ## Emitted when all chunks are preloaded

@export var view_distance: int = 3  ## Chunks visible in each direction from player
@export var unload_distance: int = 5  ## Chunks beyond this are freed
@export var lod1_distance: int = 2  ## Chebyshev distance threshold for LOD 1
@export var lod2_distance: int = 4  ## Chebyshev distance threshold for LOD 2
@export var scatter_props: bool = true  ## Enable prop scattering on nearby chunks
@export var prop_distance: int = 2  ## Max chunk distance for prop spawning
@export var build_nav_mesh: bool = true  ## Build a NavMesh on setup (slow for large maps)
@export var chunks_per_frame: int = 4  ## How many chunks to build per frame during preload
var visual_only_props: bool = false  ## When true, scatter only grass/flowers (trees placed in scene)

var _data: HeightmapData  ## Set directly before calling preload_all()
var _loaded_chunks: Dictionary = {}  ## Key: Vector2i(cx, cz), Value: HeightmapChunk
var _loaded_props: Dictionary = {}  ## Key: Vector2i(cx, cz), Value: Node3D (prop root)
var _player: Node3D
var _last_player_chunk := Vector2i(-999, -999)
var _prop_seed: int = 42
var _nav_region: NavigationRegion3D = null  ## Terrain navigation mesh

## Preload queue — filled by preload_all(), drained in _process()
var _preload_queue: Array[Vector2i] = []
var _prop_preload_queue: Array[Vector2i] = []
var _preload_total: int = 0
var _preloading: bool = false


func setup(data: HeightmapData, player: Node3D) -> void:
	## Initialize terrain with heightmap data and player reference.
	_data = data
	_player = player
	name = "TerrainManager"
	_update_chunks()
	if build_nav_mesh:
		_build_navigation_mesh()


func preload_all(player: Node3D) -> void:
	## Queues every chunk for loading across multiple frames.
	## Emits loading_progress(done, total) each frame and loading_complete when done.
	## Call this instead of setup() when you want a loading screen.
	_data = _data  # already set via the data property before calling
	_player = player
	name = "TerrainManager"

	var cx_count: int = _data.get_chunk_count_x()
	var cz_count: int = _data.get_chunk_count_z()
	_preload_queue.clear()
	# Queue from center outward so terrain appears in a ring expanding from the player
	var center_cx: int = clampi(int(_player.global_position.x / ((HeightmapData.CHUNK_SIZE - 1) * _data.terrain_scale.x)), 0, cx_count - 1)
	var center_cz: int = clampi(int(_player.global_position.z / ((HeightmapData.CHUNK_SIZE - 1) * _data.terrain_scale.z)), 0, cz_count - 1)
	var max_r: int = maxi(cx_count, cz_count)
	for r in range(max_r + 1):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dz) != r:
					continue  # only the ring edge
				var cx2: int = center_cx + dx
				var cz2: int = center_cz + dz
				if cx2 < 0 or cx2 >= cx_count or cz2 < 0 or cz2 >= cz_count:
					continue
				var key := Vector2i(cx2, cz2)
				if not _loaded_chunks.has(key):
					_preload_queue.append(key)

	# Also queue all prop chunks so grass/flowers are preloaded during the loading screen
	if scatter_props:
		_prop_preload_queue.clear()
		for cz2 in range(cz_count):
			for cx2 in range(cx_count):
				_prop_preload_queue.append(Vector2i(cx2, cz2))

	_preload_total = _preload_queue.size() + _prop_preload_queue.size()
	_preloading = true
	if build_nav_mesh:
		_build_navigation_mesh()


func _process(_delta: float) -> void:
	if _preloading:
		_process_preload_queue()
		return
	if not _data or not _player:
		return
	var current_chunk: Vector2i = _world_to_chunk(_player.global_position)
	if current_chunk != _last_player_chunk:
		_last_player_chunk = current_chunk
		_update_chunks()


func _process_preload_queue() -> void:
	var done_this_frame: int = 0

	# Phase 1: terrain chunks
	while _preload_queue.size() > 0 and done_this_frame < chunks_per_frame:
		var key: Vector2i = _preload_queue[0]
		_preload_queue.remove_at(0)
		if not _loaded_chunks.has(key):
			_load_chunk(key.x, key.y, 0)
		done_this_frame += 1

	# Phase 2: prop chunks (only once terrain queue is empty)
	if _preload_queue.is_empty():
		while _prop_preload_queue.size() > 0 and done_this_frame < chunks_per_frame:
			var key: Vector2i = _prop_preload_queue[0]
			_prop_preload_queue.remove_at(0)
			if not _loaded_props.has(key):
				_load_props(key.x, key.y)
			done_this_frame += 1

	var remaining: int = _preload_queue.size() + _prop_preload_queue.size()
	loading_progress.emit(_preload_total - remaining, _preload_total)

	if _preload_queue.is_empty() and _prop_preload_queue.is_empty():
		_preloading = false
		loading_complete.emit()


func _world_to_chunk(world_pos: Vector3) -> Vector2i:
	## Converts world position to chunk index.
	var chunk_world_size: float = float(HeightmapData.CHUNK_SIZE - 1) * _data.terrain_scale.x
	var cx: int = floori(world_pos.x / chunk_world_size)
	var cz: int = floori(world_pos.z / chunk_world_size)
	return Vector2i(cx, cz)


func _get_lod_for_distance(dist: int) -> int:
	## Returns the LOD level for a given Chebyshev distance from the player chunk.
	if dist >= lod2_distance:
		return 2
	if dist >= lod1_distance:
		return 1
	return 0


func _update_chunks() -> void:
	var center: Vector2i = _last_player_chunk
	var chunks_x: int = _data.get_chunk_count_x()
	var chunks_z: int = _data.get_chunk_count_z()

	# Load/update chunks within view distance
	for dz in range(-view_distance, view_distance + 1):
		for dx in range(-view_distance, view_distance + 1):
			var cx: int = center.x + dx
			var cz: int = center.y + dz
			if cx < 0 or cx >= chunks_x or cz < 0 or cz >= chunks_z:
				continue
			var key := Vector2i(cx, cz)
			var dist: int = maxi(absi(dx), absi(dz))
			var target_lod: int = _get_lod_for_distance(dist)

			if _loaded_chunks.has(key):
				# Re-build if LOD level changed
				var existing: HeightmapChunk = _loaded_chunks[key]
				if existing.lod_level != target_lod:
					existing.queue_free()
					_load_chunk(cx, cz, target_lod)
			else:
				_load_chunk(cx, cz, target_lod)

	# Load/unload props for nearby chunks
	if scatter_props:
		for dz2 in range(-prop_distance, prop_distance + 1):
			for dx2 in range(-prop_distance, prop_distance + 1):
				var pcx: int = center.x + dx2
				var pcz: int = center.y + dz2
				if pcx < 0 or pcx >= chunks_x or pcz < 0 or pcz >= chunks_z:
					continue
				var pkey := Vector2i(pcx, pcz)
				if not _loaded_props.has(pkey):
					_load_props(pcx, pcz)

	# Unload chunks beyond unload distance
	var keys_to_remove: Array[Vector2i] = []
	var chunk_keys: Array = _loaded_chunks.keys()
	for i in range(chunk_keys.size()):
		var key: Vector2i = chunk_keys[i]
		var dist: int = maxi(absi(key.x - center.x), absi(key.y - center.y))
		if dist > unload_distance:
			keys_to_remove.append(key)

	for i in range(keys_to_remove.size()):
		var key: Vector2i = keys_to_remove[i]
		_unload_chunk(key)

	# Unload props beyond prop distance
	var prop_keys_to_remove: Array[Vector2i] = []
	var prop_keys: Array = _loaded_props.keys()
	for i in range(prop_keys.size()):
		var key: Vector2i = prop_keys[i]
		var dist: int = maxi(absi(key.x - center.x), absi(key.y - center.y))
		if dist > prop_distance + 1:
			prop_keys_to_remove.append(key)

	for i in range(prop_keys_to_remove.size()):
		var key: Vector2i = prop_keys_to_remove[i]
		_unload_props(key)


func _load_chunk(cx: int, cz: int, lod: int = 0) -> void:
	var key := Vector2i(cx, cz)
	var chunk := HeightmapChunk.new()
	chunk.build(_data, cx, cz, lod)
	add_child(chunk)
	_loaded_chunks[key] = chunk


func _unload_chunk(key: Vector2i) -> void:
	var chunk: HeightmapChunk = _loaded_chunks[key]
	if chunk and is_instance_valid(chunk):
		chunk.queue_free()
	_loaded_chunks.erase(key)


func _load_props(cx: int, cz: int) -> void:
	var key := Vector2i(cx, cz)
	var ow_defs: Array = _get_prop_defs()
	var props_root: Node3D = PropScatter.scatter_chunk(_data, cx, cz, _prop_seed, visual_only_props, ow_defs)
	add_child(props_root)
	_loaded_props[key] = props_root


func _get_prop_defs() -> Array:
	## Returns the appropriate prop list for the current map.
	## Empty array means PropScatter will use PropRegistry.get_all() (area maps).
	if _data != null and _data.is_overworld:
		return _OverworldPropRegistry.get_all()
	return []


func _unload_props(key: Vector2i) -> void:
	var node: Node3D = _loaded_props[key]
	if node and is_instance_valid(node):
		node.queue_free()
	_loaded_props.erase(key)


func rebuild_chunk(cx: int, cz: int) -> void:
	## Force-rebuilds a loaded chunk after heightmap data has been modified.
	var key := Vector2i(cx, cz)
	if _loaded_chunks.has(key):
		var old: HeightmapChunk = _loaded_chunks[key]
		var lod: int = old.lod_level
		old.queue_free()
		_loaded_chunks.erase(key)
		_load_chunk(cx, cz, lod)


func get_loaded_chunk_count() -> int:
	return _loaded_chunks.size()


func get_height_at_world(world_pos: Vector3) -> float:
	## Returns the terrain height at a world XZ position using triangle interpolation
	## that matches the HeightmapChunk mesh topology.
	if not _data:
		return 0.0
	var lx: float = world_pos.x / _data.terrain_scale.x
	var lz: float = world_pos.z / _data.terrain_scale.z
	var ix: int = clampi(floori(lx), 0, _data.width - 2)
	var iz: int = clampi(floori(lz), 0, _data.height - 2)
	var fx: float = clampf(lx - float(ix), 0.0, 1.0)
	var fz: float = clampf(lz - float(iz), 0.0, 1.0)

	var sy: float = _data.terrain_scale.y
	var h00: float = _data.get_height_at(ix, iz) * sy
	var h10: float = _data.get_height_at(ix + 1, iz) * sy
	var h01: float = _data.get_height_at(ix, iz + 1) * sy
	var h11: float = _data.get_height_at(ix + 1, iz + 1) * sy

	# Triangle interpolation matching HeightmapChunk diagonal split
	if fx + fz <= 1.0:
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	else:
		return h10 + (fx + fz - 1.0) * (h11 - h10) + (1.0 - fx) * (h01 - h10)


func get_navigation_map() -> RID:
	## Returns the navigation map RID for pathfinding queries.
	if _nav_region:
		return _nav_region.get_navigation_map()
	return NavigationServer3D.get_maps()[0] if not NavigationServer3D.get_maps().is_empty() else RID()


const NAV_STEP := 2  ## Sample every Nth vertex for NavMesh (lower = more detailed, slower)
const NAV_MAX_SLOPE := 45.0  ## Maximum walkable slope in degrees


func _build_navigation_mesh() -> void:
	## Builds a NavigationRegion3D from the heightmap for NPC/enemy pathfinding.
	## Samples at reduced resolution (NAV_STEP) for performance.
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "TerrainNavRegion"

	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = NAV_MAX_SLOPE
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.2

	# Build vertices and triangles from heightmap at reduced resolution
	var sx: float = _data.terrain_scale.x
	var sy: float = _data.terrain_scale.y
	var sz: float = _data.terrain_scale.z
	var cols: int = ceili(float(_data.width - 1) / NAV_STEP) + 1
	var rows: int = ceili(float(_data.height - 1) / NAV_STEP) + 1

	var verts := PackedVector3Array()
	verts.resize(cols * rows)
	for rz in range(rows):
		var hz: int = mini(rz * NAV_STEP, _data.height - 1)
		for rx in range(cols):
			var hx: int = mini(rx * NAV_STEP, _data.width - 1)
			var idx: int = rz * cols + rx
			verts[idx] = Vector3(float(hx) * sx, _data.get_height_at(hx, hz) * sy, float(hz) * sz)

	var indices := PackedInt32Array()
	for rz2 in range(rows - 1):
		for rx2 in range(cols - 1):
			var tl: int = rz2 * cols + rx2
			var tr: int = tl + 1
			var bl: int = (rz2 + 1) * cols + rx2
			var br: int = bl + 1
			# Triangle 1 (CCW from above)
			indices.append(tl)
			indices.append(tr)
			indices.append(bl)
			# Triangle 2
			indices.append(tr)
			indices.append(br)
			indices.append(bl)

	nav_mesh.set_vertices(verts)
	var polygon_count: int = indices.size() / 3
	for pi in range(polygon_count):
		var poly := PackedInt32Array()
		poly.resize(3)
		poly[0] = indices[pi * 3]
		poly[1] = indices[pi * 3 + 1]
		poly[2] = indices[pi * 3 + 2]
		nav_mesh.add_polygon(poly)

	_nav_region.navigation_mesh = nav_mesh
	add_child(_nav_region)
	DebugLogger.log_info("Built NavMesh: %d verts, %d polygons (step=%d)" % [verts.size(), polygon_count, NAV_STEP], "TerrainManager")
