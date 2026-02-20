extends Control
## Reward/loot screen. Lets the player drag items from a loot pool into
## squad members' grid inventories. Used after battle victories and chest looting.
## Remaining items are sent to the party stash on continue.

enum DragState { IDLE, DRAGGING }
enum DragSource { NONE, GRID, LOOT }

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
var _inventory_item_indices: Dictionary = {}  ## int -> bool (tracks which loot indices came from inventory)
var _items_placed_from_loot: Dictionary = {}  ## {character_id: {grid_pos: true}} tracks items placed from loot this session
var _from_battle: bool = false  ## Tracks if loot came from battle (for proper return behavior)

var _drag_state: DragState = DragState.IDLE
var _dragged_item: ItemData = null
var _drag_source: DragSource = DragSource.NONE
var _drag_source_pos: Vector2i = Vector2i.ZERO
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
	_loot_pool.background_clicked.connect(_on_loot_background_clicked)

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

	# Clear tracking
	_inventory_item_indices.clear()
	_items_placed_from_loot.clear()

	# Title based on source
	var source: String = data.get("source", "battle")
	_from_battle = (source == "battle")  # Track if returning from battle
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
		# Check for item upgrade opportunity
		if ItemUpgradeSystem.can_upgrade(_dragged_item, item):
			_perform_loot_upgrade(item, index)
			return

		_return_to_loot_pool()
	else:
		_start_drag_from_loot(item, index)


func _on_loot_background_clicked() -> void:
	if _drag_state == DragState.DRAGGING:
		_return_to_loot_pool()


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
		# Note: Upgradeable highlighting is handled in _update_drag_preview()
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
	_drag_source = DragSource.LOOT
	_drag_source_loot_index = index
	_drag_rotation = 0
	_drag_state = DragState.DRAGGING

	# Remove from loot pool
	_loot_items.remove_at(index)

	# Update tracking indices - remove this index and shift down all subsequent
	_inventory_item_indices.erase(index)
	var keys_to_update: Array = []
	for idx in _inventory_item_indices.keys():
		if idx > index:
			keys_to_update.append(idx)
	for idx in keys_to_update:
		_inventory_item_indices[idx - 1] = true
		_inventory_item_indices.erase(idx)

	_refresh_loot_pool()
	_item_tooltip.hide_tooltip()

	_drag_preview.setup(_dragged_item, _drag_rotation)
	DebugLogger.log_info("Picked up %s from loot pool" % _dragged_item.display_name, "Loot")


func _start_drag_from_grid(placed: GridInventory.PlacedItem) -> void:
	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	_dragged_item = placed.item_data
	_drag_source = DragSource.GRID
	_drag_source_pos = placed.grid_position
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

	# Check for item upgrade opportunity
	var target_item: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if target_item and ItemUpgradeSystem.can_upgrade(_dragged_item, target_item.item_data):
		_perform_item_upgrade(inv, target_item)
		return

	if not inv.can_place(_dragged_item, grid_pos, _drag_rotation):
		return

	var placed: GridInventory.PlacedItem = inv.place_item(_dragged_item, grid_pos, _drag_rotation)
	if not placed:
		return

	# Track if this item was placed from loot (so we know it's not an "inventory item" if moved back)
	if _drag_source == DragSource.LOOT:
		if not _items_placed_from_loot.has(_current_character_id):
			_items_placed_from_loot[_current_character_id] = {}
		_items_placed_from_loot[_current_character_id][grid_pos] = true

	EventBus.item_placed.emit(_current_character_id, _dragged_item, grid_pos)
	EventBus.inventory_changed.emit(_current_character_id)

	_end_drag()
	_grid_panel.refresh()
	_update_loot_count()
	DebugLogger.log_info("Placed %s at (%d, %d)" % [placed.item_data.display_name, grid_pos.x, grid_pos.y], "Loot")


func _perform_item_upgrade(inv: GridInventory, target_placed: GridInventory.PlacedItem) -> void:
	# Create upgraded item
	var upgraded_item: ItemData = ItemUpgradeSystem.create_upgraded_item(target_placed.item_data)

	# Remove target item from inventory
	var target_pos: Vector2i = target_placed.grid_position
	var target_rot: int = target_placed.rotation
	inv.remove_item(target_placed)

	# Place upgraded item at same position
	var new_placed: GridInventory.PlacedItem = inv.place_item(upgraded_item, target_pos, target_rot)

	if new_placed:
		# Emit signals
		EventBus.inventory_changed.emit(_current_character_id)

		# Visual feedback
		_grid_panel.refresh()
		_update_loot_count()

		# Log upgrade
		DebugLogger.log_info("UPGRADE! %s + %s → %s" % [
			_dragged_item.display_name,
			target_placed.item_data.display_name,
			upgraded_item.display_name
		], "Loot")

		# TODO: Add visual/audio effect for upgrade

	_end_drag()


func _perform_loot_upgrade(target_item: ItemData, target_index: int) -> void:
	# Create upgraded item
	var upgraded_item: ItemData = ItemUpgradeSystem.create_upgraded_item(target_item)

	# Remove target item from loot pool
	_loot_items.remove_at(target_index)

	# Update tracking indices - remove this index and shift down all subsequent
	_inventory_item_indices.erase(target_index)
	var keys_to_update: Array = []
	for idx in _inventory_item_indices.keys():
		if idx > target_index:
			keys_to_update.append(idx)
	for idx in keys_to_update:
		_inventory_item_indices[idx - 1] = true
		_inventory_item_indices.erase(idx)

	# Add upgraded item to loot pool
	_loot_items.append(upgraded_item)

	# Refresh loot pool display
	_refresh_loot_pool()
	_update_loot_count()

	# Log upgrade
	DebugLogger.log_info("LOOT UPGRADE! %s + %s → %s" % [
		_dragged_item.display_name,
		target_item.display_name,
		upgraded_item.display_name
	], "Loot")

	# End drag
	_end_drag()


