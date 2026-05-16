extends Control
## Character stat screen with inventory grid and stash.
## Shows character info, stat breakdown, inventory grid, skills panel, and stash.

@onready var _bg: ColorRect = $BG
@onready var _back_btn: Button = $Window/VBox/TopBar/HBox/BackButton
@warning_ignore("unused_private_class_variable")
@onready var _title: Label = $Window/VBox/TopBar/HBox/Title
@onready var _gold_label: Label = $Window/VBox/Content/LeftPanel/Body/Gold
@onready var _character_tabs: VBoxContainer = $Window/VBox/Content/LeftPanel/Body/CharacterTabs

# Left panel

# Center panel
@onready var _inventory_label: SectionHeader = $Window/VBox/Content/CenterPanel/VBox/InventoryLabel
@onready var _grid_panel: Control = $Window/VBox/Content/CenterPanel/VBox/GridStashHBox/GridCentering/GridPanel

# Center panel - element bar
@onready var _element_bar: HBoxContainer = $Window/VBox/Content/CenterPanel/VBox/ElementBar

# Right panel
@onready var _skills_header: Label = $Window/VBox/Content/RightPanel/VBox/TopSlot/SkillsHeader
@onready var _skills_sep: HSeparator = $Window/VBox/Content/RightPanel/VBox/TopSlot/HSeparator
@onready var _skills_scroll: ScrollContainer = $Window/VBox/Content/RightPanel/VBox/TopSlot/SkillsScroll
@onready var _skills_list: VBoxContainer = $Window/VBox/Content/RightPanel/VBox/TopSlot/SkillsScroll/SkillsList
@onready var _item_tooltip: PanelContainer = $Window/VBox/Content/RightPanel/VBox/ItemTooltip
@onready var _top_slot: Control = $Window/VBox/Content/RightPanel/VBox/TopSlot
@onready var _stats_bars: VBoxContainer = $Window/VBox/Content/RightPanel/VBox/StatsBars
@onready var _element_rows: VBoxContainer = $Window/VBox/Content/RightPanel/VBox/ElementRows
@onready var _passive_list: VBoxContainer = $Window/VBox/Content/RightPanel/VBox/PassiveScroll/PassiveList
@onready var _stash_panel: PanelContainer = $Window/VBox/Content/CenterPanel/VBox/GridStashHBox/StashPanel

var _skill_tooltip: PanelContainer = null

# Drag layer
@onready var _drag_preview: Control = $DragLayer/DragPreview

var _current_character_id: String = ""

# Drag state
var _drag := InventoryDragState.new()

# Tooltip control
var _tooltips_enabled: bool = true
var _last_hovered_grid_pos: Variant = null
var _last_hovered_stash_item: Variant = null
var _last_hovered_stash_global_pos: Vector2 = Vector2.ZERO

# Consumable usage
var _pending_consumable: ItemData = null
var _pending_consumable_source: int = InventoryDragState.Source.NONE
var _pending_consumable_index: int = -1
var _pending_consumable_placed: GridInventory.PlacedItem = null
var _target_selection_popup: PopupPanel = null

# Discard confirmation
var _discard_dialog: ConfirmationDialog = null
var _pending_discard_item: ItemData = null
var _pending_discard_index: int = -1
var _pending_discard_is_dragged: bool = false
# Cached data for skill damage estimation
var _cached_char_data: CharacterData = null
var _cached_inv: GridInventory = null
var _cached_passive_bonuses: Dictionary = {}


func _ready() -> void:
	_back_btn.pressed.connect(_on_back)

	# Grid interaction signals
	_grid_panel.cell_clicked.connect(_on_grid_cell_clicked)
	_grid_panel.cell_pressed.connect(_on_grid_cell_pressed)
	_grid_panel.cell_released.connect(_on_grid_cell_released)
	_grid_panel.cell_hovered.connect(_on_grid_cell_hovered)
	_grid_panel.cell_exited.connect(_on_hover_exited)

	# Stash interaction signals
	if GameManager.party:
		_stash_panel.refresh(GameManager.party.stash)
	_stash_panel.item_clicked.connect(_on_stash_item_clicked)
	_stash_panel.item_hovered.connect(_on_stash_item_hovered)
	_stash_panel.item_exited.connect(_on_hover_exited)
	_stash_panel.item_use_requested.connect(_on_stash_item_use_requested)
	_stash_panel.item_discard_requested.connect(_on_stash_discard_requested)
	_stash_panel.background_clicked.connect(_on_stash_background_clicked)

	_discard_dialog = ConfirmationDialog.new()
	_discard_dialog.title = "Discard Item"
	_discard_dialog.confirmed.connect(_on_discard_confirmed)
	add_child(_discard_dialog)

	EventBus.inventory_changed.connect(_on_inventory_changed_refresh_equipment)

	if GameManager.party:
		_character_tabs.setup(GameManager.party.squad, GameManager.party.roster)
		_character_tabs.character_selected.connect(_on_character_selected)

	if GameManager.party and not GameManager.party.squad.is_empty():
		_on_character_selected(GameManager.party.squad[0])
		_character_tabs.select(GameManager.party.squad[0])

	# Update gold display
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.stash_changed.connect(_on_stash_changed)
	EventBus.inventory_expanded.connect(_on_inventory_expanded)
	_update_gold_display()

	# Tooltip is embedded in the right panel (no floating layer)
	_item_tooltip.embedded = true
	_item_tooltip.show_empty_state()
	_drag_preview.visible = false

	_populate_inventory_toolbar()

	# Skill tooltip — floating overlay positioned near cursor
	_skill_tooltip = _create_skill_tooltip()
	add_child(_skill_tooltip)

	DebugLogger.log_info("Character stats scene ready", "CharStats")


