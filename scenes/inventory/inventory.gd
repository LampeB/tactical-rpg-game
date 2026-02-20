extends Control
## Main inventory scene orchestrator.
## Manages drag-and-drop between grid and stash, character switching, tooltips.

enum DragState { IDLE, DRAGGING }
enum DragSource { NONE, GRID, STASH }

# --- Child references ---
@onready var _grid_panel: Control = $VBox/Content/GridSide/GridCentering/GridPanel
@onready var _stash_panel: PanelContainer = $VBox/Content/StashPanel
@onready var _character_tabs: HBoxContainer = $VBox/Content/GridSide/CharacterTabs
@onready var _skills_panel: PanelContainer = $VBox/Content/GridSide/SkillsSummaryPanel
@onready var _skills_list: VBoxContainer = $VBox/Content/GridSide/SkillsSummaryPanel/VBox/SkillsScroll/SkillsList
@onready var _item_tooltip: PanelContainer = $TooltipLayer/ItemTooltip
@onready var _drag_preview: Control = $DragLayer/DragPreview

# --- State ---
var _grid_inventories: Dictionary = {}  ## character_id -> GridInventory
var _undo_stacks: Dictionary = {}  ## character_id -> InventoryUndo
var _current_character_id: String = ""

var _drag_state: DragState = DragState.IDLE
var _dragged_item: ItemData = null
var _drag_source: DragSource = DragSource.NONE
var _drag_source_placed: GridInventory.PlacedItem = null
var _drag_source_pos: Vector2i = Vector2i.ZERO
var _drag_source_rotation: int = 0
var _drag_source_stash_index: int = -1
var _drag_rotation: int = 0

# --- Consumable usage ---
enum ConsumableSource { NONE = -1, STASH, GRID }
var _pending_consumable: ItemData = null
var _pending_consumable_source: ConsumableSource = ConsumableSource.NONE
var _pending_consumable_index: int = -1  # For stash
var _pending_consumable_placed: GridInventory.PlacedItem = null  # For grid
var _target_selection_popup: PopupPanel = null


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
		_stash_panel.item_use_requested.connect(_on_stash_item_use_requested)

	# Setup grid panel signals
	_grid_panel.cell_clicked.connect(_on_grid_cell_clicked)
	_grid_panel.cell_hovered.connect(_on_grid_cell_hovered)
	_grid_panel.cell_exited.connect(_on_item_hover_exited)

	# Listen for inventory changes to refresh skills summary
	EventBus.inventory_changed.connect(_on_inventory_changed)

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


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Handle stash drops during drag in _input (before GUI processing)
	# so the stash PanelContainer's mouse_filter doesn't block the event.
	if _drag_state == DragState.DRAGGING:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _stash_panel.is_mouse_over():
				_return_to_stash()
				get_viewport().set_input_as_handled()


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
	_populate_skills_summary.call_deferred()
	DebugLogger.log_info("Switched to character: %s" % character_id, "Inventory")


func _on_inventory_changed(character_id: String) -> void:
	# Refresh skills summary when inventory changes for current character
	if character_id == _current_character_id:
		_populate_skills_summary.call_deferred()


func _populate_skills_summary() -> void:
	# Clear existing summary items
	for child in _skills_list.get_children():
		_skills_list.remove_child(child)
		child.queue_free()

	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		var label: Label = Label.new()
		label.text = "No inventory"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_skills_list.add_child(label)
		return

	# Get all active tools
	var tools: Array = []
	var placed_items: Array = inv.get_all_placed_items()
	for i in range(placed_items.size()):
		var placed: GridInventory.PlacedItem = placed_items[i]
		if placed.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
			tools.append(placed)

	if tools.is_empty():
		var label: Label = Label.new()
		label.text = "No active tools equipped"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Constants.COLOR_TEXT_SECONDARY
		_skills_list.add_child(label)
		return

	# Build summary for each tool
	for i in range(tools.size()):
		var tool: GridInventory.PlacedItem = tools[i]
		var row: VBoxContainer = VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		# Tool name
		var name_label: Label = Label.new()
		name_label.text = tool.item_data.display_name
		name_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_HEADER)
		name_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_HEADER)
		row.add_child(name_label)

		# Granted skills
		if not tool.item_data.granted_skills.is_empty():
			var skills_label: Label = Label.new()
			var skill_names: Array = []
			for j in range(tool.item_data.granted_skills.size()):
				var skill: SkillData = tool.item_data.granted_skills[j]
				if skill:
					skill_names.append(skill.display_name)
			skills_label.text = " • Skills: " + ", ".join(skill_names)
			skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			skills_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SKILL)
			row.add_child(skills_label)

		# Affecting modifiers
		var modifiers: Array = inv.get_modifiers_affecting(tool)
		if not modifiers.is_empty():
			var mods_label: Label = Label.new()
			var mod_names: Array = []
			for j in range(modifiers.size()):
				var mod_placed: GridInventory.PlacedItem = modifiers[j]
				mod_names.append(mod_placed.item_data.display_name)
			mods_label.text = " • Modifiers: " + ", ".join(mod_names)
			mods_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			mods_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_MODIFIER)
			row.add_child(mods_label)

		# Separator
		var separator: HSeparator = HSeparator.new()
		separator.add_theme_constant_override("separation", 8)
		row.add_child(separator)

		_skills_list.add_child(row)


