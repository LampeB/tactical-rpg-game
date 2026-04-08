extends Control
## Inventory panel — grid + stash + drag/drop + compact stats sidebar.
## Used in the game menu's Inventory tab. Lighter than character_stats.gd.

@onready var _grid_panel: Control = $Content/CenterPanel/VBox/GridCentering/GridPanel
@onready var _element_bar: HBoxContainer = $Content/CenterPanel/VBox/ElementBar
@onready var _stash_panel: PanelContainer = $Content/RightPanel/VBox/StashPanel
@onready var _item_tooltip: PanelContainer = $Content/RightPanel/VBox/ItemTooltip
@onready var _drag_preview: Control = $DragLayer/DragPreview
@onready var _left_panel: PanelContainer = $Content/LeftPanel

var _current_character_id: String = ""
var _drag := InventoryDragState.new()
var _tooltips_enabled: bool = true
var _last_hovered_grid_pos: Variant = null
var _last_hovered_stash_item: Variant = null
var _last_hovered_stash_global_pos: Vector2 = Vector2.ZERO
var _discard_dialog: ConfirmationDialog
var _equipment_panel: PanelContainer = null
var _pending_discard_item: ItemData = null
var _pending_discard_index: int = -1


func _ready() -> void:
	# Grid interaction
	_grid_panel.cell_clicked.connect(_on_grid_cell_clicked)
	_grid_panel.cell_pressed.connect(_on_grid_cell_pressed)
	_grid_panel.cell_released.connect(_on_grid_cell_released)
	_grid_panel.cell_hovered.connect(_on_grid_cell_hovered)
	_grid_panel.cell_exited.connect(_on_hover_exited)

	# Stash interaction
	if GameManager.party:
		_stash_panel.refresh(GameManager.party.stash)
	_stash_panel.item_clicked.connect(_on_stash_item_clicked)
	_stash_panel.item_hovered.connect(_on_stash_item_hovered)
	_stash_panel.item_exited.connect(_on_hover_exited)
	_stash_panel.item_discard_requested.connect(_on_stash_discard_requested)
	_stash_panel.background_clicked.connect(_on_stash_background_clicked)

	_discard_dialog = ConfirmationDialog.new()
	_discard_dialog.title = "Discard Item"
	_discard_dialog.confirmed.connect(_on_discard_confirmed)
	add_child(_discard_dialog)

	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.stash_changed.connect(_on_stash_changed)


func setup_embedded(character_id: String) -> void:
	_current_character_id = character_id
	_item_tooltip.embedded = true
	_item_tooltip.show_empty_state()
	_refresh_all()


func _refresh_all() -> void:
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if inv:
		_grid_panel.setup(inv)
		_update_element_bar(inv)
	if GameManager.party:
		_stash_panel.refresh(GameManager.party.stash)
	_build_compact_left_panel()


# ---------------------------------------------------------------------------
# Compact Left Panel (stats summary + equipment slots)
# ---------------------------------------------------------------------------

