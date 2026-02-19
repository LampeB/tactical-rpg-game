extends Control
## Character stat screen. Shows full stat breakdown per character:
## base stats, equipment bonuses, passive bonuses, and effective totals.

@onready var _back_btn: Button = $VBox/TopBar/BackButton
@onready var _title: Label = $VBox/TopBar/Title
@onready var _character_tabs: HBoxContainer = $VBox/CharacterTabs
@onready var _portrait: TextureRect = $VBox/Content/InfoPanel/InfoVBox/Portrait
@onready var _char_name: Label = $VBox/Content/InfoPanel/InfoVBox/CharName
@onready var _char_desc: Label = $VBox/Content/InfoPanel/InfoVBox/CharDesc
@onready var _skills_header: Label = $VBox/Content/InfoPanel/InfoVBox/SkillsHeader
@onready var _skills_list: VBoxContainer = $VBox/Content/InfoPanel/InfoVBox/SkillsList
@onready var _effects_header: Label = $VBox/Content/InfoPanel/InfoVBox/EffectsHeader
@onready var _effects_list: VBoxContainer = $VBox/Content/InfoPanel/InfoVBox/EffectsList
@onready var _stat_rows: VBoxContainer = $VBox/Content/StatsPanel/StatsVBox/StatRows

var _current_character_id: String = ""

# Stats to display in order
const DISPLAY_STATS: Array = [
	Enums.Stat.MAX_HP,
	Enums.Stat.MAX_MP,
	Enums.Stat.SPEED,
	Enums.Stat.LUCK,
	Enums.Stat.PHYSICAL_ATTACK,
	Enums.Stat.PHYSICAL_DEFENSE,
	Enums.Stat.SPECIAL_ATTACK,
	Enums.Stat.SPECIAL_DEFENSE,
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
	Enums.Stat.SPECIAL_ATTACK: "Spec Atk",
	Enums.Stat.SPECIAL_DEFENSE: "Spec Def",
	Enums.Stat.CRITICAL_RATE: "Crit Rate",
	Enums.Stat.CRITICAL_DAMAGE: "Crit Dmg",
}


func _ready() -> void:
	_back_btn.pressed.connect(_on_back)

	if GameManager.party:
		_character_tabs.setup(GameManager.party.squad, GameManager.party.roster)
		_character_tabs.character_selected.connect(_on_character_selected)

	if GameManager.party and not GameManager.party.squad.is_empty():
		_on_character_selected(GameManager.party.squad[0])
		_character_tabs.select(GameManager.party.squad[0])

	DebugLogger.log_info("Character stats scene ready", "CharStats")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		_on_back()
		get_viewport().set_input_as_handled()


func _on_back() -> void:
	SceneManager.pop_scene()


func _on_character_selected(character_id: String) -> void:
	_current_character_id = character_id
	var char_data: CharacterData = GameManager.party.roster.get(character_id)
	if not char_data:
		return

	var inv: GridInventory = GameManager.party.grid_inventories.get(character_id)
	var tree = get_node("/root/PassiveTreeDatabase").get_passive_tree(character_id)
	var passive_bonuses: Dictionary = GameManager.party.get_passive_bonuses(character_id, tree)

	_update_info_panel(char_data, inv, passive_bonuses)
	_update_stat_table(char_data, inv, passive_bonuses)


# === Info Panel ===

func _update_info_panel(char_data: CharacterData, inv: GridInventory, passive_bonuses: Dictionary) -> void:
	# Portrait
	if char_data.portrait:
		_portrait.texture = char_data.portrait
		_portrait.visible = true
	else:
		_portrait.visible = false

	_char_name.text = char_data.display_name
	_char_desc.text = char_data.description if not char_data.description.is_empty() else ""

	# Skills
	_clear_children(_skills_list)
	var skills: Array = _get_all_skills(char_data, inv)
	if skills.is_empty():
		_skills_header.visible = false
	else:
		_skills_header.visible = true
		for i in range(skills.size()):
			var skill: SkillData = skills[i]
			var label: Label = Label.new()
			label.text = "• %s (MP: %d)" % [skill.display_name, skill.mp_cost]
			label.add_theme_font_size_override("font_size", 14)
			_skills_list.add_child(label)

	# Passive effects
	_clear_children(_effects_list)
	var effects: Array = passive_bonuses.get("special_effects", [])
	if effects.is_empty():
		_effects_header.visible = false
	else:
		_effects_header.visible = true
		for i in range(effects.size()):
			var label: Label = Label.new()
			label.text = "• %s" % _get_effect_description(effects[i])
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
			_effects_list.add_child(label)


