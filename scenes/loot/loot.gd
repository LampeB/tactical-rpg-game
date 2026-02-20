extends Control
## Reward/loot screen. Lets the player drag items from a loot pool into
## squad members' grid inventories. Used after battle victories and chest looting.
## Remaining items are sent to the party stash on continue.

enum DragState { IDLE, DRAGGING }

# --- Child references ---
@onready var _title: Label = $VBox/TopBar/Title
@onready var _gold_label: Label = $VBox/TopBar/GoldLabel
@onready var _loot_pool: PanelContainer = $VBox/Content/LootPool
@onready var _grid_panel: Control = $VBox/Content/GridSide/GridCentering/GridPanel
@onready var _character_tabs: HBoxContainer = $VBox/Content/GridSide/CharacterTabs
@onready var _item_tooltip: PanelContainer = $TooltipLayer/ItemTooltip
@onready var _drag_preview: Control = $DragLayer/DragPreview
@onready var _loot_count_label: Label = $VBox/BottomBar/LootCountLabel
@onready var _send_to_stash_btn: Button = $VBox/BottomBar/SendToStashButton
@onready var _continue_btn: Button = $VBox/BottomBar/ContinueButton

# --- State ---
var _loot_items: Array = []  ## Local pool of items available to pick up
var _grid_inventories: Dictionary = {}  ## character_id -> GridInventory
var _current_character_id: String = ""

var _drag_state: DragState = DragState.IDLE
var _dragged_item: ItemData = null
var _drag_source: String = ""  # "loot" or "grid"
var _drag_source_placed: GridInventory.PlacedItem = null
var _drag_source_pos: Vector2i = Vector2i.ZERO
var _drag_source_rotation: int = 0
var _drag_source_loot_index: int = -1
var _drag_rotation: int = 0


func _ready() -> void:
	# Wire buttons
	_continue_btn.pressed.connect(_on_continue)
	_send_to_stash_btn.pressed.connect(_on_send_all_to_stash)

	# Use persistent grid inventories from Party
	if GameManager.party:
		_grid_inventories = GameManager.party.grid_inventories

		_character_tabs.setup(GameManager.party.squad, GameManager.party.roster)
		_character_tabs.character_selected.connect(_on_character_selected)

	# Configure loot pool label (reuses StashPanel component)
	_loot_pool.set_label_prefix("Loot", false)
	_loot_pool.item_clicked.connect(_on_loot_item_clicked)
	_loot_pool.item_hovered.connect(_on_loot_item_hovered)
	_loot_pool.item_exited.connect(_on_item_hover_exited)

	# Wire grid panel signals
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

	_refresh_loot_pool()
	_update_loot_count()
	DebugLogger.log_info("Loot scene ready with %d items" % _loot_items.size(), "Loot")


func receive_data(data: Dictionary) -> void:
	if data.has("loot"):
		_loot_items = data["loot"].duplicate()

	# Title based on source
	var source: String = data.get("source", "battle")
	if source == "battle":
		_title.text = "Victory!"
	elif source == "chest":
		_title.text = "Chest Loot"
	else:
		_title.text = "Loot"

	# Gold display
	var gold: int = data.get("gold", 0)
	if gold > 0:
		_gold_label.text = "+%d Gold" % gold
	else:
		_gold_label.text = ""

	# Refresh UI with received loot (receive_data called after _ready)
	_refresh_loot_pool()
	_update_loot_count()
	DebugLogger.log_info("Received %d loot items" % _loot_items.size(), "Loot")


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
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_drag()
			get_viewport().set_input_as_handled()
			return
		# Left-click over loot pool to return item
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _loot_pool.is_mouse_over():
				_return_to_loot_pool()
				get_viewport().set_input_as_handled()
				return
		return


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
	DebugLogger.log_info("Switched to character: %s" % character_id, "Loot")


# === Loot Pool Interaction ===

func _on_loot_item_clicked(item: ItemData, index: int) -> void:
	if _drag_state == DragState.DRAGGING:
		_return_to_loot_pool()
	else:
		_start_drag_from_loot(item, index)


func _on_loot_item_hovered(item: ItemData, global_pos: Vector2) -> void:
	if _drag_state == DragState.IDLE:
		_item_tooltip.show_for_item(item, null, null, global_pos)


func _on_item_hover_exited() -> void:
	if _drag_state == DragState.IDLE:
		_item_tooltip.hide_tooltip()
		_grid_panel.clear_highlights()


# === Grid Interaction ===

