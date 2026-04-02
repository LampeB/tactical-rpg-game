extends Control
## Renders a character's inventory grid and handles mouse interaction.

signal cell_clicked(grid_pos: Vector2i, button: int)
signal cell_hovered(grid_pos: Vector2i)
signal cell_exited()

const CELL_SIZE_MIN: int = Constants.GRID_CELL_SIZE  ## 25
const CELL_SIZE_MAX: int = 45
const GridCellScene: PackedScene = preload("res://scenes/inventory/ui/grid_cell.tscn")

var cell_size: int = CELL_SIZE_MIN  ## Computed per-setup to best fill available space.

var _grid_inventory: GridInventory
var _cells: Dictionary = {}  ## Vector2i -> GridCell node
var _item_visuals: Dictionary = {}  ## PlacedItem -> TextureRect
var _star_overlays: Array = []  ## Star labels for modifier connections
var _hover_reach_cells: Array[Vector2i] = []  ## Cells temporarily set to MODIFIER_REACH on hover
var _last_hovered_cell: Vector2i = Vector2i(-1, -1)
var _last_purchasable_cell: Vector2i = Vector2i(-1, -1)  ## Tracks highlighted buyable cell.
var _grid_origin: Vector2i = Vector2i.ZERO  ## Min layout coordinate — used to offset rendering.
var _grid_width_cells: int = 0   ## Actual shape width (max_x - min_x + 1).
var _grid_height_cells: int = 0  ## Actual shape height (max_y - min_y + 1).

@onready var _cells_layer: Control = $CellsLayer
@onready var _items_layer: Control = $ItemsLayer
@onready var _panel_backdrop: NinePatchRect = $PanelBackdrop


func _ready() -> void:
	mouse_exited.connect(_on_mouse_exited)
	_apply_panel_theme()


func _apply_panel_theme() -> void:
	# No backdrop — void cells should be transparent (game background shows through)
	if _panel_backdrop:
		_panel_backdrop.visible = false

func setup(grid_inventory: GridInventory) -> void:
	_grid_inventory = grid_inventory
	_build_cells()
	refresh()


func refresh() -> void:
	if not _grid_inventory:
		return
	_last_purchasable_cell = Vector2i(-1, -1)  # Reset purchasable tracker on full refresh.
	_last_hovered_cell = Vector2i(-1, -1)  # Force re-emit on next mouse motion (e.g. after drag start).
	# Reset all cell states
	for pos: Vector2i in _cells:
		var cell_node: Control = _cells[pos]
		if _grid_inventory.grid_template.is_cell_active(pos):
			cell_node.set_state(cell_node.CellState.EMPTY)
		else:
			cell_node.set_state(cell_node.CellState.INACTIVE)

	# Mark occupied cells with rarity slot colors
	for i in range(_grid_inventory.get_all_placed_items().size()):
		var placed: GridInventory.PlacedItem = _grid_inventory.get_all_placed_items()[i]
		var slot_colors: Array = Constants.RARITY_SLOT_COLORS.get(placed.item_data.rarity, [])
		var occupied: Array[Vector2i] = placed.get_occupied_cells()
		for cell in occupied:
			if _cells.has(cell):
				_cells[cell].set_state(_cells[cell].CellState.OCCUPIED)
				if slot_colors.size() >= 2:
					_cells[cell].set_rarity_tint(slot_colors[0])  # bg_normal

	_update_item_visuals()


var last_failure_reason: String = ""