func _get_all_skills(char_data: CharacterData, inv: GridInventory) -> Array:
	var skills: Array = []
	for i in range(char_data.innate_skills.size()):
		var skill = char_data.innate_skills[i]
		if skill is SkillData:
			skills.append(skill)
	if inv:
		for i in range(inv.get_all_placed_items().size()):
			var placed: GridInventory.PlacedItem = inv.get_all_placed_items()[i]
			for j in range(placed.item_data.granted_skills.size()):
				var skill = placed.item_data.granted_skills[j]
				if skill is SkillData and skill not in skills:
					skills.append(skill)
	return skills


# === Stat Table ===

func _update_stat_table(char_data: CharacterData, inv: GridInventory, passive_bonuses: Dictionary) -> void:
	_clear_children(_stat_rows)

	var equip_stats: Dictionary = inv.get_computed_stats() if inv else {}
	var passive_mods: Array = passive_bonuses.get("stat_modifiers", [])

	# Build a CombatEntity to get effective stats
	var entity: CombatEntity = CombatEntity.from_character(char_data, inv, passive_bonuses)

	for i in range(DISPLAY_STATS.size()):
		var stat: int = DISPLAY_STATS[i]
		var stat_name: String = STAT_NAMES[stat]
		var is_pct_stat: bool = (stat == Enums.Stat.CRITICAL_RATE or stat == Enums.Stat.CRITICAL_DAMAGE)

		# Base value
		var base: float = float(char_data.get_base_stat(stat))
		if stat == Enums.Stat.CRITICAL_RATE:
			base = Constants.BASE_CRITICAL_RATE * 100.0  # Display as percentage
		elif stat == Enums.Stat.CRITICAL_DAMAGE:
			base = Constants.BASE_CRITICAL_DAMAGE * 100.0

		# Equipment bonus
		var equip: float = equip_stats.get(stat, 0.0)

		# Passive bonus (combined flat + pct display)
		var passive: Dictionary = _compute_passive_bonus(stat, passive_mods)

		# Effective value
		var effective: float = entity.get_effective_stat(stat)
		if stat == Enums.Stat.CRITICAL_RATE:
			# CombatEntity doesn't compute crit rate in get_effective_stat,
			# compute it manually: base + equipment + passives (all are in % points)
			effective = base + equip + passive.flat + passive.pct
		elif stat == Enums.Stat.CRITICAL_DAMAGE:
			effective = base + equip + passive.flat + passive.pct

		# Create row
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Stat name
		var name_label: Label = _make_cell(stat_name, 1.2)
		name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		row.add_child(name_label)

		# Base
		var base_text: String
		if is_pct_stat:
			base_text = "%.0f%%" % base
		else:
			base_text = "%d" % int(base)
		row.add_child(_make_cell(base_text, 0.8))

		# Equipment
		var equip_text: String = _format_bonus(equip, is_pct_stat)
		var equip_label: Label = _make_cell(equip_text, 0.8)
		if equip > 0:
			equip_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		row.add_child(equip_label)

		# Passives
		var pass_val: float = passive.flat + passive.pct
		var pass_text: String = _format_bonus(pass_val, is_pct_stat)
		var pass_label: Label = _make_cell(pass_text, 0.8)
		if pass_val > 0:
			pass_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))
		row.add_child(pass_label)

		# Effective total
		var eff_text: String
		if is_pct_stat:
			eff_text = "%.0f%%" % effective
		else:
			eff_text = "%.0f" % effective
		var eff_label: Label = _make_cell(eff_text, 0.8)
		eff_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		row.add_child(eff_label)

		_stat_rows.add_child(row)


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
	label.add_theme_font_size_override("font_size", 15)
	return label


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _get_effect_description(effect_id: String) -> String:
	match effect_id:
		PassiveEffects.COUNTER_ATTACK:
			return "15% chance to counter-attack"
		PassiveEffects.LIFESTEAL_5:
			return "Heal 5% of damage dealt"
		PassiveEffects.LIFESTEAL_10:
			return "Heal 10% of damage dealt"
		PassiveEffects.START_SHIELD:
			return "Gain 15 HP shield at battle start"
		PassiveEffects.THORNS:
			return "Reflect 5 damage when hit"
		PassiveEffects.MANA_REGEN:
			return "Restore 3 MP each turn"
		PassiveEffects.EVASION:
			return "10% chance to dodge attacks"
		PassiveEffects.FIRST_STRIKE:
			return "+50 Speed in round 1"
		PassiveEffects.DOUBLE_GOLD:
			return "Double gold earned from battles"
		_:
			return effect_id
