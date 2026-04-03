extends Control
## Floating ghost preview that follows the mouse while dragging an item.

var cell_size: int = Constants.GRID_CELL_SIZE  ## Synced from GridPanel on drag start.

var item_data: ItemData
var current_rotation: int = 0
var _center_offset_px: Vector2 = Vector2.ZERO
var _anchor_cell: Vector2i = Vector2i.ZERO

@onready var _icon: TextureRect = $Icon
@onready var _shape_container: Control = $ShapeCells
var _reach_container: Control = null


@warning_ignore("shadowed_variable_base_class")
func setup(item: ItemData, rotation: int = 0, anchor: Vector2i = Vector2i(-1, -1)) -> void:
	item_data = item
	current_rotation = rotation
	if anchor == Vector2i(-1, -1):
		_anchor_cell = item.shape.get_center_cell_offset(rotation)
	else:
		_anchor_cell = anchor
	_icon.texture = item.icon
	_rebuild_shape()
	visible = true


func rotate_cw() -> void:
	if not item_data:
		return
	# Rotate anchor through the same transform as ItemShape.get_rotated_cells():
	# 1. Get cells at current rotation, then rotate all cells + anchor by 90° CW
	var old_cells: Array[Vector2i] = item_data.shape.get_rotated_cells(current_rotation)
	var rotated_cells: Array[Vector2i] = []
	for c in old_cells:
		rotated_cells.append(Vector2i(-c.y, c.x))
	var rotated_anchor: Vector2i = Vector2i(-_anchor_cell.y, _anchor_cell.x)
	# 2. Normalize using the same min offset as the shape
	var min_x: int = 0
	var min_y: int = 0
	for rc in rotated_cells:
		min_x = mini(min_x, rc.x)
		min_y = mini(min_y, rc.y)
	_anchor_cell = Vector2i(rotated_anchor.x - min_x, rotated_anchor.y - min_y)
	# Always allow 4 rotations so the sprite can face any direction
	current_rotation = (current_rotation + 1) % 4
	_rebuild_shape()


func get_cells() -> Array[Vector2i]:
	if not item_data:
		return []
	return item_data.shape.get_rotated_cells(current_rotation)


## Returns the grid-cell offset to subtract from world_to_grid(mouse) for anchor placement.
func get_center_cell_offset() -> Vector2i:
	if not item_data:
		return Vector2i.ZERO
	return _anchor_cell


func set_valid(_is_valid: bool) -> void:
	modulate.a = 0.8


func set_reach_visible(show_reach: bool) -> void:
	if _reach_container:
		_reach_container.visible = show_reach


func hide_preview() -> void:
	visible = false
	item_data = null
	if _reach_container:
		_reach_container.queue_free()
		_reach_container = null


func _process(_delta: float) -> void:
	if visible:
		global_position = get_global_mouse_position() - _center_offset_px


func _rebuild_shape() -> void:
	# Clear old shape panels
	for child in _shape_container.get_children():
		child.queue_free()

	if not item_data:
		return

	var cells: Array[Vector2i] = get_cells()
	if cells.is_empty():
		return

	# Find bounding box for icon sizing
	var min_pos: Vector2i = cells[0]
	var max_pos: Vector2i = cells[0]
	for cell in cells:
		min_pos.x = mini(min_pos.x, cell.x)
		min_pos.y = mini(min_pos.y, cell.y)
		max_pos.x = maxi(max_pos.x, cell.x)
		max_pos.y = maxi(max_pos.y, cell.y)

	var bbox_size: Vector2 = Vector2((max_pos.x - min_pos.x + 1) * cell_size, (max_pos.y - min_pos.y + 1) * cell_size)
	_center_offset_px = Vector2(_anchor_cell) * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)

	# Position icon to cover bounding box — set expand mode before texture
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = Vector2(min_pos.x * cell_size, min_pos.y * cell_size)
	_icon.size = bbox_size
	_icon.pivot_offset = bbox_size / 2.0
	_icon.rotation = current_rotation * PI / 2.0

	# Draw outer-only rarity border (no fill)
	var rarity_color: Color = Constants.get_rarity_color(item_data.rarity)
	for cell in cells:
		var panel: PanelContainer = PanelContainer.new()
		panel.position = Vector2(cell.x * cell_size, cell.y * cell_size)
		panel.custom_minimum_size = Vector2(cell_size, cell_size)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_color = rarity_color
		@warning_ignore("integer_division")
		var bw: int = maxi(1, cell_size / 24)
		style.border_width_left = bw if not cells.has(cell + Vector2i(-1, 0)) else 0
		style.border_width_right = bw if not cells.has(cell + Vector2i(1, 0)) else 0
		style.border_width_top = bw if not cells.has(cell + Vector2i(0, -1)) else 0
		style.border_width_bottom = bw if not cells.has(cell + Vector2i(0, 1)) else 0
		panel.add_theme_stylebox_override("panel", style)

		_shape_container.add_child(panel)

	# Draw modifier reach preview if this is a modifier item
	_build_reach_overlay(cells)


func _build_reach_overlay(shape_cells: Array[Vector2i]) -> void:
	## Draws faint star overlays around the item shape showing its modifier reach.
	if _reach_container:
		_reach_container.queue_free()
		_reach_container = null

	if not item_data or item_data.item_type != Enums.ItemType.MODIFIER:
		return

	var reach_pattern: Array[Vector2i] = item_data.get_reach_cells(current_rotation)
	if reach_pattern.is_empty():
		return

	_reach_container = Control.new()
	_reach_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reach_container)

	# Collect unique reach cells that are NOT part of the item shape
	var reach_cells: Array[Vector2i] = []
	var shape_set: Dictionary = {}
	for sc in shape_cells:
		shape_set[sc] = true
	for sc in shape_cells:
		for offset in reach_pattern:
			var target: Vector2i = sc + offset
			if not shape_set.has(target) and not reach_cells.has(target):
				reach_cells.append(target)

	# Draw faint stars on reach cells
	@warning_ignore("integer_division")
	var font_sz: int = maxi(cell_size / 2, 10)
	for rc in reach_cells:
		var label := Label.new()
		label.text = "\u2605"
		label.add_theme_font_size_override("font_size", font_sz)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.2))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.3))
		label.add_theme_constant_override("outline_size", 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(rc.x * cell_size, rc.y * cell_size)
		label.size = Vector2(cell_size, cell_size)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reach_container.add_child(label)
