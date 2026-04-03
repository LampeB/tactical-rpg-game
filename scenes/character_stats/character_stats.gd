extends Control
## Character stat screen with inventory grid and stash.
## Shows character info, stat breakdown, inventory grid, skills panel, and stash.

@onready var _bg: ColorRect = $BG
@onready var _back_btn: Button = $VBox/TopBar/BackButton
@warning_ignore("unused_private_class_variable")
@onready var _title: Label = $VBox/TopBar/Title
@onready var _gold_label: Label = $VBox/TopBar/Gold
@onready var _character_tabs: HBoxContainer = $VBox/CharacterTabs

# Left panel
@onready var _char_name: Label = $VBox/Content/LeftPanel/VBox/CharHeader/CharName
@onready var _class_level: Label = $VBox/Content/LeftPanel/VBox/CharHeader/ClassLevel
@onready var _char_desc: Label = $VBox/Content/LeftPanel/VBox/CharHeader/CharDesc
@onready var _hp_label: Label = $VBox/Content/LeftPanel/VBox/HPLabel
@onready var _hp_bar: ProgressBar = $VBox/Content/LeftPanel/VBox/HPBar
@onready var _mp_label: Label = $VBox/Content/LeftPanel/VBox/MPLabel
@onready var _mp_bar: ProgressBar = $VBox/Content/LeftPanel/VBox/MPBar
@onready var _stat_rows: VBoxContainer = $VBox/Content/LeftPanel/VBox/StatRows
@onready var _advanced_stats_btn: Button = $VBox/Content/LeftPanel/VBox/AdvancedStatsBtn

# Center panel
@onready var _inventory_label: Label = $VBox/Content/CenterPanel/VBox/InventoryLabel
@onready var _grid_panel: Control = $VBox/Content/CenterPanel/VBox/GridCentering/GridPanel

# Center panel - element bar
@onready var _element_bar: HBoxContainer = $VBox/Content/CenterPanel/VBox/ElementBar

# Right panel
@onready var _skills_header: Label = $VBox/Content/RightPanel/VBox/TopSlot/SkillsHeader
@onready var _skills_sep: HSeparator = $VBox/Content/RightPanel/VBox/TopSlot/HSeparator
@onready var _skills_scroll: ScrollContainer = $VBox/Content/RightPanel/VBox/TopSlot/SkillsScroll
@onready var _skills_list: VBoxContainer = $VBox/Content/RightPanel/VBox/TopSlot/SkillsScroll/SkillsList
@onready var _item_tooltip: PanelContainer = $VBox/Content/RightPanel/VBox/TopSlot/ItemTooltip
@onready var _top_slot: Control = $VBox/Content/RightPanel/VBox/TopSlot
@onready var _stash_panel: PanelContainer = $VBox/Content/RightPanel/VBox/StashPanel

var _skill_tooltip: PanelContainer = null

# Drag layer
@onready var _drag_preview: Control = $DragLayer/DragPreview

var _current_character_id: String = ""

# Drag state
enum DragState { IDLE, DRAGGING }
enum DragSource { NONE, GRID, STASH }
var _drag_state: DragState = DragState.IDLE
var _dragged_item: ItemData = null
var _drag_source: DragSource = DragSource.NONE
var _drag_source_placed: GridInventory.PlacedItem = null
var _drag_source_pos: Vector2i = Vector2i.ZERO
var _drag_source_rotation: int = 0
var _drag_source_stash_index: int = -1
var _drag_rotation: int = 0
var _last_preview_grid_pos: Vector2i = Vector2i(-999, -999)

# Tooltip control
var _tooltips_enabled: bool = true
var _last_hovered_grid_pos: Variant = null
var _last_hovered_stash_item: Variant = null
var _last_hovered_stash_global_pos: Vector2 = Vector2.ZERO

# Consumable usage
var _pending_consumable: ItemData = null
var _pending_consumable_source: DragSource = DragSource.NONE
var _pending_consumable_index: int = -1
var _pending_consumable_placed: GridInventory.PlacedItem = null
var _target_selection_popup: PopupPanel = null

