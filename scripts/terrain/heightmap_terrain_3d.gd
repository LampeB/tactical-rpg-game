@tool
class_name HeightmapTerrain3D
extends Node3D
## @tool node that renders heightmap terrain directly in the Godot 3D viewport.
## Can either load an existing HeightmapData .tres or generate one from parameters.
## Supports ORA-based map painting workflow (export → edit in GIMP → import).

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
@export_range(17, 1025) var gen_width: int = 129
@export_range(17, 1025) var gen_depth: int = 81
@export var gen_seed: int = 42
@export var use_overworld_generator: bool = false
@export var generate: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_generate_heightmap()

@export_group("Map Painting")
@export var export_map_layers: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_export_zone_map()
## Import individual layers — click in order (top to bottom):
@export var import_1_of_6_heightmap: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_import_single("heightmap")
@export var import_2_of_6_zones: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_import_single("zones")
@export var import_3_of_6_rivers: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_import_single("rivers")
@export var import_4_of_6_roads: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_import_single("roads")
@export var import_5_of_6_pois: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_import_single("pois")
@export var import_6_of_6_walls: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_import_single("walls")
@export var import_all: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_import_all_layers()

@export_group("Editor Preview")
@export_range(0, 2) var preview_lod: int = 0:
	set(value):
		preview_lod = value
		if is_inside_tree() and Engine.is_editor_hint():
			_rebuild()
@export var show_walls: bool = false:
	set(value):
		show_walls = value
		if is_inside_tree() and Engine.is_editor_hint():
			_rebuild_wall_overlay()


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const ORA_SCALE: int = 7
const _POI_CIRCLE_RADIUS: int = 5

## Wall types
const WALL_MOUNTAIN: int = 1
const WALL_WATER: int = 2
const WALL_GATE: int = 3
const WALL_BARRIER: int = 4
const WALL_FOREST: int = 5
const WALL_DEATHBLIGHT: int = 6

const _WALL_COLORS: Dictionary = {
	WALL_MOUNTAIN:    Color(1.0, 0.0, 0.0, 1.0),
	WALL_WATER:       Color(0.0, 0.0, 1.0, 1.0),
	WALL_GATE:        Color(1.0, 1.0, 1.0, 1.0),
	WALL_BARRIER:     Color(0.5, 0.0, 1.0, 1.0),
	WALL_FOREST:      Color(0.0, 0.8, 0.0, 1.0),
	WALL_DEATHBLIGHT: Color(0.3, 0.3, 0.3, 1.0),
}

const _WALL_FLAGS: Dictionary = {
	WALL_MOUNTAIN:    "has_airship",
	WALL_WATER:       "has_boat",
	WALL_GATE:        "gate_opened",
	WALL_BARRIER:     "barrier_broken",
	WALL_FOREST:      "forest_cleared",
	WALL_DEATHBLIGHT: "blight_cured",
}

## POI type → pixel color
const _POI_COLORS: Dictionary = {
	PointOfInterest.Type.DUNGEON: Color(1.0, 0.0, 0.0, 1.0),
	PointOfInterest.Type.RUINS:   Color(1.0, 0.5, 0.0, 1.0),
	PointOfInterest.Type.CAMP:    Color(0.0, 0.6, 0.0, 1.0),
	PointOfInterest.Type.SHRINE:  Color(0.0, 1.0, 1.0, 1.0),
	PointOfInterest.Type.CITY:    Color(1.0, 1.0, 0.0, 1.0),
	PointOfInterest.Type.VILLAGE: Color(0.6, 1.0, 0.2, 1.0),
	PointOfInterest.Type.GATE:    Color(1.0, 1.0, 1.0, 1.0),
	PointOfInterest.Type.BRIDGE:  Color(1.0, 0.0, 1.0, 1.0),
}

## Zone ID → pixel color
const _ZONE_COLORS: Dictionary = {
	0:   Color(0.0, 0.0, 0.5),
	1:   Color(0.0, 0.8, 0.0),
	2:   Color(1.0, 0.9, 0.0),
	3:   Color(0.5, 0.0, 0.5),
	4:   Color(0.2, 0.2, 0.2),
	5:   Color(0.8, 0.8, 0.8),
	255: Color(1.0, 1.0, 1.0),
}


# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------
var _chunk_parent: Node3D = null
var _river_parent: Node3D = null
var _water_parent: Node3D = null
var _prop_parent: Node3D = null
var _poi_parent: Node3D = null
var _wall_overlay: Node3D = null
var _chunks: Dictionary = {}


func _ready() -> void:
	_rebuild()


func _generate_heightmap() -> void:
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
		heightmap_data.get_chunk_count_x() * heightmap_data.get_chunk_count_z()])


# ---------------------------------------------------------------------------
# Rebuild
# ---------------------------------------------------------------------------

func _rebuild() -> void:
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

	_rebuild_rivers()
	_rebuild_water()
	_rebuild_props()
	_rebuild_pois()
	_rebuild_wall_overlay()


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
	for ri in range(heightmap_data.rivers.size()):
		var rp = heightmap_data.rivers[ri]
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
	for i in range(heightmap_data.water_zones.size()):
		var zone = heightmap_data.water_zones[i]
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


