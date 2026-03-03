extends Control
## Reward/loot screen. Lets the player drag items between a loot grid and
## squad members' grid inventories. Used after battle victories and chest looting.
## Items left on the loot grid when the player presses Continue are LOST.

enum DragState { IDLE, DRAGGING }
enum DragSource { NONE, PLAYER_GRID, LOOT_GRID, STASH }

const DEFAULT_LOOT_GRID_WIDTH: int = 8
const DEFAULT_LOOT_GRID_HEIGHT: int = 5

# --- Child references ---
@onready var _bg: ColorRect = $Background
@onready var _title: Label = $VBox/TopBar/Title
@onready var _gold_label: Label = $VBox/TopBar/GoldLabel
@onready var _loot_label: Label = $VBox/Content/LootSide/LootLabel
@onready var _loot_grid_panel: Control = $VBox/Content/LootSide/LootGridCentering/LootGridPanel
@onready var _loot_info_label: Label = $VBox/Content/LootSide/LootInfoLabel
@onready var _grid_panel: Control = $VBox/Content/GridSide/GridCentering/GridPanel
@onready var _character_tabs: HBoxContainer = $VBox/Content/GridSide/CharacterTabs
@onready var _item_tooltip: PanelContainer = $TooltipLayer/ItemTooltip
@onready var _drag_preview: Control = $DragLayer/DragPreview
@onready var _loot_count_label: Label = $VBox/BottomBar/LootCountLabel
@onready var _continue_btn: Button = $VBox/BottomBar/ContinueButton

# --- State ---
var _loot_inventory: GridInventory = null  ## The loot grid inventory
var _grid_inventories: Dictionary = {}  ## character_id -> GridInventory
var _current_character_id: String = ""
var _inventory_items_on_loot_grid: Dictionary = {}  ## PlacedItem -> true (items from player inv on loot grid)
var _items_placed_from_loot: Dictionary = {}  ## {character_id: {grid_pos: true}} tracks items placed from loot this session
var _from_battle: bool = false

var _drag_state: DragState = DragState.IDLE
var _dragged_item: ItemData = null
var _drag_source: DragSource = DragSource.NONE
var _drag_source_pos: Vector2i = Vector2i.ZERO
var _drag_rotation: int = 0
var _drag_hover_pos: Vector2i = Vector2i(-1, -1)  ## Last grid cell hovered during drag
var _drag_hover_panel: Control = null  ## Which grid panel is being hovered during drag
var _dragged_was_inventory_item: bool = false  ## Whether the dragged item was from player inventory (on loot grid)

# Stash state
@onready var _stash_panel: PanelContainer = $VBox/Content/StashSide/StashPanel
@onready var _discard_zone: PanelContainer = $VBox/Content/GridSide/DiscardZone
var _drag_source_stash_index: int = -1

# Discard state
var _discard_dialog: ConfirmationDialog = null
var _pending_discard_item: ItemData = null
var _pending_discard_index: int = -1
var _pending_discard_is_dragged: bool = false

# Consumable use state
var _target_selection_popup: PopupPanel = null
var _pending_consumable_placed: GridInventory.PlacedItem = null
var _pending_consumable_stash_index: int = -1


func _ready() -> void:
	_bg.color = UIColors.BG_LOOT
	_continue_btn.pressed.connect(_on_continue)

	# Use persistent grid inventories from Party
	if GameManager.party:
		_grid_inventories = GameManager.party.grid_inventories
		_character_tabs.setup(GameManager.party.squad, GameManager.party.roster)
		_character_tabs.character_selected.connect(_on_character_selected)

	# Wire loot grid panel signals
	_loot_grid_panel.cell_clicked.connect(_on_loot_grid_cell_clicked)
	_loot_grid_panel.cell_hovered.connect(_on_loot_grid_cell_hovered)
	_loot_grid_panel.cell_exited.connect(_on_item_hover_exited)

	# Wire player grid panel signals
	_grid_panel.cell_clicked.connect(_on_grid_cell_clicked)
	_grid_panel.cell_hovered.connect(_on_grid_cell_hovered)
	_grid_panel.cell_exited.connect(_on_item_hover_exited)

	# Select first squad member
	if GameManager.party and not GameManager.party.squad.is_empty():
		_on_character_selected(GameManager.party.squad[0])
		_character_tabs.select(GameManager.party.squad[0])

	# Wire stash panel signals
	_stash_panel.set_label_prefix("Stash")
	_stash_panel.item_clicked.connect(_on_stash_item_clicked)
	_stash_panel.item_hovered.connect(_on_stash_item_hovered)
	_stash_panel.item_exited.connect(_on_stash_item_exited)
	_stash_panel.background_clicked.connect(_on_stash_background_clicked)
	_stash_panel.item_use_requested.connect(_on_stash_item_use_requested)
	_stash_panel.item_discard_requested.connect(_on_stash_discard_requested)
	EventBus.stash_changed.connect(_on_stash_changed)
	if GameManager.party:
		_stash_panel.refresh(GameManager.party.stash)

	# Wire discard zone
	_discard_zone.gui_input.connect(_on_discard_zone_input)

	# Discard confirmation dialog
	_discard_dialog = ConfirmationDialog.new()
	_discard_dialog.title = "Discard Item"
	_discard_dialog.confirmed.connect(_on_discard_confirmed)
	add_child(_discard_dialog)

	_item_tooltip.visible = false
	_drag_preview.visible = false