func _build_compact_left_panel() -> void:
	for child in _left_panel.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_left_panel.add_child(vbox)

	var char_data: CharacterData = GameManager.party.roster.get(_current_character_id) if GameManager.party else null
	if not char_data:
		return

	# Name + class
	var name_lbl := Label.new()
	name_lbl.text = char_data.display_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	vbox.add_child(name_lbl)

	var class_lbl := Label.new()
	class_lbl.text = char_data.character_class
	class_lbl.add_theme_font_size_override("font_size", 13)
	class_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(class_lbl)

	# HP/MP
	if GameManager.party:
		var hp_cur: int = GameManager.party.get_current_hp(_current_character_id)
		var hp_max: int = char_data.max_hp
		var mp_cur: int = GameManager.party.get_current_mp(_current_character_id)
		var mp_max: int = char_data.max_mp

		var hp_lbl := Label.new()
		hp_lbl.text = "HP: %d / %d" % [hp_cur, hp_max]
		hp_lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(hp_lbl)
		var hp_bar := TextureProgressBar.new()
		hp_bar.max_value = hp_max
		hp_bar.value = hp_cur
		hp_bar.custom_minimum_size = Vector2(0, 14)
		hp_bar.nine_patch_stretch = true
		hp_bar.stretch_margin_left = 4
		hp_bar.stretch_margin_top = 4
		hp_bar.stretch_margin_right = 4
		hp_bar.stretch_margin_bottom = 4
		hp_bar.texture_under = preload("res://assets/sprites/ui/bars/hp_empty.png")
		hp_bar.texture_over = preload("res://assets/sprites/ui/bars/hp_frame.png")
		hp_bar.texture_progress = preload("res://assets/sprites/ui/bars/hp_fill.png")
		vbox.add_child(hp_bar)

		var mp_lbl := Label.new()
		mp_lbl.text = "MP: %d / %d" % [mp_cur, mp_max]
		mp_lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(mp_lbl)
		var mp_bar := TextureProgressBar.new()
		mp_bar.max_value = mp_max
		mp_bar.value = mp_cur
		mp_bar.custom_minimum_size = Vector2(0, 12)
		mp_bar.nine_patch_stretch = true
		mp_bar.stretch_margin_left = 4
		mp_bar.stretch_margin_top = 4
		mp_bar.stretch_margin_right = 4
		mp_bar.stretch_margin_bottom = 4
		mp_bar.texture_under = preload("res://assets/sprites/ui/bars/mp_empty.png")
		mp_bar.texture_over = preload("res://assets/sprites/ui/bars/mp_frame.png")
		mp_bar.texture_progress = preload("res://assets/sprites/ui/bars/mp_fill.png")
		vbox.add_child(mp_bar)

	# Key stats — grouped by Offense / Defense
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if inv:
		vbox.add_child(HSeparator.new())
		var entity: CombatEntity = CombatEntity.from_character(char_data, inv, {})
		var equip_stats: Dictionary = inv.get_computed_stats().get("stats", {})

		# === OFFENSE ===
		_add_section_header(vbox, "Offense")
		for stat_info in [
			["Phys. Attack", Enums.Stat.PHYSICAL_ATTACK],
			["Mag. Attack", Enums.Stat.MAGICAL_ATTACK],
			["Speed", Enums.Stat.SPEED],
		]:
			_add_stat_row(vbox, char_data, equip_stats, stat_info[0], stat_info[1])

		var crit_rate: float = Constants.BASE_CRITICAL_RATE * 100.0 + equip_stats.get(Enums.Stat.CRITICAL_RATE, 0.0)
		var crit_dmg: float = Constants.BASE_CRITICAL_DAMAGE * 100.0 + equip_stats.get(Enums.Stat.CRITICAL_DAMAGE, 0.0)
		_add_pct_row(vbox, "Crit Rate", crit_rate, equip_stats.get(Enums.Stat.CRITICAL_RATE, 0.0) > 0)
		_add_pct_row(vbox, "Crit Damage", crit_dmg, equip_stats.get(Enums.Stat.CRITICAL_DAMAGE, 0.0) > 0)

		vbox.add_child(HSeparator.new())

		# === DEFENSE ===
		_add_section_header(vbox, "Defense")
		_add_stat_row(vbox, char_data, equip_stats, "Phys. Defense", Enums.Stat.PHYSICAL_DEFENSE)
		_add_stat_row(vbox, char_data, equip_stats, "Mag. Defense", Enums.Stat.MAGICAL_DEFENSE)

		# Armor pools (refilled each turn)
		var armor_row := HBoxContainer.new()
		var armor_lbl := Label.new()
		armor_lbl.text = "Phys. Armor"
		armor_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		armor_lbl.add_theme_font_size_override("font_size", 13)
		armor_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58))
		armor_row.add_child(armor_lbl)
		var armor_val := Label.new()
		armor_val.text = "%d / turn" % entity.base_armor
		armor_val.add_theme_font_size_override("font_size", 13)
		armor_val.add_theme_color_override("font_color", Color(0.85, 0.65, 0.4) if entity.base_armor > 0 else Color(0.5, 0.5, 0.5))
		armor_row.add_child(armor_val)
		vbox.add_child(armor_row)

		var spirit_row := HBoxContainer.new()
		var spirit_lbl := Label.new()
		spirit_lbl.text = "Spirit Shield"
		spirit_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spirit_lbl.add_theme_font_size_override("font_size", 13)
		spirit_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58))
		spirit_row.add_child(spirit_lbl)
		var spirit_val := Label.new()
		spirit_val.text = "%d / turn" % entity.base_spirit_shield
		spirit_val.add_theme_font_size_override("font_size", 13)
		spirit_val.add_theme_color_override("font_color", Color(0.55, 0.65, 0.95) if entity.base_spirit_shield > 0 else Color(0.5, 0.5, 0.5))
		spirit_row.add_child(spirit_val)
		vbox.add_child(spirit_row)

	# Equipment slots
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)
	var equip_title := Label.new()
	equip_title.text = "Equipment"
	equip_title.add_theme_font_size_override("font_size", 15)
	equip_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(equip_title)
	if inv:
		_equipment_panel = load("res://scenes/inventory/ui/equipment_slots_panel.tscn").instantiate()
		vbox.add_child(_equipment_panel)
		_equipment_panel.setup(inv)