@warning_ignore("shadowed_variable_base_class")
func show_placement_preview(item_data: ItemData, grid_pos: Vector2i, rotation: int) -> void:
	clear_placement_preview()
	if not _grid_inventory:
		return
	var shape_cells: Array[Vector2i] = item_data.shape.get_rotated_cells(rotation)
	var can_place: bool = _grid_inventory.can_place(item_data, grid_pos, rotation)

	# Detect single-item swap possibility
	var is_swap: bool = false
	if not can_place:
		var blockers: Array = _grid_inventory.get_blocking_items(item_data, grid_pos, rotation)
		if blockers.size() == 1 and _grid_inventory.can_place_ignoring(item_data, grid_pos, rotation, blockers[0]):
			is_swap = true
			last_failure_reason = ""
		else:
			last_failure_reason = _grid_inventory.get_placement_failure_reason(item_data, grid_pos, rotation)
	else:
		last_failure_reason = ""

	# Show modifier reach area if this is a modifier item
	if item_data.item_type == Enums.ItemType.MODIFIER:
		_show_modifier_reach_preview(shape_cells, grid_pos, item_data, rotation)

	# Check if this modifier would affect any tools
	var affected_tools: Array = []
	if (can_place or is_swap) and item_data.item_type == Enums.ItemType.MODIFIER:
		var temp_placed: GridInventory.PlacedItem = GridInventory.PlacedItem.new()
		temp_placed.item_data = item_data
		temp_placed.grid_position = grid_pos
		temp_placed.rotation = rotation
		affected_tools = _grid_inventory.get_tools_affected_by(temp_placed)

	# Show valid/invalid/swap drop on grid cells
	for cell_offset in shape_cells:
		var target: Vector2i = grid_pos + cell_offset
		if _cells.has(target):
			if can_place:
				_cells[target].set_state(_cells[target].CellState.VALID_DROP)
			elif is_swap:
				_cells[target].set_state(_cells[target].CellState.SWAP_DROP)
			else:
				_cells[target].set_state(_cells[target].CellState.INVALID_DROP)

	# Highlight the tools that would be affected by this modifier
	if not affected_tools.is_empty() and can_place:
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
	_clear_hover_reach_cells()
	if not _grid_inventory or not placed:
		return
	if placed.item_data.is_modifiable():
		# Hovering a modifiable item: one star per gem, on the gem cell that reaches it
		var tool_cells: Array[Vector2i] = placed.get_occupied_cells()
		var modifiers: Array = _grid_inventory.get_modifiers_affecting(placed)
		for j in range(modifiers.size()):
			var mod: GridInventory.PlacedItem = modifiers[j]
			var best: Vector2i = _pick_best_reaching_cell(mod, tool_cells)
			if best != Vector2i(-999, -999):
				_add_star_at_cell(best)
	elif placed.item_data.item_type == Enums.ItemType.MODIFIER:
		# Hovering a gem: show rotated reach cells + one star per weapon connected
		var placed_cells: Array[Vector2i] = placed.get_occupied_cells()
		var reach_pattern: Array[Vector2i] = placed.item_data.get_reach_cells(placed.rotation)
		for mc in placed_cells:
			for offset in reach_pattern:
				var target: Vector2i = mc + offset
				if _cells.has(target) and not placed_cells.has(target):
					_cells[target].set_state(_cells[target].CellState.MODIFIER_REACH)
					_hover_reach_cells.append(target)
		var tools: Array = _grid_inventory.get_tools_affected_by(placed)
		for j in range(tools.size()):
			var tool_item: GridInventory.PlacedItem = tools[j]
			var tool_cells: Array[Vector2i] = tool_item.get_occupied_cells()
			var best: Vector2i = _pick_best_reached_cell(placed, tool_cells)
			if best != Vector2i(-999, -999):
				_add_star_at_cell(best)


func clear_highlights() -> void:
	_clear_star_overlays()
	_clear_hover_reach_cells()


func _clear_hover_reach_cells() -> void:
	for cell_pos in _hover_reach_cells:
		if _cells.has(cell_pos) and _grid_inventory:
			var cell_node: Control = _cells[cell_pos]
			if not _grid_inventory.grid_template.is_cell_active(cell_pos):
				cell_node.set_state(cell_node.CellState.INACTIVE)
			elif _grid_inventory.get_item_at(cell_pos) != null:
				var item_there: GridInventory.PlacedItem = _grid_inventory.get_item_at(cell_pos)
				var rarity_color: Color = Constants.get_rarity_color(item_there.item_data.rarity)
				cell_node.set_state(cell_node.CellState.OCCUPIED)
				cell_node.set_rarity_tint(rarity_color)
			else:
				cell_node.set_state(cell_node.CellState.EMPTY)
	_hover_reach_cells.clear()


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
	UIThemes.set_font_size(star, maxi(10, cell_size - 8))
	star.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	star.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	star.add_theme_constant_override("shadow_offset_x", 1)
	star.add_theme_constant_override("shadow_offset_y", 1)
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.size = Vector2(cell_size, cell_size)
	star.position = Vector2((cell_pos.x - _grid_origin.x) * cell_size, (cell_pos.y - _grid_origin.y) * cell_size)
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