func receive_data(data: Dictionary) -> void:
	var loot: Array = data.get("loot", [])
	var template: GridTemplate = data.get("loot_grid_template", null) as GridTemplate

	_inventory_items_on_loot_grid.clear()
	_items_placed_from_loot.clear()

	# Title based on source
	var source: String = data.get("source", "battle")
	_from_battle = (source == "battle")
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

	# Setup loot grid with auto-placement
	_setup_loot_grid(loot, template)
	_update_loot_count()
	DebugLogger.log_info("Received %d loot items" % loot.size(), "Loot")


# ════════════════════════════════════════════════════════════════════════════
#  Loot Grid Setup
# ════════════════════════════════════════════════════════════════════════════

func _setup_loot_grid(items: Array, template: GridTemplate) -> void:
	var loot_template: GridTemplate
	if template:
		loot_template = template
	else:
		loot_template = GridTemplate.new()
		loot_template.id = "loot_grid_default"
		loot_template.width = DEFAULT_LOOT_GRID_WIDTH
		loot_template.height = DEFAULT_LOOT_GRID_HEIGHT

	_loot_inventory = GridInventory.new(loot_template)
	_loot_inventory.skip_equipment_checks = true

	# Sort items by rarity descending (highest priority first)
	var sorted_items: Array = items.duplicate()
	sorted_items.sort_custom(_compare_rarity_descending)

	# Place items one by one; discard items that cannot fit
	var placed_count: int = 0
	var discarded_count: int = 0
	for item in sorted_items:
		if _try_place_loot(item):
			placed_count += 1
		else:
			discarded_count += 1

	_loot_grid_panel.setup(_loot_inventory)

	if discarded_count > 0:
		DebugLogger.log_info("Loot grid: placed %d, discarded %d (no space)" % [placed_count, discarded_count], "Loot")
	else:
		DebugLogger.log_info("Loot grid: placed %d items" % placed_count, "Loot")


static func _compare_rarity_descending(a: ItemData, b: ItemData) -> bool:
	return int(a.rarity) > int(b.rarity)


func _try_place_loot(item: ItemData) -> bool:
	var grid_w: int = _loot_inventory.grid_template.width
	var grid_h: int = _loot_inventory.grid_template.height
	var rotations: int = item.shape.rotation_states if item.shape else 1
	for y in range(grid_h):
		for x in range(grid_w):
			for r in range(rotations):
				if _loot_inventory.place_item(item, Vector2i(x, y), r):
					return true
	return false


# ════════════════════════════════════════════════════════════════════════════
#  Input
# ════════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if _drag_state == DragState.DRAGGING:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_rotate_dragged_item()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("escape"):
			_cancel_drag()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
			_request_discard_dragged()
			get_viewport().set_input_as_handled()
			return
		return

	# Idle state — ESC exits the loot screen (with validation)
	if event.is_action_pressed("escape"):
		_on_continue()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _drag_state == DragState.DRAGGING:
		_update_drag_preview()


# ════════════════════════════════════════════════════════════════════════════
#  Character Switching
# ════════════════════════════════════════════════════════════════════════════

func _on_character_selected(character_id: String) -> void:
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()
	_current_character_id = character_id
	var inv: GridInventory = _grid_inventories.get(character_id)
	if inv:
		_grid_panel.setup(inv)
	_item_tooltip.hide_tooltip()


