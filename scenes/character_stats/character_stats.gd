extends Control
## Character stat screen with inventory grid and stash.
## Shows character info, skills, stat breakdown, inventory grid, unlocked passives, and stash.

@onready var _bg: ColorRect = $BG
@onready var _back_btn: Button = $VBox/TopBar/BackButton
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
@onready var _skills_list: VBoxContainer = $VBox/Content/LeftPanel/VBox/SkillsList
@onready var _stat_rows: VBoxContainer = $VBox/Content/LeftPanel/VBox/StatRows
@onready var _advanced_stats_btn: Button = $VBox/Content/LeftPanel/VBox/AdvancedStatsBtn

# Center panel
@onready var _grid_panel: Control = $VBox/Content/CenterPanel/VBox/GridCentering/GridPanel

# Right panel
@onready var _passives_list: VBoxContainer = $VBox/Content/RightPanel/VBox/PassivesScroll/PassivesList
@onready var _stash_panel: PanelContainer = $VBox/Content/RightPanel/VBox/StashPanel

# Drag & tooltip layers
@onready var _item_tooltip: PanelContainer = $TooltipLayer/ItemTooltip
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
	_grid_panel.cell_hovered.connect(_on_grid_cell_hovered)
	_grid_panel.cell_exited.connect(_on_hover_exited)

	# Stash interaction signals
	if GameManager.party:
		_stash_panel.refresh(GameManager.party.stash)
	_stash_panel.item_clicked.connect(_on_stash_item_clicked)
	_stash_panel.item_hovered.connect(_on_stash_item_hovered)
	_stash_panel.item_exited.connect(_on_hover_exited)
	_stash_panel.item_use_requested.connect(_on_stash_item_use_requested)
	_stash_panel.background_clicked.connect(_on_stash_background_clicked)

	if GameManager.party:
		_character_tabs.setup(GameManager.party.squad, GameManager.party.roster)
		_character_tabs.character_selected.connect(_on_character_selected)

	if GameManager.party and not GameManager.party.squad.is_empty():
		_on_character_selected(GameManager.party.squad[0])
		_character_tabs.select(GameManager.party.squad[0])

	# Update gold display
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.stash_changed.connect(_on_stash_changed)
	_update_gold_display()

	# Hide tooltip and drag preview initially
	_item_tooltip.visible = false
	_drag_preview.visible = false

	# Placement hint label — always in the tree to avoid layout reflow
	_placement_hint_label = Label.new()
	_placement_hint_label.add_theme_font_size_override("font_size", 13)
	_placement_hint_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_placement_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placement_hint_label.custom_minimum_size.y = 18
	_placement_hint_label.text = ""
	_grid_panel.get_parent().get_parent().add_child(_placement_hint_label)

	DebugLogger.log_info("Character stats scene ready", "CharStats")


func _unhandled_input(event: InputEvent) -> void:
	# Hold T to temporarily hide tooltips
	if event is InputEventKey and event.keycode == KEY_T:
		if event.pressed:
			_tooltips_enabled = false
			_item_tooltip.hide_tooltip()
		else:
			_tooltips_enabled = true
			if _last_hovered_grid_pos != null:
				var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
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
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_drag()
			get_viewport().set_input_as_handled()
			return
		return

	if event.is_action_pressed("escape"):
		_on_back()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _drag_state == DragState.DRAGGING:
		_update_drag_preview()


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
	_update_right_panel(character_id, tree)
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

	# Skills list
	_update_skills_list(char_data, inv)

	# Stat table
	_update_stat_table(char_data, inv, passive_bonuses)