# Discard confirmation
var _discard_dialog: ConfirmationDialog = null
var _pending_discard_item: ItemData = null
var _pending_discard_index: int = -1
var _pending_discard_is_dragged: bool = false
# Cached data for stat display
var _cached_char_data: CharacterData = null
var _cached_inv: GridInventory = null
var _cached_passive_bonuses: Dictionary = {}
var _show_advanced_stats: bool = false

# Simplified stats for default view
const SIMPLE_STATS: Array = [
	Enums.Stat.MAX_HP,
	Enums.Stat.MAX_MP,
	Enums.Stat.SPEED,
	Enums.Stat.PHYSICAL_ATTACK,
	Enums.Stat.MAGICAL_ATTACK,
]

# All stats for advanced view
const DISPLAY_STATS: Array = [
	Enums.Stat.MAX_HP,
	Enums.Stat.MAX_MP,
	Enums.Stat.SPEED,
	Enums.Stat.LUCK,
	Enums.Stat.PHYSICAL_ATTACK,
	Enums.Stat.PHYSICAL_DEFENSE,
	Enums.Stat.MAGICAL_ATTACK,
	Enums.Stat.MAGICAL_DEFENSE,
	Enums.Stat.CRITICAL_RATE,
	Enums.Stat.CRITICAL_DAMAGE,
]

const STAT_NAMES: Dictionary = {
	Enums.Stat.MAX_HP: "HP",
	Enums.Stat.MAX_MP: "MP",
	Enums.Stat.SPEED: "Speed",
	Enums.Stat.LUCK: "Luck",
	Enums.Stat.PHYSICAL_ATTACK: "Phys Atk",
	Enums.Stat.PHYSICAL_DEFENSE: "Phys Def",
	Enums.Stat.MAGICAL_ATTACK: "Mag Atk",
	Enums.Stat.MAGICAL_DEFENSE: "Mag Def",
	Enums.Stat.CRITICAL_RATE: "Crit Rate",
	Enums.Stat.CRITICAL_DAMAGE: "Crit Dmg",
}


func _ready() -> void:
	_bg.color = UIColors.BG_CHARACTER_STATS
	_back_btn.pressed.connect(_on_back)
	_advanced_stats_btn.pressed.connect(_on_advanced_stats_pressed)

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
	_item_tooltip.visible = false
	_drag_preview.visible = false

	# Skill tooltip — floating overlay positioned near cursor
	_skill_tooltip = _create_skill_tooltip()
	add_child(_skill_tooltip)

	# Placement hint label — always in the tree to avoid layout reflow
	_placement_hint_label = Label.new()
	UIThemes.style_label(_placement_hint_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_DAMAGE)
	_placement_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placement_hint_label.custom_minimum_size.y = 18
	_placement_hint_label.text = ""
	_grid_panel.get_parent().get_parent().add_child(_placement_hint_label)

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

	if _drag_state == DragState.DRAGGING:
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


var _drag_started_frame: int = 0

func _input(event: InputEvent) -> void:
	# Global input — catches mouse release regardless of which control has focus
	if _drag_state == DragState.DRAGGING:
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Skip if released on the same frame as drag start
			if Engine.get_process_frames() <= _drag_started_frame:
				return
			print("[Drag] _input: mouse released during drag frame=%d" % Engine.get_process_frames())
			_on_mouse_released_during_drag()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _drag_state == DragState.DRAGGING:
		_update_drag_preview()