# === Grid Interaction ===

func _on_grid_cell_clicked(grid_pos: Vector2i, button: int) -> void:
	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	# Right-click to use consumables
	if button == MOUSE_BUTTON_RIGHT:
		var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
		if placed and placed.item_data.item_type == Enums.ItemType.CONSUMABLE and placed.item_data.use_skill:
			_on_grid_item_use_requested(placed)
		return

	if button != MOUSE_BUTTON_LEFT:
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


# === Consumable Usage ===
# Out-of-combat consumable usage from stash or grid inventory.

func _on_stash_item_use_requested(item: ItemData, index: int) -> void:
	DebugLogger.log_info("_on_stash_item_use_requested called: item=%s, index=%d, has_use_skill=%s" % [item.display_name if item else "null", index, "yes" if (item and item.use_skill) else "no"], "Inventory")

	if not item.use_skill:
		DebugLogger.log_warn("Aborting: item has no use_skill", "Inventory")
		return

	_pending_consumable = item
	_pending_consumable_source = ConsumableSource.STASH
	_pending_consumable_index = index
	_pending_consumable_placed = null
	DebugLogger.log_info("Showing target selection popup", "Inventory")
	_show_target_selection_popup()


func _on_grid_item_use_requested(placed: GridInventory.PlacedItem) -> void:
	DebugLogger.log_info("_on_grid_item_use_requested called: item=%s, has_use_skill=%s" % [placed.item_data.display_name if placed else "null", "yes" if (placed and placed.item_data.use_skill) else "no"], "Inventory")

	if not placed.item_data.use_skill:
		DebugLogger.log_warn("Aborting: item has no use_skill", "Inventory")
		return

	_pending_consumable = placed.item_data
	_pending_consumable_source = ConsumableSource.GRID
	_pending_consumable_index = -1
	_pending_consumable_placed = placed
	DebugLogger.log_info("Showing target selection popup", "Inventory")
	_show_target_selection_popup()


func _show_target_selection_popup() -> void:
	# Create popup if it doesn't exist
	if not _target_selection_popup:
		_target_selection_popup = PopupPanel.new()
		add_child(_target_selection_popup)
		_target_selection_popup.popup_hide.connect(_on_target_popup_hidden)

	# Clear existing content
	for child in _target_selection_popup.get_children():
		child.queue_free()

	# Create content
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_target_selection_popup.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Select Target"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", Constants.FONT_SIZE_TITLE)
	vbox.add_child(title)

	var separator: HSeparator = HSeparator.new()
	vbox.add_child(separator)

	# Add character buttons
	if not GameManager.party:
		return

	var roster_ids: Array = GameManager.party.roster.keys()
	for i in range(roster_ids.size()):
		var char_id: String = roster_ids[i]
		var char_data: CharacterData = GameManager.party.roster[char_id]
		if not char_data:
			continue

		var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree(char_id)
		var current_hp: int = GameManager.party.get_current_hp(char_id)
		var max_hp: int = GameManager.party.get_max_hp(char_id, tree)
		var current_mp: int = GameManager.party.get_current_mp(char_id)
		var max_mp: int = GameManager.party.get_max_mp(char_id, tree)

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(250, 40)
		btn.text = "%s (HP: %d/%d, MP: %d/%d)" % [char_data.display_name, current_hp, max_hp, current_mp, max_mp]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Disable button if character is dead
		if current_hp <= 0:
			btn.disabled = true
			btn.text += " [DEAD]"

		btn.pressed.connect(_on_target_selected.bind(char_id))
		vbox.add_child(btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_target_selection_popup.hide)
	vbox.add_child(cancel_btn)

	# Show popup centered
	_target_selection_popup.popup_centered()


func _on_target_selected(character_id: String) -> void:
	DebugLogger.log_info("_on_target_selected called: character_id=%s" % character_id, "Inventory")

	# Save locally before hiding (hide triggers popup_hide signal which clears _pending_consumable)
	var item: ItemData = _pending_consumable
	var source: ConsumableSource = _pending_consumable_source
	var index: int = _pending_consumable_index
	var placed: GridInventory.PlacedItem = _pending_consumable_placed

	_target_selection_popup.hide()

	if not item:
		DebugLogger.log_warn("Cannot execute: item is null", "Inventory")
		return

	if source == ConsumableSource.STASH and index < 0:
		DebugLogger.log_warn("Cannot execute: stash item but index=%d" % index, "Inventory")
		return

	if source == ConsumableSource.GRID and not placed:
		DebugLogger.log_warn("Cannot execute: grid item but placed is null", "Inventory")
		return

	DebugLogger.log_info("Calling _execute_consumable (source=%s)" % source, "Inventory")
	_execute_consumable(item, character_id, source, index, placed)