func _update_skills_list(char_data: CharacterData, inv: GridInventory) -> void:
	_clear_children(_skills_list)

	# Innate skills
	for i in range(char_data.innate_skills.size()):
		var skill = char_data.innate_skills[i]
		if skill is SkillData:
			var label: Label = Label.new()
			label.text = "• %s (MP: %d)" % [skill.display_name, skill.mp_cost]
			label.add_theme_font_size_override("font_size", 14)
			_skills_list.add_child(label)

	# Skills from equipment
	if inv:
		for i in range(inv.get_all_placed_items().size()):
			var placed: GridInventory.PlacedItem = inv.get_all_placed_items()[i]
			if placed.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
				for j in range(placed.item_data.granted_skills.size()):
					var skill = placed.item_data.granted_skills[j]
					if skill is SkillData:
						var label: Label = Label.new()
						label.text = "• %s (MP: %d)" % [skill.display_name, skill.mp_cost]
						label.add_theme_font_size_override("font_size", 14)
						label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
						_skills_list.add_child(label)


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
		h_stat.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		header.add_child(h_stat)

		var h_base: Label = _make_cell("Base", 0.6)
		h_base.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		header.add_child(h_base)

		var h_equip: Label = _make_cell("Equip", 0.6)
		h_equip.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 1))
		header.add_child(h_equip)

		var h_passive: Label = _make_cell("Passives", 0.6)
		h_passive.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3, 1))
		header.add_child(h_passive)

		var h_total: Label = _make_cell("Total", 0.6)
		h_total.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1))
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
				equip_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
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
			name_label.add_theme_font_size_override("font_size", 14)
			name_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_PRIMARY)
			row.add_child(name_label)

			var eff_text: String = "%.0f" % effective
			var val_label: Label = Label.new()
			val_label.text = eff_text
			val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val_label.add_theme_font_size_override("font_size", 14)
			val_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_IMPORTANT)
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
	_item_tooltip.hide_tooltip()


# === Right Panel: Unlocked Passives ===

func _update_right_panel(character_id: String, tree: PassiveTreeData) -> void:
	_clear_children(_passives_list)

	if not tree:
		return

	var unlocked: Array = GameManager.party.get_unlocked_passives(character_id)
	for i in range(unlocked.size()):
		var node_id: String = unlocked[i]
		var node: PassiveNodeData = tree.get_node_by_id(node_id)
		if not node:
			continue

		# Node name label
		var name_label: Label = Label.new()
		name_label.text = node.display_name
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		_passives_list.add_child(name_label)

		# Stat bonuses
		for j in range(node.stat_modifiers.size()):
			var mod: StatModifier = node.stat_modifiers[j]
			var stat_name: String = STAT_NAMES.get(mod.stat, "Unknown")
			var value_str: String
			if mod.modifier_type == Enums.ModifierType.FLAT:
				value_str = "+%d %s" % [int(mod.value), stat_name]
			else:
				value_str = "+%d%% %s" % [int(mod.value), stat_name]

			var bonus_label: Label = Label.new()
			bonus_label.text = "• %s" % value_str
			bonus_label.add_theme_font_size_override("font_size", 14)
			bonus_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SUCCESS)
			_passives_list.add_child(bonus_label)

		# Special effect
		if not node.special_effect_id.is_empty():
			var effect_label: Label = Label.new()
			effect_label.text = "• %s" % PassiveEffects.get_description(node.special_effect_id)
			effect_label.add_theme_font_size_override("font_size", 14)
			effect_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_EMPHASIS)
			_passives_list.add_child(effect_label)


# === Grid Interaction ===

func _on_grid_cell_clicked(grid_pos: Vector2i, button: int) -> void:
	# Right-click to use consumables
	if button == MOUSE_BUTTON_RIGHT:
		var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
		if inv:
			var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
			if placed and placed.item_data.item_type == Enums.ItemType.CONSUMABLE and placed.item_data.use_skill:
				_on_grid_item_use_requested(placed)
		return

	if button != MOUSE_BUTTON_LEFT:
		return

	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		return

	if _drag_state == DragState.DRAGGING:
		_try_place_item(grid_pos)
	else:
		var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
		if placed:
			_start_drag_from_grid(placed)


func _on_grid_cell_hovered(grid_pos: Vector2i) -> void:
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		return

	if _drag_state == DragState.DRAGGING:
		return  # Handled by _update_drag_preview in _process
	else:
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


