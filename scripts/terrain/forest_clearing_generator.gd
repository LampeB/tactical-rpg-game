@tool
extends Node3D
## @tool generator for forest clearing maps. Builds a heightmap terrain with
## splatmap textures, trees (Poisson disk), undergrowth (MultiMesh), water,
## and props — all as editable child nodes. Click "Generate All" in inspector.
##
## Layers: HeightmapTerrain3D, Water/, Trees/, Undergrowth/, Props/, HandPlaced/
## HandPlaced/ is never cleared by regeneration — put custom edits there.

const _HeightmapData := preload("res://scripts/terrain/heightmap_data.gd")
const _TerrainTextureLayer := preload("res://scripts/terrain/terrain_texture_layer.gd")
const _WaterBody := preload("res://scripts/terrain/water_body.gd")
const _PropRegistry := preload("res://scripts/terrain/prop_registry.gd")

const _TEX_BASE := "res://assets/terrain_textures/"
const _FOREST_SCENES := "res://scenes/world/objects/forest/"

# ─── Inspector: Map Size ────────────────────────────────────────────────────
@export_group("Map Size")
@export_range(33, 257) var map_width: int = 65
@export_range(33, 257) var map_depth: int = 65
@export var terrain_scale: Vector3 = Vector3(1.0, 6.0, 1.0)

# ─── Inspector: Generation ──────────────────────────────────────────────────
@export_group("Generation")
@export var gen_seed: int = 42
@export_range(0.1, 0.9) var clearing_radius: float = 0.35
@export_range(0.0, 1.0) var clearing_flatness: float = 0.8
@export_range(0.0, 3.0) var edge_height: float = 1.2
@export_range(0.0, 1.0) var terrain_roughness: float = 0.3

# ─── Inspector: Water ───────────────────────────────────────────────────────
@export_group("Water")
@export var enable_pond: bool = true
@export_range(0.0, 1.0) var pond_offset: float = 0.3
@export var pond_size: Vector2 = Vector2(8, 6)

# ─── Inspector: Vegetation ──────────────────────────────────────────────────
@export_group("Vegetation")
@export_range(0.0, 3.0) var tree_density: float = 1.0
@export_range(0.0, 3.0) var undergrowth_density: float = 1.0
@export_range(2.0, 8.0) var tree_min_spacing: float = 3.5

# ─── Inspector: Paths ───────────────────────────────────────────────────────
@export_group("Paths")
@export_range(1, 6) var path_count: int = 2
@export_range(1.0, 6.0) var path_width: float = 3.0

# ─── Inspector: Encounters ──────────────────────────────────────────────────
@export_group("Encounters")
@export_range(0, 15) var enemy_count: int = 5
@export_range(3.0, 15.0) var enemy_min_spacing: float = 8.0
@export_range(2.0, 8.0) var enemy_patrol_distance: float = 5.0
## Encounter .tres paths to pick from. If empty, uses forest defaults.
@export var encounter_pool: Array[String] = []

# ─── Inspector: Actions ─────────────────────────────────────────────────────
@export_group("Actions")
@export var generate_all: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_generate_all()
@export var regenerate_terrain: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_regenerate_terrain()
@export var regenerate_trees: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_regenerate_trees()
@export var regenerate_undergrowth: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_regenerate_undergrowth()
@export var regenerate_props: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_regenerate_props()
@export var regenerate_encounters: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_regenerate_encounters()
@export var clear_all: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_clear_all()


# Cached data for layer regeneration
var _heightmap: Resource = null  # HeightmapData
var _center: Vector2 = Vector2.ZERO
var _half_size: Vector2 = Vector2.ZERO
var _path_lines: Array = []  # Array of {from: Vector2, to: Vector2}
var _pond_center: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


# ═══════════════════════════════════════════════════════════════════════════
# Generation entry points
# ═══════════════════════════════════════════════════════════════════════════

func _generate_all() -> void:
	_clear_all()
	_rng.seed = gen_seed
	_compute_layout()
	_generate_heightmap()
	_generate_water()
	_generate_trees()
	_generate_undergrowth()
	_generate_props()
	_generate_encounters()
	_ensure_hand_placed()
	print("[ForestClearingGenerator] Generation complete.")


