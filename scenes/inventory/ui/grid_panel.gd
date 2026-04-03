extends Control
## STUB — awaiting rewrite (INV-R2)
## Renders a character's inventory grid and handles mouse interaction.

signal cell_clicked(grid_pos: Vector2i, button: int)
signal cell_pressed(grid_pos: Vector2i, button: int)
signal cell_released(grid_pos: Vector2i, button: int)
signal cell_hovered(grid_pos: Vector2i)
signal cell_exited()

const CELL_SIZE_MIN: int = Constants.GRID_CELL_SIZE
const CELL_SIZE_MAX: int = 45

var cell_size: int = CELL_SIZE_MIN
var last_failure_reason: String = ""

var _grid_inventory: GridInventory
var _cells: Dictionary = {}
var _item_visuals: Dictionary = {}
var _grid_origin: Vector2i = Vector2i.ZERO
var _grid_width_cells: int = 0
var _grid_height_cells: int = 0

@onready var _cells_layer: Control = $CellsLayer
@onready var _items_layer: Control = $ItemsLayer


func _ready() -> void:
	mouse_exited.connect(_on_mouse_exited)


func setup(grid_inventory: GridInventory) -> void:
	_grid_inventory = grid_inventory


func refresh() -> void:
	pass


func show_placement_preview(_item_data: ItemData, _grid_pos: Vector2i, _rotation: int) -> void:
	pass


func clear_placement_preview() -> void:
	pass


func highlight_modifier_connections(_placed: GridInventory.PlacedItem) -> void:
	pass


func clear_highlights() -> void:
	pass


func highlight_upgradeable_items(_dragged_item: ItemData) -> void:
	pass


func clear_upgradeable_highlights() -> void:
	pass


func highlight_matching_ingredient(_ingredient: ItemData) -> void:
	pass


func clear_ingredient_highlights() -> void:
	pass


func set_cell_purchasable(_cell: Vector2i) -> void:
	pass


func set_items_greyed_out(_greyed: bool) -> void:
	pass


func highlight_item_connections(_placed: GridInventory.PlacedItem) -> void:
	pass


func clear_item_highlights() -> void:
	pass


func show_hover_feedback(_placed: GridInventory.PlacedItem) -> void:
	pass


func clear_hover_feedback() -> void:
	pass


func show_drag_feedback(_item_data: ItemData, _grid_pos: Vector2i, _rotation: int) -> void:
	pass


func clear_drag_feedback() -> void:
	pass


func world_to_grid(screen_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = screen_pos - _cells_layer.global_position
	var gx: int = floori(local_pos.x / cell_size) + _grid_origin.x
	var gy: int = floori(local_pos.y / cell_size) + _grid_origin.y
	return Vector2i(gx, gy)


func get_grid_inventory() -> GridInventory:
	return _grid_inventory


func _gui_input(_event: InputEvent) -> void:
	pass


func _on_mouse_exited() -> void:
	cell_exited.emit()
