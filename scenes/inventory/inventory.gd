extends Control
## Main inventory scene orchestrator.
## Manages drag-and-drop between grid and stash, character switching, tooltips.

enum DragState { IDLE, DRAGGING }

# --- Child references ---
@onready var _grid_panel: Control = $VBox/Content/GridSide/GridCentering/GridPanel
@onready var _stash_panel: PanelContainer = $VBox/Content/StashPanel
@onready var _character_tabs: HBoxContainer = $VBox/Content/GridSide/CharacterTabs
@onready var _item_tooltip: PanelContainer = $TooltipLayer/ItemTooltip
@onready var _drag_preview: Control = $DragLayer/DragPreview

# --- State ---
var _grid_inventories: Dictionary = {}  ## character_id -> GridInventory
var _undo_stacks: Dictionary = {}  ## character_id -> InventoryUndo
var _current_character_id: String = ""

var _drag_state: DragState = DragState.IDLE
var _dragged_item: ItemData = null
var _drag_source: String = ""  # "grid" or "stash"
var _drag_source_placed: GridInventory.PlacedItem = null
var _drag_source_pos: Vector2i = Vector2i.ZERO
var _drag_source_rotation: int = 0
var _drag_source_stash_index: int = -1
var _drag_rotation: int = 0


func _ready() -> void:
	# Use persistent grid inventories from Party
	if GameManager.party:
		_grid_inventories = GameManager.party.grid_inventories
		for character_id: String in GameManager.party.squad:
			if not _undo_stacks.has(character_id):
				_undo_stacks[character_id] = InventoryUndo.new()

		# Setup character tabs
		_character_tabs.setup(GameManager.party.squad, GameManager.party.roster)
		_character_tabs.character_selected.connect(_on_character_selected)

		# Setup stash
		_stash_panel.refresh(GameManager.party.stash)
		_stash_panel.item_clicked.connect(_on_stash_item_clicked)
		_stash_panel.item_hovered.connect(_on_stash_item_hovered)
		_stash_panel.item_exited.connect(_on_item_hover_exited)

	# Setup grid panel signals
	_grid_panel.cell_clicked.connect(_on_grid_cell_clicked)
	_grid_panel.cell_hovered.connect(_on_grid_cell_hovered)
	_grid_panel.cell_exited.connect(_on_item_hover_exited)

	# Select first squad member
	if GameManager.party and not GameManager.party.squad.is_empty():
		_on_character_selected(GameManager.party.squad[0])
		_character_tabs.select(GameManager.party.squad[0])

	# Hide tooltip and drag preview initially
	_item_tooltip.visible = false
	_drag_preview.visible = false

	# Wire top bar buttons
	$VBox/TopBar/BackButton.pressed.connect(_on_back)
	$VBox/TopBar/StatsButton.pressed.connect(_on_stats)
	DebugLogger.log_info("Inventory scene ready", "Inventory")


func _unhandled_input(event: InputEvent) -> void:
	if _drag_state == DragState.DRAGGING:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			_rotate_dragged_item()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("escape"):
			_cancel_drag()
			get_viewport().set_input_as_handled()
			return
		# Right-click to cancel drag
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_drag()
			get_viewport().set_input_as_handled()
			return
		# Left-click to place (when not over grid — the grid handles its own clicks)
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _stash_panel.is_mouse_over():
				_return_to_stash()
				get_viewport().set_input_as_handled()
				return
		return

	# Ctrl+Z for undo
	if event is InputEventKey and event.pressed and event.keycode == KEY_Z and event.ctrl_pressed:
		_perform_undo()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("escape") or event.is_action_pressed("open_inventory"):
		_on_back()


func _process(_delta: float) -> void:
	if _drag_state == DragState.DRAGGING:
		_update_drag_preview()


# === Character Switching ===

func _on_character_selected(character_id: String) -> void:
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()
	_current_character_id = character_id
	var inv: GridInventory = _grid_inventories.get(character_id)
	if inv:
		_grid_panel.setup(inv)
	_item_tooltip.hide_tooltip()
	DebugLogger.log_info("Switched to character: %s" % character_id, "Inventory")