func _regenerate_terrain() -> void:
	_rng.seed = gen_seed
	_compute_layout()
	_remove_layer("HeightmapTerrain3D")
	_generate_heightmap()


func _regenerate_trees() -> void:
	_rng.seed = gen_seed + 100
	_compute_layout()
	_remove_layer("Trees")
	_generate_trees()


func _regenerate_undergrowth() -> void:
	_rng.seed = gen_seed + 200
	_compute_layout()
	_remove_layer("Undergrowth")
	_generate_undergrowth()


func _regenerate_props() -> void:
	_rng.seed = gen_seed + 300
	_compute_layout()
	_remove_layer("Props")
	_generate_props()


func _regenerate_encounters() -> void:
	_rng.seed = gen_seed + 400
	_compute_layout()
	_remove_layer("Encounters")
	_generate_encounters()


func _clear_all() -> void:
	var children_to_remove: Array[Node] = []
	for i in range(get_child_count()):
		var child: Node = get_child(i)
		if child.name == "HandPlaced":
			continue
		children_to_remove.append(child)
	for child in children_to_remove:
		remove_child(child)
		child.queue_free()
	_heightmap = null


func _remove_layer(layer_name: String) -> void:
	# Search direct children by name (find_child with owned=false skips owned nodes)
	for i in range(get_child_count()):
		var child: Node = get_child(i)
		if child.name == layer_name:
			remove_child(child)
			child.queue_free()
			return


func _ensure_hand_placed() -> void:
	for i in range(get_child_count()):
		if get_child(i).name == "HandPlaced":
			return
	if true:
		var hp := Node3D.new()
		hp.name = "HandPlaced"
		_add_owned(hp, self)


# ═══════════════════════════════════════════════════════════════════════════
# Layout computation
# ═══════════════════════════════════════════════════════════════════════════

func _compute_layout() -> void:
	var w: float = (map_width - 1) * terrain_scale.x
	var d: float = (map_depth - 1) * terrain_scale.z
	_center = Vector2(w * 0.5, d * 0.5)
	_half_size = Vector2(w * 0.5, d * 0.5)

	# Compute path lines from edge to center
	_path_lines.clear()
	for i in range(path_count):
		var angle: float = (float(i) / path_count) * TAU + PI * 0.5  # Start from top
		var edge := Vector2(
			_center.x + cos(angle) * _half_size.x,
			_center.y + sin(angle) * _half_size.y
		)
		_path_lines.append({"from": edge, "to": _center})

	# Pond position
	var pond_rng := RandomNumberGenerator.new()
	pond_rng.seed = gen_seed + 999
	var pond_angle: float = pond_rng.randf() * TAU
	var pond_dist: float = pond_offset * minf(_half_size.x, _half_size.y)
	_pond_center = Vector2(
		_center.x + cos(pond_angle) * pond_dist,
		_center.y + sin(pond_angle) * pond_dist
	)


func _get_clearing_mask(world_x: float, world_z: float) -> float:
	## Returns 0.0 at clearing center, 1.0 at forest edge.
	var dx: float = (world_x - _center.x) / _half_size.x
	var dz: float = (world_z - _center.y) / _half_size.y
	var dist: float = sqrt(dx * dx + dz * dz)
	return smoothstep(clearing_radius - 0.1, clearing_radius + 0.1, dist)


func _get_path_mask(world_x: float, world_z: float) -> float:
	## Returns 1.0 on a path, 0.0 far from paths.
	var best: float = 0.0
	var p := Vector2(world_x, world_z)
	for i in range(_path_lines.size()):
		var line: Dictionary = _path_lines[i]
		var from: Vector2 = line["from"]
		var to: Vector2 = line["to"]
		var closest: Vector2 = _closest_point_on_segment(p, from, to)
		var d: float = p.distance_to(closest)
		var mask: float = 1.0 - smoothstep(0.0, path_width, d)
		if mask > best:
			best = mask
	return best


