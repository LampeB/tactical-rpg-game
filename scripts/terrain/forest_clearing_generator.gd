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
const _ENVIRONMENT_SCENE := "res://scenes/shared/environment_3d.tscn"
const _WIND_SHADER := "res://shaders/foliage_wind.gdshader"
const _MapParticleEmitter := preload("res://scripts/terrain/map_particle_emitter.gd")

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

# ─── Inspector: River ───────────────────────────────────────────────────────
@export_group("River")
@export var enable_river: bool = false
@export_range(1.0, 6.0) var river_width: float = 2.5
@export_range(0.5, 3.0) var river_water_width: float = 1.0  ## Multiplier for the water surface width relative to carving
@export_range(0.05, 0.3) var river_carve_depth: float = 0.14
@export_range(-2.0, 2.0) var river_water_y_offset: float = 0.0  ## Vertical offset for water surface
@export var use_custom_river_points: bool = false:
	set(value):
		use_custom_river_points = value
		if Engine.is_editor_hint() and is_inside_tree():
			_toggle_river_gizmos()

# ─── Inspector: Vegetation ──────────────────────────────────────────────────
@export_group("Vegetation")
@export_range(0.0, 3.0) var tree_density: float = 1.0
@export_range(0.0, 3.0) var undergrowth_density: float = 1.0
@export_range(2.0, 8.0) var tree_min_spacing: float = 3.5

# ─── Inspector: Connections & Paths ─────────────────────────────────────────
@export_group("Connections")
## MapConnection resources to place at map edges. Paths are carved from each to its target.
@export var connections: Array[MapConnection] = []
## Target point for each connection's path (index matches connections array).
## Vector3.ZERO = go to map center. Set XZ to create branching paths.
@export var path_targets: Array[Vector3] = []
## Extra path segments between any two points (for branches, shortcuts, loops).
## Each entry is a pair: [from: Vector3, to: Vector3] flattened as [x1,z1, x2,z2].
@export var extra_paths: Array[Vector4] = []
@export_range(1.0, 12.0) var path_width: float = 5.0

# ─── Inspector: Encounters ──────────────────────────────────────────────────
@export_group("Encounters")
@export_range(0, 50) var enemy_count: int = 5
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
var _path_polylines: Array = []  # Array of PackedVector2Array (curved path waypoints)
var _path_junctions: PackedVector2Array = PackedVector2Array()  # Points where paths meet
var _river_polyline: PackedVector2Array = PackedVector2Array()  # River centerline (for crossing detection)
var _river_crossings: PackedVector2Array = PackedVector2Array()  # Points where paths cross the river
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
	_generate_river()
	_generate_water()
	_generate_trees()
	_generate_undergrowth()
	_generate_props()
	_generate_encounters()
	_generate_connections()
	_generate_environment()
	_generate_particles()
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
		if child.name == "HandPlaced" or child.name == "RiverStart" or child.name == "RiverEnd":
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

	# Build curved path polylines from connection edges to their targets
	_path_polylines.clear()
	var path_rng := RandomNumberGenerator.new()
	path_rng.seed = gen_seed + 500
	var conn_count: int = connections.size()
	if conn_count == 0:
		conn_count = 2
	for i in range(conn_count):
		var edge: Vector2
		if i < connections.size() and connections[i].position != Vector3.ZERO:
			edge = Vector2(connections[i].position.x, connections[i].position.z)
		else:
			var angle: float = (float(i) / conn_count) * TAU + PI * 0.5
			edge = Vector2(
				_center.x + cos(angle) * _half_size.x,
				_center.y + sin(angle) * _half_size.y
			)
		# Determine target: custom path_target or default to center
		var target: Vector2 = _center
		if i < path_targets.size() and path_targets[i] != Vector3.ZERO:
			target = Vector2(path_targets[i].x, path_targets[i].z)
		var polyline: PackedVector2Array = _build_curved_path(edge, target, path_rng)
		_path_polylines.append(polyline)

	# Extra path segments (branches, shortcuts)
	for i in range(extra_paths.size()):
		var ep: Vector4 = extra_paths[i]
		var from := Vector2(ep.x, ep.y)
		var to := Vector2(ep.z, ep.w)
		var polyline: PackedVector2Array = _build_curved_path(from, to, path_rng)
		_path_polylines.append(polyline)

	# Collect junction points (endpoints where paths converge)
	_path_junctions.clear()
	var endpoint_counts: Dictionary = {}
	for pi in range(_path_polylines.size()):
		var poly: PackedVector2Array = _path_polylines[pi]
		if poly.size() < 2:
			continue
		var last: Vector2 = poly[poly.size() - 1]
		# Round to 1 decimal to group nearby endpoints
		var key := Vector2i(roundi(last.x), roundi(last.y))
		endpoint_counts[key] = endpoint_counts.get(key, 0) + 1
		var first: Vector2 = poly[0]
		var fkey := Vector2i(roundi(first.x), roundi(first.y))
		endpoint_counts[fkey] = endpoint_counts.get(fkey, 0) + 1
	for key in endpoint_counts:
		if endpoint_counts[key] >= 2:
			_path_junctions.append(Vector2(key.x, key.y))

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
	## Checks distance to nearest segment of each curved polyline.
	## Fades out near the clearing center so paths don't dominate the clearing.
	var best: float = 0.0
	var p := Vector2(world_x, world_z)
	for pi in range(_path_polylines.size()):
		var poly: PackedVector2Array = _path_polylines[pi]
		for si in range(poly.size() - 1):
			var closest: Vector2 = _closest_point_on_segment(p, poly[si], poly[si + 1])
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