func _on_mouse_released_during_drag() -> void:
	## Called from _process when mouse button is released during a drag.
	if _drag_state != DragState.DRAGGING:
		return
	var mouse_pos: Vector2 = get_global_mouse_position()
	var over_grid: bool = _grid_panel.get_global_rect().has_point(mouse_pos)
	var over_stash: bool = _stash_panel.is_mouse_over()
	print("[Drag] Mouse released. item='%s' source=%d over_grid=%s over_stash=%s" % [
		_dragged_item.display_name if _dragged_item else "null", _drag_source, str(over_grid), str(over_stash)])
	if over_grid:
		var grid_pos: Vector2i = _grid_panel.world_to_grid(mouse_pos)
		var adjusted_pos: Vector2i = grid_pos - _drag_preview.get_center_cell_offset()
		print("[Drag] Trying place at grid_pos=%s adjusted=%s rotation=%d" % [grid_pos, adjusted_pos, _drag_rotation])
		var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
		if inv:
			print("[Drag] Before place: hand_used=%d hand_avail=%d items=%d" % [inv.get_used_hand_slots(), inv.get_available_hand_slots(), inv.get_all_placed_items().size()])
			var can: bool = inv.can_place(_dragged_item, adjusted_pos, _drag_rotation)
			print("[Drag] can_place=%s reason='%s'" % [str(can), inv.get_placement_failure_reason(_dragged_item, adjusted_pos, _drag_rotation) if not can else ""])
		_try_place_item(adjusted_pos)
		if _drag_state == DragState.DRAGGING:
			print("[Drag] Place failed, canceling")
			_cancel_drag()
		else:
			print("[Drag] Place succeeded")
	elif over_stash:
		print("[Drag] Dropping to stash")
		_return_to_stash()
	else:
		print("[Drag] Released outside, canceling")
		_cancel_drag()


func _on_back() -> void:
	SceneManager.pop_scene()


var _embedded: bool = false

func setup_embedded(character_id: String) -> void:
	_embedded = true
	$VBox/TopBar.visible = false
	$VBox/CharacterTabs.visible = false
	_on_character_selected(character_id)


func _on_character_selected(character_id: String) -> void:
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()
	_current_character_id = character_id
	var char_data: CharacterData = GameManager.party.roster.get(character_id)
	if not char_data:
		return

	var inv: GridInventory = GameManager.party.grid_inventories.get(character_id)
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var passive_bonuses: Dictionary = GameManager.party.get_passive_bonuses(character_id, tree)

	_update_left_panel(char_data, inv, passive_bonuses)
	_update_center_panel(inv)
	_update_skills_panel(char_data, inv)
	if GameManager.party:
		_stash_panel.refresh(GameManager.party.stash)


# === Left Panel: Character Info + Skills + Stats ===

func _update_left_panel(char_data: CharacterData, inv: GridInventory, passive_bonuses: Dictionary) -> void:
	# Cache for advanced stats popup
	_cached_char_data = char_data
	_cached_inv = inv
	_cached_passive_bonuses = passive_bonuses

	# Character header
	_char_name.text = char_data.display_name

	# Calculate level based on unlocked passives
	var unlocked_count: int = GameManager.party.get_unlocked_passives(_current_character_id).size()
	var level: int = unlocked_count + 1  # Level 1 = 0 passives, Level 2 = 1 passive, etc.

	# Display class and level
	var char_class: String = char_data.character_class if not char_data.character_class.is_empty() else "Adventurer"
	_class_level.text = "- %s - Level %d" % [char_class, level]

	_char_desc.text = char_data.description if not char_data.description.is_empty() else ""

	# HP/MP vitals
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var current_hp: int = GameManager.party.get_current_hp(_current_character_id)
	var max_hp: int = GameManager.party.get_max_hp(_current_character_id, tree)
	var current_mp: int = GameManager.party.get_current_mp(_current_character_id)
	var max_mp: int = GameManager.party.get_max_mp(_current_character_id, tree)

	_hp_label.text = "HP: %d / %d" % [current_hp, max_hp]
	_hp_bar.max_value = max_hp
	_hp_bar.value = current_hp

	_mp_label.text = "MP: %d / %d" % [current_mp, max_mp]
	_mp_bar.max_value = max_mp
	_mp_bar.value = current_mp

	# Stat table
	_update_stat_table(char_data, inv, passive_bonuses)



