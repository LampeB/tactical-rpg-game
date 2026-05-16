extends Control
## Stats panel — full character sheet with portrait, vitals, stat table,
## combat stats, skills, element points, and passive abilities.
## Used in the game menu's Stats tab.

var _current_character_id: String = ""

const _SlotTex := preload("res://assets/sprites/ui/theme/slot.png")
const _PortraitFrameTex := preload("res://assets/sprites/ui/theme/portrait_frame.png")


func setup_embedded(character_id: String) -> void:
	_current_character_id = character_id
	_build_view()


func _build_view() -> void:
	for child in get_children():
		child.queue_free()

	var char_data: CharacterData = GameManager.party.roster.get(_current_character_id) if GameManager.party else null
	if not char_data:
		return

	var inv: GridInventory = GameManager.party.grid_inventories.get(_current_character_id) if GameManager.party else null
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var passive_bonuses: Dictionary = GameManager.party.get_passive_bonuses(_current_character_id, tree) if GameManager.party else {}
	var entity: CombatEntity = CombatEntity.from_character(char_data, inv, passive_bonuses)

	# 3-column layout
	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 8)
	add_child(columns)

	# === LEFT: Identity + Vitals + Stats ===
	var left_card := PanelContainer.new()
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_card.size_flags_stretch_ratio = 1.0
	left_card.add_theme_stylebox_override("panel", DesignTokens.make_paper_panel(12, 1))
	columns.add_child(left_card)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_card.add_child(left_scroll)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	left_scroll.add_child(left)

	# Portrait
	var portrait_frame := NinePatchRect.new()
	portrait_frame.texture = _PortraitFrameTex
	portrait_frame.patch_margin_left = 4
	portrait_frame.patch_margin_top = 4
	portrait_frame.patch_margin_right = 4
	portrait_frame.patch_margin_bottom = 4
	portrait_frame.custom_minimum_size = Vector2(0, 140)
	left.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 5
	portrait.offset_top = 5
	portrait.offset_right = -5
	portrait.offset_bottom = -5
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if char_data.portrait:
		portrait.texture = char_data.portrait
	elif char_data.sprite:
		portrait.texture = char_data.sprite
	portrait_frame.add_child(portrait)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = char_data.display_name
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", DesignTokens.INK)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(name_lbl)

	# Class + Level
	var unlocked_count: int = GameManager.party.get_unlocked_passives(_current_character_id).size() if GameManager.party else 0
	var level: int = unlocked_count + 1
	var char_class: String = char_data.character_class if not char_data.character_class.is_empty() else "Adventurer"
	var class_lbl := Label.new()
	class_lbl.text = "%s  —  Level %d" % [char_class, level]
	class_lbl.add_theme_font_size_override("font_size", 15)
	class_lbl.add_theme_color_override("font_color", DesignTokens.INK_3)
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(class_lbl)

	# Description
	if not char_data.description.is_empty():
		var desc_lbl := Label.new()
		desc_lbl.text = char_data.description
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", DesignTokens.INK_4)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left.add_child(desc_lbl)

	left.add_child(HSeparator.new())

	# HP / MP
	var hp_cur: int = GameManager.party.get_current_hp(_current_character_id) if GameManager.party else char_data.max_hp
	var hp_max: int = GameManager.party.get_max_hp(_current_character_id, tree) if GameManager.party else char_data.max_hp
	var mp_cur: int = GameManager.party.get_current_mp(_current_character_id) if GameManager.party else char_data.max_mp
	var mp_max: int = GameManager.party.get_max_mp(_current_character_id, tree) if GameManager.party else char_data.max_mp
	_add_bar(left, "HP", hp_cur, hp_max, true)
	_add_bar(left, "MP", mp_cur, mp_max, false)

	left.add_child(HSeparator.new())

	# Stat table header
	_add_section_header(left, "Attributes")

	var equip_stats: Dictionary = inv.get_computed_stats().get("stats", {}) if inv else {}
	var passive_mods: Array = passive_bonuses.get("stat_modifiers", [])

	var stats: Array = [
		["Physical Attack", Enums.Stat.PHYSICAL_ATTACK, DesignTokens.BRASS],
		["Physical Defense", Enums.Stat.PHYSICAL_DEFENSE, DesignTokens.BRASS_SOFT],
		["Magical Attack", Enums.Stat.MAGICAL_ATTACK, DesignTokens.INDIGO],
		["Magical Defense", Enums.Stat.MAGICAL_DEFENSE, Color(0.45, 0.53, 0.72)],
		["Speed", Enums.Stat.SPEED, DesignTokens.MOSS],
		["Luck", Enums.Stat.LUCK, DesignTokens.EMBER],
	]

	# Compute totals first so bars share a common max
	var stat_totals: Array[int] = []
	for stat_info in stats:
		var base: int = char_data.get_base_stat(stat_info[1] as int)
		var equip: int = int(equip_stats.get(stat_info[1], 0.0))
		var passive: int = _get_passive_flat(stat_info[1] as int, passive_mods)
		stat_totals.append(base + equip + passive)
	var bar_max: int = 0
	for t in stat_totals:
		if t > bar_max:
			bar_max = t
	bar_max = max(bar_max, 1)

	for i in range(stats.size()):
		var stat_name: String = stats[i][0]
		var stat_id: int = stats[i][1]
		var fill_color: Color = stats[i][2]
		var base: int = char_data.get_base_stat(stat_id)
		var equip: int = int(equip_stats.get(stat_id, 0.0))
		var passive: int = _get_passive_flat(stat_id, passive_mods)
		var total: int = stat_totals[i]
		_add_stat_bar(left, stat_name, base, equip, passive, total, bar_max, fill_color)

	# === CENTER: Equipment + Combat ===
	var center_card := PanelContainer.new()
	center_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_card.size_flags_stretch_ratio = 1.0
	center_card.add_theme_stylebox_override("panel", DesignTokens.make_paper_panel(12, 1))
	columns.add_child(center_card)

	var center_scroll := ScrollContainer.new()
	center_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center_card.add_child(center_scroll)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	center_scroll.add_child(center)

	_add_section_header(center, "Equipment")
	_build_equipment_section(center, inv, entity)

	center.add_child(HSeparator.new())
	_add_section_header(center, "Offense")

	var phys_power: int = entity.get_total_weapon_physical_power()
	var mag_power: int = entity.get_total_weapon_magical_power()
	_add_kv_row(center, "Weapon Power", str(phys_power), DesignTokens.BRASS)
	_add_kv_row(center, "Magic Power", str(mag_power), DesignTokens.INDIGO)

	var crit_rate: float = Constants.BASE_CRITICAL_RATE * 100.0 + equip_stats.get(Enums.Stat.CRITICAL_RATE, 0.0) + _get_passive_flat(Enums.Stat.CRITICAL_RATE, passive_mods)
	var crit_dmg: float = Constants.BASE_CRITICAL_DAMAGE * 100.0 + equip_stats.get(Enums.Stat.CRITICAL_DAMAGE, 0.0) + _get_passive_flat(Enums.Stat.CRITICAL_DAMAGE, passive_mods)
	_add_kv_row(center, "Crit Rate", "%.0f%%" % crit_rate, DesignTokens.BRASS)
	_add_kv_row(center, "Crit Damage", "%.0f%%" % crit_dmg, DesignTokens.BRASS)

	center.add_child(HSeparator.new())
	_add_section_header(center, "Defense")

	var phys_def: float = clampf(entity.get_effective_stat(Enums.Stat.PHYSICAL_DEFENSE), 0.0, 100.0)
	var mag_def: float = clampf(entity.get_effective_stat(Enums.Stat.MAGICAL_DEFENSE), 0.0, 100.0)
	_add_kv_row(center, "Phys. Mitigation", "%.0f%%" % phys_def, DesignTokens.BRASS)
	_add_kv_row(center, "Magic Mitigation", "%.0f%%" % mag_def, DesignTokens.INDIGO)
	_add_kv_row(center, "Phys. Armor", "%d / turn" % entity.base_armor, DesignTokens.BRASS)
	_add_kv_row(center, "Spirit Shield", "%d / turn" % entity.base_spirit_shield, DesignTokens.INDIGO)

	var armor_hint := Label.new()
	armor_hint.text = "Armor & shield absorb flat damage and refill each turn."
	armor_hint.add_theme_font_size_override("font_size", 11)
	armor_hint.add_theme_color_override("font_color", DesignTokens.INK_4)
	armor_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(armor_hint)

	center.add_child(HSeparator.new())
	_add_section_header(center, "Special Effects")

	var has_specials: bool = false
	var lifesteal: float = entity.get_item_lifesteal_percent()
	if lifesteal > 0.0:
		_add_bullet(center, "Lifesteal: %d%%" % int(lifesteal * 100), DesignTokens.MOSS)
		has_specials = true
	var on_kill_heal: float = entity.get_on_kill_heal_percent()
	if on_kill_heal > 0.0:
		_add_bullet(center, "On Kill: Heal %d%% HP" % int(on_kill_heal * 100), DesignTokens.MOSS)
		has_specials = true
	if entity.has_force_aoe() or entity.has_innate_force_aoe():
		_add_bullet(center, "Attacks hit all enemies", DesignTokens.EMBER)
		has_specials = true
	var extra_hits: int = entity.get_extra_hit_count()
	if extra_hits > 0:
		_add_bullet(center, "+%d extra hit(s)" % extra_hits, DesignTokens.BRASS)
		has_specials = true
	if not has_specials:
		_add_faded(center, "None")

	# === RIGHT: Skills + Elements + Passives ===
	var right_card := PanelContainer.new()
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_card.size_flags_stretch_ratio = 1.0
	right_card.add_theme_stylebox_override("panel", DesignTokens.make_paper_panel(12, 1))
	columns.add_child(right_card)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_card.add_child(right_scroll)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	right_scroll.add_child(right)

	_add_section_header(right, "Active Skills")

	var element_points: Dictionary = inv.get_element_points() if inv else {}
	var has_skills: bool = false

	for skill in char_data.innate_skills:
		if skill is SkillData:
			_add_skill_row(right, skill, true)
			has_skills = true

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
				has_skills = true

	if not has_skills:
		_add_faded(right, "No active skills")

	right.add_child(HSeparator.new())
	_add_section_header(right, "Element Points")

	var elements: Array = [
		[Enums.Element.FIRE, "Fire"], [Enums.Element.WATER, "Water"],
		[Enums.Element.AIR, "Air"], [Enums.Element.EARTH, "Earth"],
		[Enums.Element.PLANT, "Plant"], [Enums.Element.LIGHT, "Light"],
		[Enums.Element.DARK, "Dark"],
	]
	var has_elements: bool = false
	for elem_info in elements:
		var elem: int = elem_info[0]
		var pts: int = element_points.get(elem, 0)
		if pts <= 0:
			continue
		has_elements = true
		var color: Color = Constants.ELEMENT_COLORS.get(elem, DesignTokens.INK_3)
		_add_kv_row(right, elem_info[1], str(pts), color)

	if not has_elements:
		_add_faded(right, "No element gems equipped")

	right.add_child(HSeparator.new())
	_add_section_header(right, "Passive Abilities")

	var effects: Array = passive_bonuses.get("special_effects", [])
	if effects.is_empty():
		_add_faded(right, "No passive abilities unlocked")
	else:
		for i in range(effects.size()):
			var effect_id: String = effects[i]
			var desc: String = PassiveEffects.get_description(effect_id)
			if not desc.is_empty():
				_add_bullet(right, desc, DesignTokens.INDIGO)