# === Grid Interaction ===

func _on_grid_cell_clicked(grid_pos: Vector2i, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return

	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	if _drag_state == DragState.DRAGGING:
		# Try to place the dragged item
		_try_place_item(grid_pos)
	else:
		# Pick up item from grid
		var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
		if placed:
			_start_drag_from_grid(placed)


func _on_grid_cell_hovered(grid_pos: Vector2i) -> void:
	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	if _drag_state == DragState.DRAGGING:
		# Show placement preview
		_grid_panel.show_placement_preview(_dragged_item, grid_pos, _drag_rotation)
		var can_place: bool = inv.can_place(_dragged_item, grid_pos, _drag_rotation)
		_drag_preview.set_valid(can_place)
	else:
		# Show tooltip and modifier highlights for hovered item
		var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
		if placed:
			_grid_panel.highlight_modifier_connections(placed)
			_item_tooltip.show_for_item(placed.item_data, placed, inv, get_global_mouse_position())
		else:
			_grid_panel.clear_highlights()
			_item_tooltip.hide_tooltip()


# === Stash Interaction ===

func _on_stash_item_clicked(item: ItemData, index: int) -> void:
	if _drag_state == DragState.DRAGGING:
		# Drop current item to stash
		_return_to_stash()
	else:
		# Pick up from stash
		_start_drag_from_stash(item, index)


func _on_stash_item_hovered(item: ItemData, global_pos: Vector2) -> void:
	if _drag_state == DragState.IDLE:
		_item_tooltip.show_for_item(item, null, null, global_pos)


func _on_item_hover_exited() -> void:
	if _drag_state == DragState.IDLE:
		_item_tooltip.hide_tooltip()
		_grid_panel.clear_highlights()


# === Drag and Drop ===

func _start_drag_from_grid(placed: GridInventory.PlacedItem) -> void:
	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	_dragged_item = placed.item_data
	_drag_source = "grid"
	_drag_source_placed = placed
	_drag_source_pos = placed.grid_position
	_drag_source_rotation = placed.rotation
	_drag_rotation = placed.rotation
	_drag_state = DragState.DRAGGING

	# Remove from grid (will be restored on cancel)
	inv.remove_item(placed)
	_grid_panel.refresh()
	_item_tooltip.hide_tooltip()

	# Show drag preview
	_drag_preview.setup(_dragged_item, _drag_rotation)
	DebugLogger.log_info("Picked up %s from grid" % _dragged_item.display_name, "Inventory")


func _start_drag_from_stash(item: ItemData, index: int) -> void:
	_dragged_item = item
	_drag_source = "stash"
	_drag_source_stash_index = index
	_drag_rotation = 0
	_drag_state = DragState.DRAGGING

	# Remove from stash
	GameManager.party.stash.remove_at(index)
	_stash_panel.refresh(GameManager.party.stash)
	_item_tooltip.hide_tooltip()

	# Show drag preview
	_drag_preview.setup(_dragged_item, _drag_rotation)
	DebugLogger.log_info("Picked up %s from stash" % _dragged_item.display_name, "Inventory")


func _try_place_item(grid_pos: Vector2i) -> void:
	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	if not inv.can_place(_dragged_item, grid_pos, _drag_rotation):
		return

	var placed: GridInventory.PlacedItem = inv.place_item(_dragged_item, grid_pos, _drag_rotation)
	if not placed:
		return

	# Record undo
	var undo: InventoryUndo = _undo_stacks.get(_current_character_id)
	if undo:
		if _drag_source == "grid":
			undo.push_move(_dragged_item, _drag_source_pos, grid_pos, _drag_source_rotation, _drag_rotation)
		else:
			undo.push_place(_dragged_item, grid_pos, _drag_rotation)

	# Emit signals
	EventBus.item_placed.emit(_current_character_id, _dragged_item, grid_pos)
	EventBus.inventory_changed.emit(_current_character_id)

	_end_drag()
	_grid_panel.refresh()
	DebugLogger.log_info("Placed %s at (%d, %d)" % [placed.item_data.display_name, grid_pos.x, grid_pos.y], "Inventory")


func _return_to_stash() -> void:
	if not _dragged_item:
		return

	GameManager.party.add_to_stash(_dragged_item)
	_stash_panel.refresh(GameManager.party.stash)

	# Record undo if it came from grid
	if _drag_source == "grid":
		var undo: InventoryUndo = _undo_stacks.get(_current_character_id)
		if undo:
			undo.push_remove(_dragged_item, _drag_source_pos, _drag_source_rotation)
		EventBus.item_removed.emit(_current_character_id, _dragged_item, _drag_source_pos)
		EventBus.inventory_changed.emit(_current_character_id)

	EventBus.stash_changed.emit()
	var item_name: String = _dragged_item.display_name
	_end_drag()
	DebugLogger.log_info("Returned %s to stash" % item_name, "Inventory")


func _cancel_drag() -> void:
	if not _dragged_item:
		_end_drag()
		return

	# Restore item to original location
	if _drag_source == "grid":
		var inv: GridInventory = _grid_inventories.get(_current_character_id)
		if inv:
			inv.place_item(_dragged_item, _drag_source_pos, _drag_source_rotation)
			_grid_panel.refresh()
	elif _drag_source == "stash":
		GameManager.party.stash.insert(mini(_drag_source_stash_index, GameManager.party.stash.size()), _dragged_item)
		_stash_panel.refresh(GameManager.party.stash)

	_end_drag()
	DebugLogger.log_info("Cancelled drag", "Inventory")


func _rotate_dragged_item() -> void:
	if not _dragged_item:
		return
	_drag_rotation = (_drag_rotation + 1) % _dragged_item.shape.rotation_states
	_drag_preview.rotate_cw()
	EventBus.item_rotated.emit(_current_character_id, _dragged_item)


func _update_drag_preview() -> void:
	# Update stash highlight
	_stash_panel.highlight_drop_target(_stash_panel.is_mouse_over())


func _end_drag() -> void:
	_drag_state = DragState.IDLE
	_dragged_item = null
	_drag_source = ""
	_drag_source_placed = null
	_drag_source_stash_index = -1
	_drag_preview.hide_preview()
	_stash_panel.highlight_drop_target(false)
	_grid_panel.clear_placement_preview()


# === Undo ===

func _perform_undo() -> void:
	var undo: InventoryUndo = _undo_stacks.get(_current_character_id)
	if not undo or not undo.can_undo():
		return

	var action: InventoryUndo.UndoAction = undo.pop()
	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	match action.type:
		InventoryUndo.UndoAction.Type.PLACE:
			var placed: GridInventory.PlacedItem = _find_placed_item(inv, action.item_data, action.to_position)
			if placed:
				inv.remove_item(placed)
				GameManager.party.add_to_stash(action.item_data)
				_stash_panel.refresh(GameManager.party.stash)
		InventoryUndo.UndoAction.Type.REMOVE:
			var idx: int = GameManager.party.stash.find(action.item_data)
			if idx >= 0:
				GameManager.party.stash.remove_at(idx)
				inv.place_item(action.item_data, action.from_position, action.from_rotation)
				_stash_panel.refresh(GameManager.party.stash)
		InventoryUndo.UndoAction.Type.MOVE:
			var placed: GridInventory.PlacedItem = _find_placed_item(inv, action.item_data, action.to_position)
			if placed:
				inv.remove_item(placed)
				inv.place_item(action.item_data, action.from_position, action.from_rotation)

	_grid_panel.refresh()
	EventBus.inventory_changed.emit(_current_character_id)
	DebugLogger.log_info("Undo performed", "Inventory")


func _find_placed_item(inv: GridInventory, item_data: ItemData, pos: Vector2i) -> GridInventory.PlacedItem:
	for i in range(inv.get_all_placed_items().size()):
		var placed: GridInventory.PlacedItem = inv.get_all_placed_items()[i]
		if placed.item_data == item_data and placed.grid_position == pos:
			return placed
	return null


# === Navigation ===

func _on_back() -> void:
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()
		return
	SceneManager.pop_scene()


func _on_stats() -> void:
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()
	SceneManager.push_scene("res://scenes/character_stats/character_stats.tscn")
