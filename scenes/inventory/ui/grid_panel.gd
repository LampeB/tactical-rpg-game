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
var _star_overlays: Array = []  ## Star labels for modifier connections
var _last_hovered_cell: Vector2i = Vector2i(-1, -1)
var _last_purchasable_cell: Vector2i = Vector2i(-1, -1)  ## Tracks highlighted buyable cell.

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
	_last_purchasable_cell = Vector2i(-1, -1)  # Reset purchasable tracker on full refresh.
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


var last_failure_reason: String = ""

func show_placement_preview(item_data: ItemData, grid_pos: Vector2i, rotation: int) -> void:
	clear_placement_preview()
	if not _grid_inventory:
		return
	var shape_cells: Array[Vector2i] = item_data.shape.get_rotated_cells(rotation)
	var can_place: bool = _grid_inventory.can_place(item_data, grid_pos, rotation)
	if not can_place:
		last_failure_reason = _grid_inventory.get_placement_failure_reason(item_data, grid_pos, rotation)
	else:
		last_failure_reason = ""

	# Show modifier reach area if this is a modifier item
	if item_data.item_type == Enums.ItemType.MODIFIER:
		_show_modifier_reach_preview(shape_cells, grid_pos, item_data, rotation)

	# Check if this modifier would affect any tools
	var would_modify_tools: bool = false
	if can_place and item_data.item_type == Enums.ItemType.MODIFIER:
		# Create temporary PlacedItem to check what tools would be affected
		var temp_placed: GridInventory.PlacedItem = GridInventory.PlacedItem.new()
		temp_placed.item_data = item_data
		temp_placed.grid_position = grid_pos
		temp_placed.rotation = rotation
		var affected_tools: Array = _grid_inventory.get_tools_affected_by(temp_placed)
		would_modify_tools = not affected_tools.is_empty()

	# Show valid/invalid drop on grid cells
	for cell_offset in shape_cells:
		var target: Vector2i = grid_pos + cell_offset
		if _cells.has(target):
			if can_place:
				_cells[target].set_state(_cells[target].CellState.VALID_DROP)
			else:
				_cells[target].set_state(_cells[target].CellState.INVALID_DROP)

	# Highlight the tools that would be affected by this modifier
	if would_modify_tools and can_place:
		var temp_placed: GridInventory.PlacedItem = GridInventory.PlacedItem.new()
		temp_placed.item_data = item_data
		temp_placed.grid_position = grid_pos
		temp_placed.rotation = rotation
		var affected_tools: Array = _grid_inventory.get_tools_affected_by(temp_placed)
		for i in range(affected_tools.size()):
			var tool: GridInventory.PlacedItem = affected_tools[i]
			var tool_cells: Array[Vector2i] = tool.get_occupied_cells()
			for cell in tool_cells:
				if _cells.has(cell):
					_cells[cell]._background.color = Color(1.0, 0.0, 1.0, 0.8)  # Magenta highlights affected tools


func clear_placement_preview() -> void:
	refresh()


func highlight_modifier_connections(placed: GridInventory.PlacedItem) -> void:
	_clear_star_overlays()
	if not _grid_inventory or not placed:
		return
	if placed.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
		# Hovering a weapon: one star per gem, on the gem cell that reaches the weapon
		var tool_cells: Array[Vector2i] = placed.get_occupied_cells()
		var modifiers: Array = _grid_inventory.get_modifiers_affecting(placed)
		for j in range(modifiers.size()):
			var mod: GridInventory.PlacedItem = modifiers[j]
			var best: Vector2i = _pick_best_reaching_cell(mod, tool_cells)
			if best != Vector2i(-999, -999):
				_add_star_at_cell(best)
	elif placed.item_data.item_type == Enums.ItemType.MODIFIER:
		# Hovering a gem: one star per weapon, on the weapon cell reached by this gem
		var tools: Array = _grid_inventory.get_tools_affected_by(placed)
		for j in range(tools.size()):
			var tool_item: GridInventory.PlacedItem = tools[j]
			var tool_cells: Array[Vector2i] = tool_item.get_occupied_cells()
			var best: Vector2i = _pick_best_reached_cell(placed, tool_cells)
			if best != Vector2i(-999, -999):
				_add_star_at_cell(best)