# === Equipment Section with Runewood Slots ===

func _build_equipment_section(parent: VBoxContainer, inv: GridInventory, _entity: CombatEntity) -> void:
	var equipped_armor: Dictionary = inv.get_equipped_armor_slots() if inv else {}
	var used_hands: int = inv.get_used_hand_slots() if inv else 0
	var available_hands: int = inv.get_available_hand_slots() if inv else 2

	var eq_columns := HBoxContainer.new()
	eq_columns.add_theme_constant_override("separation", 12)
	eq_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(eq_columns)

	# === LEFT COLUMN ===
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 8)
	eq_columns.add_child(left_col)

	_add_section_label(left_col, "WEAPONS")
	var weapons_row := HBoxContainer.new()
	weapons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	weapons_row.add_theme_constant_override("separation", 6)
	for i in range(available_hands):
		weapons_row.add_child(_make_slot_icon(i < used_hands, 36))
	left_col.add_child(weapons_row)

	left_col.add_child(HSeparator.new())

	_add_section_label(left_col, "ARMOR")
	_add_slot_with_label(left_col, "Helmet", equipped_armor.has(Enums.EquipmentCategory.HELMET))

	var chest_gloves_row := HBoxContainer.new()
	chest_gloves_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chest_gloves_row.add_theme_constant_override("separation", 16)
	chest_gloves_row.add_child(_make_labeled_slot("Chest", equipped_armor.has(Enums.EquipmentCategory.CHESTPLATE)))
	chest_gloves_row.add_child(_make_labeled_slot("Gloves", equipped_armor.has(Enums.EquipmentCategory.GLOVES)))
	left_col.add_child(chest_gloves_row)

	_add_slot_with_label(left_col, "Legs", equipped_armor.has(Enums.EquipmentCategory.LEGS))
	_add_slot_with_label(left_col, "Boots", equipped_armor.has(Enums.EquipmentCategory.BOOTS))

	# === RIGHT COLUMN ===
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 6)
	eq_columns.add_child(right_col)

	_add_section_label(right_col, "JEWELRY")
	_add_slot_with_label(right_col, "Necklace", equipped_armor.has(Enums.EquipmentCategory.NECKLACE))

	right_col.add_child(HSeparator.new())

	var ring_count: int = 0
	if inv:
		for pi_idx in range(inv.placed_items.size()):
			var placed: GridInventory.PlacedItem = inv.placed_items[pi_idx]
			if placed.item_data.item_type == Enums.ItemType.PASSIVE_GEAR and placed.item_data.armor_slot == Enums.EquipmentCategory.RING:
				ring_count += 1

	var rings_label := Label.new()
	rings_label.text = "Rings"
	rings_label.add_theme_font_size_override("font_size", 12)
	rings_label.add_theme_color_override("font_color", DesignTokens.INK_4)
	rings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_col.add_child(rings_label)

	var ring_columns := HBoxContainer.new()
	ring_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	ring_columns.add_theme_constant_override("separation", 12)
	right_col.add_child(ring_columns)

	for side in [["Left", 0], ["Right", 5]]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var lbl := Label.new()
		lbl.text = side[0]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", DesignTokens.INK_4)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lbl)
		var offset: int = side[1]
		for i in range(5):
			col.add_child(_make_slot_icon((i + offset) < ring_count, 22))
		ring_columns.add_child(col)


