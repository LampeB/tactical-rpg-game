extends Control
## Reward/loot screen. Lets the player drag items between a loot grid and
## squad members' grid inventories. Used after battle victories and chest looting.
## Items left on the loot grid when the player presses Continue are LOST.

enum DragState { IDLE, DRAGGING }
enum DragSource { NONE, PLAYER_GRID, LOOT_GRID }

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
var _dragged_was_inventory_item: bool = false  ## Whether the dragged item was from player inventory (on loot grid)

# Consumable use state
var _target_selection_popup: PopupPanel = null
var _pending_consumable_placed: GridInventory.PlacedItem = null


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
	# Right-click: use consumable
	if button == MOUSE_BUTTON_RIGHT:
		var placed: GridInventory.PlacedItem = _loot_inventory.get_item_at(grid_pos)
		if placed and placed.item_data.item_type == Enums.ItemType.CONSUMABLE and placed.item_data.use_skill:
			_on_loot_consumable_use(placed)
		return

	if button != MOUSE_BUTTON_LEFT:
		return

	if _drag_state == DragState.DRAGGING:
		_try_place_on_loot_grid(grid_pos)
	else:
		var placed: GridInventory.PlacedItem = _loot_inventory.get_item_at(grid_pos)
		if placed:
			_start_drag_from_loot_grid(placed)


func _on_loot_grid_cell_hovered(grid_pos: Vector2i) -> void:
	if _drag_state == DragState.DRAGGING:
		_loot_grid_panel.show_placement_preview(_dragged_item, grid_pos, _drag_rotation)
		var can_place: bool = _loot_inventory.can_place(_dragged_item, grid_pos, _drag_rotation)
		_drag_preview.set_valid(can_place)
	else:
		var placed: GridInventory.PlacedItem = _loot_inventory.get_item_at(grid_pos)
		if placed:
			_item_tooltip.show_for_item(placed.item_data, null, null, get_global_mouse_position())
		else:
			_loot_grid_panel.clear_highlights()
			_item_tooltip.hide_tooltip()


func _on_item_hover_exited() -> void:
	if _drag_state == DragState.IDLE:
		_item_tooltip.hide_tooltip()
		_grid_panel.clear_highlights()
		_loot_grid_panel.clear_highlights()


# ════════════════════════════════════════════════════════════════════════════
#  Player Grid Interaction
# ════════════════════════════════════════════════════════════════════════════

func _on_grid_cell_clicked(grid_pos: Vector2i, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return

	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	if _drag_state == DragState.DRAGGING:
		_try_place_on_player_grid(grid_pos)
	else:
		var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
		if placed:
			_start_drag_from_player_grid(placed)


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


# ════════════════════════════════════════════════════════════════════════════
#  Drag Start
# ════════════════════════════════════════════════════════════════════════════

func _start_drag_from_loot_grid(placed: GridInventory.PlacedItem) -> void:
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
	_item_tooltip.hide_tooltip()
	_drag_preview.setup(_dragged_item, _drag_rotation)


func _start_drag_from_player_grid(placed: GridInventory.PlacedItem) -> void:
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
	_item_tooltip.hide_tooltip()
	_drag_preview.setup(_dragged_item, _drag_rotation)


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

	EventBus.item_placed.emit(_current_character_id, _dragged_item, grid_pos)
	EventBus.inventory_changed.emit(_current_character_id)

	_end_drag()
	_grid_panel.refresh()
	_update_loot_count()


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

	_end_drag()


func _rotate_dragged_item() -> void:
	if not _dragged_item or not _dragged_item.shape:
		return
	_drag_rotation = (_drag_rotation + 1) % _dragged_item.shape.rotation_states
	_drag_preview.rotate_cw()


func _update_drag_preview() -> void:
	_grid_panel.highlight_upgradeable_items(_dragged_item)
	_loot_grid_panel.highlight_upgradeable_items(_dragged_item)


func _end_drag() -> void:
	_drag_state = DragState.IDLE
	_dragged_item = null
	_drag_source = DragSource.NONE
	_dragged_was_inventory_item = false
	_drag_preview.hide_preview()
	_grid_panel.clear_placement_preview()
	_loot_grid_panel.clear_placement_preview()
	_loot_grid_panel.clear_highlights()


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
		DebugLogger.log_warning("Continue blocked: %d inventory item(s) on loot grid" % _inventory_items_on_loot_grid.size(), "Loot")
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
#  Consumable Use (right-click on loot grid)
# ════════════════════════════════════════════════════════════════════════════

func _on_loot_consumable_use(placed: GridInventory.PlacedItem) -> void:
	if not placed.item_data.use_skill:
		return
	_pending_consumable_placed = placed
	_show_target_selection_popup()


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
	var placed: GridInventory.PlacedItem = _pending_consumable_placed
	_target_selection_popup.hide()

	if not placed or not placed.item_data.use_skill:
		return

	if not GameManager.party:
		return

	var skill: SkillData = placed.item_data.use_skill
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var target_max_hp: int = GameManager.party.get_max_hp(character_id, tree)

	var heal: int = DamageCalculator.calculate_healing(
		skill.heal_amount,
		skill.heal_percent,
		target_max_hp
	)

	GameManager.party.heal_character(character_id, heal, 0, tree)

	# Remove consumed item from loot grid
	_inventory_items_on_loot_grid.erase(placed)
	_loot_inventory.remove_item(placed)
	_loot_grid_panel.refresh()
	_update_loot_count()

	DebugLogger.log_info("Used %s on %s, healed %d HP" % [placed.item_data.display_name, character_id, heal], "Loot")


func _on_target_popup_hidden() -> void:
	_pending_consumable_placed = null
