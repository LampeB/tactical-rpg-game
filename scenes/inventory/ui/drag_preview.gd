extends Control
## STUB — awaiting rewrite (INV-R3)
## Floating ghost preview that follows the mouse while dragging an item.

var cell_size: int = 25
var item_data: ItemData = null
var current_rotation: int = 0

@onready var _shape_container: Control = $ShapeContainer

var _center_offset_px: Vector2 = Vector2.ZERO


func setup(_item: ItemData, _rotation: int, _anchor: Vector2i = Vector2i(-1, -1)) -> void:
	pass


func rotate_cw() -> void:
	pass


func get_cells() -> Array[Vector2i]:
	return []


func get_center_cell_offset() -> Vector2i:
	return Vector2i.ZERO


func set_valid(_is_valid: bool) -> void:
	pass


func hide_preview() -> void:
	visible = false
	item_data = null


func set_snap_position(_snap_pos: Vector2) -> void:
	pass


func clear_snap() -> void:
	pass


func _process(_delta: float) -> void:
	pass
