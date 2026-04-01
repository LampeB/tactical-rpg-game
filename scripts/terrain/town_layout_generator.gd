class_name TownLayoutGenerator
extends RefCounted
## Procedurally generates town/village layouts using pre-built building prefab scenes.
## Places buildings along roads on a flattened terrain area, with props and NPC markers.
## Result is written into HeightmapData (structures, splatmap road zones).

## -- Grid constants ----------------------------------------------------------
## Wall pieces in the kit are 4 world-units wide. Buildings snap to this grid.
const CELL := 4.0

## -- Town size profiles -------------------------------------------------------
enum TownSize { VILLAGE, TOWN, CITY }

## Building blueprint: describes one structure with a prefab scene.
## Size is in grid cells (e.g. 1×1 = 4×4 world units, 2×1 = 8×4).
class BuildingBlueprint:
	var id: String
	var cells_x: int  ## Width in cells (along X)
	var cells_z: int  ## Depth in cells (along Z)
	var scene_path: String  ## Path to the pre-built .tscn prefab
	var npc_role: String  ## "" = no NPC, "merchant", "innkeeper", "quest", "townsfolk"

	func _init(p_id: String, cx: int, cz: int, p_scene: String,
			p_role: String = "") -> void:
		id = p_id
		cells_x = cx
		cells_z = cz
		scene_path = p_scene
		npc_role = p_role


## -- Building prefab paths ----------------------------------------------------
const _BUILDING_PATH := AssetPaths.BUILDING_PREFABS

## Lazy-init blueprint library
static var _blueprints_cache: Array = []


static func _get_blueprints() -> Array:
	if not _blueprints_cache.is_empty():
		return _blueprints_cache
	_blueprints_cache = [
		# Small houses (1×1)
		BuildingBlueprint.new("small_house_a", 1, 1,
			_BUILDING_PATH + "small_house_plaster.tscn", "townsfolk"),
		BuildingBlueprint.new("small_house_b", 1, 1,
			_BUILDING_PATH + "small_house_brick.tscn", "townsfolk"),
		# Medium houses
		BuildingBlueprint.new("medium_house_a", 2, 1,
			_BUILDING_PATH + "medium_house_plaster.tscn", "townsfolk"),
		BuildingBlueprint.new("medium_house_b", 1, 2,
			_BUILDING_PATH + "medium_house_brick.tscn", "townsfolk"),
		# Large two-story
		BuildingBlueprint.new("large_house", 2, 2,
			_BUILDING_PATH + "large_house.tscn", "townsfolk"),
		# Shops
		BuildingBlueprint.new("shop_a", 2, 1,
			_BUILDING_PATH + "shop.tscn", "merchant"),
		BuildingBlueprint.new("shop_b", 1, 2,
			_BUILDING_PATH + "shop.tscn", "merchant"),
		# Tavern / inn
		BuildingBlueprint.new("tavern", 2, 2,
			_BUILDING_PATH + "tavern.tscn", "innkeeper"),
		# Quest building
		BuildingBlueprint.new("guild_hall", 2, 2,
			_BUILDING_PATH + "guild_hall.tscn", "quest"),
	]
	return _blueprints_cache


## -- Main generation entry point -----------------------------------------------