func _build_curved_path(from: Vector2, to: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	## Builds a curved polyline from `from` to `to` with natural-looking bends.
	## Uses perpendicular noise offsets at evenly-spaced waypoints.
	var points := PackedVector2Array()
	var total_dist: float = from.distance_to(to)
	var segment_length: float = 4.0  # Waypoint every ~4 world units
	var num_segments: int = maxi(3, int(total_dist / segment_length))
	var direction: Vector2 = (to - from).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)

	# Curve amplitude scales with distance but caps for natural look
	var amplitude: float = minf(total_dist * 0.15, 12.0)

	points.append(from)
	for i in range(1, num_segments):
		var t: float = float(i) / num_segments
		var base: Vector2 = from.lerp(to, t)
		# Noise offset perpendicular to path — stronger in middle, zero at endpoints
		var envelope: float = sin(t * PI)  # 0 at edges, 1 at midpoint
		var offset: float = rng.randf_range(-amplitude, amplitude) * envelope
		var point: Vector2 = base + perpendicular * offset
		points.append(point)
	points.append(to)

	# Smooth pass: average each interior point with its neighbours
	for _pass in range(2):
		for i in range(1, points.size() - 1):
			points[i] = (points[i - 1] + points[i] * 2.0 + points[i + 1]) * 0.25

	return points


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

			# Flatten paths + junctions
			var flatten_m: float = path_m
			for ji in range(_path_junctions.size()):
				var jpt: Vector2 = _path_junctions[ji]
				var jdx: float = (wx - jpt.x) / (path_width * 1.5)
				var jdz: float = (wz - jpt.y) / (path_width * 1.5)
				var jflat: float = 1.0 - smoothstep(0.0, 1.0, sqrt(jdx * jdx + jdz * jdz))
				flatten_m = maxf(flatten_m, jflat)
			h = lerpf(h, 0.0, flatten_m * 0.8)

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
			# Add dirt circles at path junctions where paths converge
			for ji in range(_path_junctions.size()):
				var jpt: Vector2 = _path_junctions[ji]
				var jdx: float = (wx - jpt.x) / (path_width * 1.5)
				var jdz: float = (wz - jpt.y) / (path_width * 1.5)
				var jdirt: float = 1.0 - smoothstep(0.0, 1.0, sqrt(jdx * jdx + jdz * jdz))
				path_m = maxf(path_m, jdirt)

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
# Step 2b: River
# ═══════════════════════════════════════════════════════════════════════════