func _get_pond_mask(world_x: float, world_z: float) -> float:
	## Returns 1.0 inside pond, 0.0 far from pond.
	if not enable_pond:
		return 0.0
	var dx: float = (world_x - _pond_center.x) / (pond_size.x * 0.5)
	var dz: float = (world_z - _pond_center.y) / (pond_size.y * 0.5)
	var dist: float = sqrt(dx * dx + dz * dz)
	return 1.0 - smoothstep(0.8, 1.5, dist)


static func _closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.001:
		return a
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t


# ═══════════════════════════════════════════════════════════════════════════
# Step 1: Heightmap + Splatmap
# ═══════════════════════════════════════════════════════════════════════════

func _generate_heightmap() -> void:
	var data: Resource = _HeightmapData.new()
	data.width = map_width
	data.height = map_depth
	data.terrain_scale = terrain_scale
	data.initialize(0.0)

	# --- Skip auto-props (generator manages its own trees/undergrowth) ---
	data.skip_auto_props = true

	# --- Texture layers ---
	data.texture_layers = _create_texture_layers()

	# --- Height noise ---
	var noise := FastNoiseLite.new()
	noise.seed = gen_seed
	noise.frequency = 0.04
	noise.fractal_octaves = 3

	for z in range(map_depth):
		for x in range(map_width):
			var wx: float = x * terrain_scale.x
			var wz: float = z * terrain_scale.z
			var mask: float = _get_clearing_mask(wx, wz)
			var path_m: float = _get_path_mask(wx, wz)

			# Bowl shape: flat center, raised edges
			var h: float = mask * edge_height

			# Add noise on edges only
			var n: float = noise.get_noise_2d(float(x), float(z))
			h += n * terrain_roughness * mask

			# Flatten paths
			h = lerpf(h, 0.0, path_m * 0.8)

			# Depress pond area
			if enable_pond:
				var pond_m: float = _get_pond_mask(wx, wz)
				if pond_m > 0.0:
					h = lerpf(h, -0.15, pond_m)

			# Slight micro-variation everywhere
			h += noise.get_noise_2d(float(x) * 3.0, float(z) * 3.0) * 0.03

			data.set_height_at(x, z, h)

	# --- Splatmap ---
	for z in range(map_depth):
		for x in range(map_width):
			var wx: float = x * terrain_scale.x
			var wz: float = z * terrain_scale.z
			var mask: float = _get_clearing_mask(wx, wz)
			var path_m: float = _get_path_mask(wx, wz)
			var pond_m: float = _get_pond_mask(wx, wz)

			# Layer 0 = Grass (clearing), Layer 1 = ForestFloor (canopy),
			# Layer 2 = Dirt (paths), Layer 3 = Mud (pond edge)
			var grass: float = (1.0 - mask) * (1.0 - path_m) * (1.0 - pond_m)
			var forest: float = mask * (1.0 - path_m) * (1.0 - pond_m * 0.5)
			var dirt: float = path_m
			var mud: float = pond_m * 0.6

			# Normalize
			var total: float = grass + forest + dirt + mud
			if total > 0.001:
				grass /= total
				forest /= total
				dirt /= total
				mud /= total
			else:
				grass = 1.0

			data.set_splatmap_weights(x, z, Color(grass, forest, dirt, mud))

	_heightmap = data

	# --- Create terrain node ---
	var terrain: Node3D = HeightmapTerrain3D.new()
	terrain.name = "HeightmapTerrain3D"
	terrain.set("heightmap_data", data)
	_add_owned(terrain, self)
	terrain.call("_rebuild")


