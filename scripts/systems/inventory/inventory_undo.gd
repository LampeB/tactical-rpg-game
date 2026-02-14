class_name InventoryUndo
extends RefCounted
## Stack-based undo system for inventory grid operations.

const MAX_UNDO := 10

var _stack: Array = []  ## of UndoAction


func push_place(item: ItemData, pos: Vector2i, rot: int) -> void:
	_push(UndoAction.new(UndoAction.Type.PLACE, item, Vector2i.ZERO, pos, 0, rot))


func push_remove(item: ItemData, pos: Vector2i, rot: int) -> void:
	_push(UndoAction.new(UndoAction.Type.REMOVE, item, pos, Vector2i.ZERO, rot, 0))


func push_move(item: ItemData, from_pos: Vector2i, to_pos: Vector2i, from_rot: int, to_rot: int) -> void:
	_push(UndoAction.new(UndoAction.Type.MOVE, item, from_pos, to_pos, from_rot, to_rot))


func pop() -> UndoAction:
	if _stack.is_empty():
		return null
	return _stack.pop_back()


func can_undo() -> bool:
	return not _stack.is_empty()


func clear() -> void:
	_stack.clear()


func _push(action: UndoAction) -> void:
	_stack.append(action)
	if _stack.size() > MAX_UNDO:
		_stack.pop_front()


class UndoAction:
	enum Type { PLACE, REMOVE, MOVE }

	var type: Type
	var item_data: ItemData
	var from_position: Vector2i
	var to_position: Vector2i
	var from_rotation: int
	var to_rotation: int

	func _init(p_type: Type, p_item: ItemData, p_from: Vector2i, p_to: Vector2i, p_from_rot: int, p_to_rot: int) -> void:
		type = p_type
		item_data = p_item
		from_position = p_from
		to_position = p_to
		from_rotation = p_from_rot
		to_rotation = p_to_rot
