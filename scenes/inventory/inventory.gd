extends Control
## Main inventory scene orchestrator.
## Manages drag-and-drop between grid and stash, character switching, tooltips.

enum DragState { IDLE, DRAGGING }
enum DragSource { NONE, GRID, STASH }

# --- Child references ---
@onready var _grid_panel: Control = $VBox/Content/MiddleColumn/GridCentering/GridPanel
@onready var _equipment_slots_panel: PanelContainer = $VBox/Content/LeftSidebar/EquipmentSlotsPanel
@onready var _stash_panel: PanelContainer = $VBox/Content/StashPanel
@onready var _character_tabs: HBoxContainer = $VBox/Content/MiddleColumn/CharacterTabs
@onready var _skills_panel: PanelContainer = $VBox/Content/LeftSidebar/SkillsSummaryPanel
@onready var _skills_list: VBoxContainer = $VBox/Content/LeftSidebar/SkillsSummaryPanel/VBox/SkillsScroll/SkillsList
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

# --- Tooltip control ---
var _tooltips_enabled: bool = true  ## Hold T key to hide
var _last_hovered_grid_pos: Variant = null  ## Vector2i or null
var _last_hovered_stash_item: Variant = null  ## ItemData or null
var _last_hovered_stash_global_pos: Vector2 = Vector2.ZERO

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
		_stash_panel.background_clicked.connect(_on_stash_background_clicked)

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
	# No longer needed - stash panel handles its own background clicks via background_clicked signal
	pass


func _unhandled_input(event: InputEvent) -> void:
	# Hold T to temporarily hide tooltips
	if event is InputEventKey and event.keycode == KEY_T:
		if event.pressed:
			# T pressed - hide tooltips
			_tooltips_enabled = false
			_item_tooltip.hide_tooltip()
		else:
			# T released - show tooltips again
			_tooltips_enabled = true
			# Re-show tooltip if still hovering over something
			if _last_hovered_grid_pos != null:
				var inv: GridInventory = _grid_inventories.get(_current_character_id)
				if inv:
					var placed: GridInventory.PlacedItem = inv.get_item_at(_last_hovered_grid_pos)
					if placed:
						_item_tooltip.show_for_item(placed.item_data, placed, inv, get_global_mouse_position())
			elif _last_hovered_stash_item != null:
				_item_tooltip.show_for_item(_last_hovered_stash_item, null, null, _last_hovered_stash_global_pos)
		get_viewport().set_input_as_handled()
		return

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
		_equipment_slots_panel.setup(inv)
	_item_tooltip.hide_tooltip()
	_populate_skills_summary.call_deferred()
	DebugLogger.log_info("Switched to character: %s" % character_id, "Inventory")


func _on_inventory_changed(character_id: String) -> void:
	# Refresh skills summary and equipment slots when inventory changes for current character
	if character_id == _current_character_id:
		_populate_skills_summary.call_deferred()
		_equipment_slots_panel.refresh()


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

	# Collect all skills with their sources
	var skills_map: Dictionary = {}  # skill_id -> {skill: SkillData, sources: [{weapon, gems}]}

	var placed_items: Array = inv.get_all_placed_items()
	for i in range(placed_items.size()):
		var placed: GridInventory.PlacedItem = placed_items[i]
		if placed.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
			var weapon: ItemData = placed.item_data
			var modifiers: Array = inv.get_modifiers_affecting(placed)

			# Get all skills from this weapon
			var all_skills: Array = []

			# Innate weapon skills
			for j in range(weapon.granted_skills.size()):
				all_skills.append(weapon.granted_skills[j])

			# Conditional skills from gems
			var computed: Dictionary = inv.get_computed_stats()
			var tool_states: Dictionary = computed.get("tool_states", {})
			var state = tool_states.get(placed, null)
			if state:
				for j in range(state.conditional_skills.size()):
					all_skills.append(state.conditional_skills[j])

			# Add each skill to the map
			for j in range(all_skills.size()):
				var skill: SkillData = all_skills[j]
				if skill:
					if not skills_map.has(skill.id):
						skills_map[skill.id] = {"skill": skill, "sources": []}

					# Add source (weapon + gems)
					var source_gems: Array = []
					for k in range(modifiers.size()):
						source_gems.append(modifiers[k].item_data.display_name)

					skills_map[skill.id]["sources"].append({
						"weapon": weapon.display_name,
						"gems": source_gems
					})

	if skills_map.is_empty():
		var label: Label = Label.new()
		label.text = "No skills available"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SECONDARY)
		_skills_list.add_child(label)
		return

	# Create collapsible skill entries
	var keys: Array = skills_map.keys()
	for i in range(keys.size()):
		var skill_id: String = keys[i]
		var entry: Dictionary = skills_map[skill_id]
		var skill: SkillData = entry["skill"]
		var sources: Array = entry["sources"]

		_create_skill_entry(skill, sources)

		# Add separator between skills
		if i < keys.size() - 1:
			var separator: HSeparator = HSeparator.new()
			separator.add_theme_constant_override("separation", 6)
			_skills_list.add_child(separator)