@warning_ignore("shadowed_variable")
func _unhandled_input(event: InputEvent) -> void:
	# Hold T to temporarily hide tooltips
	if event is InputEventKey and event.keycode == KEY_T:
		if event.pressed:
			_tooltips_enabled = false
			_item_tooltip.hide_tooltip()
			_show_skills_section()
		else:
			_tooltips_enabled = true
			if _last_hovered_grid_pos != null:
				var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
				if inv:
					var placed: GridInventory.PlacedItem = inv.get_item_at(_last_hovered_grid_pos)
					if placed:
						_hide_skills_section()
						_item_tooltip.show_for_item(placed.item_data, placed, inv, get_global_mouse_position())
			elif _last_hovered_stash_item != null:
				_hide_skills_section()
				var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
				_item_tooltip.show_for_item(_last_hovered_stash_item, null, inv, _last_hovered_stash_global_pos)
		get_viewport().set_input_as_handled()
		return

	if _drag.is_dragging():
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_rotate_dragged_item()
			get_viewport().set_input_as_handled()
			return
		# Mouse release — drop to stash if over stash, otherwise cancel
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _stash_panel.is_mouse_over():
				_return_to_stash()
			else:
				_cancel_drag()
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

	if event.is_action_pressed("escape"):
		_on_back()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# Global input — catches mouse release regardless of which control has focus
	if _drag.is_dragging():
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _drag.is_same_frame_release(Engine.get_process_frames()):
				return
			_on_mouse_released_during_drag()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _drag.is_dragging():
		_update_drag_preview()


func _on_mouse_released_during_drag() -> void:
	## Called from _process when mouse button is released during a drag.
	if not _drag.is_dragging():
		return
	var mouse_pos: Vector2 = get_global_mouse_position()
	var over_grid: bool = _grid_panel.get_global_rect().has_point(mouse_pos)
	var over_stash: bool = _stash_panel.is_mouse_over()
	if over_grid:
		var grid_pos: Vector2i = _grid_panel.world_to_grid(mouse_pos)
		var adjusted_pos: Vector2i = grid_pos - _drag_preview.get_center_cell_offset()
		var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
		if inv:
			var can: bool = inv.can_place(_drag.item, adjusted_pos, _drag.rotation)
		_try_place_item(adjusted_pos)
		if _drag.is_dragging():
			_cancel_drag()
	elif over_stash:
		var slot_info: Dictionary = _stash_panel.get_item_at_global_pos(mouse_pos)
		if not slot_info.is_empty():
			var target_item: ItemData = slot_info["item"] as ItemData
			if target_item and ItemUpgradeSystem.can_upgrade(_drag.item, target_item):
				_perform_stash_upgrade(target_item, int(slot_info["index"]))
				return
		_return_to_stash()
	else:
		_cancel_drag()


func _on_back() -> void:
	SceneManager.pop_scene()


var _embedded: bool = false

enum EmbedMode { FULL, INVENTORY_ONLY, STATS_ONLY }
var _embed_mode: int = EmbedMode.FULL


func setup_embedded(character_id: String, mode: int = EmbedMode.FULL) -> void:
	_embedded = true
	_embed_mode = mode
	$Window/VBox/TopBar.visible = false
	match mode:
		EmbedMode.FULL:
			# Hub owns the party list — hide our left panel and fill the freed space
			$Window/VBox/Content/LeftPanel.visible = false
			var cp: Control = $Window/VBox/Content/CenterPanel
			cp.anchor_left = 0.0
			cp.offset_left = 0.0
			# Remove the gap reserved for the now-hidden TopBar and Footer
			var content: Control = $Window/VBox/Content
			content.offset_top = 0.0
			content.offset_bottom = 0.0
			$Window/VBox/Footer.visible = false
		EmbedMode.INVENTORY_ONLY:
			$Window/VBox/Content/LeftPanel/Body/CharacterTabs.visible = false
			_replace_left_panel_with_compact_view()
			_skills_header.visible = false
			_skills_sep.visible = false
			_skills_scroll.visible = false
		EmbedMode.STATS_ONLY:
			$Window/VBox/Content/LeftPanel/Body/CharacterTabs.visible = false
			$Window/VBox/Content/CenterPanel.visible = false
			_stash_panel.visible = false
	_on_character_selected(character_id)


func _on_character_selected(character_id: String) -> void:
	if _drag.is_dragging():
		_cancel_drag()
	_current_character_id = character_id
	var char_data: CharacterData = GameManager.party.roster.get(character_id)
	if not char_data:
		return

	var inv: GridInventory = GameManager.party.grid_inventories.get(character_id)
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var passive_bonuses: Dictionary = GameManager.party.get_passive_bonuses(character_id, tree)

	match _embed_mode:
		EmbedMode.INVENTORY_ONLY:
			_replace_left_panel_with_compact_view()
			_update_center_panel(inv)
		EmbedMode.STATS_ONLY:
			_update_left_panel(char_data, inv, passive_bonuses)
			_update_skills_panel(char_data, inv)
			_update_element_display(inv)
			_update_passive_display(passive_bonuses)
		_:
			_update_left_panel(char_data, inv, passive_bonuses)
			_update_center_panel(inv)
			_update_skills_panel(char_data, inv)
			_update_element_display(inv)
			_update_passive_display(passive_bonuses)
			_update_stats_bars(char_data, inv)
	if GameManager.party:
		_stash_panel.refresh(GameManager.party.stash)


# === Left Panel: Character Info + Skills + Stats ===

func _update_left_panel(char_data: CharacterData, inv: GridInventory, passive_bonuses: Dictionary) -> void:
	_cached_char_data = char_data
	_cached_inv = inv
	_cached_passive_bonuses = passive_bonuses


# === Center Panel: Inventory Grid ===

func _update_center_panel(inv: GridInventory) -> void:
	if inv and _grid_panel.has_method("setup"):
		_grid_panel.setup(inv)
	_update_tier_display()
	_update_element_bar(inv)
	_item_tooltip.hide_tooltip()
	_show_skills_section()


func _populate_inventory_toolbar() -> void:
	var ToolButtonScene: PackedScene = preload("res://scenes/ui/components/tool_button.tscn")
	for label_text in ["ADJACENCY", "SORT"]:
		var btn: ToolButton = ToolButtonScene.instantiate()
		btn.text = label_text
		_inventory_label.toolbar.add_child(btn)


