extends Control
## Floating ghost preview that follows the mouse while dragging an item.

const CELL_SIZE: int = Constants.GRID_CELL_SIZE

var item_data: ItemData
var current_rotation: int = 0

@onready var _icon: TextureRect = $Icon
@onready var _shape_container: Control = $ShapeCells


func setup(item: ItemData, rotation: int = 0) -> void:
	item_data = item
	current_rotation = rotation
	_icon.texture = item.icon
	_rebuild_shape()
	visible = true


func rotate_cw() -> void:
	if not item_data:
		return
	# Always allow 4 rotations so the sprite can face any direction
	current_rotation = (current_rotation + 1) % 4
	_rebuild_shape()


func get_cells() -> Array[Vector2i]:
	if not item_data:
		return []
	return item_data.shape.get_rotated_cells(current_rotation)


func set_valid(_is_valid: bool) -> void:
	modulate.a = 0.8


func hide_preview() -> void:
	visible = false
	item_data = null


func _process(_delta: float) -> void:
	if visible:
		global_position = get_global_mouse_position()


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

	var bbox_size: Vector2 = Vector2((max_pos.x - min_pos.x + 1) * CELL_SIZE, (max_pos.y - min_pos.y + 1) * CELL_SIZE)

	# Position icon to cover bounding box — set expand mode before texture
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = Vector2(min_pos.x * CELL_SIZE, min_pos.y * CELL_SIZE)
	_icon.size = bbox_size
	_icon.pivot_offset = bbox_size / 2.0
	_icon.rotation = current_rotation * PI / 2.0

	# Draw outer-only rarity border (no fill)
	var rarity_color: Color = Constants.RARITY_COLORS.get(item_data.rarity, Color.WHITE)
	for cell in cells:
		var panel: PanelContainer = PanelContainer.new()
		panel.position = Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE)
		panel.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_color = rarity_color
		style.border_width_left = 2 if not cells.has(cell + Vector2i(-1, 0)) else 0
		style.border_width_right = 2 if not cells.has(cell + Vector2i(1, 0)) else 0
		style.border_width_top = 2 if not cells.has(cell + Vector2i(0, -1)) else 0
		style.border_width_bottom = 2 if not cells.has(cell + Vector2i(0, 1)) else 0
		panel.add_theme_stylebox_override("panel", style)

		_shape_container.add_child(panel)
