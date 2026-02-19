extends Control
## Renders a character's inventory grid and handles mouse interaction.

signal cell_clicked(grid_pos: Vector2i, button: int)
signal cell_hovered(grid_pos: Vector2i)
signal cell_exited()

const CELL_SIZE: int = Constants.GRID_CELL_SIZE
const GridCellScene: PackedScene = preload("res://scenes/inventory/ui/grid_cell.tscn")

var _grid_inventory: GridInventory
var _cells: Dictionary = {}  ## Vector2i -> GridCell node
var _item_visuals: Dictionary = {}  ## PlacedItem -> TextureRect
var _last_hovered_cell: Vector2i = Vector2i(-1, -1)

@onready var _cells_layer: Control = $CellsLayer
@onready var _items_layer: Control = $ItemsLayer


func _ready() -> void:
	mouse_exited.connect(_on_mouse_exited)

func setup(grid_inventory: GridInventory) -> void:
	_grid_inventory = grid_inventory
	_build_cells()
	refresh()


func refresh() -> void:
	if not _grid_inventory:
		return
	# Reset all cell states
	for pos: Vector2i in _cells:
		var cell_node: Control = _cells[pos]
		if _grid_inventory.grid_template.is_cell_active(pos):
			cell_node.set_state(cell_node.CellState.EMPTY)
		else:
			cell_node.set_state(cell_node.CellState.INACTIVE)

	# Mark occupied cells with rarity tint
	for i in range(_grid_inventory.get_all_placed_items().size()):
		var placed: GridInventory.PlacedItem = _grid_inventory.get_all_placed_items()[i]
		var rarity_color: Color = Constants.RARITY_COLORS.get(placed.item_data.rarity, Color.WHITE)
		var occupied: Array[Vector2i] = placed.get_occupied_cells()
		for cell in occupied:
			if _cells.has(cell):
				_cells[cell].set_state(_cells[cell].CellState.OCCUPIED)
				_cells[cell].set_rarity_tint(rarity_color)

	_update_item_visuals()


func show_placement_preview(item_data: ItemData, grid_pos: Vector2i, rotation: int) -> void:
	clear_placement_preview()
	if not _grid_inventory:
		return
	var shape_cells: Array[Vector2i] = item_data.shape.get_rotated_cells(rotation)
	var can_place: bool = _grid_inventory.can_place(item_data, grid_pos, rotation)
	for cell_offset in shape_cells:
		var target: Vector2i = grid_pos + cell_offset
		if _cells.has(target):
			if can_place:
				_cells[target].set_state(_cells[target].CellState.VALID_DROP)
			else:
				_cells[target].set_state(_cells[target].CellState.INVALID_DROP)


func clear_placement_preview() -> void:
	refresh()


func highlight_modifier_connections(placed: GridInventory.PlacedItem) -> void:
	if not _grid_inventory or not placed:
		return
	if placed.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
		var modifiers: Array = _grid_inventory.get_modifiers_affecting(placed)
		for j in range(modifiers.size()):
			var mod: GridInventory.PlacedItem = modifiers[j]
			var mod_cells: Array[Vector2i] = mod.get_occupied_cells()
			for cell in mod_cells:
				if _cells.has(cell):
					_cells[cell].set_state(_cells[cell].CellState.MODIFIER_HIGHLIGHT)
	elif placed.item_data.item_type == Enums.ItemType.MODIFIER:
		var tools: Array = _grid_inventory.get_tools_affected_by(placed)
		for j in range(tools.size()):
			var tool_item: GridInventory.PlacedItem = tools[j]
			var tool_cells: Array[Vector2i] = tool_item.get_occupied_cells()
			for cell in tool_cells:
				if _cells.has(cell):
					_cells[cell].set_state(_cells[cell].CellState.MODIFIER_HIGHLIGHT)


func clear_highlights() -> void:
	refresh()


func world_to_grid(screen_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = screen_pos - _cells_layer.global_position
	var gx: int = floori(local_pos.x / CELL_SIZE)
	var gy: int = floori(local_pos.y / CELL_SIZE)
	return Vector2i(gx, gy)


func is_pos_over_grid(screen_pos: Vector2) -> bool:
	var grid_pos: Vector2i = world_to_grid(screen_pos)
	return _cells.has(grid_pos)


func get_grid_inventory() -> GridInventory:
	return _grid_inventory


# === Internal ===

func _build_cells() -> void:
	# Clear existing
	for child in _cells_layer.get_children():
		child.queue_free()
	_cells.clear()

	if not _grid_inventory:
		return

	var template: GridTemplate = _grid_inventory.grid_template
	for y in range(template.height):
		for x in range(template.width):
			var pos: Vector2i = Vector2i(x, y)
			var cell_node: Control = GridCellScene.instantiate()
			cell_node.position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			cell_node.setup(pos)
			if not template.is_cell_active(pos):
				cell_node.set_state(cell_node.CellState.INACTIVE)
			_cells_layer.add_child(cell_node)
			_cells[pos] = cell_node

	# Size this control to match grid dimensions
	custom_minimum_size = Vector2(template.width * CELL_SIZE, template.height * CELL_SIZE)
	size = custom_minimum_size


func _update_item_visuals() -> void:
	# Clear old visuals
	for child in _items_layer.get_children():
		child.queue_free()
	_item_visuals.clear()

	if not _grid_inventory:
		return

	for i in range(_grid_inventory.get_all_placed_items().size()):
		var placed: GridInventory.PlacedItem = _grid_inventory.get_all_placed_items()[i]
		_create_item_visual(placed)


func _create_item_visual(placed: GridInventory.PlacedItem) -> void:
	var cells: Array[Vector2i] = placed.get_occupied_cells()
	if cells.is_empty():
		return

	# Find bounding box of occupied cells
	var min_pos: Vector2i = cells[0]
	var max_pos: Vector2i = cells[0]
	for cell in cells:
		min_pos.x = mini(min_pos.x, cell.x)
		min_pos.y = mini(min_pos.y, cell.y)
		max_pos.x = maxi(max_pos.x, cell.x)
		max_pos.y = maxi(max_pos.y, cell.y)

	var bbox_w: int = (max_pos.x - min_pos.x + 1) * CELL_SIZE
	var bbox_h: int = (max_pos.y - min_pos.y + 1) * CELL_SIZE

	# Wrap in a clipping container so the icon never overflows its cells
	var container: Control = Control.new()
	container.clip_contents = true
	container.position = Vector2(min_pos.x * CELL_SIZE, min_pos.y * CELL_SIZE)
	container.size = Vector2(bbox_w, bbox_h)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture = placed.item_data.icon
	tex_rect.position = Vector2.ZERO
	tex_rect.size = Vector2(bbox_w, bbox_h)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	container.add_child(tex_rect)
	_items_layer.add_child(container)
	_item_visuals[placed] = container


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var grid_pos: Vector2i = world_to_grid(event.global_position)
		if _cells.has(grid_pos):
			if grid_pos != _last_hovered_cell:
				_last_hovered_cell = grid_pos
				cell_hovered.emit(grid_pos)
		elif _last_hovered_cell != Vector2i(-1, -1):
			_last_hovered_cell = Vector2i(-1, -1)
			cell_exited.emit()

	if event is InputEventMouseButton and event.pressed:
		var grid_pos: Vector2i = world_to_grid(event.global_position)
		if _cells.has(grid_pos):
			cell_clicked.emit(grid_pos, event.button_index)


func _on_mouse_exited() -> void:
	if _last_hovered_cell != Vector2i(-1, -1):
		_last_hovered_cell = Vector2i(-1, -1)
		cell_exited.emit()