func _update_tier_display() -> void:
	var char_data: CharacterData = GameManager.party.roster.get(_current_character_id) if GameManager.party else null
	if char_data and not char_data.backpack_tiers.is_empty():
		var state := GameManager.party.get_or_init_backpack_state(char_data)
		var current_tier: int = state.get("tier", 0) + 1
		var max_tier: int = char_data.backpack_tiers.size()
		_inventory_label.title = "%s's Inventory" % char_data.display_name
		_inventory_label.subtitle = "TIER %d / %d" % [current_tier, max_tier]
	else:
		_inventory_label.title = "Inventory"
		_inventory_label.subtitle = ""


# === Right Panel: Skills (simple list of current loadout skills) ===

func _update_skills_panel(char_data: CharacterData, inv: GridInventory) -> void:
	_clear_children(_skills_list)

	var element_points: Dictionary = inv.get_element_points() if inv else {}

	# Innate skills
	for skill in char_data.innate_skills:
		if skill is SkillData:
			_skills_list.add_child(_build_skill_row(skill, true))

	# Element-unlocked skills
	var table: ElementSkillTable = ElementSkillSystem.get_table()
	if table:
		var innate_ids: Array[String] = []
		for skill in char_data.innate_skills:
			if skill is SkillData:
				innate_ids.append(skill.id)
		var unlocked: Array[SkillData] = table.get_unlocked_skills(element_points)
		for skill in unlocked:
			if skill.id not in innate_ids:
				_skills_list.add_child(_build_skill_row(skill, false))

	if _skills_list.get_child_count() == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "No active skills"
		UIThemes.style_label(empty_lbl, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_FADED)
		_skills_list.add_child(empty_lbl)


func _update_element_display(inv: GridInventory) -> void:
	_clear_children(_element_rows)
	var element_points: Dictionary = inv.get_element_points() if inv else {}

	var elements: Array = [
		[Enums.Element.FIRE, "Fire"],
		[Enums.Element.WATER, "Water"],
		[Enums.Element.AIR, "Air"],
		[Enums.Element.EARTH, "Earth"],
		[Enums.Element.PLANT, "Plant"],
		[Enums.Element.LIGHT, "Light"],
		[Enums.Element.DARK, "Dark"],
	]

	var has_any: bool = false
	for elem_info in elements:
		var elem: int = elem_info[0]
		var elem_name: String = elem_info[1]
		var pts: int = element_points.get(elem, 0)
		if pts <= 0:
			continue
		has_any = true
		var row := HBoxContainer.new()
		var color: Color = Constants.ELEMENT_COLORS.get(elem, Color.WHITE)

		var name_lbl := Label.new()
		name_lbl.text = elem_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIThemes.style_label(name_lbl, Constants.FONT_SIZE_TINY, color)
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.text = str(pts)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		UIThemes.style_label(val_lbl, Constants.FONT_SIZE_TINY, color)
		row.add_child(val_lbl)

		_element_rows.add_child(row)

	if not has_any:
		var empty_lbl := Label.new()
		empty_lbl.text = "No element gems equipped"
		UIThemes.style_label(empty_lbl, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_FADED)
		_element_rows.add_child(empty_lbl)


func _update_passive_display(passive_bonuses: Dictionary) -> void:
	_clear_children(_passive_list)
	var effects: Array = passive_bonuses.get("special_effects", [])

	if effects.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No passive abilities unlocked"
		UIThemes.style_label(empty_lbl, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_FADED)
		_passive_list.add_child(empty_lbl)
		return

	for i in range(effects.size()):
		var effect_id: String = effects[i]
		var desc: String = PassiveEffects.get_description(effect_id)
		if desc.is_empty():
			continue
		var lbl := Label.new()
		lbl.text = "• " + desc
		UIThemes.style_label(lbl, Constants.FONT_SIZE_TINY, Color(0.7, 0.85, 1.0))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_passive_list.add_child(lbl)


func _update_stats_bars(char_data: CharacterData, inv: GridInventory) -> void:
	_clear_children(_stats_bars)
	if not char_data or not GameManager.party:
		return
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var equip_stats: Dictionary = inv.get_computed_stats().get("stats", {}) if inv else {}
	var hp_cur: int = GameManager.party.get_current_hp(_current_character_id)
	var hp_max: int = GameManager.party.get_max_hp(_current_character_id, tree)
	var mp_cur: int = GameManager.party.get_current_mp(_current_character_id)
	var mp_max: int = GameManager.party.get_max_mp(_current_character_id, tree)
	_add_stat_bar_row("HP", hp_cur, hp_max, Color(0.78, 0.22, 0.22))
	_add_stat_bar_row("MP", mp_cur, mp_max, Color(0.25, 0.45, 0.82))
	var stats_to_show: Array = [
		["ATK",   Enums.Stat.PHYSICAL_ATTACK,  Color(0.69, 0.53, 0.27)],
		["DEF",   Enums.Stat.PHYSICAL_DEFENSE, Color(0.87, 0.79, 0.62)],
		["M.ATK", Enums.Stat.MAGICAL_ATTACK,   Color(0.29, 0.35, 0.56)],
		["M.DEF", Enums.Stat.MAGICAL_DEFENSE,  Color(0.45, 0.53, 0.72)],
		["SPD",   Enums.Stat.SPEED,            Color(0.38, 0.56, 0.38)],
	]

	var stat_totals: Array = []
	for stat_info in stats_to_show:
		var base_val: int = char_data.get_base_stat(stat_info[1] as int)
		var equip_bonus: int = int(equip_stats.get(stat_info[1], 0.0))
		stat_totals.append(base_val + equip_bonus)

	for i in range(stats_to_show.size()):
		_add_stat_bar_row(stats_to_show[i][0], stat_totals[i], 200, stats_to_show[i][2])