func _create_texture_layers() -> Array[TerrainTextureLayer]:
	var layers: Array[TerrainTextureLayer] = []

	# Layer 0: Grass
	var grass := _make_layer("Grass",
		_TEX_BASE + "Grass/Stylized_Grass_001_basecolor.jpg",
		_TEX_BASE + "Grass/Stylized_Grass_001_normal.jpg",
		_TEX_BASE + "Grass/Stylized_Grass_001_roughness.jpg", 8.0)
	layers.append(grass)

	# Layer 1: Forest Floor
	var forest := _make_layer("ForestFloor",
		_TEX_BASE + "ForestFloor/Ground068_1K-JPG_Color.jpg",
		_TEX_BASE + "ForestFloor/Ground068_1K-JPG_NormalGL.jpg",
		_TEX_BASE + "ForestFloor/Ground068_1K-JPG_Roughness.jpg", 8.0)
	layers.append(forest)

	# Layer 2: Dirt
	var dirt := _make_layer("Dirt",
		_TEX_BASE + "Soil/Ground104_1K-JPG_Color.jpg",
		_TEX_BASE + "Soil/Ground104_1K-JPG_NormalGL.jpg",
		_TEX_BASE + "Soil/Ground104_1K-JPG_Roughness.jpg", 10.0)
	layers.append(dirt)

	# Layer 3: Mud
	var mud := _make_layer("Mud",
		_TEX_BASE + "Mud/Ground_wet_003_basecolor.jpg",
		_TEX_BASE + "Mud/Ground_wet_003_normal.jpg",
		_TEX_BASE + "Mud/Ground_wet_003_roughness.jpg", 8.0)
	layers.append(mud)

	return layers


func _make_layer(layer_name: String, albedo_path: String, normal_path: String,
		roughness_path: String, uv: float) -> TerrainTextureLayer:
	var layer := TerrainTextureLayer.new()
	layer.name = layer_name
	if ResourceLoader.exists(albedo_path):
		layer.albedo_texture = load(albedo_path)
	if ResourceLoader.exists(normal_path):
		layer.normal_texture = load(normal_path)
	if ResourceLoader.exists(roughness_path):
		layer.roughness_texture = load(roughness_path)
	layer.uv_scale = uv
	return layer


# ═══════════════════════════════════════════════════════════════════════════
# Step 2: Water
# ═══════════════════════════════════════════════════════════════════════════

func _generate_water() -> void:
	if not enable_pond:
		return

	var water_parent := Node3D.new()
	water_parent.name = "Water"
	_add_owned(water_parent, self)

	var water: MeshInstance3D = _WaterBody.new()
	water.name = "Pond"
	water.set("water_size", pond_size)
	water.set("water_shape", 1)  # Ellipse
	water.set("water_level", -0.1 * terrain_scale.y)
	water.set("shallow_color", Color(0.25, 0.55, 0.65, 0.5))
	water.set("deep_color", Color(0.08, 0.2, 0.35, 0.8))
	water.position = Vector3(_pond_center.x, 0, _pond_center.y)
	_add_owned(water, water_parent)


# ═══════════════════════════════════════════════════════════════════════════
# Step 3: Trees
# ═══════════════════════════════════════════════════════════════════════════

const _TREE_POOL: Array[Dictionary] = [
	{"file": "commontree_1.tscn", "weight": 3, "min_s": 2.4, "max_s": 3.9},
	{"file": "commontree_2.tscn", "weight": 3, "min_s": 2.4, "max_s": 3.9},
	{"file": "commontree_3.tscn", "weight": 2, "min_s": 2.4, "max_s": 3.9},
	{"file": "pine_1.tscn",       "weight": 3, "min_s": 2.4, "max_s": 4.2},
	{"file": "pine_2.tscn",       "weight": 3, "min_s": 2.4, "max_s": 4.2},
	{"file": "pine_3.tscn",       "weight": 2, "min_s": 2.4, "max_s": 4.2},
	{"file": "birch_1.tscn",      "weight": 2, "min_s": 2.4, "max_s": 3.6},
	{"file": "birch_2.tscn",      "weight": 1, "min_s": 2.4, "max_s": 3.6},
	{"file": "deadtree_1.tscn",   "weight": 1, "min_s": 2.1, "max_s": 3.3},
	{"file": "twistedtree_1.tscn","weight": 1, "min_s": 2.1, "max_s": 3.6},
]


