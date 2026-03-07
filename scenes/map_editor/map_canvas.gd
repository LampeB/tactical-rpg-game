class_name MapCanvas
extends Control
## 2D top-down canvas for rendering and editing map data.
## Uses custom _draw() for performance (avoids thousands of child nodes).

const CELL_PX := 36
const MIN_ZOOM := 0.15
const MAX_ZOOM := 4.0
const ZOOM_STEP := 0.1
const ELEMENT_RADIUS := 8.0

signal cell_painted(grid_pos: Vector2i, block_type: int)
signal element_clicked(element_index: int)
signal element_moved(element_index: int, new_pos: Vector3)
signal canvas_right_clicked(world_pos: Vector2)
signal hover_changed(grid_pos: Vector2i)
signal zoom_changed(zoom_level: float)
signal element_placed(world_pos: Vector2)

enum Tool { SELECT, PAINT, PLACE, ZONE }

var map_data: MapData = null
var active_tool: Tool = Tool.SELECT
var paint_block: int = 0  # Block type for painting
var place_element_type: int = 0  # MapElement.ElementType for placing
var selected_element_index: int = -1

var _zoom: float = 0.5
var _pan_offset: Vector2 = Vector2.ZERO
var _is_panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_offset: Vector2 = Vector2.ZERO
var _is_painting: bool = false
var _last_painted_cell: Vector2i = Vector2i(-1, -1)
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _is_dragging_element: bool = false
var _drag_element_index: int = -1
var _drag_offset: Vector2 = Vector2.ZERO

# Element type colors for rendering
const ELEMENT_COLORS: Dictionary = {
	MapElement.ElementType.LOCATION: Color(1.0, 0.85, 0.0),     # Gold
	MapElement.ElementType.NPC: Color(0.3, 0.5, 1.0),           # Blue
	MapElement.ElementType.ENEMY: Color(1.0, 0.2, 0.2),         # Red
	MapElement.ElementType.CHEST: Color(1.0, 0.8, 0.2),         # Yellow
	MapElement.ElementType.DECORATION: Color(0.3, 0.7, 0.3),    # Green
	MapElement.ElementType.SIGN: Color(0.6, 0.4, 0.2),          # Brown
	MapElement.ElementType.FENCE: Color(0.5, 0.35, 0.15),       # Dark brown
}