func _add_stat_bar_row(label_text: String, current: int, maximum: int, bar_color: Color) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(40, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIThemes.style_label(lbl, Constants.FONT_SIZE_TINY, Color(0.35, 0.28, 0.18))
	hbox.add_child(lbl)
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 12)
	bar.max_value = maxi(maximum, 1)
	bar.value = current
	bar.show_percentage = false
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = bar_color
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.78, 0.73, 0.65, 0.5)
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_left = 2
	bg_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", bg_style)
	hbox.add_child(bar)
	var val_lbl := Label.new()
	val_lbl.text = "%d/%d" % [current, maximum]
	val_lbl.custom_minimum_size = Vector2(56, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIThemes.style_label(val_lbl, Constants.FONT_SIZE_TINY, Color(0.35, 0.28, 0.18))
	hbox.add_child(val_lbl)
	_stats_bars.add_child(hbox)



func _build_skill_row(skill: SkillData, is_innate: bool) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	hbox.mouse_filter = Control.MOUSE_FILTER_STOP

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = skill.display_name
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_innate:
		UIThemes.style_label(name_label, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_EMPHASIS)
	else:
		UIThemes.style_label(name_label, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_PRIMARY)
	hbox.add_child(name_label)

	if skill.mp_cost > 0:
		var mp_label := Label.new()
		mp_label.text = "%d MP" % skill.mp_cost
		mp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIThemes.style_label(mp_label, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_SECONDARY)
		hbox.add_child(mp_label)

	hbox.mouse_entered.connect(_on_skill_hovered.bind(skill, is_innate))
	hbox.mouse_exited.connect(_on_skill_exited)

	return hbox


func _create_skill_tooltip() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.90)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.border_color = Color(0.3, 0.35, 0.5, 0.6)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 10
	var margin := MarginContainer.new()
	UIThemes.set_uniform_margins(margin, 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)
	panel.visible = false
	return panel


func _show_skill_tooltip(skill: SkillData, is_innate: bool) -> void:
	var vbox: VBoxContainer = _skill_tooltip.get_child(0).get_child(0)
	for child in vbox.get_children():
		child.queue_free()

	# Name
	var name_lbl := Label.new()
	name_lbl.text = skill.display_name
	var name_color: Color = Constants.COLOR_TEXT_EMPHASIS if is_innate else Color.WHITE
	UIThemes.style_label(name_lbl, Constants.FONT_SIZE_BODY, name_color)
	vbox.add_child(name_lbl)

	# Innate tag
	if is_innate:
		var tag := Label.new()
		tag.text = "Innate"
		UIThemes.style_label(tag, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_SECONDARY)
		vbox.add_child(tag)

	# Separator
	vbox.add_child(HSeparator.new())

	# MP cost
	if skill.mp_cost > 0:
		_add_skill_stat_label(vbox, "MP Cost", "%d" % skill.mp_cost, Constants.COLOR_MP)
	elif skill.use_all_mp:
		_add_skill_stat_label(vbox, "MP Cost", "All remaining", Constants.COLOR_MP)

	# Target
	_add_skill_stat_label(vbox, "Target", Enums.get_target_type_name(skill.target_type), Constants.COLOR_TEXT_FADED)

	# Cooldown
	if skill.cooldown_turns > 0:
		_add_skill_stat_label(vbox, "Cooldown", "%d turn(s)" % skill.cooldown_turns, Constants.COLOR_TEXT_FADED)

	# Damage scaling + estimated damage
	if skill.has_damage():
		if skill.physical_scaling > 0.0:
			_add_skill_stat_label(vbox, "Phys Scaling", "%.1fx" % skill.physical_scaling, Constants.COLOR_DAMAGE)
		if skill.magical_scaling > 0.0:
			_add_skill_stat_label(vbox, "Mag Scaling", "%.1fx" % skill.magical_scaling, Color(0.5, 0.6, 1.0))
		# Estimated raw damage (no defense, no crit)
		var est: int = _estimate_skill_damage(skill)
		if est > 0:
			_add_skill_stat_label(vbox, "Est. Damage", "~%d" % est, Color(1.0, 0.85, 0.4))

	# Healing
	if skill.heal_amount > 0:
		_add_skill_stat_label(vbox, "Heals", "%d HP" % skill.heal_amount, Constants.COLOR_HEAL)
	if skill.heal_percent > 0.0:
		_add_skill_stat_label(vbox, "Heals", "%d%% max HP" % int(skill.heal_percent * 100), Constants.COLOR_HEAL)

	# Status effects
	if not skill.applied_statuses.is_empty():
		var sep2 := HSeparator.new()
		vbox.add_child(sep2)
		for status in skill.applied_statuses:
			if status is StatusEffectData:
				var status_lbl := Label.new()
				status_lbl.text = "Applies: %s" % status.display_name
				UIThemes.style_label(status_lbl, Constants.FONT_SIZE_TINY, Color(1.0, 0.8, 0.3))
				vbox.add_child(status_lbl)

	# Description
	if not skill.description.is_empty():
		var desc_sep := HSeparator.new()
		vbox.add_child(desc_sep)
		var desc := Label.new()
		desc.text = skill.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(180, 0)
		UIThemes.style_label(desc, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_FADED)
		vbox.add_child(desc)

	_skill_tooltip.reset_size()
	# Position tooltip to the left of the right panel
	var panel_rect: Rect2 = _top_slot.get_global_rect()
	var tip_size: Vector2 = _skill_tooltip.size
	var pos_x: float = panel_rect.position.x - tip_size.x - 8
	var pos_y: float = clampf(get_global_mouse_position().y - tip_size.y * 0.5, 0, size.y - tip_size.y)
	_skill_tooltip.global_position = Vector2(pos_x, pos_y)
	_skill_tooltip.visible = true