func _generate_trees() -> void:
	var tree_parent := Node3D.new()
	tree_parent.name = "Trees"
	_add_owned(tree_parent, self)

	var w: float = (map_width - 1) * terrain_scale.x
	var d: float = (map_depth - 1) * terrain_scale.z
	var bounds := Rect2(2, 2, w - 4, d - 4)

	# Poisson disk for candidate positions
	var tree_rng := RandomNumberGenerator.new()
	tree_rng.seed = gen_seed + 100
	var candidates: PackedVector2Array = PoissonDisk.sample_2d(bounds, tree_min_spacing, tree_rng)

	# Weighted tree selection
	var weight_total: int = 0
	for i in range(_TREE_POOL.size()):
		var entry: Dictionary = _TREE_POOL[i]
		weight_total += entry["weight"] as int

	var placed: int = 0
	for i in range(candidates.size()):
		var pos: Vector2 = candidates[i]
		var mask: float = _get_clearing_mask(pos.x, pos.y)
		var path_m: float = _get_path_mask(pos.x, pos.y)
		var pond_m: float = _get_pond_mask(pos.x, pos.y)

		# Reject: in clearing center, on paths, or in pond
		if path_m > 0.3:
			continue
		if pond_m > 0.3:
			continue
		# Accept with probability based on clearing mask and density
		var accept_chance: float = mask * tree_density
		if accept_chance < 0.15:
			continue
		if tree_rng.randf() > accept_chance:
			continue

		# Pick tree type
		var tree_def: Dictionary = _pick_weighted(tree_rng, _TREE_POOL, weight_total)
		var scene_path: String = _FOREST_SCENES + tree_def["file"]
		if not ResourceLoader.exists(scene_path):
			continue

		var scene: PackedScene = load(scene_path)
		if not scene:
			continue

		var tree: Node3D = scene.instantiate()
		var s: float = tree_rng.randf_range(tree_def["min_s"] as float, tree_def["max_s"] as float)
		tree.scale = Vector3(s, s, s)
		tree.rotation.y = tree_rng.randf() * TAU

		# Position with terrain height
		var h: float = _sample_terrain_height(pos.x, pos.y)
		tree.position = Vector3(pos.x, h * terrain_scale.y, pos.y)

		_add_owned(tree, tree_parent)
		placed += 1

	print("[ForestClearingGenerator] Placed %d trees from %d candidates." % [placed, candidates.size()])


# ═══════════════════════════════════════════════════════════════════════════
# Step 4: Undergrowth
# ═══════════════════════════════════════════════════════════════════════════

const _UNDERGROWTH_POOL: Array[Dictionary] = [
	# Canopy zone (high clearing_mask)
	{"file": "fern_1.tscn",          "zone": "canopy",   "weight": 3, "min_s": 0.3, "max_s": 0.6},
	{"file": "fern_2.tscn",          "zone": "canopy",   "weight": 3, "min_s": 0.3, "max_s": 0.6},
	{"file": "bush_common.tscn",     "zone": "canopy",   "weight": 2, "min_s": 0.7, "max_s": 1.2},
	{"file": "mushroom_common.tscn", "zone": "canopy",   "weight": 2, "min_s": 0.6, "max_s": 1.2},
	{"file": "mushroom_redcap.tscn", "zone": "canopy",   "weight": 1, "min_s": 0.6, "max_s": 1.0},
	# Clearing zone (low clearing_mask)
	{"file": "flower_1_group.tscn",  "zone": "clearing", "weight": 2, "min_s": 0.3, "max_s": 0.5},
	{"file": "flower_2_group.tscn",  "zone": "clearing", "weight": 2, "min_s": 0.3, "max_s": 0.5},
	{"file": "flower_3_group.tscn",  "zone": "clearing", "weight": 2, "min_s": 0.3, "max_s": 0.5},
	{"file": "flower_4_group.tscn",  "zone": "clearing", "weight": 2, "min_s": 0.3, "max_s": 0.5},
	{"file": "clover_1.tscn",        "zone": "clearing", "weight": 2, "min_s": 0.3, "max_s": 0.5},
	# Everywhere
	{"file": "grass_common_short.tscn", "zone": "any",   "weight": 5, "min_s": 0.25, "max_s": 0.45},
	{"file": "grass_wispy_short.tscn",  "zone": "any",   "weight": 4, "min_s": 0.25, "max_s": 0.45},
	{"file": "grass_wide_short.tscn",   "zone": "any",   "weight": 3, "min_s": 0.25, "max_s": 0.45},
	{"file": "plant_1.tscn",            "zone": "any",   "weight": 2, "min_s": 0.3, "max_s": 0.5},
]


