extends Control
## Renders a character's inventory grid and handles mouse interaction.
## Supports hover feedback (grey out, glow, stars) and drag placement preview.

signal cell_clicked(grid_pos: Vector2i, button: int)
signal cell_pressed(grid_pos: Vector2i, button: int)
signal cell_released(grid_pos: Vector2i, button: int)
signal cell_hovered(grid_pos: Vector2i)
signal cell_exited()

const CELL_SIZE_MIN: int = Constants.GRID_CELL_SIZE
const CELL_SIZE_MAX: int = 45
const GridCellScene: PackedScene = preload("res://scenes/inventory/ui/grid_cell.tscn")

var cell_size: int = CELL_SIZE_MIN
var last_failure_reason: String = ""

var _grid_inventory: GridInventory
var _cells: Dictionary = {}          ## Vector2i -> GridCell
var _item_visuals: Dictionary = {}   ## PlacedItem -> Control (container)
var _star_overlays: Array = []
var _glow_overlays: Array = []  ## PanelContainers on overlay layer for visible glow
var _hover_reach_cells: Array[Vector2i] = []
var _preview_modified_cells: Array[Vector2i] = []
var _preview_glowed_cells: Array[Vector2i] = []
var _last_hovered_cell: Vector2i = Vector2i(-1, -1)
var _last_purchasable_cell: Vector2i = Vector2i(-1, -1)
var _grid_origin: Vector2i = Vector2i.ZERO
var _grid_width_cells: int = 0
var _grid_height_cells: int = 0

@onready var _cells_layer: Control = $CellsLayer
@onready var _items_layer: Control = $ItemsLayer
@onready var _overlay_layer: Control = $OverlayLayer


func _ready() -> void:
	mouse_exited.connect(_on_mouse_exited)


# ---------------------------------------------------------------------------
# Setup & Refresh
# ---------------------------------------------------------------------------

func setup(grid_inventory: GridInventory) -> void:
	_grid_inventory = grid_inventory
	_build_cells()
	refresh()


func refresh() -> void:
	if not _grid_inventory:
		return
	_last_purchasable_cell = Vector2i(-1, -1)
	_last_hovered_cell = Vector2i(-1, -1)
	# Reset all cell states
	for pos: Vector2i in _cells:
		var cell_node: Control = _cells[pos]
		if _grid_inventory.grid_template.is_cell_active(pos):
			cell_node.set_state(cell_node.CellState.EMPTY)
		else:
			cell_node.set_state(cell_node.CellState.INACTIVE)
	# Mark occupied cells with rarity tint
	var slot_colors_cache: Dictionary = {}
	for i in range(_grid_inventory.get_all_placed_items().size()):
		var placed: GridInventory.PlacedItem = _grid_inventory.get_all_placed_items()[i]
		var slot_colors: Array = Constants.RARITY_SLOT_COLORS.get(placed.item_data.rarity, [])
		var bg_color: Color = slot_colors[0] if slot_colors.size() >= 1 else Color(0.5, 0.5, 0.5)
		for cell in placed.get_occupied_cells():
			if _cells.has(cell):
				_cells[cell].set_state(_cells[cell].CellState.OCCUPIED)
				_cells[cell].set_rarity_tint(bg_color)
	_update_item_visuals()


func get_grid_inventory() -> GridInventory:
	return _grid_inventory


# ---------------------------------------------------------------------------
# Placement Preview (used during drag)
# ---------------------------------------------------------------------------