func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	parent.add_child(lbl)


func _add_stat_row(parent: VBoxContainer, char_data: CharacterData, equip_stats: Dictionary, label_text: String, stat_id: int) -> void:
	var base_val: int = char_data.get_base_stat(stat_id)
	var equip_bonus: int = int(equip_stats.get(stat_id, 0.0))
	var total: int = base_val + equip_bonus
	var row := HBoxContainer.new()
	var lbl_name := Label.new()
	lbl_name.text = label_text
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.add_theme_font_size_override("font_size", 13)
	lbl_name.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58))
	row.add_child(lbl_name)
	var lbl_val := Label.new()
	lbl_val.text = str(total)
	lbl_val.add_theme_font_size_override("font_size", 13)
	lbl_val.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75) if equip_bonus == 0 else Color(0.4, 1.0, 0.4))
	row.add_child(lbl_val)
	parent.add_child(row)


func _add_pct_row(parent: VBoxContainer, label_text: String, value: float, has_bonus: bool) -> void:
	var row := HBoxContainer.new()
	var lbl_name := Label.new()
	lbl_name.text = label_text
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.add_theme_font_size_override("font_size", 13)
	lbl_name.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58))
	row.add_child(lbl_name)
	var lbl_val := Label.new()
	lbl_val.text = "%.0f%%" % value
	lbl_val.add_theme_font_size_override("font_size", 13)
	lbl_val.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75) if not has_bonus else Color(0.9, 0.75, 0.3))
	row.add_child(lbl_val)
	parent.add_child(row)


# ---------------------------------------------------------------------------
# Element Bar
# ---------------------------------------------------------------------------