func _create_skill_entry(skill: SkillData, sources: Array) -> void:
	var container: VBoxContainer = VBoxContainer.new()
	container.add_theme_constant_override("separation", 3)

	# Header row with skill name and MP cost
	var header: HBoxContainer = HBoxContainer.new()

	# Clickable button for expand/collapse
	var expand_btn: Button = Button.new()
	expand_btn.toggle_mode = true
	expand_btn.flat = true
	expand_btn.text = "▸"
	expand_btn.custom_minimum_size = Vector2(20, 0)
	expand_btn.add_theme_font_size_override("font_size", Constants.FONT_SIZE_NORMAL)
	expand_btn.add_theme_color_override("font_color", Constants.COLOR_TEXT_SKILL)
	header.add_child(expand_btn)

	# Skill name
	var name_label: Label = Label.new()
	name_label.text = skill.display_name.to_upper()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_NORMAL)
	name_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SKILL)
	header.add_child(name_label)

	# MP cost (right aligned)
	var mp_label: Label = Label.new()
	mp_label.text = "MP: %d" % skill.mp_cost
	mp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mp_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_SMALL)
	mp_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	header.add_child(mp_label)

	container.add_child(header)

	# Source weapons (always visible)
	var source_weapons: Array = []
	for i in range(sources.size()):
		var source: Dictionary = sources[i]
		var weapon_name: String = source["weapon"]
		if not source_weapons.has(weapon_name):
			source_weapons.append(weapon_name)

	var sources_label: Label = Label.new()
	sources_label.text = "     " + " / ".join(source_weapons)
	sources_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_SMALL)
	sources_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(sources_label)

	# Details panel (initially hidden, shown on expand)
	var details: VBoxContainer = VBoxContainer.new()
	details.add_theme_constant_override("separation", 2)
	details.visible = false

	# Power/Type if applicable
	if skill.has_damage():
		var scaling_label: Label = Label.new()
		var parts: Array = []
		if skill.physical_scaling > 0.0:
			parts.append("Phys: %.1fx" % skill.physical_scaling)
		if skill.magical_scaling > 0.0:
			parts.append("Mag: %.1fx" % skill.magical_scaling)
		scaling_label.text = "     Scaling: %s" % " / ".join(parts)
		scaling_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_SMALL)
		scaling_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
		details.add_child(scaling_label)

	# Description
	if not skill.description.is_empty():
		var desc_label: Label = Label.new()
		desc_label.text = "     " + skill.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_SMALL)
		desc_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SECONDARY)
		details.add_child(desc_label)

	# Gem modifiers (if any)
	for i in range(sources.size()):
		var source: Dictionary = sources[i]
		if not source["gems"].is_empty():
			var gems_label: Label = Label.new()
			gems_label.text = "     + " + ", ".join(source["gems"])
			gems_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_SMALL)
			gems_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_MODIFIER)
			details.add_child(gems_label)

	container.add_child(details)

	# Toggle button handler
	expand_btn.toggled.connect(func(pressed: bool) -> void:
		details.visible = pressed
		expand_btn.text = "▾" if pressed else "▸"
	)

	_skills_list.add_child(container)


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
		# Note: Upgradeable highlighting is handled in _update_drag_preview()
	else:
		# Show tooltip and modifier highlights for hovered item
		var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
		if placed:
			_last_hovered_grid_pos = grid_pos
			_last_hovered_stash_item = null
			_grid_panel.highlight_modifier_connections(placed)
			if _tooltips_enabled:
				_item_tooltip.show_for_item(placed.item_data, placed, inv, get_global_mouse_position())
		else:
			_last_hovered_grid_pos = null
			_last_hovered_stash_item = null
			_grid_panel.clear_highlights()
			_item_tooltip.hide_tooltip()


# === Stash Interaction ===