# ════════════════════════════════════════════════════════════════════════════
#  Loot Grid Interaction
# ════════════════════════════════════════════════════════════════════════════

func _on_loot_grid_cell_clicked(grid_pos: Vector2i, button: int) -> void:
	# During drag, right-click rotates the held item
	if _drag_state == DragState.DRAGGING and button == MOUSE_BUTTON_RIGHT:
		_rotate_dragged_item()
		return

	# Right-click: use consumable
	if button == MOUSE_BUTTON_RIGHT:
		var placed: GridInventory.PlacedItem = _loot_inventory.get_item_at(grid_pos)
		if placed and placed.item_data.item_type == Enums.ItemType.CONSUMABLE and placed.item_data.use_skill:
			_on_loot_consumable_use(placed)
		return

	if button != MOUSE_BUTTON_LEFT:
		return

	if _drag_state == DragState.DRAGGING:
		var adjusted_pos: Vector2i = grid_pos - _drag_preview.get_center_cell_offset()
		_try_place_on_loot_grid(adjusted_pos)
	elif _drag_state == DragState.IDLE:
		var placed: GridInventory.PlacedItem = _loot_inventory.get_item_at(grid_pos)
		if placed:
			_start_drag_from_loot_grid(placed, grid_pos)


func _on_loot_grid_cell_hovered(grid_pos: Vector2i) -> void:
	if _drag_state == DragState.DRAGGING:
		_drag_hover_pos = grid_pos
		_drag_hover_panel = _loot_grid_panel
		var adjusted_pos: Vector2i = grid_pos - _drag_preview.get_center_cell_offset()
		_loot_grid_panel.show_placement_preview(_dragged_item, adjusted_pos, _drag_rotation)
		var can_place: bool = _loot_inventory.can_place(_dragged_item, adjusted_pos, _drag_rotation)
		_drag_preview.set_valid(can_place)
	else:
		var placed: GridInventory.PlacedItem = _loot_inventory.get_item_at(grid_pos)
		if placed:
			_item_tooltip.show_for_item(placed.item_data, null, null, get_global_mouse_position())
		else:
			_loot_grid_panel.clear_highlights()
			_item_tooltip.hide_tooltip()


func _on_item_hover_exited() -> void:
	_drag_hover_pos = Vector2i(-1, -1)
	_drag_hover_panel = null
	if _drag_state == DragState.IDLE:
		_item_tooltip.hide_tooltip()
		_grid_panel.clear_highlights()
		_loot_grid_panel.clear_highlights()


# ════════════════════════════════════════════════════════════════════════════
#  Player Grid Interaction
# ════════════════════════════════════════════════════════════════════════════

func _on_grid_cell_clicked(grid_pos: Vector2i, button: int) -> void:
	# During drag, right-click rotates the held item
	if _drag_state == DragState.DRAGGING and button == MOUSE_BUTTON_RIGHT:
		_rotate_dragged_item()
		return

	if button != MOUSE_BUTTON_LEFT:
		return

	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	if _drag_state == DragState.DRAGGING:
		var adjusted_pos: Vector2i = grid_pos - _drag_preview.get_center_cell_offset()
		_try_place_on_player_grid(adjusted_pos)
	elif _drag_state == DragState.IDLE:
		var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
		if placed:
			_start_drag_from_player_grid(placed, grid_pos)


func _on_grid_cell_hovered(grid_pos: Vector2i) -> void:
	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	if _drag_state == DragState.DRAGGING:
		_drag_hover_pos = grid_pos
		_drag_hover_panel = _grid_panel
		var adjusted_pos: Vector2i = grid_pos - _drag_preview.get_center_cell_offset()
		_grid_panel.show_placement_preview(_dragged_item, adjusted_pos, _drag_rotation)
		var can_place: bool = inv.can_place(_dragged_item, adjusted_pos, _drag_rotation)
		_drag_preview.set_valid(can_place)
	else:
		var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
		if placed:
			_grid_panel.highlight_modifier_connections(placed)
			_item_tooltip.show_for_item(placed.item_data, placed, inv, get_global_mouse_position())
		else:
			_grid_panel.clear_highlights()
			_item_tooltip.hide_tooltip()


# ════════════════════════════════════════════════════════════════════════════
#  Drag Start
# ════════════════════════════════════════════════════════════════════════════