func _update_element_bar(inv: GridInventory) -> void:
	for child in _element_bar.get_children():
		child.queue_free()
	_element_bar.add_theme_constant_override("separation", 6)
	var element_points: Dictionary = inv.get_element_points() if inv else {}

	# Show all 7 elements in Enums.Element order
	for element_id in range(7):
		var points: int = element_points.get(element_id, 0)
		var has_points: bool = points > 0
		var elem_name: String = Constants.ELEMENT_NAMES.get(element_id, "?")
		var icon_tex: Texture2D
		if has_points:
			icon_tex = Constants.ELEMENT_ICONS.get(element_id, null)
		else:
			icon_tex = Constants.ELEMENT_ICONS_FADED.get(element_id, null)

		var slot := Control.new()
		slot.custom_minimum_size = Vector2(36, 36)
		slot.tooltip_text = "%s: %d" % [elem_name, points]

		if icon_tex:
			var icon := TextureRect.new()
			icon.texture = icon_tex
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			slot.add_child(icon)

		# Number overlay — centered
		var num := Label.new()
		num.text = str(points)
		num.add_theme_font_size_override("font_size", 14)
		num.add_theme_color_override("font_color", Color.WHITE)
		num.add_theme_color_override("font_outline_color", Color.BLACK)
		num.add_theme_constant_override("outline_size", 4)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.set_anchors_preset(Control.PRESET_FULL_RECT)
		if not has_points:
			num.modulate = Color(1, 1, 1, 0.5)
		slot.add_child(num)

		_element_bar.add_child(slot)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# CTRL hold locks the tooltip on the currently displayed item; release clears it
	if event is InputEventKey and event.keycode == KEY_CTRL:
		_item_tooltip.locked = event.pressed
		if not event.pressed:
			_clear_hover()

	if _drag.is_dragging():
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _drag.is_same_frame_release(Engine.get_process_frames()):
				return
			_on_mouse_released()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _drag.is_dragging():
		_update_drag_preview()


func _on_mouse_released() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var over_grid: bool = _grid_panel.get_global_rect().has_point(mouse_pos)
	var over_stash: bool = _stash_panel.is_mouse_over()
	if over_grid:
		var grid_pos: Vector2i = _grid_panel.world_to_grid(mouse_pos) - _drag_preview.get_center_cell_offset()
		_try_place_item(grid_pos)
		if _drag.is_dragging():
			_cancel_drag()
	elif over_stash:
		_return_to_stash()
	else:
		_cancel_drag()


# ---------------------------------------------------------------------------
# Grid Interaction
# ---------------------------------------------------------------------------

func _on_grid_cell_clicked(grid_pos: Vector2i, button: int) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		if _drag.is_dragging():
			_rotate_dragged_item()
		else:
			var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
			if inv:
				var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
				if placed and placed.item_data.item_type == Enums.ItemType.CONSUMABLE and placed.item_data.use_skill:
					pass  # TODO: consumable use
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		return
	if not _drag.is_dragging() and not inv.grid_template.is_cell_active(grid_pos):
		var char_data: CharacterData = GameManager.party.roster.get(_current_character_id)
		if char_data and not char_data.backpack_tiers.is_empty():
			var state := GameManager.party.get_or_init_backpack_state(char_data)
			if BackpackUpgradeSystem.get_purchasable_cells(char_data, state).has(grid_pos):
				if GameManager.buy_backpack_cell(_current_character_id, grid_pos):
					_grid_panel.refresh()


func _on_grid_cell_pressed(grid_pos: Vector2i, button: int) -> void:
	_stash_panel.clear_displaced_highlights()
	if button != MOUSE_BUTTON_LEFT or _drag.is_dragging():
		return
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		return
	var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if placed:
		_start_drag_from_grid(placed, grid_pos)