func show_placement_preview(item_data: ItemData, grid_pos: Vector2i, rotation: int) -> void:
	clear_placement_preview()
	if not _grid_inventory:
		return
	var shape_cells: Array[Vector2i] = item_data.shape.get_rotated_cells(rotation)
	var can_place: bool = _grid_inventory.can_place(item_data, grid_pos, rotation)

	# Detect displacement possibility
	var is_swap: bool = false
	if not can_place:
		var blockers: Array = _grid_inventory.get_blocking_items(item_data, grid_pos, rotation)
		if blockers.size() >= 1:
			# Test if removing all blockers would allow placement
			is_swap = true
			last_failure_reason = ""
		else:
			last_failure_reason = _grid_inventory.get_placement_failure_reason(item_data, grid_pos, rotation)
	else:
		last_failure_reason = ""

	# Show modifier reach if this is a modifier
	if item_data.item_type == Enums.ItemType.MODIFIER:
		_show_modifier_reach_preview(shape_cells, grid_pos, item_data, rotation)

	# Check modifier connections at preview position
	var affected_tools: Array = []
	var affecting_modifiers: Array = []
	if can_place or is_swap:
		var temp_placed: GridInventory.PlacedItem = GridInventory.PlacedItem.new()
		temp_placed.item_data = item_data
		temp_placed.grid_position = grid_pos
		temp_placed.rotation = rotation
		if item_data.item_type == Enums.ItemType.MODIFIER:
			affected_tools = _grid_inventory.get_tools_affected_by(temp_placed)
		if item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
			affecting_modifiers = _grid_inventory.get_modifiers_affecting(temp_placed)

	# Color cells based on placement validity
	for cell_offset in shape_cells:
		var target: Vector2i = grid_pos + cell_offset
		if _cells.has(target):
			if can_place:
				_cells[target].set_state(_cells[target].CellState.VALID_DROP)
			elif is_swap:
				_cells[target].set_state(_cells[target].CellState.SWAP_DROP)
			else:
				_cells[target].set_state(_cells[target].CellState.INVALID_DROP)
			_preview_modified_cells.append(target)

	# Dragging a MODIFIER: stars on reach cells (no glow — glow is for hover only)
	if item_data.item_type == Enums.ItemType.MODIFIER and (can_place or is_swap):
		var mod_shape: Array[Vector2i] = item_data.shape.get_rotated_cells(rotation)
		var reach_pattern: Array[Vector2i] = item_data.get_reach_cells(rotation)

		# Collect all reach cells
		var all_reach_cells: Array[Vector2i] = []
		var mod_placed_cells: Array[Vector2i] = []
		for sc in mod_shape:
			mod_placed_cells.append(grid_pos + sc)
		for mc in mod_placed_cells:
			for offset in reach_pattern:
				var target: Vector2i = mc + offset
				if _cells.has(target) and not mod_placed_cells.has(target) and not all_reach_cells.has(target):
					all_reach_cells.append(target)

		# Find which reach cells hit actual weapons (ACTIVE_TOOL only, not armor)
		var reached_weapon_map: Dictionary = {}  # cell → true (yellow) / false (white)
		for tool_item in affected_tools:
			if tool_item.item_data.item_type != Enums.ItemType.ACTIVE_TOOL:
				continue
			var tool_cells: Array[Vector2i] = tool_item.get_occupied_cells()
			var first_hit: bool = true
			for rc in all_reach_cells:
				if tool_cells.has(rc):
					if first_hit:
						reached_weapon_map[rc] = true
						first_hit = false
					elif not reached_weapon_map.has(rc):
						reached_weapon_map[rc] = false

		# Stars on all reach cells
		for rc in all_reach_cells:
			if not _preview_modified_cells.has(rc):
				_cells[rc].set_state(_cells[rc].CellState.MODIFIER_REACH)
				_preview_modified_cells.append(rc)
			if reached_weapon_map.has(rc):
				if reached_weapon_map[rc]:
					_add_star_at_cell(rc, Color.YELLOW)
				else:
					_add_star_at_cell(rc, Color(1, 1, 1, 0.4))
			else:
				_add_star_at_cell(rc, Color(1, 1, 1, 0.15))

	# Dragging a WEAPON (ACTIVE_TOOL only): glow on modifier ITEMS that would affect it
	if not affecting_modifiers.is_empty() and (can_place or is_swap) and item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
		for mod in affecting_modifiers:
			_add_glow_for_item(mod.get_occupied_cells())


func clear_placement_preview() -> void:
	# Restore only cells we modified (no full refresh)
	for pos in _preview_modified_cells:
		_restore_cell_state(pos)
	_preview_modified_cells.clear()
	_preview_glowed_cells.clear()
	_clear_glow_overlays()
	_clear_star_overlays()
	_clear_hover_reach_cells()
	last_failure_reason = ""