func _add_skill_stat_label(container: VBoxContainer, stat_name: String, value_text: String, value_color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name_lbl := Label.new()
	name_lbl.text = stat_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIThemes.style_label(name_lbl, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_SECONDARY)
	row.add_child(name_lbl)
	var val_lbl := Label.new()
	val_lbl.text = value_text
	UIThemes.style_label(val_lbl, Constants.FONT_SIZE_TINY, value_color)
	row.add_child(val_lbl)
	container.add_child(row)


func _estimate_skill_damage(skill: SkillData) -> int:
	if not _cached_char_data or not _cached_inv:
		return 0
	var entity: CombatEntity = CombatEntity.from_character(_cached_char_data, _cached_inv, _cached_passive_bonuses)
	var phys_power: float = float(entity.get_total_weapon_physical_power())
	var phys_stat: float = entity.get_effective_stat(Enums.Stat.PHYSICAL_ATTACK)
	var passive_phys: float = entity.get_effective_stat(Enums.Stat.PHYSICAL_SCALING) / 100.0
	var phys_raw: float = (phys_power + phys_stat) * maxf(skill.physical_scaling + passive_phys, 0.0)
	var mag_power: float = float(entity.get_total_weapon_magical_power())
	var mag_stat: float = entity.get_effective_stat(Enums.Stat.MAGICAL_ATTACK)
	var passive_mag: float = entity.get_effective_stat(Enums.Stat.MAGICAL_SCALING) / 100.0
	var mag_raw: float = (mag_power + mag_stat) * maxf(skill.magical_scaling + passive_mag, 0.0)
	return maxi(int(phys_raw + mag_raw), 1)


func _on_skill_hovered(skill: SkillData, is_innate: bool) -> void:
	_show_skill_tooltip(skill, is_innate)


func _on_skill_exited() -> void:
	_skill_tooltip.visible = false


# === Element Bar (Center Panel) ===

func _update_element_bar(inv: GridInventory) -> void:
	_clear_children(_element_bar)
	var element_points: Dictionary = inv.get_element_points() if inv else {}

	for elem_idx in range(7):
		var elem: int = elem_idx
		var pts: int = element_points.get(elem, 0)
		var elem_color: Color = Constants.ELEMENT_COLORS.get(elem, Color.WHITE)

		var square := PanelContainer.new()
		square.custom_minimum_size = Vector2(26, 26)
		var sq_style := StyleBoxFlat.new()
		sq_style.corner_radius_top_left = 3
		sq_style.corner_radius_top_right = 3
		sq_style.corner_radius_bottom_left = 3
		sq_style.corner_radius_bottom_right = 3
		if pts > 0:
			sq_style.bg_color = elem_color.darkened(0.5)
			sq_style.border_color = elem_color
		else:
			sq_style.bg_color = Color(0.1, 0.1, 0.12, 0.6)
			sq_style.border_color = elem_color.darkened(0.5)
		sq_style.border_width_left = 1
		sq_style.border_width_right = 1
		sq_style.border_width_top = 1
		sq_style.border_width_bottom = 1
		square.add_theme_stylebox_override("panel", sq_style)
		var elem_name: String = Enums.get_element_name(elem as Enums.Element)
		if pts > 0:
			square.tooltip_text = "%s: %d point(s)\nGems provide element points that unlock skills." % [elem_name, pts]
		else:
			square.tooltip_text = "%s: 0\nEquip gems with %s element to unlock skills." % [elem_name, elem_name]

		var lbl := Label.new()
		lbl.text = str(pts)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if pts > 0:
			UIThemes.style_label(lbl, Constants.FONT_SIZE_TINY, elem_color)
		else:
			UIThemes.style_label(lbl, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_FADED)
		square.add_child(lbl)
		_element_bar.add_child(square)


func _show_skills_section() -> void:
	_skills_header.visible = true
	_skills_sep.visible = true
	_skills_scroll.visible = true
	_item_tooltip.hide_tooltip()
	if _skill_tooltip:
		_skill_tooltip.visible = false


func _hide_skills_section() -> void:
	_skills_header.visible = false
	_skills_sep.visible = false
	_skills_scroll.visible = false
	if _skill_tooltip:
		_skill_tooltip.visible = false


# === Grid Interaction ===

@warning_ignore("shadowed_variable")
func _on_grid_cell_clicked(grid_pos: Vector2i, button: int) -> void:
	# Right-click: rotate during drag, or use consumable when idle
	if button == MOUSE_BUTTON_RIGHT:
		if _drag.is_dragging():
			_rotate_dragged_item()
		else:
			var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
			if inv:
				var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
				if placed and placed.item_data.item_type == Enums.ItemType.CONSUMABLE and placed.item_data.use_skill:
					_on_grid_item_use_requested(placed)
		return

	if button != MOUSE_BUTTON_LEFT:
		return

	# Left-click on inactive cell: purchase it
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
	## Mouse button down — start dragging an item if there's one under the cursor.
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
	## Mouse button up — place the dragged item, or return it if placement fails.
	if button != MOUSE_BUTTON_LEFT or not _drag.is_dragging():
		return
	var adjusted_pos: Vector2i = grid_pos - _drag_preview.get_center_cell_offset()
	_try_place_item(adjusted_pos)
	# If still dragging after try_place (placement failed), cancel and return item
	if _drag.is_dragging():
		_cancel_drag()


@warning_ignore("shadowed_variable")
func _on_grid_cell_hovered(grid_pos: Vector2i) -> void:
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		return

	if _drag.is_dragging():
		return  # Handled by _update_drag_preview in _process

	var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if placed:
		_last_hovered_grid_pos = grid_pos
		_last_hovered_stash_item = null
		_grid_panel.show_hover_feedback(placed)
		if _tooltips_enabled:
			_hide_skills_section()
			_item_tooltip.show_for_item(placed.item_data, placed, inv, get_global_mouse_position())
	elif not inv.grid_template.is_cell_active(grid_pos):
		# Hovering an inactive cell — show purchase info if the cell is buyable.
		var char_data: CharacterData = GameManager.party.roster.get(_current_character_id)
		if char_data and not char_data.backpack_tiers.is_empty():
			var state := GameManager.party.get_or_init_backpack_state(char_data)
			if BackpackUpgradeSystem.get_purchasable_cells(char_data, state).has(grid_pos):
				var cost := BackpackUpgradeSystem.get_next_cell_cost(char_data, state)
				_grid_panel.set_cell_purchasable(grid_pos)
				if _tooltips_enabled:
					_hide_skills_section()
					_item_tooltip.show_for_cell_purchase(cost, GameManager.gold >= cost, get_global_mouse_position())
				return
		_last_hovered_grid_pos = null
		_last_hovered_stash_item = null
		_grid_panel.clear_hover_feedback()
		_grid_panel.clear_item_highlights()
		_item_tooltip.hide_tooltip()
		_show_skills_section()
	else:
		_last_hovered_grid_pos = null
		_last_hovered_stash_item = null
		_grid_panel.clear_hover_feedback()
		_grid_panel.clear_item_highlights()
		_item_tooltip.hide_tooltip()
		_show_skills_section()


func _on_hover_exited() -> void:
	if not _drag.is_dragging():
		_last_hovered_grid_pos = null
		_last_hovered_stash_item = null
		_item_tooltip.hide_tooltip()
		_show_skills_section()
		_grid_panel.clear_hover_feedback()


# === Stash Interaction ===

func _on_stash_item_clicked(item: ItemData, index: int) -> void:
	_stash_panel.clear_displaced_highlights()
	if _drag.is_dragging():
		# Check for upgrade
		if ItemUpgradeSystem.can_upgrade(_drag.item, item):
			_perform_stash_upgrade(item, index)
			return
		# Drop current item to stash
		_return_to_stash()
	else:
		_start_drag_from_stash(item, index)


func _on_stash_item_hovered(item: ItemData, global_pos: Vector2) -> void:
	if not _drag.is_dragging():
		_last_hovered_stash_item = item
		_last_hovered_stash_global_pos = global_pos
		_last_hovered_grid_pos = null
		if _tooltips_enabled:
			_hide_skills_section()
			var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
			_item_tooltip.show_for_item(item, null, inv, global_pos)


func _on_stash_background_clicked() -> void:
	if _drag.is_dragging():
		_return_to_stash()


func _on_stash_discard_requested(item: ItemData, index: int) -> void:
	_pending_discard_item = item
	_pending_discard_index = index
	_pending_discard_is_dragged = false
	_discard_dialog.dialog_text = "Discard %s? This cannot be undone." % item.display_name
	_discard_dialog.popup_centered()


func _request_discard_dragged() -> void:
	if not _drag.item:
		return
	_pending_discard_item = _drag.item
	_pending_discard_index = -1
	_pending_discard_is_dragged = true
	_discard_dialog.dialog_text = "Discard %s? This cannot be undone." % _drag.item.display_name
	_discard_dialog.popup_centered()


func _on_discard_confirmed() -> void:
	if not _pending_discard_item:
		return
	if _pending_discard_is_dragged:
		var was_from_grid: bool = (_drag.source == InventoryDragState.Source.GRID)
		var source_pos: Vector2i = _drag.source_pos
		_end_drag()
		if was_from_grid:
			EventBus.item_removed.emit(_current_character_id, _pending_discard_item, source_pos)
			EventBus.inventory_changed.emit(_current_character_id)
			_refresh_left_panel()
	else:
		if _pending_discard_index >= 0 and _pending_discard_index < GameManager.party.stash.size():
			GameManager.party.stash.remove_at(_pending_discard_index)
			_stash_panel.refresh(GameManager.party.stash)
			EventBus.stash_changed.emit()
	DebugLogger.log_info("Discarded: %s" % _pending_discard_item.display_name, "CharStats")
	_pending_discard_item = null
	_pending_discard_index = -1
	_pending_discard_is_dragged = false


func _on_stash_changed() -> void:
	if GameManager.party:
		_stash_panel.refresh(GameManager.party.stash)


func _on_inventory_expanded() -> void:
	if _current_character_id.is_empty() or not GameManager.party:
		return
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id)
	_update_center_panel(inv)