func _execute_consumable(item: ItemData, target_id: String, source: ConsumableSource, stash_index: int = -1, placed: GridInventory.PlacedItem = null) -> void:
	DebugLogger.log_info("_execute_consumable called: item=%s, target=%s, source=%s" % [item.display_name if item else "null", target_id, source], "Inventory")

	if not item.use_skill:
		DebugLogger.log_warn("Item has no use_skill: %s" % item.display_name, "Inventory")
		return

	if not GameManager.party:
		DebugLogger.log_warn("GameManager.party is null", "Inventory")
		return

	var skill: SkillData = item.use_skill
	DebugLogger.log_info("Using skill: %s (heal_amount=%d, heal_percent=%.1f%%)" % [skill.display_name, skill.heal_amount, skill.heal_percent], "Inventory")

	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree(target_id)
	var current_hp_before: int = GameManager.party.get_current_hp(target_id)
	var target_max_hp: int = GameManager.party.get_max_hp(target_id, tree)

	DebugLogger.log_info("Target HP before: %d/%d" % [current_hp_before, target_max_hp], "Inventory")

	# Calculate healing
	var heal: int = DamageCalculator.calculate_healing(
		skill.heal_amount,
		skill.heal_percent,
		target_max_hp
	)

	DebugLogger.log_info("Calculated heal amount: %d" % heal, "Inventory")

	# Apply healing (heal_character handles MP too, but we pass 0 for MP)
	GameManager.party.heal_character(target_id, heal, 0, tree)

	var current_hp_after: int = GameManager.party.get_current_hp(target_id)
	DebugLogger.log_info("Target HP after: %d/%d (healed %d)" % [current_hp_after, target_max_hp, current_hp_after - current_hp_before], "Inventory")

	# Remove item based on source
	if source == ConsumableSource.STASH:
		if stash_index < GameManager.party.stash.size():
			DebugLogger.log_info("Removing item at index %d from stash (stash size: %d)" % [stash_index, GameManager.party.stash.size()], "Inventory")
			GameManager.party.stash.remove_at(stash_index)
			_stash_panel.refresh(GameManager.party.stash)
			EventBus.stash_changed.emit()
		else:
			DebugLogger.log_warn("Stash index out of bounds: %d (stash size: %d)" % [stash_index, GameManager.party.stash.size()], "Inventory")
	elif source == ConsumableSource.GRID:
		if placed:
			var inv: GridInventory = _grid_inventories.get(_current_character_id)
			if inv:
				DebugLogger.log_info("Removing item from grid at (%d, %d)" % [placed.grid_position.x, placed.grid_position.y], "Inventory")
				inv.remove_item(placed)
				_grid_panel.refresh()
				EventBus.inventory_changed.emit(_current_character_id)
			else:
				DebugLogger.log_warn("Grid inventory not found for character: %s" % _current_character_id, "Inventory")
		else:
			DebugLogger.log_warn("Grid placed item is null", "Inventory")

	DebugLogger.log_info("Used %s on %s, healed %d HP" % [item.display_name, target_id, heal], "Inventory")


func _on_target_popup_hidden() -> void:
	_pending_consumable = null
	_pending_consumable_source = ConsumableSource.NONE
	_pending_consumable_index = -1
	_pending_consumable_placed = null


# === Drag and Drop ===

func _start_drag_from_grid(placed: GridInventory.PlacedItem) -> void:
	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if not inv:
		return

	_dragged_item = placed.item_data
	_drag_source = DragSource.GRID
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
	_drag_source = DragSource.STASH
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
		if _drag_source == DragSource.GRID:
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
	if _drag_source == DragSource.GRID:
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
	if _drag_source == DragSource.GRID:
		var inv: GridInventory = _grid_inventories.get(_current_character_id)
		if inv:
			inv.place_item(_dragged_item, _drag_source_pos, _drag_source_rotation)
			_grid_panel.refresh()
	elif _drag_source == DragSource.STASH:
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
	_drag_source = DragSource.NONE
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
	var placed_items: Array = inv.get_all_placed_items()
	for i in range(placed_items.size()):
		var placed: GridInventory.PlacedItem = placed_items[i]
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


func setup_embedded(character_id: String) -> void:
	$VBox/TopBar.visible = false
	$VBox/Content/GridSide/CharacterTabs.visible = false
	_on_character_selected(character_id)