func clear_upgradeable_highlights() -> void:
	## Resets upgrade-highlighted cells back to OCCUPIED with rarity tint.
	if not _grid_inventory:
		return
	for placed in _grid_inventory.get_all_placed_items():
		for cell in placed.get_occupied_cells():
			if _cells.has(cell) and _cells[cell].cell_state == _cells[cell].CellState.UPGRADEABLE:
				_cells[cell].set_state(_cells[cell].CellState.OCCUPIED)
				var rarity_color: Color = Constants.get_rarity_color(placed.item_data.rarity)
				_cells[cell].set_rarity_tint(rarity_color)


func highlight_matching_ingredient(ingredient: CraftingIngredient) -> void:
	## Highlights items that match a crafting ingredient (cyan tint).
	if not _grid_inventory or not ingredient:
		return
	for placed in _grid_inventory.get_all_placed_items():
		if CraftingSystem.item_matches(placed.item_data, ingredient):
			for cell in placed.get_occupied_cells():
				if _cells.has(cell):
					_cells[cell].set_state(_cells[cell].CellState.INGREDIENT_MATCH)


func clear_ingredient_highlights() -> void:
	## Resets ingredient-highlighted cells back to OCCUPIED with rarity tint.
	if not _grid_inventory:
		return
	for placed in _grid_inventory.get_all_placed_items():
		for cell in placed.get_occupied_cells():
			if _cells.has(cell) and _cells[cell].cell_state == _cells[cell].CellState.INGREDIENT_MATCH:
				_cells[cell].set_state(_cells[cell].CellState.OCCUPIED)
				var rarity_color: Color = Constants.get_rarity_color(placed.item_data.rarity)
				_cells[cell].set_rarity_tint(rarity_color)


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
	var gx: int = floori(local_pos.x / cell_size) + _grid_origin.x
	var gy: int = floori(local_pos.y / cell_size) + _grid_origin.y
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

	# Compute origin from layout cells so the shape renders from (0,0).
	if not positions.is_empty():
		var min_x: int = positions[0].x
		var min_y: int = positions[0].y
		for pos in positions:
			min_x = mini(min_x, pos.x)
			min_y = mini(min_y, pos.y)
		_grid_origin = Vector2i(min_x, min_y)
	else:
		_grid_origin = Vector2i.ZERO

	# Compute actual extent from layout positions (not template dimensions).
	var max_x: int = _grid_origin.x
	var max_y: int = _grid_origin.y
	for pos in positions:
		max_x = maxi(max_x, pos.x)
		max_y = maxi(max_y, pos.y)
	_grid_width_cells = max_x - _grid_origin.x + 1
	_grid_height_cells = max_y - _grid_origin.y + 1

	# Compute best cell size from available space.
	_recompute_cell_size()

	for pos in positions:
		var cell_node: Control = GridCellScene.instantiate()
		cell_node.position = Vector2((pos.x - _grid_origin.x) * cell_size, (pos.y - _grid_origin.y) * cell_size)
		cell_node.setup(pos)
		if not template.is_cell_active(pos):
			cell_node.set_state(cell_node.CellState.INACTIVE)
		_cells_layer.add_child(cell_node)
		# Override cell size from the default Constants.GRID_CELL_SIZE.
		var sz := Vector2(cell_size, cell_size)
		cell_node.custom_minimum_size = sz
		cell_node.size = sz
		_cells[pos] = cell_node

	# Size to actual extent.
	custom_minimum_size = Vector2(_grid_width_cells * cell_size, _grid_height_cells * cell_size)
	size = custom_minimum_size

	# Deferred recalc — parent layout may not be settled during initial setup.
	# Border drawing happens after resize so positions are correct.
	call_deferred("_deferred_resize")