static func generate_town(
	data: HeightmapData,
	center_x: float, center_z: float,
	town_size: TownSize,
	seed_val: int
) -> Dictionary:
	## Generates a town at the given world-space center on the heightmap.
	## Flattens terrain under the town, places buildings + roads + props.
	## Returns {"npc_spawns": Array[Dictionary]} with NPC placement info.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Determine town parameters based on size
	var road_length: int  # Road length in cells from center
	var building_count_min: int
	var building_count_max: int
	var has_plaza: bool

	match town_size:
		TownSize.VILLAGE:
			road_length = 3
			building_count_min = 4
			building_count_max = 7
			has_plaza = false
		TownSize.TOWN:
			road_length = 5
			building_count_min = 8
			building_count_max = 14
			has_plaza = true
		TownSize.CITY:
			road_length = 8
			building_count_min = 16
			building_count_max = 24
			has_plaza = true

	var building_count: int = rng.randi_range(building_count_min, building_count_max)

	# Convert center to grid coords (snap to CELL grid)
	var grid_cx: float = snappedf(center_x, CELL)
	var grid_cz: float = snappedf(center_z, CELL)

	# -- Generate road network (cross roads from center) --
	var road_cells: Array[Vector2i] = []  # Grid cell positions that are road
	var building_slots: Array[Dictionary] = []  # {pos: Vector2i, facing: float}

	# Main road: east-west
	for i in range(-road_length, road_length + 1):
		road_cells.append(Vector2i(i, 0))
	# Cross road: north-south
	for i in range(-road_length, road_length + 1):
		if i != 0:
			road_cells.append(Vector2i(0, i))

	# Side streets for towns/cities
	if town_size >= TownSize.TOWN:
		var side_offset: int = maxi(road_length / 2, 2)
		# East side street
		for i in range(-side_offset, side_offset + 1):
			road_cells.append(Vector2i(side_offset, i))
		# West side street
		for i in range(-side_offset, side_offset + 1):
			road_cells.append(Vector2i(-side_offset, i))

	if town_size >= TownSize.CITY:
		var outer: int = maxi(road_length * 2 / 3, 3)
		# Additional north-south streets
		for i in range(-road_length, road_length + 1):
			road_cells.append(Vector2i(outer, i))
			road_cells.append(Vector2i(-outer, i))

	# Deduplicate road cells
	var road_set: Dictionary = {}
	for i in range(road_cells.size()):
		var cell: Vector2i = road_cells[i]
		road_set[cell] = true

	# -- Find building slots along roads --
	# Buildings are placed 1 cell off the road, facing the road
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	var facing_angles: Array[float] = [PI * 1.5, PI * 0.5, PI, 0.0]  # Face toward road

	var slot_set: Dictionary = {}
	var road_keys: Array = road_set.keys()
	for ri in range(road_keys.size()):
		var road_cell: Vector2i = road_keys[ri]
		for di in range(directions.size()):
			var d: Vector2i = directions[di]
			var slot_pos := Vector2i(road_cell.x + d.x, road_cell.y + d.y)
			# Skip if this slot IS a road cell
			if road_set.has(slot_pos):
				continue
			# Skip if too far from center (out of town radius)
			if absi(slot_pos.x) > road_length + 2 or absi(slot_pos.y) > road_length + 2:
				continue
			if not slot_set.has(slot_pos):
				slot_set[slot_pos] = {
					"pos": slot_pos,
					"facing": facing_angles[di]
				}

	# Convert to array and shuffle
	var slot_keys: Array = slot_set.keys()
	for si in range(slot_keys.size()):
		building_slots.append(slot_set[slot_keys[si]])

	# Shuffle slots
	for si in range(building_slots.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, si)
		var tmp: Dictionary = building_slots[si]
		building_slots[si] = building_slots[j]
		building_slots[j] = tmp

	# -- Flatten terrain under the town area --
	var town_radius_cells: int = road_length + 3
	var town_world_radius: float = float(town_radius_cells) * CELL
	var ground_y: float = _get_average_height(data, center_x, center_z, town_world_radius)
	_flatten_terrain(data, center_x, center_z, town_world_radius, ground_y)

	# -- Paint road splatmap (dirt/path texture = layer 1) --
	_paint_roads(data, grid_cx, grid_cz, road_set, ground_y)

	# -- Place buildings --
	var blueprints: Array = _get_blueprints()
	var occupied: Dictionary = {}  # Grid cells occupied by buildings
	var npc_spawns: Array[Dictionary] = []
	var placed_count: int = 0

	for si in range(building_slots.size()):
		if placed_count >= building_count:
			break
		var slot: Dictionary = building_slots[si]
		var slot_pos: Vector2i = slot["pos"]
		var facing: float = slot["facing"]

		# Pick a random blueprint
		var bp: BuildingBlueprint = blueprints[rng.randi_range(0, blueprints.size() - 1)]

		# Check if all cells for this building are free
		var fits: bool = true
		var building_cells: Array[Vector2i] = _get_building_cells(slot_pos, bp.cells_x, bp.cells_z)
		for ci in range(building_cells.size()):
			var c: Vector2i = building_cells[ci]
			if occupied.has(c) or road_set.has(c):
				fits = false
				break
		if not fits:
			continue

		# Mark cells as occupied
		for ci in range(building_cells.size()):
			occupied[building_cells[ci]] = true

		# Place the building prefab
		var world_x: float = grid_cx + float(slot_pos.x) * CELL
		var world_z: float = grid_cz + float(slot_pos.y) * CELL
		_place_building(data, bp, world_x, ground_y, world_z, facing)
		placed_count += 1

		# Record NPC spawn
		if bp.npc_role != "":
			var door_offset := Vector3(
				sin(facing) * CELL * 0.5,
				0.0,
				cos(facing) * CELL * 0.5
			)
			npc_spawns.append({
				"position": Vector3(world_x + door_offset.x, ground_y, world_z + door_offset.z),
				"role": bp.npc_role,
				"building": bp.id,
			})

	# -- Place town props --
	_place_town_props(data, grid_cx, grid_cz, road_set, occupied, ground_y, rng, town_size)

	# -- Plaza (if applicable) --
	if has_plaza:
		_create_plaza(data, grid_cx, grid_cz, ground_y, rng)

	return {"npc_spawns": npc_spawns}