# === Consumable Usage ===

func _on_stash_item_use_requested(item: ItemData, index: int) -> void:
	# Blueprints are used instantly — no target selection needed.
	if item.item_type == Enums.ItemType.BLUEPRINT:
		_use_blueprint(item)
		return
	if not item.use_skill:
		return
	_pending_consumable = item
	_pending_consumable_source = InventoryDragState.Source.STASH
	_pending_consumable_index = index
	_pending_consumable_placed = null
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


func _on_grid_item_use_requested(placed: GridInventory.PlacedItem) -> void:
	if not placed.item_data.use_skill:
		return
	_pending_consumable = placed.item_data
	_pending_consumable_source = InventoryDragState.Source.GRID
	_pending_consumable_index = -1
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
	UIThemes.set_separation(vbox, 8)
	_target_selection_popup.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Select Target"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIThemes.set_font_size(title, Constants.FONT_SIZE_TITLE)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	if not GameManager.party:
		return

	var roster_ids: Array = GameManager.party.roster.keys()
	for i in range(roster_ids.size()):
		var char_id: String = roster_ids[i]
		var char_data: CharacterData = GameManager.party.roster[char_id]
		if not char_data:
			continue

		var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
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


@warning_ignore("shadowed_variable")
func _on_target_selected(character_id: String) -> void:
	var item: ItemData = _pending_consumable
	var source: int = _pending_consumable_source
	var index: int = _pending_consumable_index
	var placed: GridInventory.PlacedItem = _pending_consumable_placed

	_target_selection_popup.hide()

	if not item or not item.use_skill:
		return

	if not GameManager.party:
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

	# Remove consumed item
	if source == InventoryDragState.Source.STASH:
		if index < GameManager.party.stash.size():
			GameManager.party.stash.remove_at(index)
			_stash_panel.refresh(GameManager.party.stash)
			EventBus.stash_changed.emit()
	elif source == InventoryDragState.Source.GRID:
		if placed:
			var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id)
			if inv:
				inv.remove_item(placed)
				_grid_panel.refresh()
				EventBus.inventory_changed.emit(_current_character_id)

	# Refresh HP/MP display
	_refresh_left_panel()
	DebugLogger.log_info("Used %s on %s, healed %d HP" % [item.display_name, character_id, heal], "CharStats")


func _on_target_popup_hidden() -> void:
	_pending_consumable = null
	_pending_consumable_source = InventoryDragState.Source.NONE
	_pending_consumable_index = -1
	_pending_consumable_placed = null


# === Drag & Drop ===