const ELEMENT_LABELS: Dictionary = {
	MapElement.ElementType.LOCATION: "L",
	MapElement.ElementType.NPC: "N",
	MapElement.ElementType.ENEMY: "E",
	MapElement.ElementType.CHEST: "C",
	MapElement.ElementType.DECORATION: "d",
	MapElement.ElementType.SIGN: "S",
	MapElement.ElementType.FENCE: "f",
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func set_map(data: MapData) -> void:
	map_data = data
	# Center view on map
	if map_data:
		var map_center := Vector2(map_data.grid_width * 0.5, map_data.grid_height * 0.5)
		_pan_offset = map_center - (size * 0.5) / (CELL_PX * _zoom)
	queue_redraw()


func get_zoom() -> float:
	return _zoom


# === Coordinate transforms ===

func _world_to_screen(world_pos: Vector2) -> Vector2:
	return (world_pos * CELL_PX - _pan_offset * CELL_PX) * _zoom


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return screen_pos / (_zoom * CELL_PX) + _pan_offset


func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var world: Vector2 = _screen_to_world(screen_pos)
	return Vector2i(int(floor(world.x)), int(floor(world.y)))


# === Drawing ===

func _draw() -> void:
	if not map_data:
		draw_string(ThemeDB.fallback_font, Vector2(20, 30), "No map loaded", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.GRAY)
		return

	_draw_terrain()
	_draw_grid_lines()
	_draw_decoration_zones()
	_draw_safe_zones()
	_draw_elements()
	_draw_player_spawn()
	_draw_hover()
	_draw_selection()


func _draw_terrain() -> void:
	for z in range(map_data.grid_height):
		for x in range(map_data.grid_width):
			var block: int = map_data.get_terrain_at(x, z)
			var color: Color = MapLoader.BLOCK_COLORS[block] if block < MapLoader.BLOCK_COLORS.size() else Color.MAGENTA
			var screen_pos: Vector2 = _world_to_screen(Vector2(x, z))
			var cell_size: float = CELL_PX * _zoom
			draw_rect(Rect2(screen_pos, Vector2(cell_size, cell_size)), color)


func _draw_grid_lines() -> void:
	if _zoom < 0.3:
		return  # Skip grid lines when zoomed out too far

	var line_color := Color(0.0, 0.0, 0.0, 0.15)
	var cell_size: float = CELL_PX * _zoom

	# Only draw lines that are visible
	var start_grid: Vector2i = _screen_to_grid(Vector2.ZERO)
	var end_grid: Vector2i = _screen_to_grid(size)
	start_grid.x = maxi(start_grid.x, 0)
	start_grid.y = maxi(start_grid.y, 0)
	end_grid.x = mini(end_grid.x + 2, map_data.grid_width)
	end_grid.y = mini(end_grid.y + 2, map_data.grid_height)

	for x in range(start_grid.x, end_grid.x + 1):
		var sx: float = _world_to_screen(Vector2(x, 0)).x
		var sy0: float = _world_to_screen(Vector2(0, start_grid.y)).y
		var sy1: float = _world_to_screen(Vector2(0, end_grid.y)).y
		draw_line(Vector2(sx, sy0), Vector2(sx, sy1), line_color, 1.0)

	for z in range(start_grid.y, end_grid.y + 1):
		var sz: float = _world_to_screen(Vector2(0, z)).y
		var sx0: float = _world_to_screen(Vector2(start_grid.x, 0)).x
		var sx1: float = _world_to_screen(Vector2(end_grid.x, 0)).x
		draw_line(Vector2(sx0, sz), Vector2(sx1, sz), line_color, 1.0)


func _draw_decoration_zones() -> void:
	for zone in map_data.decoration_zones:
		var top_left: Vector2 = _world_to_screen(zone.rect.position)
		var zone_size: Vector2 = zone.rect.size * CELL_PX * _zoom
		var rect := Rect2(top_left, zone_size)
		draw_rect(rect, Color(0.3, 0.8, 0.3, 0.1))
		draw_rect(rect, Color(0.3, 0.8, 0.3, 0.4), false, 2.0)
		if _zoom > 0.4:
			draw_string(ThemeDB.fallback_font, top_left + Vector2(4, 14), zone.zone_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.8, 0.3, 0.7))


func _draw_safe_zones() -> void:
	for zone_rect in map_data.enemy_safe_zones:
		var top_left: Vector2 = _world_to_screen(zone_rect.position)
		var zone_size: Vector2 = zone_rect.size * CELL_PX * _zoom
		var rect := Rect2(top_left, zone_size)
		draw_rect(rect, Color(1.0, 0.2, 0.2, 0.08))
		draw_rect(rect, Color(1.0, 0.2, 0.2, 0.3), false, 2.0)
		if _zoom > 0.4:
			draw_string(ThemeDB.fallback_font, top_left + Vector2(4, 14), "Safe Zone",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.3, 0.3, 0.7))


