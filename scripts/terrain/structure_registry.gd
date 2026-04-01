class_name StructureRegistry
extends RefCounted
## Central registry of all modular building pieces from the Medieval Village MegaKit.
## Categorizes ~176 pieces by type for the structure placement system and editor.

const _KIT_PATH := AssetPaths.VILLAGE_KIT

static var _cache: Array[StructurePiece] = []
static var _by_category: Dictionary = {}  ## Category int → Array[StructurePiece]


static func get_all() -> Array[StructurePiece]:
	if not _cache.is_empty():
		return _cache
	_build_registry()
	return _cache


static func get_by_category(cat: StructurePiece.Category) -> Array[StructurePiece]:
	if _cache.is_empty():
		_build_registry()
	if _by_category.has(cat):
		return _by_category[cat]
	return []


static func _build_registry() -> void:
	_cache.clear()
	_by_category.clear()

	# Auto-categorize by filename prefix
	var prefix_map: Dictionary = {
		"Wall_": StructurePiece.Category.WALL,
		"Floor_": StructurePiece.Category.FLOOR,
		"Roof_": StructurePiece.Category.ROOF,
		"Door": StructurePiece.Category.DOOR,
		"DoorFrame": StructurePiece.Category.DOOR,
		"Window": StructurePiece.Category.WINDOW,
		"Stair": StructurePiece.Category.STAIRS,
		"Corner_": StructurePiece.Category.CORNER,
		"Overhang_": StructurePiece.Category.OVERHANG,
		"Balcony_": StructurePiece.Category.BALCONY,
		"Prop_": StructurePiece.Category.PROP,
		"HoleCover_": StructurePiece.Category.FLOOR,
	}

	# Pieces with special footprints (wider than 1x1)
	var footprint_overrides: Dictionary = {
		"Roof_RoundTiles_4x4": Vector2i(4, 4),
		"Roof_RoundTiles_4x6": Vector2i(4, 6),
		"Roof_RoundTiles_4x8": Vector2i(4, 8),
		"Roof_RoundTiles_6x4": Vector2i(6, 4),
		"Roof_RoundTiles_6x6": Vector2i(6, 6),
		"Roof_RoundTiles_6x8": Vector2i(6, 8),
		"Roof_RoundTiles_6x10": Vector2i(6, 10),
		"Roof_RoundTiles_6x12": Vector2i(6, 12),
		"Roof_RoundTiles_6x14": Vector2i(6, 14),
		"Roof_RoundTiles_8x8": Vector2i(8, 8),
		"Roof_RoundTiles_8x10": Vector2i(8, 10),
		"Roof_RoundTiles_8x12": Vector2i(8, 12),
		"Roof_RoundTiles_8x14": Vector2i(8, 14),
		"Roof_2x4_RoundTile": Vector2i(2, 4),
	}

	# Scan the glTF directory
	var dir := DirAccess.open(_KIT_PATH)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".gltf"):
			var base: String = file_name.get_basename()
			var piece := StructurePiece.new()
			piece.id = base.to_snake_case()
			piece.scene_path = _KIT_PATH + file_name
			piece.display_name = base.replace("_", " ")
			piece.category = _categorize(base, prefix_map)

			if footprint_overrides.has(base):
				piece.footprint = footprint_overrides[base]

			_cache.append(piece)

			var cat_int: int = piece.category
			if not _by_category.has(cat_int):
				_by_category[cat_int] = [] as Array[StructurePiece]
			_by_category[cat_int].append(piece)

		file_name = dir.get_next()
	dir.list_dir_end()


static func _categorize(base_name: String, prefix_map: Dictionary) -> StructurePiece.Category:
	var prefixes: Array = prefix_map.keys()
	for i in range(prefixes.size()):
		var prefix: String = prefixes[i]
		if base_name.begins_with(prefix):
			return prefix_map[prefix] as StructurePiece.Category
	return StructurePiece.Category.PROP