func clear_highlights() -> void:
	_clear_star_overlays()


func _pick_best_reaching_cell(modifier: GridInventory.PlacedItem, target_cells: Array[Vector2i]) -> Vector2i:
	## Pick the single best gem cell that reaches the weapon.
	## Priority: closest to weapon, then clockwise from top.
	var mod_cells: Array[Vector2i] = modifier.get_occupied_cells()
	var reach_pattern: Array[Vector2i] = modifier.item_data.get_reach_cells(modifier.rotation)
	var best: Vector2i = Vector2i(-999, -999)
	var best_dist: float = INF
	var best_angle: float = INF
	for mc in mod_cells:
		for offset in reach_pattern:
			if target_cells.has(mc + offset):
				# Distance = offset length (how far the reach extends)
				var dist: float = Vector2(offset).length()
				var angle: float = _clockwise_angle(offset)
				if dist < best_dist or (dist == best_dist and angle < best_angle):
					best = mc
					best_dist = dist
					best_angle = angle
				break  # One match per mod cell is enough
	return best


func _pick_best_reached_cell(modifier: GridInventory.PlacedItem, target_cells: Array[Vector2i]) -> Vector2i:
	## Pick the single best weapon cell reached by the gem.
	## Priority: closest to gem, then clockwise from top.
	var mod_cells: Array[Vector2i] = modifier.get_occupied_cells()
	var reach_pattern: Array[Vector2i] = modifier.item_data.get_reach_cells(modifier.rotation)
	var best: Vector2i = Vector2i(-999, -999)
	var best_dist: float = INF
	var best_angle: float = INF
	for mc in mod_cells:
		for offset in reach_pattern:
			var affected: Vector2i = mc + offset
			if target_cells.has(affected):
				var dist: float = Vector2(offset).length()
				var angle: float = _clockwise_angle(offset)
				if dist < best_dist or (dist == best_dist and angle < best_angle):
					best = affected
					best_dist = dist
					best_angle = angle
	return best


func _clockwise_angle(offset: Vector2i) -> float:
	## Returns angle in [0, TAU) clockwise from top (up = 0, right = PI/2, etc.)
	var angle: float = atan2(float(offset.x), float(-offset.y))
	if angle < 0.0:
		angle += TAU
	return angle


func _add_star_at_cell(cell_pos: Vector2i) -> void:
	var star: Label = Label.new()
	star.text = "*"
	star.add_theme_font_size_override("font_size", 28)
	star.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	star.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	star.add_theme_constant_override("shadow_offset_x", 1)
	star.add_theme_constant_override("shadow_offset_y", 1)
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.size = Vector2(CELL_SIZE, CELL_SIZE)
	star.position = Vector2(cell_pos.x * CELL_SIZE, cell_pos.y * CELL_SIZE)
	_items_layer.add_child(star)
	_star_overlays.append(star)


func _clear_star_overlays() -> void:
	for star in _star_overlays:
		if is_instance_valid(star):
			star.queue_free()
	_star_overlays.clear()


func highlight_upgradeable_items(dragged_item: ItemData) -> void:
	## Highlights items that can be upgraded with the dragged item
	if not _grid_inventory or not dragged_item:
		return

	var placed_items: Array = _grid_inventory.get_all_placed_items()
	for i in range(placed_items.size()):
		var placed: GridInventory.PlacedItem = placed_items[i]
		if ItemUpgradeSystem.can_upgrade(dragged_item, placed.item_data):
			# Highlight all cells occupied by this upgradeable item
			var occupied: Array[Vector2i] = placed.get_occupied_cells()
			for cell in occupied:
				if _cells.has(cell):
					_cells[cell].set_state(_cells[cell].CellState.UPGRADEABLE)