func _update_stat_table(char_data: CharacterData, inv: GridInventory, passive_bonuses: Dictionary) -> void:
	_clear_children(_stat_rows)

	var equip_computed: Dictionary = inv.get_computed_stats() if inv else {}
	var equip_stats: Dictionary = equip_computed.get("stats", {})
	var passive_mods: Array = passive_bonuses.get("stat_modifiers", [])
	var entity: CombatEntity = CombatEntity.from_character(char_data, inv, passive_bonuses)

	var stats_list: Array = DISPLAY_STATS if _show_advanced_stats else SIMPLE_STATS

	if _show_advanced_stats:
		# Header row for detailed view
		var header: HBoxContainer = HBoxContainer.new()
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var h_stat: Label = _make_cell("Stat", 1.0)
		h_stat.add_theme_color_override("font_color", Constants.COLOR_TEXT_SECONDARY)
		header.add_child(h_stat)

		var h_base: Label = _make_cell("Base", 0.6)
		h_base.add_theme_color_override("font_color", Constants.COLOR_TEXT_SECONDARY)
		header.add_child(h_base)

		var h_equip: Label = _make_cell("Equip", 0.6)
		h_equip.add_theme_color_override("font_color", Constants.COLOR_TEXT_EMPHASIS)
		header.add_child(h_equip)

		var h_passive: Label = _make_cell("Passives", 0.6)
		h_passive.add_theme_color_override("font_color", Constants.COLOR_TEXT_SUCCESS)
		header.add_child(h_passive)

		var h_total: Label = _make_cell("Total", 0.6)
		h_total.add_theme_color_override("font_color", Constants.COLOR_TEXT_IMPORTANT)
		header.add_child(h_total)

		_stat_rows.add_child(header)

	for i in range(stats_list.size()):
		var stat: int = stats_list[i]
		var stat_name: String = STAT_NAMES[stat]
		var is_pct_stat: bool = (stat == Enums.Stat.CRITICAL_RATE or stat == Enums.Stat.CRITICAL_DAMAGE or stat == Enums.Stat.PHYSICAL_DEFENSE or stat == Enums.Stat.MAGICAL_DEFENSE)

		var base: float = float(char_data.get_base_stat(stat))
		if stat == Enums.Stat.CRITICAL_RATE:
			base = Constants.BASE_CRITICAL_RATE * 100.0
		elif stat == Enums.Stat.CRITICAL_DAMAGE:
			base = Constants.BASE_CRITICAL_DAMAGE * 100.0

		var equip: float = equip_stats.get(stat, 0.0)
		var passive: Dictionary = _compute_passive_bonus(stat, passive_mods)

		var effective: float = entity.get_effective_stat(stat)
		if stat == Enums.Stat.CRITICAL_RATE:
			effective = base + equip + passive.flat + passive.pct
		elif stat == Enums.Stat.CRITICAL_DAMAGE:
			effective = base + equip + passive.flat + passive.pct

		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if _show_advanced_stats:
			# Detailed: Stat / Base / Equip / Passives / Total
			var name_label: Label = _make_cell(stat_name, 1.0)
			name_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_PRIMARY)
			row.add_child(name_label)

			var base_text: String
			if is_pct_stat:
				base_text = "%.0f%%" % base
			else:
				base_text = "%d" % int(base)
			row.add_child(_make_cell(base_text, 0.6))

			var equip_bonus_text: String = _format_bonus(equip, is_pct_stat)
			var equip_label: Label = _make_cell(equip_bonus_text, 0.6)
			if equip > 0:
				equip_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_EMPHASIS)
			row.add_child(equip_label)

			var pass_val: float = passive.flat + passive.pct
			var pass_text: String = _format_bonus(pass_val, is_pct_stat)
			var pass_label: Label = _make_cell(pass_text, 0.6)
			if pass_val > 0:
				pass_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SUCCESS)
			row.add_child(pass_label)

			var eff_text: String
			if is_pct_stat:
				eff_text = "%.0f%%" % effective
			else:
				eff_text = "%.0f" % effective
			var eff_label: Label = _make_cell(eff_text, 0.6)
			eff_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_IMPORTANT)
			row.add_child(eff_label)
		else:
			# Simple: Stat name + Total
			var name_label: Label = Label.new()
			name_label.text = stat_name
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UIThemes.style_label(name_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_PRIMARY)
			row.add_child(name_label)

			var eff_text: String = "%.0f" % effective
			var val_label: Label = Label.new()
			val_label.text = eff_text
			val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			UIThemes.style_label(val_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_IMPORTANT)
			row.add_child(val_label)

		_stat_rows.add_child(row)