func _create_river_gizmo(gizmo_name: String, pos: Vector3, color: Color) -> Node3D:
	var g := Node3D.new()
	g.name = gizmo_name
	g.position = pos
	add_child(g)
	var scene_root: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	g.owner = scene_root
	_add_gizmo_visuals(g, color)
	return g


func _add_gizmo_visuals(g: Node3D, color: Color) -> void:
	var sm := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.0
	sphere.height = 4.0
	sm.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material_override = mat
	g.add_child(sm)

	var lbl := Label3D.new()
	lbl.text = g.name.to_upper().replace("_", " ")
	lbl.position.y = 3.0
	lbl.font_size = 32
	lbl.modulate = Color(color.r, color.g, color.b, 1.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	g.add_child(lbl)


func _toggle_river_gizmos() -> void:
	if use_custom_river_points:
		# Gizmos created on next Generate All
		pass
	else:
		var start_node: Node = get_node_or_null("RiverStart")
		if start_node:
			start_node.queue_free()
		var end_node: Node = get_node_or_null("RiverEnd")
		if end_node:
			end_node.queue_free()


func _generate_river() -> void:
	if not enable_river or not _heightmap:
		return

	var w: float = (map_width - 1) * terrain_scale.x
	var d: float = (map_depth - 1) * terrain_scale.z
	var river_rng := RandomNumberGenerator.new()
	river_rng.seed = gen_seed + 700

	# Determine start/end positions
	var start: Vector3
	var end: Vector3
	var start_gizmo: Node3D = get_node_or_null("RiverStart") as Node3D
	var end_gizmo: Node3D = get_node_or_null("RiverEnd") as Node3D

	if use_custom_river_points:
		# Create or reuse gizmos
		if not start_gizmo:
			start_gizmo = _create_river_gizmo("RiverStart", Vector3(2, 0, d * 0.5), Color(0, 0.5, 1, 0.7))
		elif start_gizmo.get_child_count() == 0 and Engine.is_editor_hint():
			# Saved node with no visuals — add them
			_add_gizmo_visuals(start_gizmo, Color(0, 0.5, 1, 0.7))
		if not end_gizmo:
			end_gizmo = _create_river_gizmo("RiverEnd", Vector3(w - 2, 0, d * 0.5), Color(1, 0.3, 0, 0.7))
		elif end_gizmo.get_child_count() == 0 and Engine.is_editor_hint():
			_add_gizmo_visuals(end_gizmo, Color(1, 0.3, 0, 0.7))
		start = start_gizmo.position
		end = end_gizmo.position
	else:
		start = Vector3(2.0, 0, river_rng.randf_range(d * 0.3, d * 0.7))
		end = Vector3(w - 2.0, 0, river_rng.randf_range(d * 0.3, d * 0.7))

	# Build curved polyline for the river (dense — 1 point per unit for precise carving)
	var raw_polyline: PackedVector2Array = _build_curved_path(
		Vector2(start.x, start.z), Vector2(end.x, end.z), river_rng)
	# Subdivide to get ~1 point per world unit
	var polyline := PackedVector2Array()
	for i in range(raw_polyline.size() - 1):
		var a: Vector2 = raw_polyline[i]
		var b: Vector2 = raw_polyline[i + 1]
		var seg_len: float = a.distance_to(b)
		var steps: int = maxi(1, ceili(seg_len))
		for s in range(steps):
			var st: float = float(s) / steps
			polyline.append(a.lerp(b, st))
	polyline.append(raw_polyline[raw_polyline.size() - 1])

	# Convert to 3D RiverPath with terrain heights and carving
	var rp := RiverPath.new()
	rp.id = "forest_river"
	_river_polyline = polyline  # Store for crossing detection

	var points := PackedVector3Array()
	var widths := PackedFloat32Array()
	points.resize(polyline.size())
	widths.resize(polyline.size())

	# Pre-sample terrain heights BEFORE carving (so later points don't read carved values)
	var original_heights := PackedFloat32Array()
	original_heights.resize(polyline.size())
	for i in range(polyline.size()):
		original_heights[i] = _sample_terrain_height(polyline[i].x, polyline[i].y)

	for i in range(polyline.size()):
		var px: float = polyline[i].x
		var pz: float = polyline[i].y
		var h: float = original_heights[i]

		# Carve terrain along river channel
		var vx: int = clampi(roundi(px / terrain_scale.x), 0, map_width - 1)
		var vz: int = clampi(roundi(pz / terrain_scale.z), 0, map_depth - 1)
		# Taper width: narrower at edges, wider in the middle
		var t: float = float(i) / maxf(polyline.size() - 1, 1)
		var taper: float = sin(t * PI)
		var half_w: float = river_width * (0.6 + 0.4 * taper)
		widths[i] = half_w * river_water_width

		# Carve terrain — same width as water mesh
		var carve_radius: int = ceili(half_w * 1.1 / terrain_scale.x) + 1
		for dz in range(-carve_radius, carve_radius + 1):
			for dx in range(-carve_radius, carve_radius + 1):
				var nx: int = vx + dx
				var nz: int = vz + dz
				if nx < 0 or nx >= map_width or nz < 0 or nz >= map_depth:
					continue
				var dist: float = sqrt(float(dx * dx + dz * dz)) * terrain_scale.x
				if dist > half_w * 1.1:
					continue
				var old_h: float = _heightmap.get_height_at(nx, nz)
				var blend: float = 1.0 - smoothstep(half_w * 0.7, half_w * 1.1, dist)
				var target_h: float = h - river_carve_depth
				var new_h: float = lerpf(old_h, target_h, blend)
				_heightmap.set_height_at(nx, nz, maxf(new_h, target_h))
				# Paint mud on banks (just outside water edge)
				if dist > half_w * 0.5 and dist < half_w * 2.0:
					var mud_blend: float = 1.0 - smoothstep(half_w, half_w * 2.0, dist)
					var cur: Color = _heightmap.get_splatmap_weights(nx, nz)
					cur.a = maxf(cur.a, mud_blend * 0.7)
					var total: float = cur.r + cur.g + cur.b + cur.a
					if total > 0.001:
						cur.r /= total; cur.g /= total; cur.b /= total; cur.a /= total
					_heightmap.set_splatmap_weights(nx, nz, cur)

		points[i] = Vector3(px, (h - river_carve_depth) * terrain_scale.y + river_water_y_offset, pz)

	rp.points = points
	rp.widths = widths
	_heightmap.rivers.clear()
	_heightmap.rivers.append(rp)
	_heightmap.build_river_mask(ceili(river_width / terrain_scale.x) + 2)

	# Force terrain rebuild to show carved river + river mesh
	var terrain: Node = null
	for i in range(get_child_count()):
		if get_child(i).name == "HeightmapTerrain3D":
			terrain = get_child(i)
			break
	# Rebuild terrain to apply carved heights + build river mesh
	if terrain:
		terrain.call("_rebuild")

	# Create river mesh as a visible child
	_remove_layer("River")
	var river_parent := Node3D.new()
	river_parent.name = "River"
	_add_owned(river_parent, self)

	var river_body: MeshInstance3D = RiverBody.new()
	river_body.name = "RiverMesh"
	river_parent.add_child(river_body)
	river_body.setup(rp)
	if Engine.is_editor_hint():
		river_body.owner = get_tree().edited_scene_root

	# Invisible walls along river banks (prevents player from walking into water)
	_build_river_walls(points, widths, river_parent)
	print("[ForestClearingGenerator] River walls: %d shapes" % (river_parent.get_node_or_null("RiverWalls").get_child_count() if river_parent.get_node_or_null("RiverWalls") else 0))

	# Detect where paths cross the river and place bridge markers
	_detect_river_crossings()
	_place_bridge_markers(river_parent, points, widths)

	print("[ForestClearingGenerator] River generated with %d points, %d crossings." % [
		points.size(), _river_crossings.size()])


func _detect_river_crossings() -> void:
	_river_crossings.clear()
	if _river_polyline.is_empty() or _path_polylines.is_empty():
		return
	# Check each path segment against each river segment
	for pi in range(_path_polylines.size()):
		var path: PackedVector2Array = _path_polylines[pi]
		for si in range(path.size() - 1):
			var a: Vector2 = path[si]
			var b: Vector2 = path[si + 1]
			for ri in range(_river_polyline.size() - 1):
				var c: Vector2 = _river_polyline[ri]
				var d: Vector2 = _river_polyline[ri + 1]
				var crossing: Variant = _segment_intersection(a, b, c, d)
				if crossing is Vector2:
					# Check if this crossing is near an existing one (avoid duplicates)
					var is_dup: bool = false
					for existing in _river_crossings:
						if existing.distance_to(crossing) < 5.0:
							is_dup = true
							break
					if not is_dup:
						_river_crossings.append(crossing)
						print("[ForestClearingGenerator] River crossing at (%.1f, %.1f)" % [crossing.x, crossing.y])


static func _segment_intersection(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Variant:
	## Returns intersection point of segments AB and CD, or null if they don't cross.
	var ab: Vector2 = b - a
	var cd: Vector2 = d - c
	var denom: float = ab.x * cd.y - ab.y * cd.x
	if absf(denom) < 0.0001:
		return null  # Parallel
	var ac: Vector2 = c - a
	var t: float = (ac.x * cd.y - ac.y * cd.x) / denom
	var u: float = (ac.x * ab.y - ac.y * ab.x) / denom
	if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0:
		return a + ab * t
	return null


func _place_bridge_markers(river_parent: Node3D, points: PackedVector3Array, widths: PackedFloat32Array) -> void:
	for ci in range(_river_crossings.size()):
		var crossing: Vector2 = _river_crossings[ci]
		var h: float = _sample_terrain_height(crossing.x, crossing.y)

		# Find the river width at this crossing point
		var bridge_width: float = river_width
		var min_dist: float = INF
		for i in range(points.size()):
			var d: float = Vector2(points[i].x, points[i].z).distance_to(crossing)
			if d < min_dist:
				min_dist = d
				bridge_width = widths[i] if i < widths.size() else river_width

		# Find path direction at crossing for bridge rotation
		var bridge_rot: float = 0.0
		for pi in range(_path_polylines.size()):
			var path: PackedVector2Array = _path_polylines[pi]
			for si in range(path.size() - 1):
				var seg_mid: Vector2 = (path[si] + path[si + 1]) * 0.5
				if seg_mid.distance_to(crossing) < 5.0:
					var dir: Vector2 = (path[si + 1] - path[si]).normalized()
					bridge_rot = atan2(dir.x, dir.y)
					break

		# Create bridge marker
		var marker := Node3D.new()
		marker.name = "Bridge_%d" % ci
		marker.position = Vector3(crossing.x, h * terrain_scale.y, crossing.y)
		marker.rotation.y = bridge_rot
		marker.set_meta("bridge_width", bridge_width * 2.0 + 1.0)
		marker.set_meta("bridge_length", path_width + 1.0)

		# Editor gizmo
		if Engine.is_editor_hint():
			var mesh_inst := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(path_width + 1.0, 0.3, bridge_width * 2.0 + 1.0)
			mesh_inst.mesh = box
			mesh_inst.position.y = 0.2
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.6, 0.4, 0.2, 0.7)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh_inst.material_override = mat
			marker.add_child(mesh_inst)

			var lbl := Label3D.new()
			lbl.text = "BRIDGE"
			lbl.position.y = 1.5
			lbl.font_size = 28
			lbl.modulate = Color(0.8, 0.6, 0.3)
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.no_depth_test = true
			marker.add_child(lbl)

		_add_owned(marker, river_parent)


func _build_river_walls(points: PackedVector3Array, widths: PackedFloat32Array, parent: Node3D) -> void:
	# One StaticBody3D with cylinder colliders matching the carved circles
	var wall := StaticBody3D.new()
	wall.name = "RiverWalls"
	wall.collision_layer = 1
	wall.collision_mask = 0
	_add_owned(wall, parent)

	# Place cylinders every few points
	var step: int = maxi(1, points.size() / 60)
	for i in range(0, points.size(), step):
		var p: Vector3 = points[i]
		var half_w: float = widths[i] if i < widths.size() else 2.0

		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = half_w + 0.3
		cyl.height = 4.0
		col.shape = cyl
		col.position = Vector3(p.x, p.y + 0.3, p.z)
		wall.add_child(col)
		col.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self


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

		# Reject: in clearing center, on paths, in pond, or in river
		if path_m > 0.3:
			continue
		if pond_m > 0.3:
			continue
		if _is_in_river(pos.x, pos.y):
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

	var base_count: int = int(w * d * 0.007 * undergrowth_density)
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

		if path_m > 0.5 or pond_m > 0.6 or _is_in_river(px, pz):
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
		if path_m > 0.4 or pond_m > 0.3 or _is_in_river(pos.x, pos.y):
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
# Step 7: Connection Markers
# ═══════════════════════════════════════════════════════════════════════════

func _generate_connections() -> void:
	if connections.is_empty():
		print("[ForestClearingGenerator] No connections defined.")
		return

	_remove_layer("Connections")
	var parent := Node3D.new()
	parent.name = "Connections"
	_add_owned(parent, self)

	var w: float = (map_width - 1) * terrain_scale.x
	var d: float = (map_depth - 1) * terrain_scale.z
	var conn_count: int = connections.size()

	for i in range(conn_count):
		var conn: MapConnection = connections[i]

		# Determine edge position
		var edge_pos: Vector3
		if conn.position != Vector3.ZERO:
			edge_pos = conn.position
		else:
			# Auto-place evenly around map edge
			var angle: float = (float(i) / conn_count) * TAU + PI * 0.5
			edge_pos = Vector3(
				_center.x + cos(angle) * _half_size.x,
				0,
				_center.y + sin(angle) * _half_size.y
			)
			# Clamp to map bounds with margin
			edge_pos.x = clampf(edge_pos.x, 3.0, w - 3.0)
			edge_pos.z = clampf(edge_pos.z, 3.0, d - 3.0)

		# Ground to terrain height
		var h: float = _sample_terrain_height(edge_pos.x, edge_pos.z)
		edge_pos.y = h * terrain_scale.y

		# Update the connection resource position so MapLoader uses the right spot
		conn.position = edge_pos

		# Create marker node with metadata for runtime spawning
		var marker := Node3D.new()
		marker.name = "Connection_%s" % conn.connection_id
		marker.position = edge_pos
		marker.set_meta("connection_index", i)

		# Editor gizmo
		if Engine.is_editor_hint():
			_build_connection_gizmo(marker, conn)

		_add_owned(marker, parent)

	print("[ForestClearingGenerator] Placed %d connections." % conn_count)


# ═══════════════════════════════════════════════════════════════════════════
# Step 8: Environment (lighting, sky, fog) + Wind shader on undergrowth
# ═══════════════════════════════════════════════════════════════════════════

func _generate_environment() -> void:
	_remove_layer("Environment3D")

	# Add the shared environment scene (sun, fill light, moon, WorldEnvironment with SSAO)
	if ResourceLoader.exists(_ENVIRONMENT_SCENE):
		var env_scene: PackedScene = load(_ENVIRONMENT_SCENE)
		if env_scene:
			var env: Node3D = env_scene.instantiate()
			_add_owned(env, self)

			# Add forest fog to the environment
			var world_env: WorldEnvironment = env.find_child("WorldEnvironment", false, false) as WorldEnvironment
			if world_env and world_env.environment:
				var e: Environment = world_env.environment
				e.fog_enabled = true
				e.fog_light_color = Color(0.55, 0.62, 0.5)
				e.fog_density = 0.008
				e.fog_sky_affect = 0.3
				e.volumetric_fog_enabled = true
				e.volumetric_fog_density = 0.02
				e.volumetric_fog_albedo = Color(0.6, 0.65, 0.55)
				e.volumetric_fog_emission = Color(0.1, 0.12, 0.08)
				e.volumetric_fog_length = 80.0

			print("[ForestClearingGenerator] Added environment (light + sky + SSAO + fog).")

	# Apply wind shader to vegetation
	_apply_wind_to_layer("Undergrowth", 0.25, 1.5, 0.5)
	_apply_wind_to_layer("Trees", 0.12, 0.8, 10.0)  # High mesh_height = only tips sway


func _apply_wind_to_layer(layer_name: String, strength: float, speed: float, mesh_height: float) -> void:
	## Applies foliage_wind shader to all MeshInstance3D nodes in the named layer.
	var layer: Node = null
	for i in range(get_child_count()):
		if get_child(i).name == layer_name:
			layer = get_child(i)
			break
	if not layer:
		return
	if not ResourceLoader.exists(_WIND_SHADER):
		return
	var shader: Shader = load(_WIND_SHADER)
	if not shader:
		return

	var count: int = 0
	for i in range(layer.get_child_count()):
		_apply_wind_recursive(layer.get_child(i), shader, strength, speed, mesh_height)
		count += 1
	print("[ForestClearingGenerator] Applied wind to %d items in %s." % [count, layer_name])


func _apply_wind_recursive(node: Node, shader: Shader, strength: float, speed: float, mesh_height: float) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh:
			var mesh_copy: Mesh = mi.mesh.duplicate()
			for si in range(mesh_copy.get_surface_count()):
				var orig_mat: Material = mesh_copy.surface_get_material(si)
				var wind_mat := ShaderMaterial.new()
				wind_mat.shader = shader
				if orig_mat is StandardMaterial3D:
					var std: StandardMaterial3D = orig_mat as StandardMaterial3D
					if std.albedo_texture:
						wind_mat.set_shader_parameter("base_texture", std.albedo_texture)
					if std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
						wind_mat.set_shader_parameter("alpha_scissor", std.alpha_scissor_threshold)
				wind_mat.set_shader_parameter("wind_strength", strength)
				wind_mat.set_shader_parameter("wind_speed", speed)
				wind_mat.set_shader_parameter("mesh_height", mesh_height)
				mesh_copy.surface_set_material(si, wind_mat)
			mi.mesh = mesh_copy
	for i in range(node.get_child_count()):
		_apply_wind_recursive(node.get_child(i), shader, strength, speed, mesh_height)


# ═══════════════════════════════════════════════════════════════════════════
# Step 9: Ambient Particles
# ═══════════════════════════════════════════════════════════════════════════

func _generate_particles() -> void:
	_remove_layer("Particles")
	var parent := Node3D.new()
	parent.name = "Particles"
	_add_owned(parent, self)

	# Campfire embers at center
	var campfire_h: float = _sample_terrain_height(_center.x, _center.y)
	var campfire_emitter: Node3D = _MapParticleEmitter.new()
	campfire_emitter.name = "CampfireEmbers"
	campfire_emitter.position = Vector3(_center.x, campfire_h * terrain_scale.y + 0.5, _center.y)
	campfire_emitter.set("preset", _MapParticleEmitter.ParticlePreset.CAMPFIRE)
	_add_owned(campfire_emitter, parent)

	# Fireflies near pond
	if enable_pond:
		var pond_h: float = _sample_terrain_height(_pond_center.x, _pond_center.y)
		var firefly_emitter: Node3D = _MapParticleEmitter.new()
		firefly_emitter.name = "PondFireflies"
		firefly_emitter.position = Vector3(_pond_center.x, pond_h * terrain_scale.y + 1.0, _pond_center.y)
		firefly_emitter.set("preset", _MapParticleEmitter.ParticlePreset.FIREFLIES)
		_add_owned(firefly_emitter, parent)

	# Dust motes in the clearing
	var dust_emitter: Node3D = _MapParticleEmitter.new()
	dust_emitter.name = "ClearingDust"
	var clearing_h: float = _sample_terrain_height(_center.x, _center.y)
	dust_emitter.position = Vector3(_center.x, clearing_h * terrain_scale.y + 2.0, _center.y)
	dust_emitter.set("preset", _MapParticleEmitter.ParticlePreset.DUST_MOTES)
	_add_owned(dust_emitter, parent)

	# Leaves falling across the forest canopy (4 wide emitters scaled to cover large areas)
	var leaf_rng := RandomNumberGenerator.new()
	leaf_rng.seed = gen_seed + 600
	for i in range(4):
		var angle: float = (float(i) / 4.0) * TAU + PI * 0.25
		var dist: float = minf(_half_size.x, _half_size.y) * 0.7
		var lx: float = _center.x + cos(angle) * dist
		var lz: float = _center.y + sin(angle) * dist
		var lh: float = _sample_terrain_height(lx, lz)
		var leaf_emitter: Node3D = _MapParticleEmitter.new()
		leaf_emitter.name = "Leaves_%d" % i
		leaf_emitter.position = Vector3(lx, lh * terrain_scale.y + 7.5, lz)
		# Scale the emitter to cover a wide area (emission box is small, scale stretches it)
		leaf_emitter.scale = Vector3(75, 15, 255)
		leaf_emitter.set("preset", _MapParticleEmitter.ParticlePreset.LEAVES_FALLING)
		_add_owned(leaf_emitter, parent)

	print("[ForestClearingGenerator] Placed %d particle emitters." % parent.get_child_count())


# ═══════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════

func _build_connection_gizmo(marker: Node3D, conn: MapConnection) -> void:
	# Blue pillar (matching ConnectionMarker style)
	var mesh_inst := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.3
	cylinder.bottom_radius = 0.3
	cylinder.height = 3.0
	mesh_inst.mesh = cylinder
	mesh_inst.position.y = 1.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.5, 1.0)
	mat.emission_energy_multiplier = 0.5
	mesh_inst.material_override = mat
	marker.add_child(mesh_inst)

	# Name label
	var label := Label3D.new()
	label.text = conn.display_name if not conn.display_name.is_empty() else conn.connection_id
	label.position.y = 3.5
	label.font_size = 40
	label.modulate = Color(0.5, 0.8, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	marker.add_child(label)

	# Target label
	var target_label := Label3D.new()
	target_label.text = "-> %s" % conn.target_map_id
	target_label.position.y = 3.0
	target_label.font_size = 24
	target_label.modulate = Color(0.4, 0.6, 0.8)
	target_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	target_label.no_depth_test = true
	marker.add_child(target_label)


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


func _is_in_river(world_x: float, world_z: float) -> bool:
	if not _heightmap or not enable_river:
		return false
	var vx: int = roundi(world_x / terrain_scale.x)
	var vz: int = roundi(world_z / terrain_scale.z)
	return _heightmap.is_river_at(vx, vz)


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