func _start_drag_from_loot_grid(placed: GridInventory.PlacedItem, clicked_pos: Vector2i = Vector2i(-1, -1)) -> void:
	_dragged_item = placed.item_data
	_drag_source = DragSource.LOOT_GRID
	_drag_source_pos = placed.grid_position
	_drag_rotation = placed.rotation
	_drag_state = DragState.DRAGGING

	# Track if this was an inventory item on the loot grid
	_dragged_was_inventory_item = _inventory_items_on_loot_grid.has(placed)
	_inventory_items_on_loot_grid.erase(placed)

	_loot_inventory.remove_item(placed)
	_loot_grid_panel.refresh()
	var anchor: Vector2i = Vector2i(-1, -1)
	if clicked_pos != Vector2i(-1, -1):
		anchor = clicked_pos - placed.grid_position
	_drag_preview.setup(_dragged_item, _drag_rotation, anchor)


func _start_drag_from_player_grid(placed: GridInventory.PlacedItem, clicked_pos: Vector2i = Vector2i(-1, -1)) -> void:
	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	_dragged_item = placed.item_data
	_drag_source = DragSource.PLAYER_GRID
	_drag_source_pos = placed.grid_position
	_drag_rotation = placed.rotation
	_drag_state = DragState.DRAGGING

	inv.remove_item(placed)
	_grid_panel.refresh()
	var anchor: Vector2i = Vector2i(-1, -1)
	if clicked_pos != Vector2i(-1, -1):
		anchor = clicked_pos - placed.grid_position
	_drag_preview.setup(_dragged_item, _drag_rotation, anchor)


# ════════════════════════════════════════════════════════════════════════════
#  Drop on Player Grid
# ════════════════════════════════════════════════════════════════════════════

func _try_place_on_player_grid(grid_pos: Vector2i) -> void:
	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	# Check for item upgrade
	var target: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if target and ItemUpgradeSystem.can_upgrade(_dragged_item, target.item_data):
		_perform_player_grid_upgrade(inv, target)
		return

	if not inv.can_place(_dragged_item, grid_pos, _drag_rotation):
		return

	var placed: GridInventory.PlacedItem = inv.place_item(_dragged_item, grid_pos, _drag_rotation)
	if not placed:
		return

	# Track if this item was placed from loot (so we know it's not an "inventory item" if moved back)
	if _drag_source == DragSource.LOOT_GRID and not _dragged_was_inventory_item:
		if not _items_placed_from_loot.has(_current_character_id):
			_items_placed_from_loot[_current_character_id] = {}
		_items_placed_from_loot[_current_character_id][grid_pos] = true

	var was_from_stash: bool = (_drag_source == DragSource.STASH)
	EventBus.item_placed.emit(_current_character_id, _dragged_item, grid_pos)
	EventBus.inventory_changed.emit(_current_character_id)

	_end_drag()
	_grid_panel.refresh()
	_update_loot_count()
	if was_from_stash:
		EventBus.stash_changed.emit()


func _perform_player_grid_upgrade(inv: GridInventory, target_placed: GridInventory.PlacedItem) -> void:
	var upgraded_item: ItemData = ItemUpgradeSystem.create_upgraded_item(target_placed.item_data)
	var target_pos: Vector2i = target_placed.grid_position
	var target_rot: int = target_placed.rotation
	inv.remove_item(target_placed)

	var new_placed: GridInventory.PlacedItem = inv.place_item(upgraded_item, target_pos, target_rot)
	if new_placed:
		EventBus.inventory_changed.emit(_current_character_id)
		_grid_panel.refresh()
		_update_loot_count()
		DebugLogger.log_info("UPGRADE! %s + %s -> %s" % [
			_dragged_item.display_name,
			target_placed.item_data.display_name,
			upgraded_item.display_name
		], "Loot")

	_end_drag()


# ════════════════════════════════════════════════════════════════════════════
#  Drop on Loot Grid
# ════════════════════════════════════════════════════════════════════════════

