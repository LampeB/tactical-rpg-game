@tool
class_name HeightmapTerrain3D
extends Node3D
## @tool node that renders heightmap terrain directly in the Godot 3D viewport.
## Can either load an existing HeightmapData .tres or generate one from parameters.
## Baked chunks are visible at runtime — no streaming needed for pre-built maps.

const _BiomeGenerator := preload("res://scripts/terrain/biome_heightmap_generator.gd")
const _OverworldGenerator := preload("res://scripts/terrain/overworld_heightmap_generator.gd")
const _RiverBody := preload("res://scripts/terrain/river_body.gd")
const _WaterBody := preload("res://scripts/terrain/water_body.gd")
const _PropScatter := preload("res://scripts/terrain/prop_scatter.gd")
const _OverworldPropRegistry := preload("res://scripts/terrain/overworld_prop_registry.gd")
const _PropRegistry := preload("res://scripts/terrain/prop_registry.gd")

@export var heightmap_data: HeightmapData = null:
	set(value):
		heightmap_data = value
		if is_inside_tree():
			_rebuild()

@export_group("Generation")
## Width of the terrain in vertices. World width = (width-1) * terrain_scale.x
@export_range(17, 1025) var gen_width: int = 129
## Depth of the terrain in vertices. World depth = (depth-1) * terrain_scale.z
@export_range(17, 1025) var gen_depth: int = 81
## Seed for procedural noise generation. Different seeds = different terrain.
@export var gen_seed: int = 42
## When true, uses OverworldHeightmapGenerator (island shape, terrain_scale 3×20×3).
## When false, uses BiomeHeightmapGenerator (directional edges, terrain_scale 1×8×1).
@export var use_overworld_generator: bool = false
## Click to generate a new HeightmapData from the parameters above.
## Replaces the current heightmap_data. The resource is saved alongside the scene.
@export var generate: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_generate_heightmap()

@export_group("Editor Preview")
## LOD level for the editor preview (0 = full, 1 = half, 2 = quarter).
## Higher values improve editor performance on large maps.
@export_range(0, 2) var preview_lod: int = 0:
	set(value):
		preview_lod = value
		if is_inside_tree() and Engine.is_editor_hint():
			_rebuild()


var _chunk_parent: Node3D = null
var _river_parent: Node3D = null
var _water_parent: Node3D = null
var _prop_parent: Node3D = null
var _chunks: Dictionary = {}  ## Vector2i -> HeightmapChunk


func _ready() -> void:
	# Build terrain chunks both in editor and at runtime.
	# Chunks are children of this node so the node's own transform (position, rotation) applies.
	# In editor: uses preview_lod for performance. At runtime: always uses full LOD 0.
	_rebuild()


func _generate_heightmap() -> void:
	## Generates a new HeightmapData from the gen_* parameters.
	if use_overworld_generator:
		heightmap_data = _OverworldGenerator.generate(gen_width, gen_depth, gen_seed)
		heightmap_data.resource_name = "overworld_%d" % gen_seed
	else:
		heightmap_data = _BiomeGenerator.generate(gen_width, gen_depth, gen_seed)
		heightmap_data.resource_name = "terrain_%d" % gen_seed
	notify_property_list_changed()
	_rebuild()
	print("[HeightmapTerrain3D] Generated %dx%d terrain (seed %d, overworld=%s), %d chunks" % [
		gen_width, gen_depth, gen_seed, str(use_overworld_generator),
		heightmap_data.get_chunk_count_x() * heightmap_data.get_chunk_count_z()
	])


func _rebuild() -> void:
	## Clears and rebuilds all terrain chunks from heightmap_data.
	_clear_chunks()

	if not heightmap_data:
		return

	if not _chunk_parent:
		_chunk_parent = Node3D.new()
		_chunk_parent.name = "Chunks"
		add_child(_chunk_parent)

	var cx_count: int = heightmap_data.get_chunk_count_x()
	var cz_count: int = heightmap_data.get_chunk_count_z()

	var build_lod: int = preview_lod if Engine.is_editor_hint() else 0
	for cz in range(cz_count):
		for cx in range(cx_count):
			var chunk := HeightmapChunk.new()
			chunk.build(heightmap_data, cx, cz, build_lod)
			_chunk_parent.add_child(chunk)
			_chunks[Vector2i(cx, cz)] = chunk

	# Spawn river bodies, water, and props
	_rebuild_rivers()
	_rebuild_water()
	_rebuild_props()