func _build_zone_outlines(template: GridTemplate, all_positions: Array[Vector2i]) -> void:
	## Places sprite-based border pieces along the edges of each zone.
	## Uses edge and corner sprites from the inventory asset pack.
	# Remove old border sprites
	for child in _cells_layer.get_children():
		if child.name.begins_with("BorderPiece"):
			child.queue_free()

	var active_set: Dictionary = {}
	var layout_set: Dictionary = {}
	for pos in all_positions:
		layout_set[pos] = true
		if template.is_cell_active(pos):
			active_set[pos] = true

	# Outer border (around all layout cells — expansion boundary)
	_place_border_sprites(layout_set, Color(0.5, 0.3, 0.2, 0.9), "BorderPieceOuter")
	# Inner border (around active cells only — usable area)
	_place_border_sprites(active_set, Color(0.9, 0.85, 0.7, 1.0), "BorderPieceInner")


func _place_border_sprites(cell_set: Dictionary, tint: Color, prefix: String) -> void:
	## Places edge and corner TextureRects along boundary edges of the cell set.
	var edge_v_tex: Texture2D = InventoryTheme.get_edge_v_texture()
	var edge_h_tex: Texture2D = InventoryTheme.get_edge_h_texture()
	var corner_tex: Texture2D = InventoryTheme.get_corner_texture()
	if not edge_v_tex or not edge_h_tex:
		return

	var cs: int = cell_size
	var border_w: float = 4.0  # border thickness in pixels
	var idx: int = 0

	for pos_variant in cell_set:
		var pos: Vector2i = pos_variant as Vector2i
		var px: float = float((pos.x - _grid_origin.x) * cs)
		var py: float = float((pos.y - _grid_origin.y) * cs)

		# Top edge
		if not cell_set.has(Vector2i(pos.x, pos.y - 1)):
			var tr := TextureRect.new()
			tr.texture = edge_h_tex
			tr.position = Vector2(px, py - border_w)
			tr.size = Vector2(cs, border_w)
			tr.stretch_mode = TextureRect.STRETCH_TILE
			tr.modulate = tint
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.name = "%s_%d" % [prefix, idx]
			idx += 1
			_cells_layer.add_child(tr)
			_cells_layer.move_child(tr, 0)

		# Bottom edge
		if not cell_set.has(Vector2i(pos.x, pos.y + 1)):
			var tr := TextureRect.new()
			tr.texture = edge_h_tex
			tr.position = Vector2(px, py + cs)
			tr.size = Vector2(cs, border_w)
			tr.stretch_mode = TextureRect.STRETCH_TILE
			tr.modulate = tint
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.name = "%s_%d" % [prefix, idx]
			idx += 1
			_cells_layer.add_child(tr)
			_cells_layer.move_child(tr, 0)

		# Left edge
		if not cell_set.has(Vector2i(pos.x - 1, pos.y)):
			var tr := TextureRect.new()
			tr.texture = edge_v_tex
			tr.position = Vector2(px - border_w, py)
			tr.size = Vector2(border_w, cs)
			tr.stretch_mode = TextureRect.STRETCH_TILE
			tr.modulate = tint
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.name = "%s_%d" % [prefix, idx]
			idx += 1
			_cells_layer.add_child(tr)
			_cells_layer.move_child(tr, 0)

		# Right edge
		if not cell_set.has(Vector2i(pos.x + 1, pos.y)):
			var tr := TextureRect.new()
			tr.texture = edge_v_tex
			tr.position = Vector2(px + cs, py)
			tr.size = Vector2(border_w, cs)
			tr.stretch_mode = TextureRect.STRETCH_TILE
			tr.modulate = tint
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.name = "%s_%d" % [prefix, idx]
			idx += 1
			_cells_layer.add_child(tr)
			_cells_layer.move_child(tr, 0)

		# Corners — place at outer corners where two edges meet
		if corner_tex:
			var has_top: bool = not cell_set.has(Vector2i(pos.x, pos.y - 1))
			var has_bottom: bool = not cell_set.has(Vector2i(pos.x, pos.y + 1))
			var has_left: bool = not cell_set.has(Vector2i(pos.x - 1, pos.y))
			var has_right: bool = not cell_set.has(Vector2i(pos.x + 1, pos.y))
			var cw: float = border_w

			if has_top and has_left:
				_place_corner(corner_tex, Vector2(px - cw, py - cw), Vector2(cw, cw), tint, prefix, idx)
				idx += 1
			if has_top and has_right:
				_place_corner(corner_tex, Vector2(px + cs, py - cw), Vector2(cw, cw), tint, prefix, idx)
				idx += 1
			if has_bottom and has_left:
				_place_corner(corner_tex, Vector2(px - cw, py + cs), Vector2(cw, cw), tint, prefix, idx)
				idx += 1
			if has_bottom and has_right:
				_place_corner(corner_tex, Vector2(px + cs, py + cs), Vector2(cw, cw), tint, prefix, idx)
				idx += 1