func _try_place_on_loot_grid(grid_pos: Vector2i) -> void:
	# Check for upgrade on loot grid
	var target: GridInventory.PlacedItem = _loot_inventory.get_item_at(grid_pos)
	if target and ItemUpgradeSystem.can_upgrade(_dragged_item, target.item_data):
		_perform_loot_grid_upgrade(target)
		return

	if not _loot_inventory.can_place(_dragged_item, grid_pos, _drag_rotation):
		return

	var new_placed: GridInventory.PlacedItem = _loot_inventory.place_item(_dragged_item, grid_pos, _drag_rotation)
	if not new_placed:
		return

	# Track inventory items placed onto the loot grid
	var was_from_stash: bool = (_drag_source == DragSource.STASH)
	if _drag_source == DragSource.PLAYER_GRID:
		var char_placements: Dictionary = _items_placed_from_loot.get(_current_character_id, {})
		if char_placements.has(_drag_source_pos):
			# Item was originally from loot, don't mark as inventory
			char_placements.erase(_drag_source_pos)
		else:
			# Item was from player inventory, mark it so continue is blocked
			_inventory_items_on_loot_grid[new_placed] = true
		EventBus.item_removed.emit(_current_character_id, _dragged_item, _drag_source_pos)
		EventBus.inventory_changed.emit(_current_character_id)
	elif _dragged_was_inventory_item:
		# Returning an inventory item back to loot grid
		_inventory_items_on_loot_grid[new_placed] = true

	_end_drag()
	_loot_grid_panel.refresh()
	_grid_panel.refresh()
	_update_loot_count()
	if was_from_stash:
		EventBus.stash_changed.emit()


func _perform_loot_grid_upgrade(target_placed: GridInventory.PlacedItem) -> void:
	var upgraded_item: ItemData = ItemUpgradeSystem.create_upgraded_item(target_placed.item_data)
	var target_pos: Vector2i = target_placed.grid_position
	var target_rot: int = target_placed.rotation

	# Preserve inventory tracking for the target
	var target_was_inv: bool = _inventory_items_on_loot_grid.has(target_placed)
	_inventory_items_on_loot_grid.erase(target_placed)

	_loot_inventory.remove_item(target_placed)
	var new_placed: GridInventory.PlacedItem = _loot_inventory.place_item(upgraded_item, target_pos, target_rot)

	if new_placed and target_was_inv:
		_inventory_items_on_loot_grid[new_placed] = true

	DebugLogger.log_info("LOOT UPGRADE! %s + %s -> %s" % [
		_dragged_item.display_name,
		target_placed.item_data.display_name,
		upgraded_item.display_name
	], "Loot")

	_end_drag()
	_loot_grid_panel.refresh()
	_update_loot_count()


# ════════════════════════════════════════════════════════════════════════════
#  Cancel / End Drag
# ════════════════════════════════════════════════════════════════════════════

func _cancel_drag() -> void:
	if not _dragged_item:
		_end_drag()
		return

	if _drag_source == DragSource.PLAYER_GRID:
		var inv: GridInventory = _grid_inventories.get(_current_character_id)
		if inv:
			inv.place_item(_dragged_item, _drag_source_pos, _drag_rotation)
			_grid_panel.refresh()
	elif _drag_source == DragSource.LOOT_GRID:
		var restored: GridInventory.PlacedItem = _loot_inventory.place_item(_dragged_item, _drag_source_pos, _drag_rotation)
		if restored and _dragged_was_inventory_item:
			_inventory_items_on_loot_grid[restored] = true
		_loot_grid_panel.refresh()
	elif _drag_source == DragSource.STASH:
		GameManager.party.stash.insert(mini(_drag_source_stash_index, GameManager.party.stash.size()), _dragged_item)
		_stash_panel.refresh(GameManager.party.stash)

	_end_drag()


func _rotate_dragged_item() -> void:
	if not _dragged_item or not _dragged_item.shape:
		return
	_drag_rotation = (_drag_rotation + 1) % 4
	_drag_preview.rotate_cw()
	if _drag_hover_pos != Vector2i(-1, -1) and _drag_hover_panel:
		if _drag_hover_panel == _loot_grid_panel:
			_on_loot_grid_cell_hovered(_drag_hover_pos)
		else:
			_on_grid_cell_hovered(_drag_hover_pos)


func _update_drag_preview() -> void:
	_grid_panel.highlight_upgradeable_items(_dragged_item)
	_loot_grid_panel.highlight_upgradeable_items(_dragged_item)
	_stash_panel.highlight_drop_target(_stash_panel.is_mouse_over())
	_stash_panel.highlight_upgradeable_items(_dragged_item)
	var over_discard: bool = _discard_zone.get_global_rect().has_point(get_global_mouse_position())
	_highlight_discard_zone(over_discard)