func _rebuild_pois() -> void:
	if _poi_parent:
		for child in _poi_parent.get_children():
			child.queue_free()
	else:
		_poi_parent = Node3D.new()
		_poi_parent.name = "POIs"
		add_child(_poi_parent)
	if not heightmap_data:
		return
	var ts: Vector3 = heightmap_data.terrain_scale
	for pi in range(heightmap_data.points_of_interest.size()):
		var poi: PointOfInterest = heightmap_data.points_of_interest[pi]
		var marker := CSGCylinder3D.new()
		marker.radius = 2.0
		marker.height = 8.0
		marker.position = poi.position + Vector3(0, 4.0, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _POI_COLORS.get(poi.type, Color(1, 0, 1))
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.5
		marker.material = mat
		var label := Label3D.new()
		label.text = poi.display_name
		label.font_size = 48
		label.position.y = 5.0
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = mat.albedo_color
		label.outline_size = 8
		marker.add_child(label)
		_poi_parent.add_child(marker)


func _rebuild_wall_overlay() -> void:
	if _wall_overlay and is_instance_valid(_wall_overlay):
		_wall_overlay.queue_free()
		_wall_overlay = null
	if not show_walls or not heightmap_data:
		return
	if heightmap_data.wall_sdf.is_empty():
		return

	var w: int = heightmap_data.width
	var h: int = heightmap_data.height
	var ts: Vector3 = heightmap_data.terrain_scale
	var wall_height: float = 6.0

	var wall_color_map: Dictionary = {
		WALL_MOUNTAIN:    Color(1.0, 0.0, 0.0, 0.6),
		WALL_WATER:       Color(0.0, 0.3, 1.0, 0.6),
		WALL_GATE:        Color(1.0, 1.0, 1.0, 0.6),
		WALL_BARRIER:     Color(0.5, 0.0, 1.0, 0.6),
		WALL_FOREST:      Color(0.0, 0.8, 0.0, 0.6),
		WALL_DEATHBLIGHT: Color(0.3, 0.3, 0.3, 0.6),
	}

	_wall_overlay = Node3D.new()
	_wall_overlay.name = "WallOverlay"
	add_child(_wall_overlay)

	# Build quads at every wall pixel (sdf == 0)
	var type_quads: Dictionary = {}
	for z in range(h):
		for x in range(w):
			var idx: int = z * w + x
			if heightmap_data.wall_sdf[idx] > 0.01:
				continue
			var wt: int = heightmap_data.wall_type_map[idx]
			if wt == 0:
				continue
			if not type_quads.has(wt):
				type_quads[wt] = []
			var wx: float = float(x) * ts.x
			var wz: float = float(z) * ts.z
			var wy: float = heightmap_data.get_height_at(x, z) * ts.y
			# Thin vertical panel facing both directions
			var half: float = ts.x * 0.5
			type_quads[wt].append([
				Vector3(wx - half, wy - 1.0, wz),
				Vector3(wx + half, wy - 1.0, wz),
				Vector3(wx + half, wy + wall_height, wz),
				Vector3(wx - half, wy + wall_height, wz),
			])

	var tq_keys: Array = type_quads.keys()
	var panel_count: int = 0
	for ki in range(tq_keys.size()):
		var wt: int = tq_keys[ki]
		var quads: Array = type_quads[wt]
		if quads.is_empty():
			continue
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for qi in range(quads.size()):
			var q: Array = quads[qi]
			im.surface_add_vertex(q[0])
			im.surface_add_vertex(q[1])
			im.surface_add_vertex(q[2])
			im.surface_add_vertex(q[0])
			im.surface_add_vertex(q[2])
			im.surface_add_vertex(q[3])
		im.surface_end()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = wall_color_map.get(wt, Color(1, 0, 1, 0.6))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mmi := MeshInstance3D.new()
		mmi.mesh = im
		mmi.material_override = mat
		_wall_overlay.add_child(mmi)
		panel_count += quads.size()
	print("[HeightmapTerrain3D] Wall overlay: %d panels" % panel_count)


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
	if _poi_parent:
		for child in _poi_parent.get_children():
			child.queue_free()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func get_height_at_world(world_pos: Vector3) -> float:
	if not heightmap_data:
		return 0.0
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
	if fx + fz <= 1.0:
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	else:
		return h10 + (fx + fz - 1.0) * (h11 - h10) + (1.0 - fx) * (h01 - h10)


# ---------------------------------------------------------------------------
# ORA Export
# ---------------------------------------------------------------------------

func _export_zone_map() -> void:
	if not heightmap_data or heightmap_data.zone_ids.is_empty():
		print("[Export] No zone data — generate terrain first")
		return
	var w: int = heightmap_data.width
	var h: int = heightmap_data.height
	var pw: int = w * ORA_SCALE
	var ph: int = h * ORA_SCALE
	var tscale_y: float = heightmap_data.terrain_scale.y
	print("[Export] Heightmap %dx%d, paint layers %dx%d (x%d)" % [w, h, pw, ph, ORA_SCALE])

	# Layer 1: Height reference (paint res)
	var height_layer := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	var min_h: float = INF
	var max_h: float = -INF
	for z2 in range(h):
		for x2 in range(w):
			var hv: float = heightmap_data.get_height_at(x2, z2) * tscale_y
			min_h = minf(min_h, hv)
			max_h = maxf(max_h, hv)
	var h_range: float = maxf(max_h - min_h, 0.01)
	for z3 in range(ph):
		for x3 in range(pw):
			@warning_ignore("integer_division")
			var hx: int = x3 / ORA_SCALE
			@warning_ignore("integer_division")
			var hz: int = z3 / ORA_SCALE
			var hv: float = heightmap_data.get_height_at(hx, hz) * tscale_y
			var t: float = clampf((hv - min_h) / h_range, 0.0, 1.0)
			var col: Color
			if t < 0.15:
				col = Color(0.05, 0.1, 0.3).lerp(Color(0.2, 0.4, 0.6), t / 0.15)
			elif t < 0.25:
				col = Color(0.2, 0.4, 0.6).lerp(Color(0.7, 0.65, 0.4), (t - 0.15) / 0.10)
			elif t < 0.5:
				col = Color(0.3, 0.55, 0.2).lerp(Color(0.5, 0.35, 0.2), (t - 0.25) / 0.25)
			elif t < 0.75:
				col = Color(0.5, 0.35, 0.2).lerp(Color(0.6, 0.6, 0.6), (t - 0.5) / 0.25)
			else:
				col = Color(0.6, 0.6, 0.6).lerp(Color(1.0, 1.0, 1.0), (t - 0.75) / 0.25)
			col.a = 1.0
			height_layer.set_pixel(x3, z3, col)

	# Layer 2: Mountain ridges
	var ridge_layer := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	ridge_layer.fill(Color(0, 0, 0, 0))
	var ridges: Array[Array] = [
		_OverworldGenerator._ridge_main, _OverworldGenerator._ridge_sw,
		_OverworldGenerator._ridge_se, _OverworldGenerator._ridge_north_spur]
	var ridge_colors: Array[Color] = [Color(1, 0, 0, 1), Color(1, 0.5, 0, 1), Color(0, 1, 1, 1), Color(1, 1, 0, 1)]
	for ri in range(ridges.size()):
		var ridge: Array = ridges[ri]
		for pi in range(ridge.size() - 1):
			var a: Vector2 = ridge[pi]
			var b: Vector2 = ridge[pi + 1]
			_draw_line(ridge_layer,
				roundi((a.x + 1.0) * 0.5 * float(pw - 1)), roundi((a.y + 1.0) * 0.5 * float(ph - 1)),
				roundi((b.x + 1.0) * 0.5 * float(pw - 1)), roundi((b.y + 1.0) * 0.5 * float(ph - 1)),
				ridge_colors[ri], 2 * ORA_SCALE)

	# Layer 3: Zone boundaries
	var boundary_layer := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	boundary_layer.fill(Color(0, 0, 0, 0))
	for z4 in range(1, h - 1):
		for x4 in range(1, w - 1):
			if heightmap_data.zone_ids[z4 * w + x4] != heightmap_data.zone_ids[z4 * w + x4 + 1] or \
				heightmap_data.zone_ids[z4 * w + x4] != heightmap_data.zone_ids[(z4 + 1) * w + x4]:
				for bz in range(ORA_SCALE):
					for bx in range(ORA_SCALE):
						var ppx: int = x4 * ORA_SCALE + bx
						var ppz: int = z4 * ORA_SCALE + bz
						if ppx < pw and ppz < ph:
							boundary_layer.set_pixel(ppx, ppz, Color(1, 1, 1, 0.8))

	# Layer 4: Heightmap (grayscale, paintable, bilinear at paint res)
	var heightmap_layer := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	for z5 in range(ph):
		for x5 in range(pw):
			var fx: float = float(x5) / float(ORA_SCALE)
			var fz: float = float(z5) / float(ORA_SCALE)
			var ix: int = clampi(floori(fx), 0, w - 2)
			var iz: int = clampi(floori(fz), 0, h - 2)
			var tx: float = fx - float(ix)
			var tz: float = fz - float(iz)
			var h00: float = heightmap_data.get_height_at(ix, iz)
			var h10: float = heightmap_data.get_height_at(ix + 1, iz)
			var h01: float = heightmap_data.get_height_at(ix, iz + 1)
			var h11: float = heightmap_data.get_height_at(ix + 1, iz + 1)
			var hv: float = h00 * (1.0 - tx) * (1.0 - tz) + h10 * tx * (1.0 - tz) + h01 * (1.0 - tx) * tz + h11 * tx * tz
			var brightness: float = clampf((hv + 1.5) / 6.5, 0.0, 1.0)
			heightmap_layer.set_pixel(x5, z5, Color(brightness, brightness, brightness, 1.0))

	# Layer 5: Rivers
	var river_layer := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	river_layer.fill(Color(0, 0, 0, 0))
	for ri2 in range(heightmap_data.rivers.size()):
		var river: RiverPath = heightmap_data.rivers[ri2]
		for pi2 in range(river.points.size() - 1):
			var a: Vector3 = river.points[pi2]
			var b: Vector3 = river.points[pi2 + 1]
			var ax: int = clampi(roundi(a.x / heightmap_data.terrain_scale.x * float(ORA_SCALE)), 0, pw - 1)
			var az: int = clampi(roundi(a.z / heightmap_data.terrain_scale.z * float(ORA_SCALE)), 0, ph - 1)
			var bx: int = clampi(roundi(b.x / heightmap_data.terrain_scale.x * float(ORA_SCALE)), 0, pw - 1)
			var bz: int = clampi(roundi(b.z / heightmap_data.terrain_scale.z * float(ORA_SCALE)), 0, ph - 1)
			_draw_line(river_layer, ax, az, bx, bz, Color(0, 0, 1, 1), maxi(ORA_SCALE / 2, 1))

	# Layer 6: Roads
	var road_layer := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	road_layer.fill(Color(0, 0, 0, 0))

	# Layer 7: POIs
	var poi_layer := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	poi_layer.fill(Color(0, 0, 0, 0))
	for pi3 in range(heightmap_data.points_of_interest.size()):
		var poi: PointOfInterest = heightmap_data.points_of_interest[pi3]
		var ppx: int = clampi(roundi(poi.position.x / heightmap_data.terrain_scale.x * float(ORA_SCALE)), 0, pw - 1)
		var ppz: int = clampi(roundi(poi.position.z / heightmap_data.terrain_scale.z * float(ORA_SCALE)), 0, ph - 1)
		_draw_filled_circle(poi_layer, ppx, ppz, _POI_CIRCLE_RADIUS * ORA_SCALE, _POI_COLORS.get(poi.type, Color(1, 0, 1, 1)))

	# Layer 8: Walls
	var wall_layer := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	wall_layer.fill(Color(0, 0, 0, 0))
	if heightmap_data.wall_sdf.size() == w * h:
		for z_w in range(h):
			for x_w in range(w):
				var idx: int = z_w * w + x_w
				if heightmap_data.wall_sdf[idx] > 0.01:
					continue
				var wt: int = heightmap_data.wall_type_map[idx]
				if wt == 0:
					continue
				var wcol: Color = _WALL_COLORS.get(wt, Color(1, 0, 0, 1))
				for bz in range(ORA_SCALE):
					for bx in range(ORA_SCALE):
						var ppx: int = x_w * ORA_SCALE + bx
						var ppz: int = z_w * ORA_SCALE + bz
						if ppx < pw and ppz < ph:
							wall_layer.set_pixel(ppx, ppz, wcol)

	# Layer 9: Zones
	var zone_layer := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	for z6 in range(ph):
		for x6 in range(pw):
			@warning_ignore("integer_division")
			var zx: int = x6 / ORA_SCALE
			@warning_ignore("integer_division")
			var zz: int = z6 / ORA_SCALE
			var zone_id: int = heightmap_data.zone_ids[zz * w + zx]
			var col: Color = _ZONE_COLORS.get(zone_id, Color(1, 0, 1))
			col.a = 1.0
			zone_layer.set_pixel(x6, z6, col)

	# Build ORA
	var ora_path: String = "res://tools/zone_map.ora"
	var abs_path: String = ProjectSettings.globalize_path(ora_path)
	var zip := ZIPPacker.new()
	if zip.open(abs_path) != OK:
		print("[Export] Failed to create %s" % ora_path)
		return
	zip.start_file("mimetype")
	zip.write_file("image/openraster".to_utf8_buffer())
	zip.close_file()

	var ora_layers: Array[Dictionary] = [
		{"name": "Height Reference (REF)", "img": height_layer, "file": "data/height_ref.png"},
		{"name": "Mountain Ridges (REF)", "img": ridge_layer, "file": "data/ridges.png"},
		{"name": "Zone Boundaries (REF)", "img": boundary_layer, "file": "data/boundaries.png"},
		{"name": "Heightmap (PAINT)", "img": heightmap_layer, "file": "data/heightmap.png"},
		{"name": "Rivers (PAINT blue)", "img": river_layer, "file": "data/rivers.png"},
		{"name": "Roads (PAINT brown)", "img": road_layer, "file": "data/roads.png"},
		{"name": "POIs (PAINT markers)", "img": poi_layer, "file": "data/pois.png"},
		{"name": "Walls (PAINT any color)", "img": wall_layer, "file": "data/walls.png"},
		{"name": "Zones (PAINT colors)", "img": zone_layer, "file": "data/zones.png"},
	]
	for i in range(ora_layers.size()):
		var layer: Dictionary = ora_layers[i]
		zip.start_file(layer["file"])
		zip.write_file((layer["img"] as Image).save_png_to_buffer())
		zip.close_file()

	var merged_buf: PackedByteArray = zone_layer.save_png_to_buffer()
	zip.start_file("mergedimage.png")
	zip.write_file(merged_buf)
	zip.close_file()
	var thumb: Image = zone_layer.duplicate()
	thumb.resize(256, 256)
	zip.start_file("Thumbnails/thumbnail.png")
	zip.write_file(thumb.save_png_to_buffer())
	zip.close_file()

	var xml: String = '<?xml version="1.0" encoding="UTF-8"?>\n<image w="%d" h="%d">\n <stack>\n' % [pw, ph]
	for li in range(ora_layers.size() - 1, -1, -1):
		xml += '  <layer name="%s" src="%s" x="0" y="0" opacity="1.0" visibility="visible" />\n' % [
			ora_layers[li]["name"], ora_layers[li]["file"]]
	xml += ' </stack>\n</image>\n'
	zip.start_file("stack.xml")
	zip.write_file(xml.to_utf8_buffer())
	zip.close_file()
	zip.close()
	print("[Export] %s — 9 layers, open in GIMP" % ora_path)
	print("[Export] Wall colors: RED=mountain BLUE=water WHITE=gate PURPLE=barrier GREEN=forest GREY=deathblight")
	print("[Export] POI colors: RED=Dungeon ORANGE=Ruins DKGREEN=Camp CYAN=Shrine YELLOW=City LIME=Village WHITE=Gate MAGENTA=Bridge")


# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------

static func _draw_line(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color, thickness: int = 1) -> void:
	var dx: int = absi(x1 - x0)
	var dz: int = absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sz: int = 1 if y0 < y1 else -1
	var err: int = dx - dz
	var cx: int = x0
	var cz: int = y0
	var iw: int = img.get_width()
	var ih: int = img.get_height()
	for _step in range(dx + dz + 1):
		for ty in range(-thickness, thickness + 1):
			for tx in range(-thickness, thickness + 1):
				var px: int = cx + tx
				var pz: int = cz + ty
				if px >= 0 and px < iw and pz >= 0 and pz < ih:
					img.set_pixel(px, pz, col)
		if cx == x1 and cz == y1:
			break
		var e2: int = 2 * err
		if e2 > -dz:
			err -= dz
			cx += sx
		if e2 < dx:
			err += dx
			cz += sz


static func _draw_filled_circle(img: Image, cx: int, cy: int, radius: int, col: Color) -> void:
	var iw: int = img.get_width()
	var ih: int = img.get_height()
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var px: int = cx + dx
				var pz: int = cy + dy
				if px >= 0 and px < iw and pz >= 0 and pz < ih:
					img.set_pixel(px, pz, col)


# ---------------------------------------------------------------------------
# Import — single layer
# ---------------------------------------------------------------------------

func _import_single(layer_key: String) -> void:
	if not heightmap_data:
		print("[Import] No heightmap data — generate first")
		return
	var log_path: String = ProjectSettings.globalize_path("res://tools/import_%s_log.txt" % layer_key)
	var log: FileAccess = FileAccess.open(log_path, FileAccess.WRITE)
	var t0: int = Time.get_ticks_msec()
	_ilog(log, "=== Import '%s' started at %s ===" % [layer_key, Time.get_datetime_string_from_system()])

	var img: Image = _load_layer_from_ora(layer_key)
	_ilog(log, "ORA load: %dms" % (Time.get_ticks_msec() - t0))
	if not img:
		_ilog(log, "Layer '%s' not found — aborting" % layer_key)
		if log:
			log.close()
		return

	_ilog(log, "Image: %dx%d format=%d" % [img.get_width(), img.get_height(), img.get_format()])
	var w: int = heightmap_data.width
	var h: int = heightmap_data.height
	_ilog(log, "Terrain: %dx%d = %d vertices" % [w, h, w * h])
	var t1: int = Time.get_ticks_msec()

	match layer_key:
		"heightmap":
			if img.get_width() != w or img.get_height() != h:
				_ilog(log, "Resizing %dx%d → %dx%d (bilinear)" % [img.get_width(), img.get_height(), w, h])
				img.resize(w, h, Image.INTERPOLATE_BILINEAR)
				_ilog(log, "Resize: %dms" % (Time.get_ticks_msec() - t1))
			var t2: int = Time.get_ticks_msec()
			var changed: int = 0
			for z in range(h):
				for x in range(w):
					var new_h: float = lerpf(-1.5, 5.0, img.get_pixel(x, z).r)
					if absf(new_h - heightmap_data.get_height_at(x, z)) > 0.001:
						changed += 1
					heightmap_data.set_height_at(x, z, new_h)
			_ilog(log, "Height scan: %dms — %d changed / %d" % [Time.get_ticks_msec() - t2, changed, w * h])
		"zones":
			if img.get_width() != w or img.get_height() != h:
				_ilog(log, "Resizing %dx%d → %dx%d (nearest)" % [img.get_width(), img.get_height(), w, h])
				img.resize(w, h, Image.INTERPOLATE_NEAREST)
				_ilog(log, "Resize: %dms" % (Time.get_ticks_msec() - t1))
			if heightmap_data.zone_ids.size() != w * h:
				heightmap_data.zone_ids.resize(w * h)
			var t2: int = Time.get_ticks_msec()
			for z in range(h):
				for x in range(w):
					heightmap_data.zone_ids[z * w + x] = _color_to_zone(img.get_pixel(x, z))
			_ilog(log, "Zone classify: %dms" % (Time.get_ticks_msec() - t2))
			if heightmap_data.is_overworld:
				var t3: int = Time.get_ticks_msec()
				_OverworldGenerator.rebuild_splatmap_from_zones(heightmap_data)
				_ilog(log, "Splatmap rebuild: %dms" % (Time.get_ticks_msec() - t3))
		"rivers":
			if img.get_width() != w or img.get_height() != h:
				_ilog(log, "Resizing %dx%d → %dx%d (nearest)" % [img.get_width(), img.get_height(), w, h])
				img.resize(w, h, Image.INTERPOLATE_NEAREST)
				_ilog(log, "Resize: %dms" % (Time.get_ticks_msec() - t1))
			_ilog(log, "Starting river import...")
			if log:
				log.flush()
			_import_rivers(img)
			_ilog(log, "Rivers: %dms" % (Time.get_ticks_msec() - t1))
		"roads":
			if img.get_width() != w or img.get_height() != h:
				_ilog(log, "Resizing %dx%d → %dx%d (nearest)" % [img.get_width(), img.get_height(), w, h])
				img.resize(w, h, Image.INTERPOLATE_NEAREST)
				_ilog(log, "Resize: %dms" % (Time.get_ticks_msec() - t1))
			_import_roads(img)
			_ilog(log, "Roads: %dms" % (Time.get_ticks_msec() - t1))
		"pois":
			if img.get_width() != w or img.get_height() != h:
				_ilog(log, "Resizing %dx%d → %dx%d (nearest)" % [img.get_width(), img.get_height(), w, h])
				img.resize(w, h, Image.INTERPOLATE_NEAREST)
				_ilog(log, "Resize: %dms" % (Time.get_ticks_msec() - t1))
			_import_pois(img)
			_ilog(log, "POIs: %dms" % (Time.get_ticks_msec() - t1))
		"walls":
			if img.get_width() != w or img.get_height() != h:
				_ilog(log, "Resizing walls %dx%d → %dx%d (nearest)" % [img.get_width(), img.get_height(), w, h])
				img.resize(w, h, Image.INTERPOLATE_NEAREST)
				_ilog(log, "Resize: %dms" % (Time.get_ticks_msec() - t1))
			_ilog(log, "Starting wall SDF...")
			if log:
				log.flush()
			_import_walls(img)
			_ilog(log, "Walls: %dms" % (Time.get_ticks_msec() - t1))

	var t_rebuild: int = Time.get_ticks_msec()
	_ilog(log, "Starting rebuild...")
	if log:
		log.flush()
	_rebuild()
	_ilog(log, "Rebuild: %dms" % (Time.get_ticks_msec() - t_rebuild))
	var total: int = Time.get_ticks_msec() - t0
	_ilog(log, "=== TOTAL: %dms ===" % total)
	if log:
		log.close()
	print("[Import] '%s' done in %dms — log: %s" % [layer_key, total, log_path])


func _ilog(log_file: FileAccess, msg: String) -> void:
	## Prints to console AND writes to the import log file with timestamp.
	print("[Import] %s" % msg)
	if log_file:
		log_file.store_line("[%dms] %s" % [Time.get_ticks_msec(), msg])
		log_file.flush()


func _load_layer_from_ora(layer_key: String) -> Image:
	var ora_name_map: Dictionary = {
		"heightmap": "Heightmap (PAINT)",
		"zones": "Zones (PAINT colors)",
		"rivers": "Rivers (PAINT blue)",
		"roads": "Roads (PAINT brown)",
		"pois": "POIs (PAINT markers)",
		"walls": "Walls (PAINT any color)",
	}
	var ora_abs: String = ProjectSettings.globalize_path("res://tools/zone_map.ora")
	if FileAccess.file_exists(ora_abs):
		var zip := ZIPReader.new()
		if zip.open(ora_abs) == OK:
			if zip.file_exists("stack.xml"):
				var xml_str: String = zip.read_file("stack.xml").get_string_from_utf8()
				var target_name: String = ora_name_map.get(layer_key, "")
				var search_pos: int = 0
				while true:
					var ls: int = xml_str.find("<layer ", search_pos)
					if ls < 0:
						break
					var le: int = xml_str.find("/>", ls)
					if le < 0:
						break
					var tag: String = xml_str.substr(ls, le - ls + 2)
					search_pos = le + 2
					var ns: int = tag.find('name="')
					if ns < 0:
						continue
					ns += 6
					var ne: int = tag.find('"', ns)
					var lname: String = tag.substr(ns, ne - ns)
					if lname != target_name:
						continue
					var ss: int = tag.find('src="')
					if ss < 0:
						continue
					ss += 5
					var se: int = tag.find('"', ss)
					var lsrc: String = tag.substr(ss, se - ss)
					if zip.file_exists(lsrc):
						var buf: PackedByteArray = zip.read_file(lsrc)
						var result := Image.new()
						if result.load_png_from_buffer(buf) == OK:
							zip.close()
							return result
					break
			zip.close()
	# Fallback to standalone PNG
	var png_map: Dictionary = {
		"heightmap": "res://tools/heightmap.png", "zones": "res://tools/zone_map.png",
		"rivers": "res://tools/rivers.png", "roads": "res://tools/roads.png",
		"pois": "res://tools/pois.png", "walls": "res://tools/walls.png",
	}
	var png_abs: String = ProjectSettings.globalize_path(png_map.get(layer_key, ""))
	if FileAccess.file_exists(png_abs):
		var result := Image.new()
		if result.load(png_abs) == OK:
			return result
	return null


func _import_all_layers() -> void:
	if not heightmap_data:
		print("[Import] No heightmap data")
		return
	var keys: Array[String] = ["heightmap", "zones", "rivers", "roads", "pois", "walls"]
	for i in range(keys.size()):
		var img: Image = _load_layer_from_ora(keys[i])
		if img:
			print("[Import] Processing '%s'..." % keys[i])
			_import_single(keys[i])
	print("[Import] All layers done")


# ---------------------------------------------------------------------------
# Import — rivers
# ---------------------------------------------------------------------------

func _import_rivers(img: Image) -> void:
	var w: int = heightmap_data.width
	var h: int = heightmap_data.height
	var tscale: Vector3 = heightmap_data.terrain_scale

	# Find blue pixels
	var river_mask := PackedByteArray()
	river_mask.resize(w * h)
	var blue_pixels: Array[Vector2i] = []
	for z in range(h):
		for x in range(w):
			var col: Color = img.get_pixel(x, z)
			if col.b > 0.5 and col.r < 0.3 and col.g < 0.3 and col.a > 0.3:
				river_mask[z * w + x] = 1
				blue_pixels.append(Vector2i(x, z))
	print("[Import] Rivers: %d blue pixels" % blue_pixels.size())
	if blue_pixels.is_empty():
		return

	# Carve river channel
	for z in range(h):
		for x in range(w):
			if river_mask[z * w + x] == 1:
				heightmap_data.set_height_at(x, z, heightmap_data.get_height_at(x, z) - 0.25)

	# Cluster and trace into RiverPaths
	heightmap_data.rivers.clear()
	var clusters: Array = _cluster_pixels_fast(blue_pixels, w, h)
	var river_index: int = 0
	for ci in range(clusters.size()):
		var blob: Array = clusters[ci]
		if blob.size() < 10:
			continue
		# Find endpoints via BFS
		var ep_a: Vector2i = blob[0]
		var ep_b: Vector2i = _bfs_farthest(ep_a, blob, w)
		ep_a = _bfs_farthest(ep_b, blob, w)
		var path: Array[Vector2i] = _bfs_path(ep_a, ep_b, blob, w)
		if path.size() < 5:
			continue
		# Subsample
		var step: int = maxi(path.size() / 100, 1)
		var river := RiverPath.new()
		river.id = "river_%d" % river_index
		river.color_index = river_index
		var points := PackedVector3Array()
		var widths := PackedFloat32Array()
		for pi in range(0, path.size(), step):
			var gx: float = float(path[pi].x)
			var gz: float = float(path[pi].y)
			var ix: int = clampi(roundi(gx), 0, w - 1)
			var iz: int = clampi(roundi(gz), 0, h - 1)
			var yh: float = heightmap_data.get_height_at(ix, iz) * tscale.y + 2.5
			points.append(Vector3(gx * tscale.x, yh, gz * tscale.z))
			# Measure width by scanning perpendicular
			var half_w: float = 1.0
			if pi + step < path.size():
				var dx2: float = float(path[pi + step].x) - gx
				var dz2: float = float(path[pi + step].y) - gz
				var dl: float = sqrt(dx2 * dx2 + dz2 * dz2)
				if dl > 0.01:
					var perp_x: float = -dz2 / dl
					var perp_z: float = dx2 / dl
					for scan_dir in [-1.0, 1.0]:
						for sd in range(1, 30):
							var sx: int = clampi(roundi(gx + perp_x * scan_dir * float(sd)), 0, w - 1)
							var sz: int = clampi(roundi(gz + perp_z * scan_dir * float(sd)), 0, h - 1)
							if river_mask[sz * w + sx] == 0:
								half_w = maxf(half_w, float(sd))
								break
			widths.append(maxf(half_w * 2.0 * tscale.x, 4.0))
		river.points = points
		river.widths = widths
		heightmap_data.rivers.append(river)
		river_index += 1
		print("[Import] River %d: %d pixels, %d points" % [river_index - 1, blob.size(), points.size()])

	# Bank painting
	for z in range(h):
		for x in range(w):
			if river_mask[z * w + x] != 1:
				continue
			for dz in range(-4, 5):
				for dx in range(-4, 5):
					var nx: int = x + dx
					var nz: int = z + dz
					if nx < 0 or nx >= w or nz < 0 or nz >= h:
						continue
					var dist: float = sqrt(float(dx * dx + dz * dz))
					if dist > 4.0:
						continue
					var t2: float = dist / 4.0
					var cur_splat: Color = heightmap_data.get_splatmap_weights(nx, nz)
					var wet: Color = Color(0.30, 0.05, 0.35, 0.0)
					heightmap_data.set_splatmap_weights(nx, nz, cur_splat.lerp(wet, (1.0 - t2) * 0.6))
	heightmap_data.build_river_mask(6)


# ---------------------------------------------------------------------------
# Import — roads
# ---------------------------------------------------------------------------

func _import_roads(img: Image) -> void:
	var w: int = heightmap_data.width
	var h: int = heightmap_data.height
	var count: int = 0
	for z in range(h):
		for x in range(w):
			var col: Color = img.get_pixel(x, z)
			if col.r > 0.4 and col.g > 0.15 and col.g < 0.55 and col.b < 0.3 and col.a > 0.3:
				count += 1
				for dz in range(-2, 3):
					for dx in range(-2, 3):
						var nx: int = x + dx
						var nz: int = z + dz
						if nx < 0 or nx >= w or nz < 0 or nz >= h:
							continue
						var dist: float = sqrt(float(dx * dx + dz * dz))
						if dist > 2.5:
							continue
						var t2: float = dist / 2.5
						var cur_splat: Color = heightmap_data.get_splatmap_weights(nx, nz)
						var road: Color = Color(0.10, 0.75, 0.10, 0.0)
						heightmap_data.set_splatmap_weights(nx, nz, cur_splat.lerp(road, (1.0 - t2) * 0.7))
	print("[Import] Roads: %d brown pixels" % count)


# ---------------------------------------------------------------------------
# Import — POIs
# ---------------------------------------------------------------------------

func _import_pois(img: Image) -> void:
	var w: int = heightmap_data.width
	var h: int = heightmap_data.height
	var tscale: Vector3 = heightmap_data.terrain_scale
	# Already downsampled to w×h by caller
	var type_pixels: Dictionary = {}
	var poi_type_keys: Array = _POI_COLORS.keys()
	for z in range(h):
		for x in range(w):
			var col: Color = img.get_pixel(x, z)
			if col.a < 0.3:
				continue
			var best_type: int = -1
			var best_dist: float = 0.3
			for ki in range(poi_type_keys.size()):
				var ptype = poi_type_keys[ki]
				var pcol: Color = _POI_COLORS[ptype]
				var cdist: float = absf(col.r - pcol.r) + absf(col.g - pcol.g) + absf(col.b - pcol.b)
				if cdist < best_dist:
					best_dist = cdist
					best_type = int(ptype)
			if best_type >= 0:
				if not type_pixels.has(best_type):
					type_pixels[best_type] = []
				type_pixels[best_type].append(Vector2i(x, z))

	heightmap_data.points_of_interest.clear()
	var poi_names: Dictionary = {
		PointOfInterest.Type.DUNGEON: ["Ancient Crypt", "Forgotten Vault", "Dark Cavern"],
		PointOfInterest.Type.RUINS: ["Ancient Ruins", "Crumbled Tower", "Lost Temple"],
		PointOfInterest.Type.CAMP: ["Bandit Camp", "Goblin Outpost", "Mercenary Den"],
		PointOfInterest.Type.SHRINE: ["River Shrine", "Ancient Shrine", "Forest Altar"],
		PointOfInterest.Type.CITY: ["Capital City", "Port Town", "Trade Hub"],
		PointOfInterest.Type.VILLAGE: ["Small Village", "Hamlet", "Farmstead"],
		PointOfInterest.Type.GATE: ["Mountain Gate", "Stone Barricade", "Iron Gate"],
		PointOfInterest.Type.BRIDGE: ["Old Bridge", "Stone Bridge", "River Crossing"],
	}
	var total: int = 0
	var tp_keys: Array = type_pixels.keys()
	for ki in range(tp_keys.size()):
		var ptype: int = tp_keys[ki]
		var pixels: Array = type_pixels[ptype]
		var clusters: Array = _cluster_pixels_fast(pixels, w, h)
		var names: Array = poi_names.get(ptype, ["Unknown"])
		for ci in range(clusters.size()):
			var cluster: Array = clusters[ci]
			var sum_x: float = 0.0
			var sum_z: float = 0.0
			for pi2 in range(cluster.size()):
				sum_x += float(cluster[pi2].x)
				sum_z += float(cluster[pi2].y)
			var cx: int = roundi(sum_x / float(cluster.size()))
			var cz: int = roundi(sum_z / float(cluster.size()))
			var poi := PointOfInterest.new()
			poi.type = ptype as PointOfInterest.Type
			poi.id = "poi_%d" % total
			poi.display_name = names[total % names.size()]
			var ix: int = clampi(cx, 0, w - 1)
			var iz: int = clampi(cz, 0, h - 1)
			poi.position = Vector3(float(cx) * tscale.x, heightmap_data.get_height_at(ix, iz) * tscale.y, float(cz) * tscale.z)
			heightmap_data.points_of_interest.append(poi)
			total += 1
	# Set town center from first CITY
	for pi3 in range(heightmap_data.points_of_interest.size()):
		var poi: PointOfInterest = heightmap_data.points_of_interest[pi3]
		if poi.type == PointOfInterest.Type.CITY:
			heightmap_data.town_center = poi.position
			break
	print("[Import] POIs: %d placed" % total)


# ---------------------------------------------------------------------------
# Import — walls (SDF)
# ---------------------------------------------------------------------------

func _import_walls(img: Image) -> void:
	## Builds a signed distance field from painted wall pixels using multi-source BFS.
	var log_path: String = ProjectSettings.globalize_path("res://tools/import_walls_log.txt")
	var log_file: FileAccess = FileAccess.open(log_path, FileAccess.WRITE)
	if log_file:
		log_file.store_line("[%s] Wall import started" % Time.get_datetime_string_from_system())

	var w: int = heightmap_data.width
	var h: int = heightmap_data.height
	if log_file:
		log_file.store_line("Grid size: %dx%d = %d pixels" % [w, h, w * h])
		log_file.store_line("Image size: %dx%d format=%d" % [img.get_width(), img.get_height(), img.get_format()])

	# Debug: scan for any non-transparent pixels
	var any_visible: int = 0
	var sample_colors: Array = []
	for z in range(h):
		for x in range(w):
			var col: Color = img.get_pixel(x, z)
			if col.a > 0.1:
				any_visible += 1
				if sample_colors.size() < 5:
					sample_colors.append("(%d,%d): r=%.2f g=%.2f b=%.2f a=%.2f" % [x, z, col.r, col.g, col.b, col.a])
	print("[Import] Walls layer: %d non-transparent pixels out of %d" % [any_visible, w * h])
	if log_file:
		log_file.store_line("Non-transparent pixels: %d / %d" % [any_visible, w * h])
		for si in range(sample_colors.size()):
			log_file.store_line("Sample: %s" % sample_colors[si])
		log_file.flush()
	if any_visible == 0:
		print("[Import] Walls layer is completely empty — nothing to import")
		if log_file:
			log_file.store_line("EMPTY — aborting")
			log_file.close()
		return

	# Dilate by 1px to fill gaps
	var dilated := Image.create(w, h, false, Image.FORMAT_RGBA8)
	dilated.fill(Color(0, 0, 0, 0))
	for z in range(h):
		for x in range(w):
			var col: Color = img.get_pixel(x, z)
			if col.a >= 0.2:
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var nx: int = x + dx
						var nz: int = z + dz
						if nx >= 0 and nx < w and nz >= 0 and nz < h:
							if dilated.get_pixel(nx, nz).a < 0.2:
								dilated.set_pixel(nx, nz, col)

	# Classify wall pixels
	var wall_keys: Array = _WALL_COLORS.keys()
	var type_grid := PackedByteArray()
	type_grid.resize(w * h)
	var wall_count: int = 0
	for z in range(h):
		for x in range(w):
			var col: Color = dilated.get_pixel(x, z)
			if col.a < 0.2:
				continue
			var best_type: int = 0
			var best_dist: float = 0.4
			for ki in range(wall_keys.size()):
				var wtype: int = wall_keys[ki]
				var wcol: Color = _WALL_COLORS[wtype]
				var cdist: float = absf(col.r - wcol.r) + absf(col.g - wcol.g) + absf(col.b - wcol.b)
				if cdist < best_dist:
					best_dist = cdist
					best_type = wtype
			if best_type > 0:
				type_grid[z * w + x] = best_type
				wall_count += 1

	if log_file:
		log_file.store_line("Dilation complete")
		log_file.store_line("Classified wall pixels: %d" % wall_count)
		log_file.flush()

	# Build SDF via multi-source BFS
	if log_file:
		log_file.store_line("Starting BFS SDF — grid %dx%d, %d wall seeds" % [w, h, wall_count])
		log_file.flush()
	heightmap_data.wall_sdf.resize(w * h)
	heightmap_data.wall_type_map.resize(w * h)
	for i in range(w * h):
		heightmap_data.wall_sdf[i] = 9999.0
		heightmap_data.wall_type_map[i] = 0

	var bfs_queue: Array[Vector2i] = []
	for z in range(h):
		for x in range(w):
			if type_grid[z * w + x] > 0:
				heightmap_data.wall_sdf[z * w + x] = 0.0
				heightmap_data.wall_type_map[z * w + x] = type_grid[z * w + x]
				bfs_queue.append(Vector2i(x, z))

	# BFS using index cursor — never remove_at(0) which is O(n) per call
	var qi: int = 0
	while qi < bfs_queue.size():
		var cur: Vector2i = bfs_queue[qi]
		qi += 1
		var cur_idx: int = cur.y * w + cur.x
		var cur_dist: float = heightmap_data.wall_sdf[cur_idx]
		var cur_type: int = heightmap_data.wall_type_map[cur_idx]
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nx: int = cur.x + dx
				var nz: int = cur.y + dz
				if nx < 0 or nx >= w or nz < 0 or nz >= h:
					continue
				var step_d: float = 1.0 if (dx == 0 or dz == 0) else 1.414
				var new_dist: float = cur_dist + step_d
				var nidx: int = nz * w + nx
				if new_dist < heightmap_data.wall_sdf[nidx]:
					heightmap_data.wall_sdf[nidx] = new_dist
					heightmap_data.wall_type_map[nidx] = cur_type
					bfs_queue.append(Vector2i(nx, nz))

	print("[Import] SDF: %d wall pixels, BFS visited %d cells" % [wall_count, qi])
	if log_file:
		log_file.store_line("BFS complete — visited %d cells" % qi)
		log_file.store_line("Wall import finished successfully")
		log_file.close()
	print("[Import] Wall log saved to %s" % log_path)


# ---------------------------------------------------------------------------
# Pixel clustering (flood-fill based, O(n))
# ---------------------------------------------------------------------------

static func _cluster_pixels_fast(pixels: Array, grid_w: int, grid_h: int) -> Array:
	## Groups pixels into connected blobs using flood-fill on a temporary grid.
	var grid := PackedByteArray()
	grid.resize(grid_w * grid_h)
	for pi in range(pixels.size()):
		var p: Vector2i = pixels[pi]
		grid[p.y * grid_w + p.x] = 1
	var visited := PackedByteArray()
	visited.resize(grid_w * grid_h)
	var clusters: Array = []
	for pi in range(pixels.size()):
		var start: Vector2i = pixels[pi]
		if visited[start.y * grid_w + start.x] == 1:
			continue
		var blob: Array = []
		var queue: Array[Vector2i] = [start]
		visited[start.y * grid_w + start.x] = 1
		var qci: int = 0
		while qci < queue.size():
			var cur: Vector2i = queue[qci]
			qci += 1
			blob.append(cur)
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dz == 0:
						continue
					var nx: int = cur.x + dx
					var nz: int = cur.y + dz
					if nx < 0 or nx >= grid_w or nz < 0 or nz >= grid_h:
						continue
					var nk: int = nz * grid_w + nx
					if visited[nk] == 1 or grid[nk] == 0:
						continue
					visited[nk] = 1
					queue.append(Vector2i(nx, nz))
		if blob.size() >= 2:
			clusters.append(blob)
	return clusters


static func _bfs_farthest(start: Vector2i, blob: Array, grid_w: int) -> Vector2i:
	## BFS from start, returns the farthest pixel in the blob.
	var dist: Dictionary = {}
	dist[start.y * grid_w + start.x] = 0
	var blob_set: Dictionary = {}
	for i in range(blob.size()):
		blob_set[blob[i].y * grid_w + blob[i].x] = true
	var queue: Array[Vector2i] = [start]
	var farthest: Vector2i = start
	var max_d: int = 0
	var qi2: int = 0
	while qi2 < queue.size():
		var cur: Vector2i = queue[qi2]
		qi2 += 1
		var cd: int = dist[cur.y * grid_w + cur.x]
		if cd > max_d:
			max_d = cd
			farthest = cur
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nx: int = cur.x + dx
				var nz: int = cur.y + dz
				var nk: int = nz * grid_w + nx
				if not blob_set.has(nk) or dist.has(nk):
					continue
				dist[nk] = cd + 1
				queue.append(Vector2i(nx, nz))
	return farthest


static func _bfs_path(from: Vector2i, to: Vector2i, blob: Array, grid_w: int) -> Array[Vector2i]:
	## BFS from 'from' to 'to', returns the path.
	var blob_set: Dictionary = {}
	for i in range(blob.size()):
		blob_set[blob[i].y * grid_w + blob[i].x] = true
	var parent: Dictionary = {}
	parent[from.y * grid_w + from.x] = Vector2i(-1, -1)
	var queue: Array[Vector2i] = [from]
	var qi3: int = 0
	while qi3 < queue.size():
		var cur: Vector2i = queue[qi3]
		qi3 += 1
		if cur == to:
			break
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nx: int = cur.x + dx
				var nz: int = cur.y + dz
				var nk: int = nz * grid_w + nx
				if not blob_set.has(nk) or parent.has(nk):
					continue
				parent[nk] = cur
				queue.append(Vector2i(nx, nz))
	# Trace back
	var path: Array[Vector2i] = []
	var trace: Vector2i = to
	for _safety in range(blob.size() + 1):
		path.append(trace)
		var pk: int = trace.y * grid_w + trace.x
		if not parent.has(pk) or parent[pk] == Vector2i(-1, -1):
			break
		trace = parent[pk]
	path.reverse()
	return path


# ---------------------------------------------------------------------------
# Zone color matching
# ---------------------------------------------------------------------------

func _color_to_zone(col: Color) -> int:
	var best_id: int = 0
	var best_dist: float = INF
	var keys: Array = _ZONE_COLORS.keys()
	for i in range(keys.size()):
		var zone_id: int = keys[i]
		var zcol: Color = _ZONE_COLORS[zone_id]
		var dr: float = col.r - zcol.r
		var dg: float = col.g - zcol.g
		var db: float = col.b - zcol.b
		var dist: float = dr * dr + dg * dg + db * db
		if dist < best_dist:
			best_dist = dist
			best_id = zone_id
	return best_id