func _generate_undergrowth() -> void:
	var parent := Node3D.new()
	parent.name = "Undergrowth"
	_add_owned(parent, self)

	var w: float = (map_width - 1) * terrain_scale.x
	var d: float = (map_depth - 1) * terrain_scale.z
	var ug_rng := RandomNumberGenerator.new()
	ug_rng.seed = gen_seed + 200

	var base_count: int = int(w * d * 0.015 * undergrowth_density)
	var weight_total: int = 0
	for i in range(_UNDERGROWTH_POOL.size()):
		var entry: Dictionary = _UNDERGROWTH_POOL[i]
		weight_total += entry["weight"] as int

	var placed: int = 0
	for _i in range(base_count):
		var px: float = ug_rng.randf_range(3.0, w - 3.0)
		var pz: float = ug_rng.randf_range(3.0, d - 3.0)
		var mask: float = _get_clearing_mask(px, pz)
		var path_m: float = _get_path_mask(px, pz)
		var pond_m: float = _get_pond_mask(px, pz)

		if path_m > 0.5 or pond_m > 0.6:
			continue

		# Pick prop
		var def: Dictionary = _pick_weighted(ug_rng, _UNDERGROWTH_POOL, weight_total)
		var zone: String = def["zone"] as String

		# Zone filtering
		if zone == "canopy" and mask < 0.4:
			continue
		if zone == "clearing" and mask > 0.5:
			continue

		var scene_path: String = _FOREST_SCENES + def["file"]
		if not ResourceLoader.exists(scene_path):
			continue
		var scene: PackedScene = load(scene_path)
		if not scene:
			continue

		var obj: Node3D = scene.instantiate()
		var s: float = ug_rng.randf_range(def["min_s"] as float, def["max_s"] as float)
		obj.scale = Vector3(s, s, s)
		obj.rotation.y = ug_rng.randf() * TAU

		var h: float = _sample_terrain_height(px, pz)
		obj.position = Vector3(px, h * terrain_scale.y, pz)
		_add_owned(obj, parent)
		placed += 1

	print("[ForestClearingGenerator] Placed %d undergrowth items." % placed)


# ═══════════════════════════════════════════════════════════════════════════
# Step 5: Props
# ═══════════════════════════════════════════════════════════════════════════

func _generate_props() -> void:
	var parent := Node3D.new()
	parent.name = "Props"
	_add_owned(parent, self)

	var prop_rng := RandomNumberGenerator.new()
	prop_rng.seed = gen_seed + 300

	# Campfire at clearing center
	var campfire_path := "res://scenes/world/objects/campfire.tscn"
	if ResourceLoader.exists(campfire_path):
		var campfire_scene: PackedScene = load(campfire_path)
		if campfire_scene:
			var fire: Node3D = campfire_scene.instantiate()
			var h: float = _sample_terrain_height(_center.x, _center.y)
			fire.position = Vector3(_center.x, h * terrain_scale.y, _center.y)
			_add_owned(fire, parent)

	# Rock clusters around the clearing
	var rock_files: Array[String] = [
		"rock_medium_1.tscn", "rock_medium_2.tscn", "rock_medium_3.tscn",
		"rock_big_1.tscn", "rock_big_2.tscn",
	]
	for _cluster in range(4):
		var angle: float = prop_rng.randf() * TAU
		var dist: float = prop_rng.randf_range(0.2, 0.6) * minf(_half_size.x, _half_size.y)
		var cx: float = _center.x + cos(angle) * dist
		var cz: float = _center.y + sin(angle) * dist

		if _get_pond_mask(cx, cz) > 0.3:
			continue

		var rock_count: int = prop_rng.randi_range(2, 4)
		for _r in range(rock_count):
			var rx: float = cx + prop_rng.randf_range(-2.0, 2.0)
			var rz: float = cz + prop_rng.randf_range(-2.0, 2.0)
			var rock_file: String = rock_files[prop_rng.randi_range(0, rock_files.size() - 1)]
			var rock_path: String = _FOREST_SCENES + rock_file
			if not ResourceLoader.exists(rock_path):
				continue
			var rock_scene: PackedScene = load(rock_path)
			if not rock_scene:
				continue
			var rock: Node3D = rock_scene.instantiate()
			var s: float = prop_rng.randf_range(0.6, 1.5)
			rock.scale = Vector3(s, s, s)
			rock.rotation.y = prop_rng.randf() * TAU
			var h: float = _sample_terrain_height(rx, rz)
			rock.position = Vector3(rx, h * terrain_scale.y, rz)
			_add_owned(rock, parent)

	print("[ForestClearingGenerator] Props placed.")


