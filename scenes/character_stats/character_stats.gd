extends Control
## Character stat screen with inventory display.
## Shows character info, skills, stat breakdown, inventory grid, and unlocked passives.

@onready var _back_btn: Button = $VBox/TopBar/BackButton
@onready var _title: Label = $VBox/TopBar/Title
@onready var _gold_label: Label = $VBox/TopBar/Gold
@onready var _character_tabs: HBoxContainer = $VBox/CharacterTabs
@onready var _stats_tab: Button = $VBox/ViewTabs/StatsTab
@onready var _skills_tab: Button = $VBox/ViewTabs/SkillsTab
@onready var _inventory_tab: Button = $VBox/ViewTabs/InventoryTab

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

# Center panel
@onready var _grid_panel: Control = $VBox/Content/CenterPanel/VBox/GridCentering/GridPanel

# Right panel
@onready var _passives_list: VBoxContainer = $VBox/Content/RightPanel/VBox/PassivesScroll/PassivesList

var _current_character_id: String = ""

# Stats to display in order
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
	_back_btn.pressed.connect(_on_back)
	_stats_tab.pressed.connect(func() -> void: pass)  # No-op, always on stats view
	_skills_tab.pressed.connect(func() -> void: pass)
	_inventory_tab.pressed.connect(func() -> void: pass)

	if GameManager.party:
		_character_tabs.setup(GameManager.party.squad, GameManager.party.roster)
		_character_tabs.character_selected.connect(_on_character_selected)

	if GameManager.party and not GameManager.party.squad.is_empty():
		_on_character_selected(GameManager.party.squad[0])
		_character_tabs.select(GameManager.party.squad[0])

	# Update gold display
	EventBus.gold_changed.connect(_on_gold_changed)
	_update_gold_display()

	DebugLogger.log_info("Character stats scene ready", "CharStats")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		_on_back()
		get_viewport().set_input_as_handled()


func _on_back() -> void:
	SceneManager.pop_scene()


var _embedded: bool = false

func setup_embedded(character_id: String) -> void:
	_embedded = true
	$VBox/TopBar.visible = false
	$VBox/CharacterTabs.visible = false
	$VBox/ViewTabs.visible = false
	_on_character_selected(character_id)


func _on_character_selected(character_id: String) -> void:
	_current_character_id = character_id
	var char_data: CharacterData = GameManager.party.roster.get(character_id)
	if not char_data:
		return

	var inv: GridInventory = GameManager.party.grid_inventories.get(character_id)
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree(character_id)
	var passive_bonuses: Dictionary = GameManager.party.get_passive_bonuses(character_id, tree)

	_update_left_panel(char_data, inv, passive_bonuses)
	_update_center_panel(inv)
	_update_right_panel(character_id, tree)


# === Left Panel: Character Info + Skills + Stats ===