func _on_grid_cell_released(grid_pos: Vector2i, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT or not _drag.is_dragging():
		return
	var adjusted_pos: Vector2i = grid_pos - _drag_preview.get_center_cell_offset()
	_try_place_item(adjusted_pos)
	if _drag.is_dragging():
		_cancel_drag()


func _on_grid_cell_hovered(grid_pos: Vector2i) -> void:
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		return
	if _drag.is_dragging():
		return
	var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if placed:
		_last_hovered_grid_pos = grid_pos
		_last_hovered_stash_item = null
		_grid_panel.show_hover_feedback(placed)
		if _tooltips_enabled:
			_item_tooltip.show_for_item(placed.item_data, placed, inv, get_global_mouse_position())
	elif not inv.grid_template.is_cell_active(grid_pos):
		var char_data: CharacterData = GameManager.party.roster.get(_current_character_id)
		if char_data and not char_data.backpack_tiers.is_empty():
			var state := GameManager.party.get_or_init_backpack_state(char_data)
			if BackpackUpgradeSystem.get_purchasable_cells(char_data, state).has(grid_pos):
				var cost := BackpackUpgradeSystem.get_next_cell_cost(char_data, state)
				_grid_panel.set_cell_purchasable(grid_pos)
				if _tooltips_enabled:
					_item_tooltip.show_for_cell_purchase(cost, GameManager.gold >= cost, get_global_mouse_position())
				return
		_clear_hover()
	else:
		_clear_hover()


func _on_hover_exited() -> void:
	if not _drag.is_dragging():
		_clear_hover()


func _clear_hover() -> void:
	_last_hovered_grid_pos = null
	_last_hovered_stash_item = null
	_grid_panel.clear_hover_feedback()
	_item_tooltip.hide_tooltip()


# ---------------------------------------------------------------------------
# Stash Interaction
# ---------------------------------------------------------------------------

func _on_stash_item_clicked(item: ItemData, index: int) -> void:
	_stash_panel.clear_displaced_highlights()
	if _drag.is_dragging():
		if ItemUpgradeSystem.can_upgrade(_drag.item, item):
			_perform_stash_upgrade(item, index)
			return
		_return_to_stash()
	else:
		_start_drag_from_stash(item, index)


func _on_stash_item_hovered(item: ItemData, global_pos: Vector2) -> void:
	if not _drag.is_dragging():
		_last_hovered_stash_item = item
		_last_hovered_stash_global_pos = global_pos
		var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
		_item_tooltip.show_for_item(item, null, inv, global_pos)


func _on_stash_background_clicked() -> void:
	if _drag.is_dragging():
		_return_to_stash()


func _on_stash_discard_requested(item: ItemData, index: int) -> void:
	_pending_discard_item = item
	_pending_discard_index = index
	_discard_dialog.dialog_text = "Discard %s?" % item.display_name
	_discard_dialog.popup_centered()


func _on_discard_confirmed() -> void:
	if _pending_discard_item and _pending_discard_index >= 0:
		if _pending_discard_index < GameManager.party.stash.size():
			GameManager.party.stash.remove_at(_pending_discard_index)
			_stash_panel.refresh(GameManager.party.stash)
			EventBus.stash_changed.emit()
	_pending_discard_item = null
	_pending_discard_index = -1


func _on_stash_changed() -> void:
	if GameManager.party:
		_stash_panel.refresh(GameManager.party.stash)


func _on_inventory_changed(_char_id: String) -> void:
	if _equipment_panel and is_instance_valid(_equipment_panel):
		_equipment_panel.refresh()
	_grid_panel.refresh()
	_update_element_bar(GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null)


# ---------------------------------------------------------------------------
# Drag & Drop
# ---------------------------------------------------------------------------

func _start_drag_from_grid(placed: GridInventory.PlacedItem, clicked_pos: Vector2i = Vector2i(-1, -1)) -> void:
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		return
	_drag.start_from_grid(placed, Engine.get_process_frames())
	inv.remove_item(placed)
	_grid_panel.refresh()

	var anchor: Vector2i = Vector2i(-1, -1)
	if clicked_pos != Vector2i(-1, -1):
		anchor = clicked_pos - placed.grid_position
	_drag_preview.cell_size = _grid_panel.cell_size
	_drag_preview.setup(_drag.item, _drag.rotation, anchor)

	var mouse_grid_pos: Vector2i = _grid_panel.world_to_grid(get_global_mouse_position()) - _drag_preview.get_center_cell_offset()
	_drag.last_preview_grid_pos = mouse_grid_pos
	_grid_panel.show_placement_preview(_drag.item, mouse_grid_pos, _drag.rotation)
	var can_place: bool = inv.can_place(_drag.item, mouse_grid_pos, _drag.rotation)
	_drag_preview.set_valid(can_place)


func _start_drag_from_stash(item: ItemData, index: int) -> void:
	_drag.start_from_stash(item, index, Engine.get_process_frames())
	GameManager.party.stash.remove_at(index)
	_stash_panel.refresh(GameManager.party.stash)
	_item_tooltip.hide_tooltip()

	_drag_preview.cell_size = _grid_panel.cell_size
	_drag_preview.setup(_drag.item, _drag.rotation)

	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if inv:
		var mouse_grid_pos: Vector2i = _grid_panel.world_to_grid(get_global_mouse_position()) - _drag_preview.get_center_cell_offset()
		_drag.last_preview_grid_pos = mouse_grid_pos
		_grid_panel.show_placement_preview(_drag.item, mouse_grid_pos, _drag.rotation)
		var can_place: bool = inv.can_place(_drag.item, mouse_grid_pos, _drag.rotation)
		_drag_preview.set_valid(can_place)


func _try_place_item(grid_pos: Vector2i) -> void:
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		return

	var target_item: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if target_item and ItemUpgradeSystem.can_upgrade(_drag.item, target_item.item_data):
		_perform_item_upgrade(inv, target_item)
		return

	if inv.can_place(_drag.item, grid_pos, _drag.rotation):
		var item: ItemData = _drag.item
		var was_from_stash: bool = (_drag.source == InventoryDragState.Source.STASH)
		var placed: GridInventory.PlacedItem = inv.place_item(item, grid_pos, _drag.rotation)
		if not placed:
			return
		_end_drag()
		_grid_panel.refresh()
		EventBus.item_placed.emit(_current_character_id, item, grid_pos)
		EventBus.inventory_changed.emit(_current_character_id)
		if was_from_stash:
			EventBus.stash_changed.emit()
		return

	# Displacement
	var blockers: Array = inv.get_blocking_items(_drag.item, grid_pos, _drag.rotation)
	if blockers.is_empty():
		return
	var saved_blockers: Array = []
	for bi in range(blockers.size()):
		saved_blockers.append({"data": blockers[bi].item_data, "pos": blockers[bi].grid_position, "rot": blockers[bi].rotation})
	for bi in range(blockers.size()):
		inv.remove_item(blockers[bi])
	var can_place_now: bool = inv.can_place(_drag.item, grid_pos, _drag.rotation)
	if not can_place_now:
		for ri in range(saved_blockers.size()):
			inv.place_item(saved_blockers[ri]["data"], saved_blockers[ri]["pos"], saved_blockers[ri]["rot"])
		return

	var displaced_items: Array[ItemData] = []
	for si in range(saved_blockers.size()):
		displaced_items.append(saved_blockers[si]["data"])

	var item: ItemData = _drag.item
	var placed: GridInventory.PlacedItem = inv.place_item(item, grid_pos, _drag.rotation)
	if not placed:
		for bi in range(saved_blockers.size()):
			inv.place_item(displaced_items[bi], saved_blockers[bi]["pos"], saved_blockers[bi]["rot"])
		return

	var first_displaced_idx: int = GameManager.party.stash.size()
	for di in range(displaced_items.size()):
		GameManager.party.stash.append(displaced_items[di])

	_end_drag()
	_grid_panel.refresh()
	_stash_panel.refresh(GameManager.party.stash)
	for di in range(displaced_items.size()):
		_stash_panel.highlight_displaced_item(first_displaced_idx + di)
	EventBus.item_placed.emit(_current_character_id, item, grid_pos)
	EventBus.inventory_changed.emit(_current_character_id)
	EventBus.stash_changed.emit()


func _perform_item_upgrade(inv: GridInventory, target_placed: GridInventory.PlacedItem) -> void:
	var upgraded_item: ItemData = ItemUpgradeSystem.create_upgraded_item(target_placed.item_data)
	var target_pos: Vector2i = target_placed.grid_position
	var target_rot: int = target_placed.rotation
	inv.remove_item(target_placed)
	var new_placed: GridInventory.PlacedItem = inv.place_item(upgraded_item, target_pos, target_rot)
	if not new_placed:
		inv.place_item(target_placed.item_data, target_pos, target_rot)
	_end_drag()
	_grid_panel.refresh()
	EventBus.inventory_changed.emit(_current_character_id)


func _perform_stash_upgrade(target_item: ItemData, target_index: int) -> void:
	var upgraded_item: ItemData = ItemUpgradeSystem.create_upgraded_item(target_item)
	GameManager.party.stash.remove_at(target_index)
	if not GameManager.party.add_to_stash(upgraded_item):
		GameManager.party.force_add_to_stash(upgraded_item)
	_end_drag()
	_stash_panel.refresh(GameManager.party.stash)
	EventBus.stash_changed.emit()


func _return_to_stash() -> void:
	if not _drag.item:
		return
	if not GameManager.party.add_to_stash(_drag.item):
		EventBus.show_message.emit("Stash is full!")
		return
	_end_drag()
	_stash_panel.refresh(GameManager.party.stash)
	EventBus.stash_changed.emit()


func _cancel_drag() -> void:
	if not _drag.item:
		_end_drag()
		return
	if _drag.source == InventoryDragState.Source.GRID:
		var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
		if inv:
			inv.place_item(_drag.item, _drag.source_pos, _drag.source_rotation)
			_grid_panel.refresh()
	elif _drag.source == InventoryDragState.Source.STASH:
		GameManager.party.stash.insert(mini(_drag.source_stash_index, GameManager.party.stash.size()), _drag.item)
		_stash_panel.refresh(GameManager.party.stash)
	_end_drag()


func _rotate_dragged_item() -> void:
	if not _drag.item:
		return
	_drag.rotate_cw()
	_drag_preview.rotate_cw()
	_drag.last_preview_grid_pos = Vector2i(-999, -999)
	EventBus.item_rotated.emit(_current_character_id, _drag.item)


func _update_drag_preview() -> void:
	_stash_panel.highlight_drop_target(_stash_panel.is_mouse_over())
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv or not _drag.item:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var over_active: bool = false
	if _grid_panel.get_global_rect().has_point(mouse_pos) and _drag.item.shape:
		var grid_pos: Vector2i = _grid_panel.world_to_grid(mouse_pos) - _drag_preview.get_center_cell_offset()
		var shape_cells: Array[Vector2i] = _drag.item.shape.get_rotated_cells(_drag.rotation)
		for sc in shape_cells:
			var target: Vector2i = grid_pos + sc
			if inv.grid_template.is_cell_active(target):
				over_active = true
				break

	_drag_preview.set_reach_visible(not over_active)

	if over_active:
		var grid_pos: Vector2i = _grid_panel.world_to_grid(mouse_pos) - _drag_preview.get_center_cell_offset()
		if grid_pos != _drag.last_preview_grid_pos:
			_drag.last_preview_grid_pos = grid_pos
			_grid_panel.show_placement_preview(_drag.item, grid_pos, _drag.rotation)
			var placeable: bool = inv.can_place(_drag.item, grid_pos, _drag.rotation)
			_drag_preview.set_valid(placeable)
	else:
		if _drag.last_preview_grid_pos != Vector2i(-999, -999):
			_drag.last_preview_grid_pos = Vector2i(-999, -999)
			_grid_panel.clear_placement_preview()

	_grid_panel.highlight_upgradeable_items(_drag.item)
	_stash_panel.highlight_upgradeable_items(_drag.item)


func _end_drag() -> void:
	_drag.reset()
	_drag_preview.hide_preview()
	_stash_panel.highlight_drop_target(false)
	_stash_panel.clear_upgradeable_highlights()
	_grid_panel.clear_placement_preview()