## -- Terrain helpers -----------------------------------------------------------

static func _get_average_height(data: HeightmapData, cx: float, cz: float, radius: float) -> float:
	## Samples terrain heights in a radius and returns the average.
	var tscale: Vector3 = data.terrain_scale
	var total: float = 0.0
	var count: int = 0
	var step: float = CELL

	var x: float = cx - radius
	while x <= cx + radius:
		var z: float = cz - radius
		while z <= cz + radius:
			var ix: int = clampi(roundi(x / tscale.x), 0, data.width - 1)
			var iz: int = clampi(roundi(z / tscale.z), 0, data.height - 1)
			total += data.get_height_at(ix, iz) * tscale.y
			count += 1
			z += step
		x += step

	if count == 0:
		return 0.0
	return total / float(count)


static func _flatten_terrain(data: HeightmapData, cx: float, cz: float,
		radius: float, target_y: float) -> void:
	## Smoothly flattens terrain around the town center. Fully flat inside 80% radius,
	## blends to natural height at the outer edge.
	var tscale: Vector3 = data.terrain_scale
	var inner_r: float = radius * 0.75
	var target_h: float = target_y / tscale.y  # Convert to heightmap space

	var min_ix: int = maxi(0, roundi((cx - radius) / tscale.x))
	var max_ix: int = mini(data.width - 1, roundi((cx + radius) / tscale.x))
	var min_iz: int = maxi(0, roundi((cz - radius) / tscale.z))
	var max_iz: int = mini(data.height - 1, roundi((cz + radius) / tscale.z))

	for iz in range(min_iz, max_iz + 1):
		for ix in range(min_ix, max_ix + 1):
			var wx: float = float(ix) * tscale.x
			var wz: float = float(iz) * tscale.z
			var dist: float = sqrt((wx - cx) * (wx - cx) + (wz - cz) * (wz - cz))

			if dist <= inner_r:
				data.set_height_at(ix, iz, target_h)
			elif dist < radius:
				# Smooth blend
				var t: float = (dist - inner_r) / (radius - inner_r)
				t = t * t  # Quadratic ease
				var current_h: float = data.get_height_at(ix, iz)
				data.set_height_at(ix, iz, lerpf(target_h, current_h, t))

	# Also flatten the splatmap to grass for the town area
	for iz in range(min_iz, max_iz + 1):
		for ix in range(min_ix, max_ix + 1):
			var wx: float = float(ix) * tscale.x
			var wz: float = float(iz) * tscale.z
			var dist: float = sqrt((wx - cx) * (wx - cx) + (wz - cz) * (wz - cz))
			if dist <= inner_r:
				data.set_splatmap_weights(ix, iz, Color(0.8, 0.15, 0.05, 0.0))


static func _paint_roads(data: HeightmapData, cx: float, cz: float,
		road_set: Dictionary, _ground_y: float) -> void:
	## Paints dirt texture (splatmap layer 1) on road cells.
	var tscale: Vector3 = data.terrain_scale
	var road_color := Color(0.15, 0.75, 0.1, 0.0)  # Dominant dirt

	var road_keys: Array = road_set.keys()
	for ri in range(road_keys.size()):
		var cell: Vector2i = road_keys[ri]
		var world_x: float = cx + float(cell.x) * CELL
		var world_z: float = cz + float(cell.y) * CELL

		# Paint a CELL×CELL area for each road cell
		var min_ix: int = maxi(0, roundi((world_x - CELL * 0.4) / tscale.x))
		var max_ix: int = mini(data.width - 1, roundi((world_x + CELL * 0.4) / tscale.x))
		var min_iz: int = maxi(0, roundi((world_z - CELL * 0.4) / tscale.z))
		var max_iz: int = mini(data.height - 1, roundi((world_z + CELL * 0.4) / tscale.z))

		for iz in range(min_iz, max_iz + 1):
			for ix in range(min_ix, max_ix + 1):
				data.set_splatmap_weights(ix, iz, road_color)


