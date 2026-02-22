extends Control
## Floating ghost preview that follows the mouse while dragging an item.

const CELL_SIZE: int = Constants.GRID_CELL_SIZE

var item_data: ItemData
var current_rotation: int = 0
var _shape_rects: Array[ColorRect] = []

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
	# Allow 4 rotations if item has a custom reach pattern (even for 1x1 gems)
	var max_rotations: int = item_data.shape.rotation_states
	if max_rotations < 4 and not item_data.modifier_reach_pattern.is_empty():
		max_rotations = 4
	current_rotation = (current_rotation + 1) % max_rotations
	_rebuild_shape()


func get_cells() -> Array[Vector2i]:
	if not item_data:
		return []
	return item_data.shape.get_rotated_cells(current_rotation)


func set_valid(is_valid: bool) -> void:
	var tint: Color = Constants.COLOR_DRAG_VALID if is_valid else Constants.COLOR_DRAG_INVALID
	for rect in _shape_rects:
		if is_instance_valid(rect):
			rect.color = tint
	modulate.a = 0.8


func hide_preview() -> void:
	visible = false
	item_data = null


func _process(_delta: float) -> void:
	if visible:
		global_position = get_global_mouse_position()


func _rebuild_shape() -> void:
	# Clear old shape rects
	for child in _shape_container.get_children():
		child.queue_free()
	_shape_rects.clear()

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

	# Draw shape cell outlines
	for cell in cells:
		var rect: ColorRect = ColorRect.new()
		rect.position = Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE)
		rect.size = Vector2(CELL_SIZE, CELL_SIZE)
		rect.color = Constants.COLOR_DRAG_VALID
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shape_container.add_child(rect)
		_shape_rects.append(rect)