func _start_drag_from_grid(placed: GridInventory.PlacedItem, clicked_pos: Vector2i = Vector2i(-1, -1)) -> void:
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		return

	_drag.start_from_grid(placed, Engine.get_process_frames())
	inv.remove_item(placed)
	_grid_panel.refresh()
	_refresh_left_panel()

	var anchor: Vector2i = Vector2i(-1, -1)
	if clicked_pos != Vector2i(-1, -1):
		anchor = clicked_pos - placed.grid_position
	_drag_preview.cell_size = _grid_panel.cell_size
	_drag_preview.setup(_drag.item, _drag.rotation, anchor)

	# Show placement preview at current mouse position (centered on cursor)
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

	# Show placement preview at current mouse position (centered on cursor)
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if inv:
		var mouse_grid_pos: Vector2i = _grid_panel.world_to_grid(get_global_mouse_position()) - _drag_preview.get_center_cell_offset()
		_drag.last_preview_grid_pos = mouse_grid_pos
		_grid_panel.show_placement_preview(_drag.item, mouse_grid_pos, _drag.rotation)
		var can_place: bool = inv.can_place(_drag.item, mouse_grid_pos, _drag.rotation)
		_drag_preview.set_valid(can_place)


@warning_ignore("shadowed_variable")
func _try_place_item(grid_pos: Vector2i) -> void:
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		return


	# Check for upgrade
	var target_item: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if target_item and ItemUpgradeSystem.can_upgrade(_drag.item, target_item.item_data):
		_perform_item_upgrade(inv, target_item)
		return

	var can_place_direct: bool = inv.can_place(_drag.item, grid_pos, _drag.rotation)
	var fail_reason: String = inv.get_placement_failure_reason(_drag.item, grid_pos, _drag.rotation) if not can_place_direct else ""

	if can_place_direct:
		var item: ItemData = _drag.item
		var was_from_stash: bool = (_drag.source == InventoryDragState.Source.STASH)
		var placed: GridInventory.PlacedItem = inv.place_item(item, grid_pos, _drag.rotation)
		if not placed:
			return
		# End drag BEFORE emitting signals — the hub listens to inventory_changed
		# and calls setup_embedded, which would _cancel_drag and duplicate the item.
		_end_drag()
		_grid_panel.refresh()
		EventBus.item_placed.emit(_current_character_id, item, grid_pos)
		EventBus.inventory_changed.emit(_current_character_id)
		if was_from_stash:
			EventBus.stash_changed.emit()
		_refresh_left_panel()
		return

	# --- Displacement: move blocking items to stash ---
	var blockers: Array = inv.get_blocking_items(_drag.item, grid_pos, _drag.rotation)
	if blockers.is_empty():
		return

	# Save blocker data, temporarily remove all, test placement, then decide
	var saved_blockers: Array = []
	for bi in range(blockers.size()):
		saved_blockers.append({"data": blockers[bi].item_data, "pos": blockers[bi].grid_position, "rot": blockers[bi].rotation})
	for bi in range(blockers.size()):
		inv.remove_item(blockers[bi])
	var can_place_now: bool = inv.can_place(_drag.item, grid_pos, _drag.rotation)
	var fail_after: String = inv.get_placement_failure_reason(_drag.item, grid_pos, _drag.rotation) if not can_place_now else ""
	if not can_place_now:
		for ri in range(saved_blockers.size()):
			inv.place_item(saved_blockers[ri]["data"], saved_blockers[ri]["pos"], saved_blockers[ri]["rot"])
		return

	var was_from_stash: bool = (_drag.source == InventoryDragState.Source.STASH)

	# Blockers already removed — send their data to stash
	var displaced_items: Array[ItemData] = []
	for si in range(saved_blockers.size()):
		displaced_items.append(saved_blockers[si]["data"])

	# Place the held item
	var item: ItemData = _drag.item
	var placed: GridInventory.PlacedItem = inv.place_item(item, grid_pos, _drag.rotation)
	if not placed:
		# Safety fallback: restore all blockers
		for bi in range(blockers.size()):
			inv.place_item(displaced_items[bi], blockers[bi].grid_position, blockers[bi].rotation)
		return

	# Send displaced items to stash with highlight
	var first_displaced_idx: int = GameManager.party.stash.size()
	for di in range(displaced_items.size()):
		GameManager.party.stash.append(displaced_items[di])

	_end_drag()
	_grid_panel.refresh()
	_stash_panel.refresh(GameManager.party.stash)
	# Highlight all displaced items in stash
	for di in range(displaced_items.size()):
		_stash_panel.highlight_displaced_item(first_displaced_idx + di)
	EventBus.item_placed.emit(_current_character_id, item, grid_pos)
	EventBus.inventory_changed.emit(_current_character_id)
	EventBus.stash_changed.emit()
	_refresh_left_panel()


func _perform_item_upgrade(inv: GridInventory, target_placed: GridInventory.PlacedItem) -> void:
	var dragged_name: String = _drag.item.display_name
	var target_name: String = target_placed.item_data.display_name
	var was_from_stash: bool = (_drag.source == InventoryDragState.Source.STASH)
	var upgraded_item: ItemData = ItemUpgradeSystem.create_upgraded_item(target_placed.item_data)
	var target_pos: Vector2i = target_placed.grid_position
	var target_rot: int = target_placed.rotation
	inv.remove_item(target_placed)

	var new_placed: GridInventory.PlacedItem = inv.place_item(upgraded_item, target_pos, target_rot)

	# End drag BEFORE emitting signals (same reason as _try_place_item)
	_end_drag()

	if new_placed:
		_grid_panel.refresh()
		EventBus.inventory_changed.emit(_current_character_id)
		if was_from_stash:
			EventBus.stash_changed.emit()
		DebugLogger.log_info("UPGRADE! %s + %s → %s" % [
			dragged_name, target_name, upgraded_item.display_name
		], "CharStats")

	_refresh_left_panel()


func _perform_stash_upgrade(target_item: ItemData, target_index: int) -> void:
	var dragged_name: String = _drag.item.display_name
	var upgraded_item: ItemData = ItemUpgradeSystem.create_upgraded_item(target_item)

	GameManager.party.stash.remove_at(target_index)
	if not GameManager.party.add_to_stash(upgraded_item):
		GameManager.party.force_add_to_stash(upgraded_item)

	_end_drag()
	_stash_panel.refresh(GameManager.party.stash)
	EventBus.stash_changed.emit()

	DebugLogger.log_info("STASH UPGRADE! %s + %s → %s" % [
		dragged_name, target_item.display_name, upgraded_item.display_name
	], "CharStats")