func _end_drag() -> void:
	_drag_state = DragState.IDLE
	_dragged_item = null
	_drag_source = DragSource.NONE
	_drag_source_stash_index = -1
	_dragged_was_inventory_item = false
	_drag_preview.hide_preview()
	_grid_panel.clear_placement_preview()
	_loot_grid_panel.clear_placement_preview()
	_loot_grid_panel.clear_highlights()
	_stash_panel.highlight_drop_target(false)
	_stash_panel.clear_upgradeable_highlights()
	_highlight_discard_zone(false)


# ════════════════════════════════════════════════════════════════════════════
#  Discard Zone (drag-to-trash)
# ════════════════════════════════════════════════════════════════════════════

func _on_discard_zone_input(event: InputEvent) -> void:
	if _drag_state == DragState.DRAGGING:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_request_discard_dragged()


func _highlight_discard_zone(show: bool) -> void:
	if show:
		_discard_zone.self_modulate = Color(1.0, 0.4, 0.4)
	else:
		_discard_zone.self_modulate = Color.WHITE


# ════════════════════════════════════════════════════════════════════════════
#  Stash Interaction
# ════════════════════════════════════════════════════════════════════════════

func _on_stash_item_clicked(item: ItemData, index: int) -> void:
	if _drag_state == DragState.DRAGGING:
		# Check for upgrade
		if ItemUpgradeSystem.can_upgrade(_dragged_item, item):
			_perform_stash_upgrade(item, index)
			return
		# Drop current item to stash
		_return_to_stash()
	else:
		_start_drag_from_stash(item, index)


func _on_stash_item_hovered(item: ItemData, global_pos: Vector2) -> void:
	if _drag_state == DragState.IDLE:
		_item_tooltip.show_for_item(item, null, null, global_pos)


func _on_stash_item_exited() -> void:
	if _drag_state == DragState.IDLE:
		_item_tooltip.hide_tooltip()


func _on_stash_background_clicked() -> void:
	if _drag_state == DragState.DRAGGING:
		_return_to_stash()


func _start_drag_from_stash(item: ItemData, index: int) -> void:
	_dragged_item = item
	_drag_source = DragSource.STASH
	_drag_source_stash_index = index
	_drag_rotation = 0
	_drag_state = DragState.DRAGGING

	GameManager.party.stash.remove_at(index)
	_stash_panel.refresh(GameManager.party.stash)
	_item_tooltip.hide_tooltip()

	_drag_preview.setup(_dragged_item, _drag_rotation)


func _return_to_stash() -> void:
	if not _dragged_item:
		return

	if not GameManager.party.add_to_stash(_dragged_item):
		EventBus.show_message.emit("Stash is full!")
		return

	var was_from_player_grid: bool = (_drag_source == DragSource.PLAYER_GRID)
	var was_from_loot: bool = (_drag_source == DragSource.LOOT_GRID)
	var item: ItemData = _dragged_item
	var source_pos: Vector2i = _drag_source_pos

	_end_drag()
	_stash_panel.refresh(GameManager.party.stash)

	if was_from_player_grid:
		var char_placements: Dictionary = _items_placed_from_loot.get(_current_character_id, {})
		if char_placements.has(source_pos):
			char_placements.erase(source_pos)
		EventBus.item_removed.emit(_current_character_id, item, source_pos)
		EventBus.inventory_changed.emit(_current_character_id)
		_grid_panel.refresh()
	elif was_from_loot:
		_loot_grid_panel.refresh()

	_update_loot_count()
	EventBus.stash_changed.emit()
	DebugLogger.log_info("Moved %s to stash" % item.display_name, "Loot")


func _perform_stash_upgrade(target_item: ItemData, target_index: int) -> void:
	var upgraded_item: ItemData = ItemUpgradeSystem.create_upgraded_item(target_item)
	var dragged_name: String = _dragged_item.display_name
	_end_drag()
	GameManager.party.stash.remove_at(target_index)
	GameManager.party.force_add_to_stash(upgraded_item)
	_stash_panel.refresh(GameManager.party.stash)
	EventBus.stash_changed.emit()
	DebugLogger.log_info("STASH UPGRADE! %s + %s -> %s" % [
		dragged_name, target_item.display_name, upgraded_item.display_name
	], "Loot")


func _on_stash_changed() -> void:
	if GameManager.party:
		_stash_panel.refresh(GameManager.party.stash)