func _on_hover_exited() -> void:
	if _drag_state == DragState.IDLE:
		_last_hovered_grid_pos = null
		_last_hovered_stash_item = null
		_item_tooltip.hide_tooltip()
		_grid_panel.clear_highlights()


# === Stash Interaction ===

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
		_last_hovered_stash_item = item
		_last_hovered_stash_global_pos = global_pos
		_last_hovered_grid_pos = null
		if _tooltips_enabled:
			_item_tooltip.show_for_item(item, null, null, global_pos)


func _on_stash_background_clicked() -> void:
	if _drag_state == DragState.DRAGGING:
		_return_to_stash()


func _on_stash_changed() -> void:
	if GameManager.party:
		_stash_panel.refresh(GameManager.party.stash)


# === Consumable Usage ===

func _on_stash_item_use_requested(item: ItemData, index: int) -> void:
	if not item.use_skill:
		return
	_pending_consumable = item
	_pending_consumable_source = DragSource.STASH
	_pending_consumable_index = index
	_pending_consumable_placed = null
	_show_target_selection_popup()


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
	vbox.add_theme_constant_override("separation", 8)
	_target_selection_popup.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Select Target"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", Constants.FONT_SIZE_TITLE)
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

func _start_drag_from_grid(placed: GridInventory.PlacedItem) -> void:
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

	inv.remove_item(placed)
	_grid_panel.refresh()
	_item_tooltip.hide_tooltip()
	_refresh_left_panel()

	_drag_preview.setup(_dragged_item, _drag_rotation)

	# Show placement preview at current mouse position
	var mouse_grid_pos: Vector2i = _grid_panel.world_to_grid(get_global_mouse_position())
	_last_preview_grid_pos = mouse_grid_pos
	_grid_panel.show_placement_preview(_dragged_item, mouse_grid_pos, _drag_rotation)
	var can_place: bool = inv.can_place(_dragged_item, mouse_grid_pos, _drag_rotation)
	_drag_preview.set_valid(can_place)


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

	# Show placement preview at current mouse position
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if inv:
		var mouse_grid_pos: Vector2i = _grid_panel.world_to_grid(get_global_mouse_position())
		_last_preview_grid_pos = mouse_grid_pos
		_grid_panel.show_placement_preview(_dragged_item, mouse_grid_pos, _drag_rotation)
		var can_place: bool = inv.can_place(_dragged_item, mouse_grid_pos, _drag_rotation)
		_drag_preview.set_valid(can_place)


func _try_place_item(grid_pos: Vector2i) -> void:
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if not inv:
		return

	# Check for upgrade
	var target_item: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if target_item and ItemUpgradeSystem.can_upgrade(_dragged_item, target_item.item_data):
		_perform_item_upgrade(inv, target_item)
		return

	if not inv.can_place(_dragged_item, grid_pos, _drag_rotation):
		return

	var item: ItemData = _dragged_item
	var was_from_stash: bool = (_drag_source == DragSource.STASH)
	var placed: GridInventory.PlacedItem = inv.place_item(item, grid_pos, _drag_rotation)
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
	GameManager.party.add_to_stash(upgraded_item)

	_end_drag()
	_stash_panel.refresh(GameManager.party.stash)
	EventBus.stash_changed.emit()

	DebugLogger.log_info("STASH UPGRADE! %s + %s → %s" % [
		dragged_name, target_item.display_name, upgraded_item.display_name
	], "CharStats")


func _return_to_stash() -> void:
	if not _dragged_item:
		return

	var was_from_grid: bool = (_drag_source == DragSource.GRID)
	var item: ItemData = _dragged_item
	var item_name: String = _dragged_item.display_name
	var source_pos: Vector2i = _drag_source_pos
	GameManager.party.add_to_stash(_dragged_item)

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

	# Update grid placement preview every frame based on mouse position
	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	if inv and _dragged_item:
		var grid_pos: Vector2i = _grid_panel.world_to_grid(get_global_mouse_position())
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
	label.add_theme_font_size_override("font_size", 13)
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