func _on_stash_item_clicked(item: ItemData, index: int) -> void:
	if _drag_state == DragState.DRAGGING:
		# Check for item upgrade opportunity
		DebugLogger.log_info("Stash item clicked while dragging: dragged=%s (id=%s, rarity=%d), target=%s (id=%s, rarity=%d)" % [
			_dragged_item.display_name if _dragged_item else "null",
			_dragged_item.id if _dragged_item else "null",
			_dragged_item.rarity if _dragged_item else -1,
			item.display_name if item else "null",
			item.id if item else "null",
			item.rarity if item else -1
		], "Inventory")

		if ItemUpgradeSystem.can_upgrade(_dragged_item, item):
			DebugLogger.log_info("Upgrade possible! Performing stash upgrade", "Inventory")
			_perform_stash_upgrade(item, index)
			return
		else:
			DebugLogger.log_info("Upgrade not possible - items don't match", "Inventory")

		# Drop current item to stash
		_return_to_stash()
	else:
		# Pick up from stash
		_start_drag_from_stash(item, index)


func _on_stash_item_hovered(item: ItemData, global_pos: Vector2) -> void:
	if _drag_state == DragState.IDLE:
		_last_hovered_stash_item = item
		_last_hovered_stash_global_pos = global_pos
		_last_hovered_grid_pos = null
		if _tooltips_enabled:
			_item_tooltip.show_for_item(item, null, null, global_pos)


func _on_stash_background_clicked() -> void:
	# Return dragged item to stash when clicking stash background (not on an item)
	if _drag_state == DragState.DRAGGING:
		_return_to_stash()


func _on_item_hover_exited() -> void:
	if _drag_state == DragState.IDLE:
		_last_hovered_grid_pos = null
		_last_hovered_stash_item = null
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

	# Show placement preview immediately at current mouse position
	var mouse_grid_pos: Vector2i = _grid_panel.world_to_grid(get_global_mouse_position())
	_grid_panel.show_placement_preview(_dragged_item, mouse_grid_pos, _drag_rotation)
	var can_place: bool = inv.can_place(_dragged_item, mouse_grid_pos, _drag_rotation)
	_drag_preview.set_valid(can_place)

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

	# Show placement preview immediately at current mouse position
	var inv: GridInventory = _grid_inventories.get(_current_character_id)
	if inv:
		var mouse_grid_pos: Vector2i = _grid_panel.world_to_grid(get_global_mouse_position())
		_grid_panel.show_placement_preview(_dragged_item, mouse_grid_pos, _drag_rotation)
		var can_place: bool = inv.can_place(_dragged_item, mouse_grid_pos, _drag_rotation)
		_drag_preview.set_valid(can_place)

	DebugLogger.log_info("Picked up %s from stash" % _dragged_item.display_name, "Inventory")


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

		# Log upgrade
		DebugLogger.log_info("UPGRADE! %s + %s → %s" % [
			_dragged_item.display_name,
			target_placed.item_data.display_name,
			upgraded_item.display_name
		], "Inventory")

		# TODO: Add visual/audio effect for upgrade

	_end_drag()


func _perform_stash_upgrade(target_item: ItemData, target_index: int) -> void:
	# Create upgraded item
	var upgraded_item: ItemData = ItemUpgradeSystem.create_upgraded_item(target_item)

	# Remove target item from stash
	GameManager.party.stash.remove_at(target_index)

	# Add upgraded item to stash
	GameManager.party.add_to_stash(upgraded_item)

	# Refresh stash display
	_stash_panel.refresh(GameManager.party.stash)

	# Emit signal
	EventBus.stash_changed.emit()

	# Log upgrade
	DebugLogger.log_info("STASH UPGRADE! %s + %s → %s" % [
		_dragged_item.display_name,
		target_item.display_name,
		upgraded_item.display_name
	], "Inventory")

	# End drag
	_end_drag()


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

	# Always highlight ALL upgradeable items (grid + stash) when dragging
	_grid_panel.highlight_upgradeable_items(_dragged_item)
	_stash_panel.highlight_upgradeable_items(_dragged_item)


func _end_drag() -> void:
	_drag_state = DragState.IDLE
	_dragged_item = null
	_drag_source = DragSource.NONE
	_drag_source_placed = null
	_drag_source_stash_index = -1
	_drag_preview.hide_preview()
	_stash_panel.highlight_drop_target(false)
	_stash_panel.clear_upgradeable_highlights()
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
	$VBox/Content/MiddleColumn/CharacterTabs.visible = false
	_on_character_selected(character_id)