func _on_advanced_stats_pressed() -> void:
	_show_advanced_stats = not _show_advanced_stats
	_advanced_stats_btn.text = "Simple Stats" if _show_advanced_stats else "Advanced Stats"
	if _cached_char_data:
		_update_stat_table(_cached_char_data, _cached_inv, _cached_passive_bonuses)


# === Center Panel: Inventory Grid ===

func _update_center_panel(inv: GridInventory) -> void:
	if inv and _grid_panel.has_method("setup"):
		_grid_panel.setup(inv)
	_update_tier_display()
	_update_element_bar(inv)
	_item_tooltip.hide_tooltip()
	_show_skills_section()


func _update_tier_display() -> void:
	var char_data: CharacterData = GameManager.party.roster.get(_current_character_id) if GameManager.party else null
	if char_data and not char_data.backpack_tiers.is_empty():
		var state := GameManager.party.get_or_init_backpack_state(char_data)
		var current_tier: int = state.get("tier", 0) + 1
		var max_tier: int = char_data.backpack_tiers.size()
		_inventory_label.text = "Inventory — Tier %d / %d" % [current_tier, max_tier]
	else:
		_inventory_label.text = "Inventory"


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
	_item_tooltip.visible = false
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
		if _drag_state == DragState.DRAGGING:
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
	if _drag_state == DragState.IDLE and not inv.grid_template.is_cell_active(grid_pos):
		var char_data: CharacterData = GameManager.party.roster.get(_current_character_id)
		if char_data and not char_data.backpack_tiers.is_empty():
			var state := GameManager.party.get_or_init_backpack_state(char_data)
			if BackpackUpgradeSystem.get_purchasable_cells(char_data, state).has(grid_pos):
				if GameManager.buy_backpack_cell(_current_character_id, grid_pos):
					_grid_panel.refresh()


func _on_grid_cell_pressed(grid_pos: Vector2i, button: int) -> void:
	## Mouse button down — start dragging an item if there's one under the cursor.
	_stash_panel.clear_displaced_highlights()
	if button != MOUSE_BUTTON_LEFT or _drag_state != DragState.IDLE:
		return
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		return
	var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if placed:
		_start_drag_from_grid(placed, grid_pos)


func _on_grid_cell_released(grid_pos: Vector2i, button: int) -> void:
	## Mouse button up — place the dragged item, or return it if placement fails.
	if button != MOUSE_BUTTON_LEFT or _drag_state != DragState.DRAGGING:
		return
	var adjusted_pos: Vector2i = grid_pos - _drag_preview.get_center_cell_offset()
	_try_place_item(adjusted_pos)
	# If still dragging after try_place (placement failed), cancel and return item
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()


@warning_ignore("shadowed_variable")
func _on_grid_cell_hovered(grid_pos: Vector2i) -> void:
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		return

	if _drag_state == DragState.DRAGGING:
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
	if _drag_state == DragState.IDLE:
		_last_hovered_grid_pos = null
		_last_hovered_stash_item = null
		_item_tooltip.hide_tooltip()
		_show_skills_section()
		_grid_panel.clear_hover_feedback()


# === Stash Interaction ===

func _on_stash_item_clicked(item: ItemData, index: int) -> void:
	print("[Drag] Stash item clicked: '%s' index=%d drag_state=%d" % [item.display_name, index, _drag_state])
	_stash_panel.clear_displaced_highlights()
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
		_last_hovered_stash_item = item
		_last_hovered_stash_global_pos = global_pos
		_last_hovered_grid_pos = null
		if _tooltips_enabled:
			_hide_skills_section()
			var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
			_item_tooltip.show_for_item(item, null, inv, global_pos)


func _on_stash_background_clicked() -> void:
	if _drag_state == DragState.DRAGGING:
		_return_to_stash()


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
		var was_from_grid: bool = (_drag_source == DragSource.GRID)
		var source_pos: Vector2i = _drag_source_pos
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
	_pending_consumable_source = DragSource.STASH
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
	_pending_consumable_source = DragSource.GRID
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
	var source: DragSource = _pending_consumable_source
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
	if source == DragSource.STASH:
		if index < GameManager.party.stash.size():
			GameManager.party.stash.remove_at(index)
			_stash_panel.refresh(GameManager.party.stash)
			EventBus.stash_changed.emit()
	elif source == DragSource.GRID:
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
	_pending_consumable_source = DragSource.NONE
	_pending_consumable_index = -1
	_pending_consumable_placed = null