func _return_to_loot_pool() -> void:
	if not _dragged_item:
		return

	# If it came from grid, also emit removal signals
	if _drag_source == DragSource.GRID:
		EventBus.item_removed.emit(_current_character_id, _dragged_item, _drag_source_pos)
		EventBus.inventory_changed.emit(_current_character_id)

	_loot_items.append(_dragged_item)

	# Mark item as from inventory ONLY if it was NOT placed from loot during this session
	if _drag_source == DragSource.GRID:
		var char_placements: Dictionary = _items_placed_from_loot.get(_current_character_id, {})
		# Check if this grid position was where we placed an item from loot
		if char_placements.has(_drag_source_pos):
			# This item was placed from loot, remove from tracking and don't mark as inventory
			char_placements.erase(_drag_source_pos)
			DebugLogger.log_info("Item %s was placed from loot, not marking as inventory" % _dragged_item.display_name, "Loot")
		else:
			# This item was already in inventory before loot screen, mark as inventory item
			var new_index: int = _loot_items.size() - 1
			_inventory_item_indices[new_index] = true
			DebugLogger.log_info("Marked loot index %d as from player inventory" % new_index, "Loot")

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
	if _drag_source == DragSource.GRID:
		var inv: GridInventory = _grid_inventories.get(_current_character_id)
		if inv:
			inv.place_item(_dragged_item, _drag_source_pos, _drag_rotation)
			_grid_panel.refresh()
	elif _drag_source == DragSource.LOOT:
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

	# Always highlight ALL upgradeable items (grid + loot) when dragging
	_grid_panel.highlight_upgradeable_items(_dragged_item)
	_loot_pool.highlight_upgradeable_items(_dragged_item)


func _end_drag() -> void:
	_drag_state = DragState.IDLE
	_dragged_item = null
	_drag_source = DragSource.NONE
	_drag_source_loot_index = -1
	_drag_preview.hide_preview()
	_loot_pool.highlight_drop_target(false)
	_loot_pool.clear_upgradeable_highlights()
	_grid_panel.clear_placement_preview()


# === Loot Pool Management ===

func _refresh_loot_pool() -> void:
	_loot_pool.refresh(_loot_items, _inventory_item_indices)


func _update_loot_count() -> void:
	var inv_count: int = _get_inventory_item_count()
	var loot_count: int = _loot_items.size() - inv_count

	if _loot_items.is_empty():
		_loot_count_label.text = "All items collected!"
		_loot_count_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SECONDARY)
		_send_to_stash_btn.disabled = true
		_continue_btn.disabled = false
	elif inv_count > 0:
		_loot_count_label.text = "Cannot continue - %d item(s) must be placed or returned" % inv_count
		_loot_count_label.add_theme_color_override("font_color", Constants.COLOR_DAMAGE)
		_send_to_stash_btn.disabled = (loot_count == 0)
		_continue_btn.disabled = true
	else:
		_loot_count_label.text = "%d item(s) remaining" % _loot_items.size()
		_loot_count_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SECONDARY)
		_send_to_stash_btn.disabled = false
		_continue_btn.disabled = false


func _has_inventory_items_in_loot() -> bool:
	return not _inventory_item_indices.is_empty()


func _get_inventory_item_count() -> int:
	return _inventory_item_indices.size()


func _shake_loot_pool() -> void:
	var tween: Tween = create_tween()
	var original_pos: Vector2 = _loot_pool.position
	tween.tween_property(_loot_pool, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(_loot_pool, "position", original_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(_loot_pool, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(_loot_pool, "position", original_pos, 0.05)


# === Actions ===

func _on_send_all_to_stash() -> void:
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()

	var sent_count: int = 0
	var skipped_count: int = 0

	# Process in reverse to avoid index issues
	for i in range(_loot_items.size() - 1, -1, -1):
		if _inventory_item_indices.has(i):
			skipped_count += 1
			continue

		GameManager.party.add_to_stash(_loot_items[i])
		_loot_items.remove_at(i)
		sent_count += 1

	# Rebuild tracking - all remaining items are from inventory
	_inventory_item_indices.clear()
	for i in range(_loot_items.size()):
		_inventory_item_indices[i] = true

	_refresh_loot_pool()
	_update_loot_count()
	EventBus.stash_changed.emit()

	if skipped_count > 0:
		DebugLogger.log_info("Sent %d items to stash (%d from inventory skipped)" % [sent_count, skipped_count], "Loot")
	else:
		DebugLogger.log_info("Sent %d items to stash" % sent_count, "Loot")


func _on_continue() -> void:
	# Block if inventory items remain in loot
	if _has_inventory_items_in_loot():
		DebugLogger.log_warning("Continue blocked: %d inventory item(s) in loot pool" % _get_inventory_item_count(), "Loot")
		_shake_loot_pool()
		return

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
	# Pass from_battle flag so overworld can apply cooldown and save
	if _from_battle:
		SceneManager.pop_scene({"from_battle": true})
	else:
		SceneManager.pop_scene()