## -- Building placement --------------------------------------------------------

static func _get_building_cells(origin: Vector2i, cx: int, cz: int) -> Array[Vector2i]:
	## Returns all grid cells occupied by a building at origin with size cx×cz.
	var cells: Array[Vector2i] = []
	for dz in range(cz):
		for dx in range(cx):
			cells.append(Vector2i(origin.x + dx, origin.y + dz))
	return cells


static func _place_building(data: HeightmapData, bp: BuildingBlueprint,
		wx: float, wy: float, wz: float, facing: float) -> void:
	## Places a pre-built building prefab scene at the given world position.
	var s := PlacedStructure.new()
	s.piece_id = bp.id
	s.scene_path = bp.scene_path
	s.position = Vector3(wx, wy, wz)
	s.rotation_y = facing
	data.structures.append(s)


static func _add_structure(data: HeightmapData, piece_id: String,
		pos: Vector3, rot_y: float) -> void:
	var s := PlacedStructure.new()
	s.piece_id = piece_id
	s.position = pos
	s.rotation_y = rot_y
	data.structures.append(s)


## -- Town props ----------------------------------------------------------------

static func _place_town_props(data: HeightmapData, cx: float, cz: float,
		road_set: Dictionary, occupied: Dictionary, ground_y: float,
		rng: RandomNumberGenerator, town_size: TownSize) -> void:
	## Scatters decorative props around the town (fences, crates, wagons).
	var prop_ids: Array[String] = [
		"prop_crate", "prop_crate", "prop_wagon",
		"prop_wooden_fence_single", "prop_wooden_fence_extension1",
		"prop_brick1", "prop_brick2",
	]

	var prop_count: int = 4
	match town_size:
		TownSize.TOWN:
			prop_count = 8
		TownSize.CITY:
			prop_count = 15

	var placed: int = 0
	var attempts: int = 0
	while placed < prop_count and attempts < prop_count * 4:
		attempts += 1
		# Pick a random position near roads but not on roads or buildings
		var road_keys: Array = road_set.keys()
		var near_road: Vector2i = road_keys[rng.randi_range(0, road_keys.size() - 1)]
		var offset_x: int = rng.randi_range(-2, 2)
		var offset_z: int = rng.randi_range(-2, 2)
		var cell := Vector2i(near_road.x + offset_x, near_road.y + offset_z)

		if road_set.has(cell) or occupied.has(cell):
			continue

		occupied[cell] = true

		var world_x: float = cx + float(cell.x) * CELL + rng.randf_range(-1.0, 1.0)
		var world_z: float = cz + float(cell.y) * CELL + rng.randf_range(-1.0, 1.0)
		var prop_id: String = prop_ids[rng.randi_range(0, prop_ids.size() - 1)]
		var rot: float = rng.randf_range(0.0, TAU)

		_add_structure(data, prop_id, Vector3(world_x, ground_y, world_z), rot)
		placed += 1


static func _create_plaza(data: HeightmapData, cx: float, cz: float,
		ground_y: float, _rng: RandomNumberGenerator) -> void:
	## Creates a small plaza at the town center with a floor/cobblestone area.
	# Place brick floors in a 2×2 cell area at center
	for dz in range(-1, 1):
		for dx in range(-1, 1):
			var pos := Vector3(
				cx + float(dx) * CELL,
				ground_y,
				cz + float(dz) * CELL
			)
			_add_structure(data, "floor_uneven_brick", pos, 0.0)

	# Metal fence sections around the plaza
	var fence_positions: Array[Vector3] = [
		Vector3(cx - CELL, ground_y, cz - CELL),
		Vector3(cx + CELL, ground_y, cz - CELL),
		Vector3(cx - CELL, ground_y, cz + CELL),
		Vector3(cx + CELL, ground_y, cz + CELL),
	]
	var fence_rots: Array[float] = [0.0, PI * 0.5, PI * 1.5, PI]
	for i in range(fence_positions.size()):
		_add_structure(data, "prop_metal_fence_ornament", fence_positions[i], fence_rots[i])