# ---------------------------------------------------------------------------
# Hover Feedback
# ---------------------------------------------------------------------------

func show_hover_feedback(placed: GridInventory.PlacedItem) -> void:
	## Unified hover: grey other items, show glow/stars for modifier connections.
	clear_hover_feedback()
	if not _grid_inventory or not placed:
		return

	# Build set of connected items (stay bright)
	var bright_items: Dictionary = {placed: true}
	var modifiers: Array = []
	var tools: Array = []

	if placed.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
		modifiers = _grid_inventory.get_modifiers_affecting(placed)
		for mod in modifiers:
			bright_items[mod] = true
	if placed.item_data.item_type == Enums.ItemType.MODIFIER:
		tools = _grid_inventory.get_tools_affected_by(placed)
		for tool_item in tools:
			if tool_item.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
				bright_items[tool_item] = true



	# Grey out other items (never grey empty cells)
	for placed_key in _item_visuals:
		var container: Control = _item_visuals[placed_key]
		if bright_items.has(placed_key):
			container.modulate = Color.WHITE
		else:
			container.modulate = Color(0.4, 0.4, 0.4, 0.55)

	# Weapon (ACTIVE_TOOL) hovered: glow on affecting modifiers
	if placed.item_data.item_type == Enums.ItemType.ACTIVE_TOOL and not modifiers.is_empty():
		for mod in modifiers:
			_add_glow_for_item(mod.get_occupied_cells())

	# Modifier hovered: show reach area with stars, yellow on weapon cells reached
	if placed.item_data.item_type == Enums.ItemType.MODIFIER:
		var placed_cells: Array[Vector2i] = placed.get_occupied_cells()
		var reach_pattern: Array[Vector2i] = placed.item_data.get_reach_cells(placed.rotation)

		# Collect all reach cells and which weapon cells are hit
		var all_reach_cells: Array[Vector2i] = []
		var reached_weapon_cells: Dictionary = {}  # cell → true (yellow star targets)
		for mc in placed_cells:
			for offset in reach_pattern:
				var target: Vector2i = mc + offset
				if _cells.has(target) and not placed_cells.has(target):
					if not all_reach_cells.has(target):
						all_reach_cells.append(target)

		# Find which reach cells hit actual weapons (ACTIVE_TOOL only)
		for tool_item in tools:
			if tool_item.item_data.item_type != Enums.ItemType.ACTIVE_TOOL:
				continue
			var tool_cells: Array[Vector2i] = tool_item.get_occupied_cells()
			var first_hit: bool = true
			for rc in all_reach_cells:
				if tool_cells.has(rc):
					if first_hit:
						reached_weapon_cells[rc] = true  # yellow
						first_hit = false
					else:
						if not reached_weapon_cells.has(rc):
							reached_weapon_cells[rc] = false  # white

		# Show reach area + stars
		for rc in all_reach_cells:
			_cells[rc].set_state(_cells[rc].CellState.MODIFIER_REACH)
			_hover_reach_cells.append(rc)
			if reached_weapon_cells.has(rc):
				if reached_weapon_cells[rc]:
					_add_star_at_cell(rc, Color.YELLOW)
				else:
					_add_star_at_cell(rc, Color(1, 1, 1, 0.4))
			else:
				_add_star_at_cell(rc, Color(1, 1, 1, 0.15))


func clear_hover_feedback() -> void:
	# Restore item visuals
	for placed_key in _item_visuals:
		_item_visuals[placed_key].modulate = Color.WHITE
	# Clear glow and reach cells
	for pos in _hover_reach_cells:
		if _cells.has(pos):
			_restore_cell_state(pos)
	_hover_reach_cells.clear()
	_clear_glow_overlays()
	_clear_star_overlays()


## Legacy methods — delegate to new system for backward compatibility
func highlight_modifier_connections(placed: GridInventory.PlacedItem) -> void:
	show_hover_feedback(placed)

func highlight_item_connections(placed: GridInventory.PlacedItem) -> void:
	show_hover_feedback(placed)

func clear_highlights() -> void:
	clear_hover_feedback()