# === Drag & Drop ===

func _start_drag_from_grid(placed: GridInventory.PlacedItem, clicked_pos: Vector2i = Vector2i(-1, -1)) -> void:
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		return

	_dragged_item = placed.item_data
	_drag_source = DragSource.GRID
	_drag_source_placed = placed
	_drag_source_pos = placed.grid_position
	_drag_source_rotation = placed.rotation
	_drag_rotation = placed.rotation
	_drag_state = DragState.DRAGGING

	_drag_started_frame = Engine.get_process_frames()
	print("[Drag] START from grid: '%s' at %s rot=%d hands=%d frame=%d" % [placed.item_data.display_name, placed.grid_position, placed.rotation, placed.item_data.hand_slots_required, _drag_started_frame])
	inv.remove_item(placed)
	print("[Drag] After remove: hand_used=%d hand_avail=%d items=%d" % [inv.get_used_hand_slots(), inv.get_available_hand_slots(), inv.get_all_placed_items().size()])
	_grid_panel.refresh()
	_refresh_left_panel()

	var anchor: Vector2i = Vector2i(-1, -1)
	if clicked_pos != Vector2i(-1, -1):
		anchor = clicked_pos - placed.grid_position
	_drag_preview.cell_size = _grid_panel.cell_size
	_drag_preview.setup(_dragged_item, _drag_rotation, anchor)

	# Show placement preview at current mouse position (centered on cursor)
	var mouse_grid_pos: Vector2i = _grid_panel.world_to_grid(get_global_mouse_position()) - _drag_preview.get_center_cell_offset()
	_last_preview_grid_pos = mouse_grid_pos
	_grid_panel.show_placement_preview(_dragged_item, mouse_grid_pos, _drag_rotation)
	var can_place: bool = inv.can_place(_dragged_item, mouse_grid_pos, _drag_rotation)
	_drag_preview.set_valid(can_place)


func _start_drag_from_stash(item: ItemData, index: int) -> void:
	_drag_started_frame = Engine.get_process_frames()
	print("[Drag] START from stash: '%s' index=%d frame=%d" % [item.display_name, index, _drag_started_frame])
	_dragged_item = item
	_drag_source = DragSource.STASH
	_drag_source_stash_index = index
	_drag_rotation = 0
	_drag_state = DragState.DRAGGING

	GameManager.party.stash.remove_at(index)
	_stash_panel.refresh(GameManager.party.stash)
	_item_tooltip.hide_tooltip()

	_drag_preview.cell_size = _grid_panel.cell_size
	_drag_preview.setup(_dragged_item, _drag_rotation)

	# Show placement preview at current mouse position (centered on cursor)
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if inv:
		var mouse_grid_pos: Vector2i = _grid_panel.world_to_grid(get_global_mouse_position()) - _drag_preview.get_center_cell_offset()
		_last_preview_grid_pos = mouse_grid_pos
		_grid_panel.show_placement_preview(_dragged_item, mouse_grid_pos, _drag_rotation)
		var can_place: bool = inv.can_place(_dragged_item, mouse_grid_pos, _drag_rotation)
		_drag_preview.set_valid(can_place)