# ═══════════════════════════════════════════════════════════════════════════
# Step 6: Encounters & Battle Areas
# ═══════════════════════════════════════════════════════════════════════════

const _DEFAULT_FOREST_ENCOUNTERS: Array[String] = [
	"res://data/encounters/encounter_wolves.tres",
	"res://data/encounters/encounter_wolves.tres",
	"res://data/encounters/encounter_spiders.tres",
	"res://data/encounters/encounter_spiders.tres",
	"res://data/encounters/encounter_forest_elemental.tres",
	"res://data/encounters/encounter_bats.tres",
	"res://data/encounters/encounter_slimes.tres",
]

const _ENEMY_COLORS: Array[Color] = [
	Color(0.6, 0.4, 0.2, 1.0),  # brown (wolves)
	Color(0.6, 0.4, 0.2, 1.0),
	Color(0.3, 0.3, 0.3, 1.0),  # dark grey (spiders)
	Color(0.3, 0.3, 0.3, 1.0),
	Color(0.2, 0.8, 0.3, 1.0),  # green (elemental)
	Color(0.4, 0.3, 0.5, 1.0),  # purple (bats)
	Color(0.3, 0.7, 0.3, 1.0),  # green (slimes)
]


func _generate_encounters() -> void:
	var parent := Node3D.new()
	parent.name = "Encounters"
	_add_owned(parent, self)

	if enemy_count == 0:
		print("[ForestClearingGenerator] No enemies requested.")
		return

	var enc_rng := RandomNumberGenerator.new()
	enc_rng.seed = gen_seed + 400

	var pool: Array[String] = []
	if encounter_pool.is_empty():
		pool.assign(_DEFAULT_FOREST_ENCOUNTERS)
	else:
		pool.assign(encounter_pool)

	var w: float = (map_width - 1) * terrain_scale.x
	var d: float = (map_depth - 1) * terrain_scale.z
	var bounds := Rect2(6, 6, w - 12, d - 12)

	# Use Poisson disk for enemy spacing
	var candidates: PackedVector2Array = PoissonDisk.sample_2d(bounds, enemy_min_spacing, enc_rng)

	# Filter candidates: prefer the transition zone (not deep forest, not dead center)
	var valid: Array[Vector2] = []
	for i in range(candidates.size()):
		var pos: Vector2 = candidates[i]
		var mask: float = _get_clearing_mask(pos.x, pos.y)
		var path_m: float = _get_path_mask(pos.x, pos.y)
		var pond_m: float = _get_pond_mask(pos.x, pos.y)
		# Skip paths, pond, and the very center of the clearing
		if path_m > 0.4 or pond_m > 0.3:
			continue
		if mask < 0.15:
			continue  # Too deep in clearing center
		valid.append(pos)

	# Shuffle and pick up to enemy_count
	for i in range(valid.size()):
		var j: int = enc_rng.randi_range(i, valid.size() - 1)
		var tmp: Vector2 = valid[i]
		valid[i] = valid[j]
		valid[j] = tmp

	var placed: int = 0
	for i in range(mini(enemy_count, valid.size())):
		var pos: Vector2 = valid[i]
		var enc_idx: int = enc_rng.randi_range(0, pool.size() - 1)
		var enc_path: String = pool[enc_idx]
		if not ResourceLoader.exists(enc_path):
			continue

		var color: Color = Color(0.5, 0.3, 0.3, 1.0)
		if enc_idx < _ENEMY_COLORS.size():
			color = _ENEMY_COLORS[enc_idx]

		# Create a marker node with metadata (base_map reads these at runtime)
		var marker := Node3D.new()
		marker.name = "Enemy_%d" % placed
		var h: float = _sample_terrain_height(pos.x, pos.y)
		marker.position = Vector3(pos.x, h * terrain_scale.y, pos.y)
		marker.set_meta("encounter_path", enc_path)
		marker.set_meta("enemy_color", color)
		marker.set_meta("patrol_distance", enemy_patrol_distance)

		# Editor gizmo: colored sphere + label
		if Engine.is_editor_hint():
			_build_enemy_gizmo(marker, enc_path, color, enemy_patrol_distance)

		_add_owned(marker, parent)
		placed += 1

	# Battle area at clearing center
	var ba_marker := Node3D.new()
	ba_marker.name = "BattleArea_Clearing"
	var center_h: float = _sample_terrain_height(_center.x, _center.y)
	ba_marker.position = Vector3(_center.x, center_h * terrain_scale.y, _center.y)
	ba_marker.set_meta("battle_area_name", "Forest Clearing")

	# Editor gizmo: red translucent disc
	if Engine.is_editor_hint():
		_build_battle_area_gizmo(ba_marker)

	_add_owned(ba_marker, parent)

	print("[ForestClearingGenerator] Placed %d enemies + 1 battle area." % placed)