## Highlights a single inactive cell as purchasable (golden tint on hover).
## Automatically resets the previously highlighted cell so only one is lit at a time.
func set_cell_purchasable(cell: Vector2i) -> void:
	# Reset the previous purchasable highlight first.
	if _cells.has(_last_purchasable_cell):
		var prev: Control = _cells[_last_purchasable_cell]
		if prev.cell_state == prev.CellState.PURCHASABLE:
			prev.set_state(prev.CellState.INACTIVE)
	_last_purchasable_cell = Vector2i(-1, -1)

	if _cells.has(cell):
		var cell_node: Control = _cells[cell]
		if cell_node.cell_state == cell_node.CellState.INACTIVE:
			cell_node.set_state(cell_node.CellState.PURCHASABLE)
			_last_purchasable_cell = cell


func world_to_grid(screen_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = screen_pos - _cells_layer.global_position
	var gx: int = floori(local_pos.x / CELL_SIZE)
	var gy: int = floori(local_pos.y / CELL_SIZE)
	return Vector2i(gx, gy)


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

	# Determine which cell positions to render: layout_cells if set, else full bounding box.
	# Cells NOT in the layout are VOID — they are simply not created.
	var positions: Array[Vector2i] = []
	if template.layout_cells.is_empty():
		for y in range(template.height):
			for x in range(template.width):
				positions.append(Vector2i(x, y))
	else:
		positions = template.layout_cells.duplicate()

	for pos in positions:
		var cell_node: Control = GridCellScene.instantiate()
		cell_node.position = Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)
		cell_node.setup(pos)
		if not template.is_cell_active(pos):
			cell_node.set_state(cell_node.CellState.INACTIVE)
		_cells_layer.add_child(cell_node)
		_cells[pos] = cell_node

	# Size to bounding box so the panel reserves the right amount of space.
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
	tex_rect.pivot_offset = Vector2(bbox_w, bbox_h) / 2.0
	tex_rect.rotation = placed.rotation * PI / 2.0
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	container.add_child(tex_rect)

	# Create shape outline container
	var shape_outline: Control = Control.new()
	shape_outline.position = Vector2.ZERO
	shape_outline.size = Vector2(bbox_w, bbox_h)
	shape_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(shape_outline)

	# Draw outer-only border for the item shape
	var rarity_color: Color = Constants.RARITY_COLORS.get(placed.item_data.rarity, Color.WHITE)
	for cell in cells:
		var cell_panel: PanelContainer = PanelContainer.new()
		cell_panel.position = Vector2((cell.x - min_pos.x) * CELL_SIZE, (cell.y - min_pos.y) * CELL_SIZE)
		cell_panel.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		cell_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Only draw border on edges not shared with another cell of the same item
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_color = rarity_color
		style.border_width_left = 2 if not cells.has(cell + Vector2i(-1, 0)) else 0
		style.border_width_right = 2 if not cells.has(cell + Vector2i(1, 0)) else 0
		style.border_width_top = 2 if not cells.has(cell + Vector2i(0, -1)) else 0
		style.border_width_bottom = 2 if not cells.has(cell + Vector2i(0, 1)) else 0
		cell_panel.add_theme_stylebox_override("panel", style)

		shape_outline.add_child(cell_panel)

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


func _show_modifier_reach_preview(shape_cells: Array[Vector2i], grid_pos: Vector2i, item_data: ItemData, rotation: int = 0) -> void:
	## Highlights cells that would be affected by a modifier gem's reach pattern.
	var reach_pattern: Array[Vector2i] = item_data.get_reach_cells(rotation)
	var affected_cells: Array[Vector2i] = []

	for cell_offset in shape_cells:
		var modifier_cell: Vector2i = grid_pos + cell_offset
		for offset in reach_pattern:
			var target_cell: Vector2i = modifier_cell + offset
			if not affected_cells.has(target_cell):
				affected_cells.append(target_cell)

	for cell in affected_cells:
		if _cells.has(cell):
			var is_occupied_by_item: bool = false
			for cell_offset in shape_cells:
				if grid_pos + cell_offset == cell:
					is_occupied_by_item = true
					break
			if not is_occupied_by_item:
				_cells[cell].set_state(_cells[cell].CellState.MODIFIER_REACH)
