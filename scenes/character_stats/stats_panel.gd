extends Control
## Stats panel — character info, HP/MP, stat table, skills display.
## Used in the game menu's Stats tab.

var _current_character_id: String = ""
var _vbox: VBoxContainer


func _ready() -> void:
	pass


func setup_embedded(character_id: String) -> void:
	_current_character_id = character_id
	_build_stats_view()


func _build_stats_view() -> void:
	# Clear previous content
	for child in get_children():
		child.queue_free()

	var char_data: CharacterData = GameManager.party.roster.get(_current_character_id) if GameManager.party else null
	if not char_data:
		return

	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var passive_bonuses: Dictionary = GameManager.party.get_passive_bonuses(_current_character_id, tree) if GameManager.party else {}

	# Main layout: left stats + right skills
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	add_child(hbox)

	# === Left: Character Info + Stats ===
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	hbox.add_child(left)

	# Character header
	var name_lbl := Label.new()
	name_lbl.text = char_data.display_name
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	left.add_child(name_lbl)

	var class_lbl := Label.new()
	class_lbl.text = char_data.character_class
	class_lbl.add_theme_font_size_override("font_size", 16)
	class_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	left.add_child(class_lbl)

	if not char_data.description.is_empty():
		var desc_lbl := Label.new()
		desc_lbl.text = char_data.description
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		left.add_child(desc_lbl)

	# HP/MP bars
	var hp_cur: int = GameManager.party.get_current_hp(_current_character_id) if GameManager.party else char_data.max_hp
	var hp_max: int = GameManager.party.get_max_hp(_current_character_id, tree) if GameManager.party else char_data.max_hp
	var mp_cur: int = GameManager.party.get_current_mp(_current_character_id) if GameManager.party else char_data.max_mp
	var mp_max: int = GameManager.party.get_max_mp(_current_character_id, tree) if GameManager.party else char_data.max_mp

	_add_bar(left, "HP", hp_cur, hp_max, Color(0.2, 0.8, 0.2))
	_add_bar(left, "MP", mp_cur, mp_max, Color(0.3, 0.5, 1.0))

	# Separator
	left.add_child(HSeparator.new())

	# Stat table
	var equip_stats: Dictionary = inv.get_computed_stats().get("stats", {}) if inv else {}
	var passive_mods: Array = passive_bonuses.get("stat_modifiers", [])

	var stats: Array = [
		["Physical Attack", Enums.Stat.PHYSICAL_ATTACK],
		["Physical Defense", Enums.Stat.PHYSICAL_DEFENSE],
		["Magical Attack", Enums.Stat.MAGICAL_ATTACK],
		["Magical Defense", Enums.Stat.MAGICAL_DEFENSE],
		["Speed", Enums.Stat.SPEED],
		["Luck", Enums.Stat.LUCK],
	]

	for stat_info in stats:
		var stat_name: String = stat_info[0]
		var stat_id: int = stat_info[1]
		var base: int = char_data.get_base_stat(stat_id)
		var equip: int = int(equip_stats.get(stat_id, 0.0))
		var passive: int = _get_passive_flat(stat_id, passive_mods)
		var total: int = base + equip + passive
		_add_stat_row(left, stat_name, base, equip, passive, total)

	# === Right: Skills ===
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	hbox.add_child(right)

	var skills_title := Label.new()
	skills_title.text = "Active Skills"
	skills_title.add_theme_font_size_override("font_size", 18)
	skills_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	right.add_child(skills_title)
	right.add_child(HSeparator.new())

	# Innate skills
	for skill in char_data.innate_skills:
		if skill is SkillData:
			_add_skill_row(right, skill, true)

	# Element-unlocked skills
	var element_points: Dictionary = inv.get_element_points() if inv else {}
	var table: ElementSkillTable = ElementSkillSystem.get_table()
	if table:
		var innate_ids: Array[String] = []
		for skill in char_data.innate_skills:
			if skill is SkillData:
				innate_ids.append(skill.id)
		var unlocked: Array[SkillData] = table.get_unlocked_skills(element_points)
		for skill in unlocked:
			if skill.id not in innate_ids:
				_add_skill_row(right, skill, false)

	var has_skills: bool = not char_data.innate_skills.is_empty()
	if not has_skills and table:
		has_skills = not table.get_unlocked_skills(element_points).is_empty()
	if not has_skills:
		var no_skills := Label.new()
		no_skills.text = "No active skills"
		no_skills.add_theme_font_size_override("font_size", 14)
		no_skills.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		right.add_child(no_skills)

	# Equipment summary
	right.add_child(HSeparator.new())
	var equip_title := Label.new()
	equip_title.text = "Equipment Summary"
	equip_title.add_theme_font_size_override("font_size", 16)
	equip_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	right.add_child(equip_title)

	if inv:
		_equipment_panel = load("res://scenes/inventory/ui/equipment_slots_panel.tscn").instantiate()
		right.add_child(_equipment_panel)
		_equipment_panel.setup(inv)


var _equipment_panel: PanelContainer = null


func _add_bar(parent: VBoxContainer, label_text: String, current: int, maximum: int, _color: Color) -> void:
	var lbl := Label.new()
	lbl.text = "%s: %d / %d" % [label_text, current, maximum]
	lbl.add_theme_font_size_override("font_size", 15)
	parent.add_child(lbl)
	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.value = current
	bar.custom_minimum_size = Vector2(0, 12)
	bar.show_percentage = false
	parent.add_child(bar)


func _add_stat_row(parent: VBoxContainer, stat_name: String, base: int, equip: int, passive: int, total: int) -> void:
	var row := HBoxContainer.new()
	var lbl_name := Label.new()
	lbl_name.text = stat_name
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.add_theme_font_size_override("font_size", 14)
	lbl_name.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(lbl_name)

	var lbl_total := Label.new()
	lbl_total.text = str(total)
	lbl_total.add_theme_font_size_override("font_size", 14)
	var has_bonus: bool = equip > 0 or passive > 0
	lbl_total.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4) if has_bonus else Color.WHITE)
	lbl_total.custom_minimum_size = Vector2(40, 0)
	lbl_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(lbl_total)

	if has_bonus:
		var detail := Label.new()
		var parts: Array[String] = []
		parts.append(str(base))
		if equip > 0:
			parts.append("+%d equip" % equip)
		if passive > 0:
			parts.append("+%d passive" % passive)
		detail.text = "(%s)" % " ".join(parts)
		detail.add_theme_font_size_override("font_size", 12)
		detail.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(detail)

	parent.add_child(row)


func _add_skill_row(parent: VBoxContainer, skill: SkillData, is_innate: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = skill.display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(name_lbl)

	var source_lbl := Label.new()
	source_lbl.text = "(innate)" if is_innate else "(item)"
	source_lbl.add_theme_font_size_override("font_size", 12)
	source_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	row.add_child(source_lbl)

	if skill.mp_cost > 0:
		var mp_lbl := Label.new()
		mp_lbl.text = "%d MP" % skill.mp_cost
		mp_lbl.add_theme_font_size_override("font_size", 12)
		mp_lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		row.add_child(mp_lbl)

	parent.add_child(row)


func _get_passive_flat(stat_id: int, passive_mods: Array) -> int:
	var flat: float = 0.0
	for i in range(passive_mods.size()):
		var mod = passive_mods[i]
		if mod.stat == stat_id and not mod.is_percentage:
			flat += mod.value
	return int(flat)
