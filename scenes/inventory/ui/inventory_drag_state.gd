class_name InventoryDragState
extends RefCounted
## Pure-data state machine for inventory drag operations.
## No Node dependencies, no signals, no visual logic.

enum State { IDLE, DRAGGING }
enum Source { NONE, GRID, STASH }

var state: State = State.IDLE
var source: Source = Source.NONE
var item: ItemData = null
var rotation: int = 0
var source_pos: Vector2i = Vector2i.ZERO
var source_rotation: int = 0
var source_placed: GridInventory.PlacedItem = null
var source_stash_index: int = -1
var started_frame: int = 0
var last_preview_grid_pos: Vector2i = Vector2i(-999, -999)


func is_dragging() -> bool:
	return state == State.DRAGGING


func start_from_grid(placed: GridInventory.PlacedItem, frame: int) -> void:
	state = State.DRAGGING
	source = Source.GRID
	item = placed.item_data
	rotation = placed.rotation
	source_pos = placed.grid_position
	source_rotation = placed.rotation
	source_placed = placed
	source_stash_index = -1
	started_frame = frame
	last_preview_grid_pos = Vector2i(-999, -999)


func start_from_stash(stash_item: ItemData, index: int, frame: int) -> void:
	state = State.DRAGGING
	source = Source.STASH
	item = stash_item
	rotation = 0
	source_pos = Vector2i.ZERO
	source_rotation = 0
	source_placed = null
	source_stash_index = index
	started_frame = frame
	last_preview_grid_pos = Vector2i(-999, -999)


func reset() -> void:
	state = State.IDLE
	source = Source.NONE
	item = null
	rotation = 0
	source_pos = Vector2i.ZERO
	source_rotation = 0
	source_placed = null
	source_stash_index = -1
	started_frame = 0
	last_preview_grid_pos = Vector2i(-999, -999)


func is_same_frame_release(current_frame: int) -> bool:
	return current_frame <= started_frame


func rotate_cw() -> void:
	rotation = (rotation + 1) % 4