func _place_corner(tex: Texture2D, pos: Vector2, sz: Vector2, tint: Color, prefix: String, idx: int) -> void:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.position = pos
	tr.size = sz
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.modulate = tint
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.name = "%s_%d" % [prefix, idx]
	_cells_layer.add_child(tr)
	_cells_layer.move_child(tr, 0)


func _build_zone_borders(template: GridTemplate, all_positions: Array[Vector2i]) -> void:
	## Draws colored border rectangles around the active zone and expansion zone.
	# Remove old borders
	for child in _cells_layer.get_children():
		if child.name.begins_with("ZoneBorder"):
			child.queue_free()

	var active_positions: Array[Vector2i] = template.get_active_cells()
	var inactive_positions: Array[Vector2i] = []
	for pos in all_positions:
		if not template.is_cell_active(pos):
			inactive_positions.append(pos)

	# Active zone border (bright blue — clearly marks the usable area)
	if not active_positions.is_empty():
		var border: Control = _create_zone_border(active_positions, Color(0.3, 0.5, 0.9, 1.0), 3)
		border.name = "ZoneBorderActive"
		_cells_layer.add_child(border)
		_cells_layer.move_child(border, 0)

	# Expansion zone border (dark red — locked/purchasable area)
	if not inactive_positions.is_empty():
		var border: Control = _create_zone_border(inactive_positions, Color(0.6, 0.15, 0.1, 0.9), 3)
		border.name = "ZoneBorderExpansion"
		_cells_layer.add_child(border)
		_cells_layer.move_child(border, 0)


func _create_zone_border(positions: Array[Vector2i], color: Color, thickness: int) -> Control:
	## Creates a border rectangle around the bounding box of the given cell positions.
	var min_x: int = positions[0].x
	var min_y: int = positions[0].y
	var max_x: int = positions[0].x
	var max_y: int = positions[0].y
	for pos in positions:
		min_x = mini(min_x, pos.x)
		min_y = mini(min_y, pos.y)
		max_x = maxi(max_x, pos.x)
		max_y = maxi(max_y, pos.y)

	var rect_pos := Vector2((min_x - _grid_origin.x) * cell_size - thickness,
							(min_y - _grid_origin.y) * cell_size - thickness)
	var rect_size := Vector2((max_x - min_x + 1) * cell_size + thickness * 2,
							(max_y - min_y + 1) * cell_size + thickness * 2)

	# Use NinePatchRect with panel texture for the border
	var panel_tex: Texture2D = InventoryTheme.get_panel_texture()
	if panel_tex:
		var nine := NinePatchRect.new()
		nine.texture = panel_tex
		nine.position = rect_pos
		nine.size = rect_size
		nine.modulate = color
		var m: int = 6
		nine.patch_margin_left = m
		nine.patch_margin_top = m
		nine.patch_margin_right = m
		nine.patch_margin_bottom = m
		nine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return nine
	else:
		# Fallback: simple ColorRect border
		var rect := ColorRect.new()
		rect.position = rect_pos
		rect.size = rect_size
		rect.color = color
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return rect


func _recompute_cell_size() -> void:
	if _grid_width_cells <= 0 or _grid_height_cells <= 0:
		cell_size = CELL_SIZE_MIN
		return
	var available: Vector2 = _get_available_space()
	var fit_w: int = int(available.x / _grid_width_cells)
	var fit_h: int = int(available.y / _grid_height_cells)
	cell_size = clampi(mini(fit_w, fit_h), CELL_SIZE_MIN, CELL_SIZE_MAX)


func _get_available_space() -> Vector2:
	## Walk up the parent tree to find the first ancestor with a settled size.
	var node: Control = get_parent() as Control
	while node:
		if node.size.x > 0.0 and node.size.y > 0.0:
			return node.size
		node = node.get_parent() as Control
	return get_viewport_rect().size * 0.7