func _rebuild_rivers() -> void:
	if _river_parent:
		for child in _river_parent.get_children():
			child.queue_free()
	else:
		_river_parent = Node3D.new()
		_river_parent.name = "Rivers"
		add_child(_river_parent)

	if not heightmap_data:
		return

	var river_paths: Array = heightmap_data.rivers
	for ri in range(river_paths.size()):
		var rp = river_paths[ri]
		var river_body: MeshInstance3D = _RiverBody.new()
		river_body.setup(rp)
		_river_parent.add_child(river_body)


func _rebuild_water() -> void:
	if _water_parent:
		for child in _water_parent.get_children():
			child.queue_free()
	else:
		_water_parent = Node3D.new()
		_water_parent.name = "Water"
		add_child(_water_parent)

	if not heightmap_data:
		return

	var zones: Array = heightmap_data.water_zones
	for i in range(zones.size()):
		var zone = zones[i]
		var water: MeshInstance3D = _WaterBody.new()
		water.water_size = zone.size
		water.water_shape = zone.shape
		water.water_level = zone.center.y
		water.shallow_color = zone.shallow_color
		water.deep_color = zone.deep_color
		water.wave_speed = zone.wave_speed
		water.wave_strength = zone.wave_strength
		water.position = Vector3(zone.center.x, zone.center.y, zone.center.z)
		_water_parent.add_child(water)


func _rebuild_props() -> void:
	if _prop_parent:
		for child in _prop_parent.get_children():
			child.queue_free()
	else:
		_prop_parent = Node3D.new()
		_prop_parent.name = "Props"
		add_child(_prop_parent)

	if not heightmap_data:
		return

	var prop_defs: Array = []
	if heightmap_data.is_overworld:
		prop_defs = _OverworldPropRegistry.get_all()

	var cx_count: int = heightmap_data.get_chunk_count_x()
	var cz_count: int = heightmap_data.get_chunk_count_z()
	for cz in range(cz_count):
		for cx in range(cx_count):
			var props_root: Node3D = _PropScatter.scatter_chunk(
				heightmap_data, cx, cz, 42, false, prop_defs)
			_prop_parent.add_child(props_root)


func _clear_chunks() -> void:
	if _chunk_parent:
		var keys: Array = _chunks.keys()
		for i in range(keys.size()):
			var chunk: HeightmapChunk = _chunks[keys[i]]
			if is_instance_valid(chunk):
				chunk.queue_free()
		_chunks.clear()
	if _river_parent:
		for child in _river_parent.get_children():
			child.queue_free()
	if _water_parent:
		for child in _water_parent.get_children():
			child.queue_free()
	if _prop_parent:
		for child in _prop_parent.get_children():
			child.queue_free()


# ---------------------------------------------------------------------------
# Public API (used by runtime systems)
# ---------------------------------------------------------------------------

func get_height_at_world(world_pos: Vector3) -> float:
	## Triangle interpolation of terrain height matching HeightmapChunk mesh topology.
	## world_pos is in world space; the node's own transform is applied automatically.
	if not heightmap_data:
		return 0.0
	# Convert world position to terrain-local space to account for node transform/rotation
	var local_pos: Vector3 = world_pos
	if is_inside_tree():
		local_pos = global_transform.affine_inverse() * world_pos
	var lx: float = local_pos.x / heightmap_data.terrain_scale.x
	var lz: float = local_pos.z / heightmap_data.terrain_scale.z
	var ix: int = clampi(floori(lx), 0, heightmap_data.width - 2)
	var iz: int = clampi(floori(lz), 0, heightmap_data.height - 2)
	var fx: float = clampf(lx - float(ix), 0.0, 1.0)
	var fz: float = clampf(lz - float(iz), 0.0, 1.0)
	var sy: float = heightmap_data.terrain_scale.y
	var h00: float = heightmap_data.get_height_at(ix, iz) * sy
	var h10: float = heightmap_data.get_height_at(ix + 1, iz) * sy
	var h01: float = heightmap_data.get_height_at(ix, iz + 1) * sy
	var h11: float = heightmap_data.get_height_at(ix + 1, iz + 1) * sy
	# Triangle interpolation matching HeightmapChunk diagonal split
	if fx + fz <= 1.0:
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	else:
		return h10 + (fx + fz - 1.0) * (h11 - h10) + (1.0 - fx) * (h01 - h10)
