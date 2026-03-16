class_name StructureManager
extends Node3D
## Instantiates placed structures from HeightmapData on the terrain.
## Structures are static scene instances with collision from their mesh.

## Snap increment for grid-aligned placement (matches terrain vertex spacing).
const GRID_SNAP := 1.0
## Y-rotation snap: 90° increments
const ROTATION_SNAP := PI * 0.5

var _piece_cache: Dictionary = {}  ## piece_id → StructurePiece
var _instances: Array[Node3D] = []


func build(data: HeightmapData) -> void:
	## Instantiates all structures from the heightmap data.
	name = "StructureManager"
	_build_piece_cache()

	for i in range(data.structures.size()):
		var placed: PlacedStructure = data.structures[i]
		var instance: Node3D = _instantiate_piece(placed)
		if instance:
			add_child(instance)
			_instances.append(instance)


func clear() -> void:
	## Removes all structure instances.
	for i in range(_instances.size()):
		if is_instance_valid(_instances[i]):
			_instances[i].queue_free()
	_instances.clear()


func add_structure(data: HeightmapData, piece_id: String, world_pos: Vector3,
		rot_y: float = 0.0, snap_to_grid: bool = true) -> PlacedStructure:
	## Places a new structure at the given world position. Adds to both the data
	## resource and the scene. Returns the PlacedStructure, or null on failure.
	if not _piece_cache.has(piece_id):
		return null

	var placed := PlacedStructure.new()
	placed.piece_id = piece_id
	placed.rotation_y = snappedf(rot_y, ROTATION_SNAP) if snap_to_grid else rot_y

	if snap_to_grid:
		placed.position = Vector3(
			snappedf(world_pos.x, GRID_SNAP),
			world_pos.y,
			snappedf(world_pos.z, GRID_SNAP)
		)
	else:
		placed.position = world_pos

	data.structures.append(placed)

	var instance: Node3D = _instantiate_piece(placed)
	if instance:
		add_child(instance)
		_instances.append(instance)

	return placed


func get_height_for_structure(terrain_mgr: Node3D, world_pos: Vector3) -> float:
	## Returns the terrain height at a position, for snapping structures to ground.
	if terrain_mgr and terrain_mgr.has_method("get_height_at_world"):
		return terrain_mgr.get_height_at_world(world_pos)
	return 0.0


func _build_piece_cache() -> void:
	var all_pieces: Array[StructurePiece] = StructureRegistry.get_all()
	for i in range(all_pieces.size()):
		var piece: StructurePiece = all_pieces[i]
		_piece_cache[piece.id] = piece


func _instantiate_piece(placed: PlacedStructure) -> Node3D:
	var scene: PackedScene = null

	if placed.scene_path != "":
		# Direct scene path (building prefab)
		if not ResourceLoader.exists(placed.scene_path):
			return null
		scene = load(placed.scene_path) as PackedScene
	else:
		# Legacy: look up in StructureRegistry
		if not _piece_cache.has(placed.piece_id):
			return null
		var piece: StructurePiece = _piece_cache[placed.piece_id]
		if not ResourceLoader.exists(piece.scene_path):
			return null
		scene = load(piece.scene_path) as PackedScene

	if not scene:
		return null

	# Wrap in a StaticBody3D for collision
	var body := StaticBody3D.new()
	body.name = placed.piece_id if placed.piece_id != "" else placed.scene_path.get_file().get_basename()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = placed.position
	body.rotation.y = placed.rotation_y
	if placed.scale_factor != 1.0:
		body.scale = Vector3.ONE * placed.scale_factor

	# Add the visual mesh
	var visual: Node3D = scene.instantiate()
	body.add_child(visual)

	# Generate collision from meshes in the scene
	_add_mesh_collision(body, visual)

	return body


func _add_mesh_collision(body: StaticBody3D, node: Node) -> void:
	## Recursively finds MeshInstance3D nodes and creates trimesh collision shapes.
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh:
			var shape: Shape3D = mi.mesh.create_trimesh_shape()
			if shape:
				var col := CollisionShape3D.new()
				col.shape = shape
				col.transform = mi.transform
				body.add_child(col)
	for i in range(node.get_child_count()):
		_add_mesh_collision(body, node.get_child(i))