# ═══════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════

func _build_enemy_gizmo(marker: Node3D, enc_path: String, color: Color, _patrol_dist: float) -> void:
	# Simple colored box (cheap, no CSG boolean overhead)
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 1.4, 0.6)
	mesh_inst.mesh = box
	mesh_inst.position.y = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat
	marker.add_child(mesh_inst)

	# Label
	var label := Label3D.new()
	label.text = enc_path.get_file().trim_suffix(".tres").trim_prefix("encounter_")
	label.position.y = 2.0
	label.font_size = 32
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	marker.add_child(label)


func _build_battle_area_gizmo(marker: Node3D) -> void:
	var mesh_inst := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 7.0
	disc.bottom_radius = 7.0
	disc.height = 0.1
	disc.radial_segments = 24
	mesh_inst.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2, 0.15)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat
	marker.add_child(mesh_inst)

	var label := Label3D.new()
	label.text = "BATTLE AREA"
	label.position.y = 1.5
	label.font_size = 40
	label.modulate = Color(1.0, 0.3, 0.3)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	marker.add_child(label)


func _sample_terrain_height(world_x: float, world_z: float) -> float:
	## Sample height from the heightmap data in vertex space.
	if not _heightmap:
		return 0.0
	var vx: float = world_x / terrain_scale.x
	var vz: float = world_z / terrain_scale.z
	var ix: int = int(vx)
	var iz: int = int(vz)
	var fx: float = vx - ix
	var fz: float = vz - iz
	# Bilinear interpolation
	var h00: float = _heightmap.get_height_at(ix, iz)
	var h10: float = _heightmap.get_height_at(ix + 1, iz)
	var h01: float = _heightmap.get_height_at(ix, iz + 1)
	var h11: float = _heightmap.get_height_at(ix + 1, iz + 1)
	var h0: float = lerpf(h00, h10, fx)
	var h1: float = lerpf(h01, h11, fx)
	return lerpf(h0, h1, fz)


func _pick_weighted(rng: RandomNumberGenerator, pool: Array[Dictionary], total_weight: int) -> Dictionary:
	var roll: int = rng.randi_range(0, total_weight - 1)
	var cumulative: int = 0
	for i in range(pool.size()):
		var entry: Dictionary = pool[i]
		cumulative += entry["weight"] as int
		if roll < cumulative:
			return entry
	return pool[pool.size() - 1]


func _add_owned(node: Node, parent_node: Node) -> void:
	## Adds a node as a child and sets owner so it saves with the .tscn.
	parent_node.add_child(node)
	var scene_root: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	node.owner = scene_root
	# Also set owner for all descendants (instantiated scenes)
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	node.owner = scene_root
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)