func _update_left_panel(char_data: CharacterData, inv: GridInventory, passive_bonuses: Dictionary) -> void:
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
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree(_current_character_id)
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

	# Build a CombatEntity to get effective stats
	var entity: CombatEntity = CombatEntity.from_character(char_data, inv, passive_bonuses)

	for i in range(DISPLAY_STATS.size()):
		var stat: int = DISPLAY_STATS[i]
		var stat_name: String = STAT_NAMES[stat]
		var is_pct_stat: bool = (stat == Enums.Stat.CRITICAL_RATE or stat == Enums.Stat.CRITICAL_DAMAGE or stat == Enums.Stat.PHYSICAL_DEFENSE or stat == Enums.Stat.MAGICAL_DEFENSE)

		# Base value
		var base: float = float(char_data.get_base_stat(stat))
		if stat == Enums.Stat.CRITICAL_RATE:
			base = Constants.BASE_CRITICAL_RATE * 100.0
		elif stat == Enums.Stat.CRITICAL_DAMAGE:
			base = Constants.BASE_CRITICAL_DAMAGE * 100.0

		# Equipment bonus
		var equip: float = equip_stats.get(stat, 0.0)

		# Passive bonus
		var passive: Dictionary = _compute_passive_bonus(stat, passive_mods)

		# Effective value
		var effective: float = entity.get_effective_stat(stat)
		if stat == Enums.Stat.CRITICAL_RATE:
			effective = base + equip + passive.flat + passive.pct
		elif stat == Enums.Stat.CRITICAL_DAMAGE:
			effective = base + equip + passive.flat + passive.pct

		# Create row with new column order: Equip bonus / Stat / Base / Equip num / Passives / Total
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Equip bonus (colored, left column)
		var equip_bonus_text: String = _format_bonus(equip, is_pct_stat)
		var equip_bonus_label: Label = _make_cell(equip_bonus_text, 0.6)
		if equip > 0:
			equip_bonus_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		row.add_child(equip_bonus_label)

		# Stat name
		var name_label: Label = _make_cell(stat_name, 1.0)
		name_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_PRIMARY)
		row.add_child(name_label)

		# Base
		var base_text: String
		if is_pct_stat:
			base_text = "%.0f%%" % base
		else:
			base_text = "%d" % int(base)
		row.add_child(_make_cell(base_text, 0.6))

		# Equipment (number, same as first column but right-aligned)
		var equip_label: Label = _make_cell(equip_bonus_text, 0.6)
		if equip > 0:
			equip_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		row.add_child(equip_label)

		# Passives
		var pass_val: float = passive.flat + passive.pct
		var pass_text: String = _format_bonus(pass_val, is_pct_stat)
		var pass_label: Label = _make_cell(pass_text, 0.6)
		if pass_val > 0:
			pass_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SUCCESS)
		row.add_child(pass_label)

		# Effective total
		var eff_text: String
		if is_pct_stat:
			eff_text = "%.0f%%" % effective
		else:
			eff_text = "%.0f" % effective
		var eff_label: Label = _make_cell(eff_text, 0.6)
		eff_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_IMPORTANT)
		row.add_child(eff_label)

		_stat_rows.add_child(row)

	# Add Block Power row
	_add_block_power_row(inv)


func _add_block_power_row(inv: GridInventory) -> void:
	var max_block: float = 0.0

	if inv:
		for i in range(inv.get_all_placed_items().size()):
			var placed: GridInventory.PlacedItem = inv.get_all_placed_items()[i]
			if placed.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
				if placed.item_data.block_percentage > max_block:
					max_block = placed.item_data.block_percentage

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Equip bonus (left)
	var block_text: String = "%.0f%%" % (max_block * 100.0) if max_block > 0 else "-"
	var block_bonus: Label = _make_cell(block_text, 0.6)
	if max_block > 0:
		block_bonus.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	row.add_child(block_bonus)

	# Stat name
	var name_label: Label = _make_cell("Block Power", 1.0)
	name_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_PRIMARY)
	row.add_child(name_label)

	# Base
	row.add_child(_make_cell("-", 0.6))

	# Equip (number)
	var block_label: Label = _make_cell(block_text, 0.6)
	if max_block > 0:
		block_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	row.add_child(block_label)

	# Passives
	row.add_child(_make_cell("-", 0.6))

	# Total
	var total_label: Label = _make_cell(block_text, 0.6)
	if max_block > 0:
		total_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_IMPORTANT)
	row.add_child(total_label)

	_stat_rows.add_child(row)


# === Center Panel: Inventory Grid (Read-only) ===

func _update_center_panel(inv: GridInventory) -> void:
	if inv and _grid_panel.has_method("setup"):
		_grid_panel.setup(inv)
		# Make grid read-only (disable interaction)
		if _grid_panel.has_method("set_interaction_enabled"):
			_grid_panel.set_interaction_enabled(false)


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


func _on_gold_changed(_new_gold: int) -> void:
	_update_gold_display()


func _update_gold_display() -> void:
	_gold_label.text = "Gold: %d" % GameManager.gold