func _return_to_stash() -> void:
	if not _drag.item:
		return

	if not GameManager.party.add_to_stash(_drag.item):
		EventBus.show_message.emit("Stash is full!")
		return

	var was_from_grid: bool = (_drag.source == InventoryDragState.Source.GRID)
	var item: ItemData = _drag.item
	var item_name: String = _drag.item.display_name
	var source_pos: Vector2i = _drag.source_pos

	_end_drag()
	_stash_panel.refresh(GameManager.party.stash)

	if was_from_grid:
		EventBus.item_removed.emit(_current_character_id, item, source_pos)
		EventBus.inventory_changed.emit(_current_character_id)
		_refresh_left_panel()

	EventBus.stash_changed.emit()
	DebugLogger.log_info("Returned %s to stash" % item_name, "CharStats")


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
	_refresh_left_panel()


func _rotate_dragged_item() -> void:
	if not _drag.item:
		return
	_drag.rotate_cw()
	_drag_preview.rotate_cw()
	_drag.last_preview_grid_pos = Vector2i(-999, -999)
	EventBus.item_rotated.emit(_current_character_id, _drag.item)


func _update_drag_preview() -> void:
	_stash_panel.highlight_drop_target(_stash_panel.is_mouse_over())

	# Update grid placement preview every frame based on mouse position (centered on cursor)
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if inv and _drag.item:
		var mouse_pos: Vector2 = get_global_mouse_position()
		var grid_pos: Vector2i = _grid_panel.world_to_grid(mouse_pos) - _drag_preview.get_center_cell_offset()

		# Check if the item would overlap at least one active cell
		var over_active: bool = false
		if _grid_panel.get_global_rect().has_point(mouse_pos) and _drag.item.shape:
			var shape_cells: Array[Vector2i] = _drag.item.shape.get_rotated_cells(_drag.rotation)
			for sc in shape_cells:
				var target: Vector2i = grid_pos + sc
				if inv.grid_template.is_cell_active(target):
					over_active = true
					break

		_drag_preview.set_reach_visible(not over_active)

		if over_active:
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


func _refresh_left_panel() -> void:
	var char_data: CharacterData = GameManager.party.roster.get(_current_character_id) if GameManager.party else null
	if not char_data:
		return
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id)
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var passive_bonuses: Dictionary = GameManager.party.get_passive_bonuses(_current_character_id, tree)
	if _embed_mode != EmbedMode.INVENTORY_ONLY:
		_update_left_panel(char_data, inv, passive_bonuses)
		_update_skills_panel(char_data, inv)
		_update_stats_bars(char_data, inv)
	_update_element_bar(inv)


# === Helper Functions ===


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()



var _equipment_panel: PanelContainer = null


func _on_inventory_changed_refresh_equipment(_character_id: String) -> void:
	if _equipment_panel and is_instance_valid(_equipment_panel) and _equipment_panel.has_method("refresh"):
		_equipment_panel.refresh()


func _replace_left_panel_with_compact_view() -> void:
	## Replaces the full stats left panel with a compact summary + equipment slots.
	var left_panel: PanelContainer = $Window/VBox/Content/LeftPanel
	# Clear existing content
	for child in left_panel.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(vbox)

	# Compact character header
	var char_data: CharacterData = GameManager.party.roster.get(_current_character_id)
	if char_data:
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

	# HP/MP bars
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id)
	if char_data and GameManager.party:
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
		hp_bar.custom_minimum_size = Vector2(0, 16)
		hp_bar.nine_patch_stretch = true
		hp_bar.stretch_margin_left = 6
		hp_bar.stretch_margin_top = 6
		hp_bar.stretch_margin_right = 6
		hp_bar.stretch_margin_bottom = 6
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
		mp_bar.custom_minimum_size = Vector2(0, 14)
		mp_bar.nine_patch_stretch = true
		mp_bar.stretch_margin_left = 6
		mp_bar.stretch_margin_top = 6
		mp_bar.stretch_margin_right = 6
		mp_bar.stretch_margin_bottom = 6
		mp_bar.texture_under = preload("res://assets/sprites/ui/bars/mp_empty.png")
		mp_bar.texture_over = preload("res://assets/sprites/ui/bars/mp_frame.png")
		mp_bar.texture_progress = preload("res://assets/sprites/ui/bars/mp_fill.png")
		vbox.add_child(mp_bar)

	# Compact stat summary
	if char_data and inv:
		var sep := HSeparator.new()
		vbox.add_child(sep)

		var equip_stats: Dictionary = inv.get_computed_stats().get("stats", {})
		var stats_to_show: Array = [
			["ATK", Enums.Stat.PHYSICAL_ATTACK],
			["DEF", Enums.Stat.PHYSICAL_DEFENSE],
			["M.ATK", Enums.Stat.MAGICAL_ATTACK],
			["M.DEF", Enums.Stat.MAGICAL_DEFENSE],
			["SPD", Enums.Stat.SPEED],
		]
		for stat_info in stats_to_show:
			var stat_name: String = stat_info[0]
			var stat_id: int = stat_info[1]
			var base_val: int = char_data.get_base_stat(stat_id)
			var equip_bonus: int = int(equip_stats.get(stat_id, 0.0))
			var total: int = base_val + equip_bonus
			var row := HBoxContainer.new()
			var lbl_name := Label.new()
			lbl_name.text = stat_name
			lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl_name.add_theme_font_size_override("font_size", 13)
			lbl_name.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			row.add_child(lbl_name)
			var lbl_val := Label.new()
			lbl_val.text = str(total)
			lbl_val.add_theme_font_size_override("font_size", 13)
			lbl_val.add_theme_color_override("font_color", Color.WHITE if equip_bonus == 0 else Color(0.4, 1.0, 0.4))
			row.add_child(lbl_val)
			vbox.add_child(row)

	# Equipment slots panel
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


func _on_gold_changed(_new_gold: int) -> void:
	_update_gold_display()


func _update_gold_display() -> void:
	_gold_label.text = "%s  gold" % _format_thousands(GameManager.gold)


func _format_thousands(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	if n < 0:
		out = "-" + out
	return out