func clear_item_highlights() -> void:
	clear_hover_feedback()

func set_items_greyed_out(greyed: bool) -> void:
	_items_layer.modulate = Color(0.4, 0.4, 0.4, 0.55) if greyed else Color.WHITE


# ---------------------------------------------------------------------------
# Drag Feedback (new — used during drag-over-grid)
# ---------------------------------------------------------------------------

func show_drag_feedback(item_data: ItemData, grid_pos: Vector2i, rotation: int) -> void:
	show_placement_preview(item_data, grid_pos, rotation)

func clear_drag_feedback() -> void:
	clear_placement_preview()


# ---------------------------------------------------------------------------
# Upgrade & Ingredient Highlights
# ---------------------------------------------------------------------------

func highlight_upgradeable_items(dragged_item: ItemData) -> void:
	if not _grid_inventory or not dragged_item:
		return
	for placed in _grid_inventory.get_all_placed_items():
		if ItemUpgradeSystem.can_upgrade(dragged_item, placed.item_data):
			for cell in placed.get_occupied_cells():
				if _cells.has(cell):
					_cells[cell].set_state(_cells[cell].CellState.UPGRADEABLE)


func clear_upgradeable_highlights() -> void:
	if not _grid_inventory:
		return
	for placed in _grid_inventory.get_all_placed_items():
		for cell in placed.get_occupied_cells():
			if _cells.has(cell) and _cells[cell].cell_state == _cells[cell].CellState.UPGRADEABLE:
				_cells[cell].set_state(_cells[cell].CellState.OCCUPIED)
				var slot_colors: Array = Constants.RARITY_SLOT_COLORS.get(placed.item_data.rarity, [])
				if slot_colors.size() >= 1:
					_cells[cell].set_rarity_tint(slot_colors[0])


func highlight_matching_ingredient(ingredient: CraftingIngredient) -> void:
	if not _grid_inventory or not ingredient:
		return
	for placed in _grid_inventory.get_all_placed_items():
		if CraftingSystem.item_matches(placed.item_data, ingredient):
			for cell in placed.get_occupied_cells():
				if _cells.has(cell):
					_cells[cell].set_state(_cells[cell].CellState.INGREDIENT_MATCH)


func clear_ingredient_highlights() -> void:
	if not _grid_inventory:
		return
	for placed in _grid_inventory.get_all_placed_items():
		for cell in placed.get_occupied_cells():
			if _cells.has(cell) and _cells[cell].cell_state == _cells[cell].CellState.INGREDIENT_MATCH:
				_cells[cell].set_state(_cells[cell].CellState.OCCUPIED)
				var slot_colors: Array = Constants.RARITY_SLOT_COLORS.get(placed.item_data.rarity, [])
				if slot_colors.size() >= 1:
					_cells[cell].set_rarity_tint(slot_colors[0])


func set_cell_purchasable(cell: Vector2i) -> void:
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


# ---------------------------------------------------------------------------
# Coordinate Conversion
# ---------------------------------------------------------------------------

