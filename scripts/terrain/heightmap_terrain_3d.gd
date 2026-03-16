@tool
class_name HeightmapTerrain3D
extends Node3D
## @tool node that renders heightmap terrain directly in the Godot 3D viewport.
## Can either load an existing HeightmapData .tres or generate one from parameters.
## At runtime, TerrainManager reads the heightmap_data for LOD streaming.

const _BiomeGenerator := preload("res://scripts/terrain/biome_heightmap_generator.gd")

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
var _chunks: Dictionary = {}  ## Vector2i -> HeightmapChunk


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()
	else:
		# At runtime, hide editor terrain chunks — TerrainManager handles rendering.
		# Don't hide the whole node so sibling/child props remain visible.
		if _chunk_parent:
			_chunk_parent.visible = false


func _generate_heightmap() -> void:
	## Generates a new HeightmapData from the gen_* parameters.
	heightmap_data = _BiomeGenerator.generate(gen_width, gen_depth, gen_seed)
	# Mark the resource as local so it saves with the scene
	heightmap_data.resource_name = "terrain_%d" % gen_seed
	notify_property_list_changed()
	_rebuild()
	print("[HeightmapTerrain3D] Generated %dx%d terrain (seed %d), %d chunks" % [
		gen_width, gen_depth, gen_seed,
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

	for cz in range(cz_count):
		for cx in range(cx_count):
			var chunk := HeightmapChunk.new()
			chunk.build(heightmap_data, cx, cz, preview_lod)
			_chunk_parent.add_child(chunk)
			_chunks[Vector2i(cx, cz)] = chunk


func _clear_chunks() -> void:
	if _chunk_parent:
		var keys: Array = _chunks.keys()
		for i in range(keys.size()):
			var chunk: HeightmapChunk = _chunks[keys[i]]
			if is_instance_valid(chunk):
				chunk.queue_free()
		_chunks.clear()


# ---------------------------------------------------------------------------
# Public API (used by runtime systems)
# ---------------------------------------------------------------------------

func get_height_at_world(world_pos: Vector3) -> float:
	## Triangle interpolation of terrain height matching HeightmapChunk mesh topology.
	if not heightmap_data:
		return 0.0
	var lx: float = world_pos.x / heightmap_data.terrain_scale.x
	var lz: float = world_pos.z / heightmap_data.terrain_scale.z
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