func _draw_elements() -> void:
	var radius: float = maxf(ELEMENT_RADIUS * _zoom, 3.0)
	for i in range(map_data.elements.size()):
		var elem: MapElement = map_data.elements[i]
		var screen_pos: Vector2 = _world_to_screen(Vector2(elem.position.x, elem.position.z))
		var color: Color = ELEMENT_COLORS.get(elem.element_type, Color.WHITE)

		match elem.element_type:
			MapElement.ElementType.LOCATION:
				# Star shape (draw as circle with outline)
				draw_circle(screen_pos, radius * 1.3, color)
				draw_circle(screen_pos, radius * 1.3, Color.WHITE, false, 2.0)
			MapElement.ElementType.ENEMY:
				# Diamond
				var pts := PackedVector2Array([
					screen_pos + Vector2(0, -radius),
					screen_pos + Vector2(radius, 0),
					screen_pos + Vector2(0, radius),
					screen_pos + Vector2(-radius, 0),
				])
				draw_colored_polygon(pts, color)
				draw_polyline(pts, Color.WHITE, 1.5)
			MapElement.ElementType.CHEST:
				# Square
				draw_rect(Rect2(screen_pos - Vector2(radius, radius), Vector2(radius * 2, radius * 2)), color)
				draw_rect(Rect2(screen_pos - Vector2(radius, radius), Vector2(radius * 2, radius * 2)), Color.WHITE, false, 1.5)
			MapElement.ElementType.FENCE, MapElement.ElementType.SIGN:
				# Small triangle
				if _zoom > 0.3:
					draw_circle(screen_pos, radius * 0.6, color)
			MapElement.ElementType.DECORATION:
				if _zoom > 0.3:
					draw_circle(screen_pos, radius * 0.5, color)
			_:
				draw_circle(screen_pos, radius, color)

		# Label
		if _zoom > 0.35:
			var lbl: String = ELEMENT_LABELS.get(elem.element_type, "?")
			var font_size: int = maxi(int(10 * _zoom), 7)
			draw_string(ThemeDB.fallback_font, screen_pos + Vector2(-3, 4), lbl,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _draw_player_spawn() -> void:
	var spawn_screen: Vector2 = _world_to_screen(Vector2(map_data.player_spawn.x, map_data.player_spawn.z))
	var arm: float = 8.0 * _zoom
	draw_line(spawn_screen + Vector2(-arm, 0), spawn_screen + Vector2(arm, 0), Color.GREEN, 2.0)
	draw_line(spawn_screen + Vector2(0, -arm), spawn_screen + Vector2(0, arm), Color.GREEN, 2.0)
	draw_circle(spawn_screen, 4.0 * _zoom, Color(0, 1, 0, 0.3))
	if _zoom > 0.4:
		draw_string(ThemeDB.fallback_font, spawn_screen + Vector2(arm + 2, 4), "Spawn",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.GREEN)


func _draw_hover() -> void:
	if _hover_cell.x < 0 or not map_data:
		return
	if _hover_cell.x >= map_data.grid_width or _hover_cell.y >= map_data.grid_height:
		return
	var screen_pos: Vector2 = _world_to_screen(Vector2(_hover_cell.x, _hover_cell.y))
	var cell_size: float = CELL_PX * _zoom
	draw_rect(Rect2(screen_pos, Vector2(cell_size, cell_size)), Color(1, 1, 1, 0.2))
	if active_tool == Tool.PAINT:
		var block_color: Color = MapLoader.BLOCK_COLORS[paint_block] if paint_block < MapLoader.BLOCK_COLORS.size() else Color.MAGENTA
		draw_rect(Rect2(screen_pos, Vector2(cell_size, cell_size)), Color(block_color, 0.5))


func _draw_selection() -> void:
	if selected_element_index < 0 or not map_data:
		return
	if selected_element_index >= map_data.elements.size():
		return
	var elem: MapElement = map_data.elements[selected_element_index]
	var screen_pos: Vector2 = _world_to_screen(Vector2(elem.position.x, elem.position.z))
	var sel_radius: float = maxf(ELEMENT_RADIUS * _zoom * 2.0, 8.0)
	draw_circle(screen_pos, sel_radius, Color(1, 1, 1, 0.15))
	draw_circle(screen_pos, sel_radius, Color.WHITE, false, 2.0)


# === Input ===

func _gui_input(event: InputEvent) -> void:
	if not map_data:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			_is_panning = true
			_pan_start_mouse = event.position
			_pan_start_offset = _pan_offset
		else:
			_is_panning = false
		accept_event()
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_at(event.position, ZOOM_STEP)
		accept_event()
		return
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_at(event.position, -ZOOM_STEP)
		accept_event()
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			match active_tool:
				Tool.PAINT:
					_is_painting = true
					_paint_at(event.position)
				Tool.SELECT:
					var hit: int = _hit_test_element(event.position)
					if hit >= 0:
						selected_element_index = hit
						element_clicked.emit(hit)
						_is_dragging_element = true
						_drag_element_index = hit
						var elem: MapElement = map_data.elements[hit]
						var elem_screen: Vector2 = _world_to_screen(Vector2(elem.position.x, elem.position.z))
						_drag_offset = elem_screen - event.position
					else:
						selected_element_index = -1
						element_clicked.emit(-1)
					queue_redraw()
				Tool.PLACE:
					var world: Vector2 = _screen_to_world(event.position)
					element_placed.emit(world)
		else:
			_is_painting = false
			_last_painted_cell = Vector2i(-1, -1)
			_is_dragging_element = false
			_drag_element_index = -1
		accept_event()

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var world: Vector2 = _screen_to_world(event.position)
		canvas_right_clicked.emit(world)
		accept_event()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	# Pan
	if _is_panning:
		var delta: Vector2 = event.position - _pan_start_mouse
		_pan_offset = _pan_start_offset - delta / (_zoom * CELL_PX)
		queue_redraw()
		return

	# Update hover cell
	var grid: Vector2i = _screen_to_grid(event.position)
	if grid != _hover_cell:
		_hover_cell = grid
		hover_changed.emit(_hover_cell)
		queue_redraw()

	# Paint drag
	if _is_painting and active_tool == Tool.PAINT:
		_paint_at(event.position)

	# Element drag
	if _is_dragging_element and _drag_element_index >= 0:
		var world: Vector2 = _screen_to_world(event.position + _drag_offset)
		# Snap to 0.5 increments
		var snapped_x: float = snappedf(world.x, 0.5)
		var snapped_z: float = snappedf(world.y, 0.5)
		var new_pos := Vector3(snapped_x, 0, snapped_z)
		element_moved.emit(_drag_element_index, new_pos)
		queue_redraw()


func _paint_at(screen_pos: Vector2) -> void:
	var grid: Vector2i = _screen_to_grid(screen_pos)
	if grid == _last_painted_cell:
		return
	if grid.x < 0 or grid.y < 0:
		return
	if grid.x >= map_data.grid_width or grid.y >= map_data.grid_height:
		return
	_last_painted_cell = grid
	cell_painted.emit(grid, paint_block)
	queue_redraw()


func _zoom_at(screen_pos: Vector2, delta: float) -> void:
	var world_before: Vector2 = _screen_to_world(screen_pos)
	_zoom = clampf(_zoom + delta, MIN_ZOOM, MAX_ZOOM)
	var world_after: Vector2 = _screen_to_world(screen_pos)
	_pan_offset -= world_after - world_before
	zoom_changed.emit(_zoom)
	queue_redraw()


func _hit_test_element(screen_pos: Vector2) -> int:
	## Returns the index of the element closest to screen_pos, or -1.
	var best_idx: int = -1
	var best_dist_sq: float = INF
	var threshold: float = maxf(ELEMENT_RADIUS * _zoom * 2.0, 12.0)
	var threshold_sq: float = threshold * threshold

	for i in range(map_data.elements.size()):
		var elem: MapElement = map_data.elements[i]
		var elem_screen: Vector2 = _world_to_screen(Vector2(elem.position.x, elem.position.z))
		var dist_sq: float = screen_pos.distance_squared_to(elem_screen)
		if dist_sq < threshold_sq and dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_idx = i

	return best_idx


func deselect() -> void:
	selected_element_index = -1
	queue_redraw()