func _deferred_resize() -> void:
	## Re-evaluate cell size after the layout pass has settled parent sizes.
	var old_size: int = cell_size
	_recompute_cell_size()
	var size_changed: bool = cell_size != old_size
	if not size_changed:
		# Still draw borders on first call even if size didn't change
		if _grid_inventory:
			var template: GridTemplate = _grid_inventory.grid_template
			var positions: Array[Vector2i] = []
			if template.layout_cells.is_empty():
				for y in range(template.height):
					for x in range(template.width):
						positions.append(Vector2i(x, y))
			else:
				positions = template.layout_cells.duplicate()
			_build_zone_outlines(template, positions)
		return
	# Reposition and resize all cells.
	for pos: Vector2i in _cells:
		var cell_node: Control = _cells[pos]
		cell_node.position = Vector2((pos.x - _grid_origin.x) * cell_size, (pos.y - _grid_origin.y) * cell_size)
		var sz := Vector2(cell_size, cell_size)
		cell_node.custom_minimum_size = sz
		cell_node.size = sz
	custom_minimum_size = Vector2(_grid_width_cells * cell_size, _grid_height_cells * cell_size)
	size = custom_minimum_size
	_update_item_visuals()
	# Draw borders after cells are at final positions
	if _grid_inventory:
		var template: GridTemplate = _grid_inventory.grid_template
		var positions: Array[Vector2i] = []
		if template.layout_cells.is_empty():
			for y in range(template.height):
				for x in range(template.width):
					positions.append(Vector2i(x, y))
		else:
			positions = template.layout_cells.duplicate()
		_build_zone_outlines(template, positions)


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

	var bbox_w: int = (max_pos.x - min_pos.x + 1) * cell_size
	var bbox_h: int = (max_pos.y - min_pos.y + 1) * cell_size

	# Wrap in a clipping container so the icon never overflows its cells
	var container: Control = Control.new()
	container.clip_contents = true
	container.position = Vector2((min_pos.x - _grid_origin.x) * cell_size, (min_pos.y - _grid_origin.y) * cell_size)
	container.size = Vector2(bbox_w, bbox_h)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create shape outline container (background + border — drawn BEHIND the item sprite)
	var shape_outline: Control = Control.new()
	shape_outline.position = Vector2.ZERO
	shape_outline.size = Vector2(bbox_w, bbox_h)
	shape_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(shape_outline)

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

	# Draw outer-only border for the item shape with solid rarity background
	var slot_colors: Array = Constants.RARITY_SLOT_COLORS.get(placed.item_data.rarity, [])
	var bg_color: Color = slot_colors[0] if slot_colors.size() >= 1 else Color(0.3, 0.3, 0.3)
	var border_color: Color = slot_colors[1] if slot_colors.size() >= 2 else Color(0.5, 0.5, 0.5)
	bg_color.a = 1.0
	border_color.a = 1.0
	for cell in cells:
		var cell_panel: PanelContainer = PanelContainer.new()
		cell_panel.position = Vector2((cell.x - min_pos.x) * cell_size, (cell.y - min_pos.y) * cell_size)
		cell_panel.custom_minimum_size = Vector2(cell_size, cell_size)
		cell_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Only draw border on edges not shared with another cell of the same item
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = bg_color
		style.border_color = border_color
		@warning_ignore("integer_division")
		var bw: int = maxi(1, cell_size / 24)
		style.border_width_left = bw if not cells.has(cell + Vector2i(-1, 0)) else 0
		style.border_width_right = bw if not cells.has(cell + Vector2i(1, 0)) else 0
		style.border_width_top = bw if not cells.has(cell + Vector2i(0, -1)) else 0
		style.border_width_bottom = bw if not cells.has(cell + Vector2i(0, 1)) else 0
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


@warning_ignore("shadowed_variable_base_class")
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
			for check_offset in shape_cells:
				if grid_pos + check_offset == cell:
					is_occupied_by_item = true
					break
			if not is_occupied_by_item:
				_cells[cell].set_state(_cells[cell].CellState.MODIFIER_REACH)