@warning_ignore("shadowed_variable")
func _try_place_item(grid_pos: Vector2i) -> void:
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		print("[TryPlace] No inventory!")
		return

	print("[TryPlace] item='%s' at %s rot=%d type=%d hands_req=%d" % [
		_dragged_item.display_name, grid_pos, _drag_rotation, _dragged_item.item_type, _dragged_item.hand_slots_required])
	print("[TryPlace] Inventory: placed=%d hand_used=%d hand_avail=%d" % [
		inv.get_all_placed_items().size(), inv.get_used_hand_slots(), inv.get_available_hand_slots()])

	# Check for upgrade
	var target_item: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if target_item:
		print("[TryPlace] Cell occupied by '%s', can_upgrade=%s" % [target_item.item_data.display_name, str(ItemUpgradeSystem.can_upgrade(_dragged_item, target_item.item_data))])
	if target_item and ItemUpgradeSystem.can_upgrade(_dragged_item, target_item.item_data):
		_perform_item_upgrade(inv, target_item)
		return

	var can_place_direct: bool = inv.can_place(_dragged_item, grid_pos, _drag_rotation)
	var fail_reason: String = inv.get_placement_failure_reason(_dragged_item, grid_pos, _drag_rotation) if not can_place_direct else ""
	print("[TryPlace] can_place=%s reason='%s'" % [str(can_place_direct), fail_reason])

	if can_place_direct:
		var item: ItemData = _dragged_item
		var was_from_stash: bool = (_drag_source == DragSource.STASH)
		var placed: GridInventory.PlacedItem = inv.place_item(item, grid_pos, _drag_rotation)
		if not placed:
			print("[TryPlace] place_item returned null despite can_place=true!")
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
	var blockers: Array = inv.get_blocking_items(_dragged_item, grid_pos, _drag_rotation)
	print("[TryPlace] Blockers: %d" % blockers.size())
	for bi in range(blockers.size()):
		print("[TryPlace]   blocker[%d]: '%s' at %s" % [bi, blockers[bi].item_data.display_name, blockers[bi].grid_position])
	if blockers.is_empty():
		print("[TryPlace] No blockers and can't place — giving up")
		return

	# Save blocker data, temporarily remove all, test placement, then decide
	var saved_blockers: Array = []
	for bi in range(blockers.size()):
		saved_blockers.append({"data": blockers[bi].item_data, "pos": blockers[bi].grid_position, "rot": blockers[bi].rotation})
	for bi in range(blockers.size()):
		inv.remove_item(blockers[bi])
	var can_place_now: bool = inv.can_place(_dragged_item, grid_pos, _drag_rotation)
	var fail_after: String = inv.get_placement_failure_reason(_dragged_item, grid_pos, _drag_rotation) if not can_place_now else ""
	print("[TryPlace] After removing blockers: can_place=%s reason='%s' hand_used=%d hand_avail=%d" % [
		str(can_place_now), fail_after, inv.get_used_hand_slots(), inv.get_available_hand_slots()])
	if not can_place_now:
		for ri in range(saved_blockers.size()):
			inv.place_item(saved_blockers[ri]["data"], saved_blockers[ri]["pos"], saved_blockers[ri]["rot"])
		print("[TryPlace] Restored blockers, can't displace")
		return

	print("[Displace] Displacing %d items to stash" % saved_blockers.size())
	var was_from_stash: bool = (_drag_source == DragSource.STASH)

	# Blockers already removed — send their data to stash
	var displaced_items: Array[ItemData] = []
	for si in range(saved_blockers.size()):
		displaced_items.append(saved_blockers[si]["data"])

	# Place the held item
	var item: ItemData = _dragged_item
	var placed: GridInventory.PlacedItem = inv.place_item(item, grid_pos, _drag_rotation)
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
	var dragged_name: String = _dragged_item.display_name
	var target_name: String = target_placed.item_data.display_name
	var was_from_stash: bool = (_drag_source == DragSource.STASH)
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
	var dragged_name: String = _dragged_item.display_name
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
	if not _dragged_item:
		return

	if not GameManager.party.add_to_stash(_dragged_item):
		EventBus.show_message.emit("Stash is full!")
		return

	var was_from_grid: bool = (_drag_source == DragSource.GRID)
	var item: ItemData = _dragged_item
	var item_name: String = _dragged_item.display_name
	var source_pos: Vector2i = _drag_source_pos

	_end_drag()
	_stash_panel.refresh(GameManager.party.stash)

	if was_from_grid:
		EventBus.item_removed.emit(_current_character_id, item, source_pos)
		EventBus.inventory_changed.emit(_current_character_id)
		_refresh_left_panel()

	EventBus.stash_changed.emit()
	DebugLogger.log_info("Returned %s to stash" % item_name, "CharStats")