# ════════════════════════════════════════════════════════════════════════════
#  Discard
# ════════════════════════════════════════════════════════════════════════════

func _on_stash_discard_requested(item: ItemData, index: int) -> void:
	_pending_discard_item = item
	_pending_discard_index = index
	_pending_discard_is_dragged = false
	_discard_dialog.dialog_text = "Discard %s? This cannot be undone." % item.display_name
	_discard_dialog.popup_centered()


func _request_discard_dragged() -> void:
	if not _dragged_item:
		return
	_pending_discard_item = _dragged_item
	_pending_discard_index = -1
	_pending_discard_is_dragged = true
	_discard_dialog.dialog_text = "Discard %s? This cannot be undone." % _dragged_item.display_name
	_discard_dialog.popup_centered()


func _on_discard_confirmed() -> void:
	if not _pending_discard_item:
		return
	if _pending_discard_is_dragged:
		var was_from_player_grid: bool = (_drag_source == DragSource.PLAYER_GRID)
		var was_from_loot: bool = (_drag_source == DragSource.LOOT_GRID)
		var source_pos: Vector2i = _drag_source_pos
		_end_drag()
		if was_from_player_grid:
			EventBus.item_removed.emit(_current_character_id, _pending_discard_item, source_pos)
			EventBus.inventory_changed.emit(_current_character_id)
			_grid_panel.refresh()
		elif was_from_loot:
			_loot_grid_panel.refresh()
			_update_loot_count()
	else:
		if _pending_discard_index >= 0 and _pending_discard_index < GameManager.party.stash.size():
			GameManager.party.stash.remove_at(_pending_discard_index)
			_stash_panel.refresh(GameManager.party.stash)
			EventBus.stash_changed.emit()
	DebugLogger.log_info("Discarded: %s" % _pending_discard_item.display_name, "Loot")
	_pending_discard_item = null
	_pending_discard_index = -1
	_pending_discard_is_dragged = false


# ════════════════════════════════════════════════════════════════════════════
#  Loot Count / Info Label
# ════════════════════════════════════════════════════════════════════════════

func _update_loot_count() -> void:
	if not _loot_inventory:
		return

	var total_on_grid: int = _loot_inventory.get_all_placed_items().size()
	var inv_count: int = _inventory_items_on_loot_grid.size()
	var loot_count: int = total_on_grid - inv_count

	if total_on_grid == 0 or loot_count == 0:
		_loot_info_label.text = "All items collected!"
		_loot_info_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		_loot_count_label.text = ""
		_continue_btn.disabled = (inv_count > 0)
	elif inv_count > 0:
		_loot_info_label.text = "%d inventory item(s) must be returned" % inv_count
		_loot_info_label.add_theme_color_override("font_color", Constants.COLOR_DAMAGE)
		_loot_count_label.text = "%d item(s) remaining" % loot_count
		_continue_btn.disabled = true
	else:
		_loot_info_label.text = "%d item(s) remaining (will be lost)" % loot_count
		_loot_info_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		_loot_count_label.text = ""
		_continue_btn.disabled = false