# === Section helpers ===

func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", DesignTokens.INK)
	parent.add_child(lbl)
	var sep := HSeparator.new()
	parent.add_child(sep)


func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", DesignTokens.INK_3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)


func _add_slot_with_label(parent: VBoxContainer, slot_name: String, filled: bool) -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.text = slot_name
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", DesignTokens.INK_4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lbl)
	var c := CenterContainer.new()
	c.add_child(_make_slot_icon(filled, 36))
	box.add_child(c)
	parent.add_child(box)


func _make_labeled_slot(slot_name: String, filled: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.text = slot_name
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", DesignTokens.INK_4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lbl)
	var c := CenterContainer.new()
	c.add_child(_make_slot_icon(filled, 36))
	box.add_child(c)
	return box


func _make_slot_icon(filled: bool, icon_size: int = 28) -> TextureRect:
	var tex_rect := TextureRect.new()
	tex_rect.texture = _SlotTex
	tex_rect.custom_minimum_size = Vector2(icon_size, icon_size)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.modulate = DesignTokens.BRASS if filled else Color(DesignTokens.INK_4.r, DesignTokens.INK_4.g, DesignTokens.INK_4.b, 0.5)
	return tex_rect


# === Row / label helpers ===

func _add_bar(parent: VBoxContainer, label_text: String, current: int, maximum: int, is_hp: bool) -> void:
	var lbl := Label.new()
	lbl.text = "%s: %d / %d" % [label_text, current, maximum]
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", DesignTokens.INK_2)
	parent.add_child(lbl)
	var bar := TextureProgressBar.new()
	bar.max_value = maximum
	bar.value = current
	bar.custom_minimum_size = Vector2(0, 20 if is_hp else 18)
	bar.nine_patch_stretch = true
	bar.stretch_margin_left = 6
	bar.stretch_margin_top = 6
	bar.stretch_margin_right = 6
	bar.stretch_margin_bottom = 6
	bar.texture_under = preload("res://assets/sprites/ui/bars/hp_empty.png") if is_hp else preload("res://assets/sprites/ui/bars/mp_empty.png")
	bar.texture_over = preload("res://assets/sprites/ui/bars/hp_frame.png") if is_hp else preload("res://assets/sprites/ui/bars/mp_frame.png")
	bar.texture_progress = preload("res://assets/sprites/ui/bars/hp_fill.png") if is_hp else preload("res://assets/sprites/ui/bars/mp_fill.png")
	parent.add_child(bar)


func _add_stat_bar(parent: VBoxContainer, stat_name: String, base: int, equip: int, passive: int, total: int, max_val: int, fill_color: Color) -> void:
	var has_bonus: bool = equip > 0 or passive > 0

	var header_row := HBoxContainer.new()
	var lbl_name := Label.new()
	lbl_name.text = stat_name
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.add_theme_font_size_override("font_size", 13)
	lbl_name.add_theme_color_override("font_color", DesignTokens.INK_3)
	header_row.add_child(lbl_name)

	var lbl_val := Label.new()
	lbl_val.text = str(total)
	lbl_val.add_theme_font_size_override("font_size", 13)
	lbl_val.add_theme_color_override("font_color", DesignTokens.MOSS if has_bonus else DesignTokens.INK)
	header_row.add_child(lbl_val)

	parent.add_child(header_row)

	var bar := ProgressBar.new()
	bar.max_value = max_val
	bar.value = total
	bar.custom_minimum_size = Vector2(0, 8)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill_color
	fill_sb.set_corner_radius_all(2)
	fill_sb.set_content_margin_all(0)
	bar.add_theme_stylebox_override("fill", fill_sb)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = DesignTokens.PAPER_3
	bg_sb.set_corner_radius_all(2)
	bg_sb.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background", bg_sb)
	parent.add_child(bar)

	if has_bonus:
		var parts: Array[String] = []
		parts.append(str(base) + " base")
		if equip > 0:
			parts.append("+%d equip" % equip)
		if passive > 0:
			parts.append("+%d passive" % passive)
		var detail := Label.new()
		detail.text = "  ".join(parts)
		detail.add_theme_font_size_override("font_size", 11)
		detail.add_theme_color_override("font_color", DesignTokens.INK_4)
		parent.add_child(detail)


func _add_skill_row(parent: VBoxContainer, skill: SkillData, is_innate: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = skill.display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", DesignTokens.INK if is_innate else DesignTokens.INDIGO)
	row.add_child(name_lbl)

	var source_lbl := Label.new()
	source_lbl.text = "(innate)" if is_innate else "(element)"
	source_lbl.add_theme_font_size_override("font_size", 11)
	source_lbl.add_theme_color_override("font_color", DesignTokens.INK_4)
	row.add_child(source_lbl)

	if skill.mp_cost > 0:
		var mp_lbl := Label.new()
		mp_lbl.text = "%d MP" % skill.mp_cost
		mp_lbl.add_theme_font_size_override("font_size", 12)
		mp_lbl.add_theme_color_override("font_color", DesignTokens.INDIGO)
		row.add_child(mp_lbl)

	parent.add_child(row)


func _add_kv_row(parent: VBoxContainer, key: String, value: String, value_color: Color) -> void:
	var row := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.add_theme_font_size_override("font_size", 14)
	k.add_theme_color_override("font_color", DesignTokens.INK_3)
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", value_color)
	row.add_child(v)
	parent.add_child(row)


func _add_bullet(parent: VBoxContainer, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = "• " + text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)


func _add_faded(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", DesignTokens.INK_4)
	parent.add_child(lbl)


func _get_passive_flat(stat_id: int, passive_mods: Array) -> int:
	var flat: float = 0.0
	for i in range(passive_mods.size()):
		var mod = passive_mods[i]
		if mod.stat == stat_id and not mod.is_percentage:
			flat += mod.value
	return int(flat)