func world_to_grid(screen_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = screen_pos - _cells_layer.global_position
	var gx: int = floori(local_pos.x / cell_size) + _grid_origin.x
	var gy: int = floori(local_pos.y / cell_size) + _grid_origin.y
	return Vector2i(gx, gy)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

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

	if event is InputEventMouseButton:
		var grid_pos: Vector2i = world_to_grid(event.global_position)
		if _cells.has(grid_pos):
			if event.pressed:
				cell_pressed.emit(grid_pos, event.button_index)
				cell_clicked.emit(grid_pos, event.button_index)
			else:
				cell_released.emit(grid_pos, event.button_index)


func _on_mouse_exited() -> void:
	if _last_hovered_cell != Vector2i(-1, -1):
		_last_hovered_cell = Vector2i(-1, -1)
		cell_exited.emit()


# ---------------------------------------------------------------------------
# Internal — Cell Building
# ---------------------------------------------------------------------------

func _build_cells() -> void:
	for child in _cells_layer.get_children():
		child.queue_free()
	_cells.clear()
	if not _grid_inventory:
		return

	var template: GridTemplate = _grid_inventory.grid_template

	# Determine positions to render (layout cells or full bounding box)
	var positions: Array[Vector2i] = []
	if template.layout_cells.is_empty():
		for y in range(template.height):
			for x in range(template.width):
				positions.append(Vector2i(x, y))
	else:
		positions = template.layout_cells.duplicate()

	# Compute origin
	if not positions.is_empty():
		var min_x: int = positions[0].x
		var min_y: int = positions[0].y
		for pos in positions:
			min_x = mini(min_x, pos.x)
			min_y = mini(min_y, pos.y)
		_grid_origin = Vector2i(min_x, min_y)
	else:
		_grid_origin = Vector2i.ZERO

	# Compute extent
	var max_x: int = _grid_origin.x
	var max_y: int = _grid_origin.y
	for pos in positions:
		max_x = maxi(max_x, pos.x)
		max_y = maxi(max_y, pos.y)
	_grid_width_cells = max_x - _grid_origin.x + 1
	_grid_height_cells = max_y - _grid_origin.y + 1

	_recompute_cell_size()

	# Create cell nodes
	for pos in positions:
		var cell_node: Control = GridCellScene.instantiate()
		cell_node.position = Vector2((pos.x - _grid_origin.x) * cell_size, (pos.y - _grid_origin.y) * cell_size)
		cell_node.setup(pos)
		if not template.is_cell_active(pos):
			cell_node.set_state(cell_node.CellState.INACTIVE)
		_cells_layer.add_child(cell_node)
		var sz := Vector2(cell_size, cell_size)
		cell_node.custom_minimum_size = sz
		cell_node.size = sz
		_cells[pos] = cell_node

	custom_minimum_size = Vector2(_grid_width_cells * cell_size, _grid_height_cells * cell_size)
	size = custom_minimum_size
	call_deferred("_deferred_resize")


func _recompute_cell_size() -> void:
	if _grid_width_cells <= 0 or _grid_height_cells <= 0:
		cell_size = CELL_SIZE_MIN
		return
	var available: Vector2 = _get_available_space()
	@warning_ignore("integer_division")
	var fit_w: int = int(available.x) / _grid_width_cells
	@warning_ignore("integer_division")
	var fit_h: int = int(available.y) / _grid_height_cells
	cell_size = clampi(mini(fit_w, fit_h), CELL_SIZE_MIN, CELL_SIZE_MAX)


func _get_available_space() -> Vector2:
	var node: Control = get_parent() as Control
	while node:
		if node.size.x > 0.0 and node.size.y > 0.0:
			return node.size
		node = node.get_parent() as Control
	return get_viewport_rect().size * 0.7


func _deferred_resize() -> void:
	var old_size: int = cell_size
	_recompute_cell_size()
	if cell_size != old_size:
		for pos: Vector2i in _cells:
			var cell_node: Control = _cells[pos]
			cell_node.position = Vector2((pos.x - _grid_origin.x) * cell_size, (pos.y - _grid_origin.y) * cell_size)
			var sz := Vector2(cell_size, cell_size)
			cell_node.custom_minimum_size = sz
			cell_node.size = sz
		custom_minimum_size = Vector2(_grid_width_cells * cell_size, _grid_height_cells * cell_size)
		size = custom_minimum_size
	_update_item_visuals()
	# Build border sprites after cells are at final positions
	if _grid_inventory:
		var template: GridTemplate = _grid_inventory.grid_template
		var positions: Array[Vector2i] = []
		if template.layout_cells.is_empty():
			for y in range(template.height):
				for x in range(template.width):
					positions.append(Vector2i(x, y))
		else:
			positions = template.layout_cells.duplicate()
		_build_zone_borders(template, positions)


# ---------------------------------------------------------------------------
# Internal — Item Visuals
# ---------------------------------------------------------------------------

func _update_item_visuals() -> void:
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

	# Bounding box
	var min_pos: Vector2i = cells[0]
	var max_pos: Vector2i = cells[0]
	for cell in cells:
		min_pos.x = mini(min_pos.x, cell.x)
		min_pos.y = mini(min_pos.y, cell.y)
		max_pos.x = maxi(max_pos.x, cell.x)
		max_pos.y = maxi(max_pos.y, cell.y)
	var bbox_w: int = (max_pos.x - min_pos.x + 1) * cell_size
	var bbox_h: int = (max_pos.y - min_pos.y + 1) * cell_size

	# Container
	var container: Control = Control.new()
	container.clip_contents = true
	container.position = Vector2((min_pos.x - _grid_origin.x) * cell_size, (min_pos.y - _grid_origin.y) * cell_size)
	container.size = Vector2(bbox_w, bbox_h)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background + border per cell (ColorRect — responds to modulate)
	var slot_colors: Array = Constants.RARITY_SLOT_COLORS.get(placed.item_data.rarity, [])
	var bg_color: Color = slot_colors[0] if slot_colors.size() >= 1 else Color(0.3, 0.3, 0.3)
	var border_color: Color = slot_colors[1] if slot_colors.size() >= 2 else Color(0.5, 0.5, 0.5)
	bg_color.a = 1.0
	border_color.a = 1.0
	@warning_ignore("integer_division")
	var bw: int = maxi(1, cell_size / 24)

	var shape_outline: Control = Control.new()
	shape_outline.position = Vector2.ZERO
	shape_outline.size = Vector2(bbox_w, bbox_h)
	shape_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(shape_outline)

	for cell in cells:
		var cx: float = float((cell.x - min_pos.x) * cell_size)
		var cy: float = float((cell.y - min_pos.y) * cell_size)
		var cs: float = float(cell_size)
		var border_rect := ColorRect.new()
		border_rect.position = Vector2(cx, cy)
		border_rect.size = Vector2(cs, cs)
		border_rect.color = border_color
		border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shape_outline.add_child(border_rect)
		var left: float = float(bw) if not cells.has(cell + Vector2i(-1, 0)) else 0.0
		var right: float = float(bw) if not cells.has(cell + Vector2i(1, 0)) else 0.0
		var top_edge: float = float(bw) if not cells.has(cell + Vector2i(0, -1)) else 0.0
		var bottom: float = float(bw) if not cells.has(cell + Vector2i(0, 1)) else 0.0
		var bg_rect := ColorRect.new()
		bg_rect.position = Vector2(cx + left, cy + top_edge)
		bg_rect.size = Vector2(cs - left - right, cs - top_edge - bottom)
		bg_rect.color = bg_color
		bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shape_outline.add_child(bg_rect)

	# Item icon
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

	_items_layer.add_child(container)
	_item_visuals[placed] = container


# ---------------------------------------------------------------------------
# Internal — Zone Borders
# ---------------------------------------------------------------------------

func _build_zone_borders(template: GridTemplate, all_positions: Array[Vector2i]) -> void:
	for child in _cells_layer.get_children():
		if child.name.begins_with("BorderPiece"):
			child.queue_free()

	var active_set: Dictionary = {}
	var layout_set: Dictionary = {}
	for pos in all_positions:
		layout_set[pos] = true
		if template.is_cell_active(pos):
			active_set[pos] = true

	# Outer border (all layout cells)
	_place_border_sprites(layout_set, Color(0.5, 0.3, 0.2, 0.9), "BorderPieceOuter")
	# Inner border (active cells)
	_place_border_sprites(active_set, Color(0.9, 0.85, 0.7, 1.0), "BorderPieceInner")


func _place_border_sprites(cell_set: Dictionary, tint: Color, prefix: String) -> void:
	var edge_v_tex: Texture2D = InventoryTheme.get_edge_v_texture()
	var edge_h_tex: Texture2D = InventoryTheme.get_edge_h_texture()
	var corner_tex: Texture2D = InventoryTheme.get_corner_texture()
	if not edge_v_tex or not edge_h_tex:
		return

	var cs: int = cell_size
	var border_w: float = 4.0
	var idx: int = 0

	for pos_variant in cell_set:
		var pos: Vector2i = pos_variant as Vector2i
		var px: float = float((pos.x - _grid_origin.x) * cs)
		var py: float = float((pos.y - _grid_origin.y) * cs)

		if not cell_set.has(Vector2i(pos.x, pos.y - 1)):
			_add_border_piece(edge_h_tex, Vector2(px, py - border_w), Vector2(cs, border_w), tint, prefix, idx)
			idx += 1
		if not cell_set.has(Vector2i(pos.x, pos.y + 1)):
			_add_border_piece(edge_h_tex, Vector2(px, py + cs), Vector2(cs, border_w), tint, prefix, idx)
			idx += 1
		if not cell_set.has(Vector2i(pos.x - 1, pos.y)):
			_add_border_piece(edge_v_tex, Vector2(px - border_w, py), Vector2(border_w, cs), tint, prefix, idx)
			idx += 1
		if not cell_set.has(Vector2i(pos.x + 1, pos.y)):
			_add_border_piece(edge_v_tex, Vector2(px + cs, py), Vector2(border_w, cs), tint, prefix, idx)
			idx += 1

		if corner_tex:
			var has_top: bool = not cell_set.has(Vector2i(pos.x, pos.y - 1))
			var has_bottom: bool = not cell_set.has(Vector2i(pos.x, pos.y + 1))
			var has_left: bool = not cell_set.has(Vector2i(pos.x - 1, pos.y))
			var has_right: bool = not cell_set.has(Vector2i(pos.x + 1, pos.y))
			if has_top and has_left:
				_add_border_piece(corner_tex, Vector2(px - border_w, py - border_w), Vector2(border_w, border_w), tint, prefix, idx)
				idx += 1
			if has_top and has_right:
				_add_border_piece(corner_tex, Vector2(px + cs, py - border_w), Vector2(border_w, border_w), tint, prefix, idx)
				idx += 1
			if has_bottom and has_left:
				_add_border_piece(corner_tex, Vector2(px - border_w, py + cs), Vector2(border_w, border_w), tint, prefix, idx)
				idx += 1
			if has_bottom and has_right:
				_add_border_piece(corner_tex, Vector2(px + cs, py + cs), Vector2(border_w, border_w), tint, prefix, idx)
				idx += 1


func _add_border_piece(tex: Texture2D, pos: Vector2, sz: Vector2, tint: Color, prefix: String, idx: int) -> void:
	var piece := TextureRect.new()
	piece.texture = tex
	piece.position = pos
	piece.size = sz
	piece.stretch_mode = TextureRect.STRETCH_TILE
	piece.modulate = tint
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piece.name = "%s_%d" % [prefix, idx]
	_cells_layer.add_child(piece)
	_cells_layer.move_child(piece, 0)


# ---------------------------------------------------------------------------
# Internal — Stars & Reach
# ---------------------------------------------------------------------------

func _add_glow_for_item(item_cells: Array[Vector2i]) -> void:
	## Creates an animated glow border following the exact shape of an item on the overlay layer.
	## Draws border segments only on outer edges (where no neighbor cell exists).
	if item_cells.is_empty():
		return

	var cell_set: Dictionary = {}
	for c in item_cells:
		cell_set[c] = true

	var cs: int = cell_size
	var bw: float = 3.0
	var container := Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(container)
	_glow_overlays.append(container)

	# Shared animated color — all segments reference the same ColorRect array
	var segments: Array[ColorRect] = []
	var color_a := Color(1.0, 0.85, 0.2, 1.0)

	for pos in item_cells:
		var px: float = float((pos.x - _grid_origin.x) * cs)
		var py: float = float((pos.y - _grid_origin.y) * cs)

		# Top edge
		if not cell_set.has(Vector2i(pos.x, pos.y - 1)):
			var seg := ColorRect.new()
			seg.position = Vector2(px, py - bw)
			seg.size = Vector2(cs, bw)
			seg.color = color_a
			seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(seg)
			segments.append(seg)
		# Bottom edge
		if not cell_set.has(Vector2i(pos.x, pos.y + 1)):
			var seg := ColorRect.new()
			seg.position = Vector2(px, py + cs)
			seg.size = Vector2(cs, bw)
			seg.color = color_a
			seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(seg)
			segments.append(seg)
		# Left edge
		if not cell_set.has(Vector2i(pos.x - 1, pos.y)):
			var seg := ColorRect.new()
			seg.position = Vector2(px - bw, py)
			seg.size = Vector2(bw, cs)
			seg.color = color_a
			seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(seg)
			segments.append(seg)
		# Right edge
		if not cell_set.has(Vector2i(pos.x + 1, pos.y)):
			var seg := ColorRect.new()
			seg.position = Vector2(px + cs, py)
			seg.size = Vector2(bw, cs)
			seg.color = color_a
			seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(seg)
			segments.append(seg)

	# Animate all segments together
	if not segments.is_empty():
		var tween := container.create_tween().set_loops()
		tween.tween_callback(func() -> void:
			for seg in segments:
				seg.color = Color(1.0, 0.85, 0.2, 1.0)
		)
		tween.tween_interval(0.5)
		tween.tween_callback(func() -> void:
			for seg in segments:
				seg.color = Color(1.0, 0.55, 0.0, 1.0)
		)
		tween.tween_interval(0.5)


func _clear_glow_overlays() -> void:
	for glow in _glow_overlays:
		if is_instance_valid(glow):
			glow.queue_free()
	_glow_overlays.clear()


func _add_star_at_cell(cell_pos: Vector2i, color: Color) -> void:
	if not _cells.has(cell_pos):
		return
	var label := Label.new()
	label.text = "\u2605"
	@warning_ignore("integer_division")
	label.add_theme_font_size_override("font_size", maxi(cell_size / 2, 10))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2((cell_pos.x - _grid_origin.x) * cell_size, (cell_pos.y - _grid_origin.y) * cell_size)
	label.size = Vector2(cell_size, cell_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(label)
	_star_overlays.append(label)


func _clear_star_overlays() -> void:
	for star in _star_overlays:
		if is_instance_valid(star):
			star.queue_free()
	_star_overlays.clear()


func _clear_hover_reach_cells() -> void:
	for cell_pos in _hover_reach_cells:
		if _cells.has(cell_pos):
			_restore_cell_state(cell_pos)
	_hover_reach_cells.clear()


func _show_modifier_reach_preview(shape_cells: Array[Vector2i], grid_pos: Vector2i, item_data: ItemData, rotation: int = 0) -> void:
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
			var is_part_of_shape: bool = false
			for so in shape_cells:
				if grid_pos + so == cell:
					is_part_of_shape = true
					break
			if not is_part_of_shape:
				_cells[cell].set_state(_cells[cell].CellState.MODIFIER_REACH)
				_preview_modified_cells.append(cell)


func _pick_best_reaching_cell(modifier: GridInventory.PlacedItem, target_cells: Array[Vector2i]) -> Vector2i:
	## Returns the modifier's occupied cell closest to the target cells.
	var mod_cells: Array[Vector2i] = modifier.get_occupied_cells()
	var reach: int = modifier.item_data.modifier_reach
	var reach_pattern: Array[Vector2i] = modifier.item_data.get_reach_cells(modifier.rotation)
	var best: Vector2i = Vector2i(-999, -999)
	var best_dist: float = INF
	for mc in mod_cells:
		for offset in reach_pattern:
			var reached: Vector2i = mc + offset
			if target_cells.has(reached):
				var dist: float = float(mc.x * mc.x + mc.y * mc.y)
				if dist < best_dist:
					best_dist = dist
					best = mc
	return best


func _restore_cell_state(pos: Vector2i) -> void:
	## Restores a cell to its correct state based on the data model.
	if not _cells.has(pos) or not _grid_inventory:
		return
	var cell_node: Control = _cells[pos]
	if not _grid_inventory.grid_template.is_cell_active(pos):
		cell_node.set_state(cell_node.CellState.INACTIVE)
		return
	var placed: GridInventory.PlacedItem = _grid_inventory.get_item_at(pos)
	if placed:
		cell_node.set_state(cell_node.CellState.OCCUPIED)
		var slot_colors: Array = Constants.RARITY_SLOT_COLORS.get(placed.item_data.rarity, [])
		if slot_colors.size() >= 1:
			cell_node.set_rarity_tint(slot_colors[0])
	else:
		cell_node.set_state(cell_node.CellState.EMPTY)