func _cancel_drag() -> void:
	if not _dragged_item:
		_end_drag()
		return

	if _drag_source == DragSource.GRID:
		var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
		if inv:
			inv.place_item(_dragged_item, _drag_source_pos, _drag_source_rotation)
			_grid_panel.refresh()
	elif _drag_source == DragSource.STASH:
		GameManager.party.stash.insert(mini(_drag_source_stash_index, GameManager.party.stash.size()), _dragged_item)
		_stash_panel.refresh(GameManager.party.stash)

	_end_drag()
	_refresh_left_panel()


func _rotate_dragged_item() -> void:
	if not _dragged_item:
		return
	# Always allow 4 rotations so items can face any direction
	_drag_rotation = (_drag_rotation + 1) % 4
	_drag_preview.rotate_cw()
	# Force preview refresh at current position (rotation changed)
	_last_preview_grid_pos = Vector2i(-999, -999)
	EventBus.item_rotated.emit(_current_character_id, _dragged_item)


func _update_drag_preview() -> void:
	_stash_panel.highlight_drop_target(_stash_panel.is_mouse_over())

	# Update grid placement preview every frame based on mouse position (centered on cursor)
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if inv and _dragged_item:
		var grid_pos: Vector2i = _grid_panel.world_to_grid(get_global_mouse_position()) - _drag_preview.get_center_cell_offset()
		if grid_pos != _last_preview_grid_pos:
			_last_preview_grid_pos = grid_pos
			_grid_panel.show_placement_preview(_dragged_item, grid_pos, _drag_rotation)
			var placeable: bool = inv.can_place(_dragged_item, grid_pos, _drag_rotation)
			_drag_preview.set_valid(placeable)
			if not placeable and _grid_panel.last_failure_reason != "":
				_show_placement_hint(_grid_panel.last_failure_reason)
			else:
				_hide_placement_hint()

	_grid_panel.highlight_upgradeable_items(_dragged_item)
	_stash_panel.highlight_upgradeable_items(_dragged_item)


func _end_drag() -> void:
	_drag_state = DragState.IDLE
	_dragged_item = null
	_drag_source = DragSource.NONE
	_last_preview_grid_pos = Vector2i(-999, -999)
	_drag_source_placed = null
	_drag_source_stash_index = -1
	_drag_preview.hide_preview()
	_stash_panel.highlight_drop_target(false)
	_stash_panel.clear_upgradeable_highlights()
	_grid_panel.clear_placement_preview()
	_hide_placement_hint()


func _refresh_left_panel() -> void:
	var char_data: CharacterData = GameManager.party.roster.get(_current_character_id) if GameManager.party else null
	if not char_data:
		return
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id)
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var passive_bonuses: Dictionary = GameManager.party.get_passive_bonuses(_current_character_id, tree)
	_update_left_panel(char_data, inv, passive_bonuses)
	_update_skills_panel(char_data, inv)
	_update_element_bar(inv)


# === Helper Functions ===

func _compute_passive_bonus(stat: int, passive_mods: Array) -> Dictionary:
	var flat: float = 0.0
	var pct: float = 0.0
	for i in range(passive_mods.size()):
		var mod: StatModifier = passive_mods[i]
		if mod.stat == stat:
			if mod.modifier_type == Enums.ModifierType.FLAT:
				flat += mod.value
			else:
				pct += mod.value
	return {"flat": flat, "pct": pct}


func _format_bonus(value: float, is_pct: bool) -> String:
	if value == 0.0:
		return "-"
	if is_pct:
		return "+%.0f%%" % value
	return "+%d" % int(value)


func _make_cell(text: String, stretch: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = stretch
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIThemes.set_font_size(label, Constants.FONT_SIZE_SMALL)
	return label


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


var _placement_hint_label: Label = null

func _show_placement_hint(reason: String) -> void:
	if _placement_hint_label:
		_placement_hint_label.text = reason

func _hide_placement_hint() -> void:
	if _placement_hint_label:
		_placement_hint_label.text = ""


func _on_gold_changed(_new_gold: int) -> void:
	_update_gold_display()


func _update_gold_display() -> void:
	_gold_label.text = "Gold: %d" % GameManager.gold