func _shake_loot_grid() -> void:
	var tween: Tween = create_tween()
	var target: Control = _loot_grid_panel
	var original_pos: Vector2 = target.position
	tween.tween_property(target, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(target, "position", original_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(target, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(target, "position", original_pos, 0.05)


# ════════════════════════════════════════════════════════════════════════════
#  Continue (Exit)
# ════════════════════════════════════════════════════════════════════════════

func _on_continue() -> void:
	# Block if inventory items remain on the loot grid
	if not _inventory_items_on_loot_grid.is_empty():
		DebugLogger.log_warn("Continue blocked: %d inventory item(s) on loot grid" % _inventory_items_on_loot_grid.size(), "Loot")
		_shake_loot_grid()
		return

	if _drag_state == DragState.DRAGGING:
		_cancel_drag()

	# Items remaining on loot grid are LOST
	var remaining: int = _loot_inventory.get_all_placed_items().size()
	if remaining > 0:
		DebugLogger.log_info("Discarding %d unclaimed loot items" % remaining, "Loot")

	EventBus.loot_screen_closed.emit()
	if _from_battle:
		SceneManager.pop_scene({"from_battle": true})
	else:
		SceneManager.pop_scene()


# ════════════════════════════════════════════════════════════════════════════
#  Consumable Use
# ════════════════════════════════════════════════════════════════════════════

func _on_loot_consumable_use(placed: GridInventory.PlacedItem) -> void:
	if not placed.item_data.use_skill:
		return
	_pending_consumable_placed = placed
	_pending_consumable_stash_index = -1
	_show_target_selection_popup()


func _on_stash_item_use_requested(item: ItemData, index: int) -> void:
	# Blueprints are used instantly
	if item.item_type == Enums.ItemType.BLUEPRINT:
		_use_blueprint(item)
		return
	if not item.use_skill:
		return
	_pending_consumable_placed = null
	_pending_consumable_stash_index = index
	_show_target_selection_popup()


func _use_blueprint(item: ItemData) -> void:
	if GameManager.get_flag(item.id) == true:
		DebugLogger.log_info("Blueprint already learned: %s" % item.id, "Crafting")
		return
	GameManager.set_flag(item.id, true)
	GameManager.party.remove_from_stash(item)
	EventBus.stash_changed.emit()
	EventBus.show_message.emit("New recipe unlocked!")
	DebugLogger.log_info("Blueprint used: %s" % item.id, "Crafting")


func _show_target_selection_popup() -> void:
	if not _target_selection_popup:
		_target_selection_popup = PopupPanel.new()
		add_child(_target_selection_popup)
		_target_selection_popup.popup_hide.connect(_on_target_popup_hidden)

	for child in _target_selection_popup.get_children():
		child.queue_free()

	var vbox: VBoxContainer = VBoxContainer.new()
	_target_selection_popup.add_child(vbox)

	var popup_title: Label = Label.new()
	popup_title.text = "Select Target"
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(popup_title)

	vbox.add_child(HSeparator.new())

	if not GameManager.party:
		return

	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var roster_ids: Array = GameManager.party.roster.keys()
	for i in range(roster_ids.size()):
		var char_id: String = roster_ids[i]
		var char_data: CharacterData = GameManager.party.roster[char_id]
		if not char_data:
			continue

		var current_hp: int = GameManager.party.get_current_hp(char_id)
		var max_hp: int = GameManager.party.get_max_hp(char_id, tree)
		var current_mp: int = GameManager.party.get_current_mp(char_id)
		var max_mp: int = GameManager.party.get_max_mp(char_id, tree)

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(250, 40)
		btn.text = "%s (HP: %d/%d, MP: %d/%d)" % [char_data.display_name, current_hp, max_hp, current_mp, max_mp]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if current_hp <= 0:
			btn.disabled = true
			btn.text += " [DEAD]"
		btn.pressed.connect(_on_target_selected.bind(char_id))
		vbox.add_child(btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_target_selection_popup.hide)
	vbox.add_child(cancel_btn)

	_target_selection_popup.popup_centered()


func _on_target_selected(character_id: String) -> void:
	_target_selection_popup.hide()

	if not GameManager.party:
		return

	var item: ItemData = null
	var is_stash_consumable: bool = (_pending_consumable_stash_index >= 0)

	if is_stash_consumable:
		if _pending_consumable_stash_index >= GameManager.party.stash.size():
			return
		item = GameManager.party.stash[_pending_consumable_stash_index]
	elif _pending_consumable_placed:
		item = _pending_consumable_placed.item_data
	else:
		return

	if not item or not item.use_skill:
		return

	var skill: SkillData = item.use_skill
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var target_max_hp: int = GameManager.party.get_max_hp(character_id, tree)

	var heal: int = DamageCalculator.calculate_healing(
		skill.heal_amount,
		skill.heal_percent,
		target_max_hp
	)

	GameManager.party.heal_character(character_id, heal, 0, tree)

	if is_stash_consumable:
		GameManager.party.stash.remove_at(_pending_consumable_stash_index)
		_stash_panel.refresh(GameManager.party.stash)
		EventBus.stash_changed.emit()
		DebugLogger.log_info("Used %s on %s from stash, healed %d HP" % [item.display_name, character_id, heal], "Loot")
	else:
		_inventory_items_on_loot_grid.erase(_pending_consumable_placed)
		_loot_inventory.remove_item(_pending_consumable_placed)
		_loot_grid_panel.refresh()
		_update_loot_count()
		DebugLogger.log_info("Used %s on %s, healed %d HP" % [item.display_name, character_id, heal], "Loot")


func _on_target_popup_hidden() -> void:
	_pending_consumable_placed = null
	_pending_consumable_stash_index = -1