func _on_grid_cell_clicked(grid_pos: Vector2i, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return

	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	if _drag_state == DragState.DRAGGING:
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
		_grid_panel.show_placement_preview(_dragged_item, grid_pos, _drag_rotation)
		var can_place: bool = inv.can_place(_dragged_item, grid_pos, _drag_rotation)
		_drag_preview.set_valid(can_place)
	else:
		var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
		if placed:
			_grid_panel.highlight_modifier_connections(placed)
			_item_tooltip.show_for_item(placed.item_data, placed, inv, get_global_mouse_position())
		else:
			_grid_panel.clear_highlights()
			_item_tooltip.hide_tooltip()


# === Drag and Drop ===

func _start_drag_from_loot(item: ItemData, index: int) -> void:
	_dragged_item = item
	_drag_source = "loot"
	_drag_source_loot_index = index
	_drag_rotation = 0
	_drag_state = DragState.DRAGGING

	# Remove from loot pool
	_loot_items.remove_at(index)
	_refresh_loot_pool()
	_item_tooltip.hide_tooltip()

	_drag_preview.setup(_dragged_item, _drag_rotation)
	DebugLogger.log_info("Picked up %s from loot pool" % _dragged_item.display_name, "Loot")


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

	inv.remove_item(placed)
	_grid_panel.refresh()
	_item_tooltip.hide_tooltip()

	_drag_preview.setup(_dragged_item, _drag_rotation)
	DebugLogger.log_info("Picked up %s from grid" % _dragged_item.display_name, "Loot")


func _try_place_item(grid_pos: Vector2i) -> void:
	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	if not inv.can_place(_dragged_item, grid_pos, _drag_rotation):
		return

	var placed: GridInventory.PlacedItem = inv.place_item(_dragged_item, grid_pos, _drag_rotation)
	if not placed:
		return

	EventBus.item_placed.emit(_current_character_id, _dragged_item, grid_pos)
	EventBus.inventory_changed.emit(_current_character_id)

	_end_drag()
	_grid_panel.refresh()
	_update_loot_count()
	DebugLogger.log_info("Placed %s at (%d, %d)" % [placed.item_data.display_name, grid_pos.x, grid_pos.y], "Loot")


func _return_to_loot_pool() -> void:
	if not _dragged_item:
		return

	# If it came from grid, also emit removal signals
	if _drag_source == "grid":
		EventBus.item_removed.emit(_current_character_id, _dragged_item, _drag_source_pos)
		EventBus.inventory_changed.emit(_current_character_id)

	_loot_items.append(_dragged_item)
	_refresh_loot_pool()

	var item_name: String = _dragged_item.display_name
	_end_drag()
	_update_loot_count()
	DebugLogger.log_info("Returned %s to loot pool" % item_name, "Loot")


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
	elif _drag_source == "loot":
		_loot_items.insert(mini(_drag_source_loot_index, _loot_items.size()), _dragged_item)
		_refresh_loot_pool()

	_end_drag()
	DebugLogger.log_info("Cancelled drag", "Loot")


func _rotate_dragged_item() -> void:
	if not _dragged_item:
		return
	_drag_rotation = (_drag_rotation + 1) % _dragged_item.shape.rotation_states
	_drag_preview.rotate_cw()


func _update_drag_preview() -> void:
	_loot_pool.highlight_drop_target(_loot_pool.is_mouse_over())


func _end_drag() -> void:
	_drag_state = DragState.IDLE
	_dragged_item = null
	_drag_source = ""
	_drag_source_placed = null
	_drag_source_loot_index = -1
	_drag_preview.hide_preview()
	_loot_pool.highlight_drop_target(false)
	_grid_panel.clear_placement_preview()


# === Loot Pool Management ===

func _refresh_loot_pool() -> void:
	_loot_pool.refresh(_loot_items)


func _update_loot_count() -> void:
	if _loot_items.is_empty():
		_loot_count_label.text = "All items collected!"
		_send_to_stash_btn.disabled = true
	else:
		_loot_count_label.text = "%d item(s) remaining" % _loot_items.size()
		_send_to_stash_btn.disabled = false


# === Actions ===

func _on_send_all_to_stash() -> void:
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()
	var count: int = _loot_items.size()
	for i in range(_loot_items.size()):
		GameManager.party.add_to_stash(_loot_items[i])
	_loot_items.clear()
	_refresh_loot_pool()
	_update_loot_count()
	EventBus.stash_changed.emit()
	DebugLogger.log_info("Sent %d items to stash" % count, "Loot")


func _on_continue() -> void:
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()

	# Send remaining loot to stash
	if not _loot_items.is_empty():
		for i in range(_loot_items.size()):
			GameManager.party.add_to_stash(_loot_items[i])
		_loot_items.clear()
		EventBus.stash_changed.emit()
		DebugLogger.log_info("Auto-sent remaining loot to stash on continue", "Loot")

	EventBus.loot_screen_closed.emit()
	SceneManager.pop_scene()
