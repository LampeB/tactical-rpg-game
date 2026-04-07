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
	columns.add_theme_constant_override("separation", 12)
	add_child(columns)

	# === LEFT: Identity + Vitals + Stats ===
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 1.0
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(left_scroll)

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
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(name_lbl)

	# Class + Level
	var unlocked_count: int = GameManager.party.get_unlocked_passives(_current_character_id).size() if GameManager.party else 0
	var level: int = unlocked_count + 1
	var char_class: String = char_data.character_class if not char_data.character_class.is_empty() else "Adventurer"
	var class_lbl := Label.new()
	class_lbl.text = "%s  —  Level %d" % [char_class, level]
	class_lbl.add_theme_font_size_override("font_size", 15)
	class_lbl.add_theme_color_override("font_color", Color(0.75, 0.68, 0.58))
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(class_lbl)

	# Description
	if not char_data.description.is_empty():
		var desc_lbl := Label.new()
		desc_lbl.text = char_data.description
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
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
	var stat_header := Label.new()
	stat_header.text = "Attributes"
	stat_header.add_theme_font_size_override("font_size", 16)
	stat_header.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	left.add_child(stat_header)

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

	# === CENTER: Equipment + Combat ===
	var center_scroll := ScrollContainer.new()
	center_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_scroll.size_flags_stretch_ratio = 1.0
	center_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(center_scroll)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	center_scroll.add_child(center)

	# Equipment header
	var equip_header := Label.new()
	equip_header.text = "Equipment"
	equip_header.add_theme_font_size_override("font_size", 16)
	equip_header.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	equip_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(equip_header)

	# Weapon slots
	_build_equipment_section(center, inv, entity)

	center.add_child(HSeparator.new())

	# === Offense ===
	var offense_header := Label.new()
	offense_header.text = "Offense"
	offense_header.add_theme_font_size_override("font_size", 16)
	offense_header.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	center.add_child(offense_header)

	var phys_power: int = entity.get_total_weapon_physical_power()
	var mag_power: int = entity.get_total_weapon_magical_power()
	_add_kv_row(center, "Weapon Power", str(phys_power), Color(1.0, 0.85, 0.5))
	_add_kv_row(center, "Magic Power", str(mag_power), Color(0.6, 0.7, 1.0))

	var crit_rate: float = Constants.BASE_CRITICAL_RATE * 100.0 + equip_stats.get(Enums.Stat.CRITICAL_RATE, 0.0) + _get_passive_flat(Enums.Stat.CRITICAL_RATE, passive_mods)
	var crit_dmg: float = Constants.BASE_CRITICAL_DAMAGE * 100.0 + equip_stats.get(Enums.Stat.CRITICAL_DAMAGE, 0.0) + _get_passive_flat(Enums.Stat.CRITICAL_DAMAGE, passive_mods)
	_add_kv_row(center, "Crit Rate", "%.0f%%" % crit_rate, Color(0.9, 0.75, 0.3))
	_add_kv_row(center, "Crit Damage", "%.0f%%" % crit_dmg, Color(0.9, 0.75, 0.3))

	center.add_child(HSeparator.new())

	# === Defense ===
	var defense_header := Label.new()
	defense_header.text = "Defense"
	defense_header.add_theme_font_size_override("font_size", 16)
	defense_header.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	center.add_child(defense_header)

	# Defense % stats (always shown — base mitigation)
	var phys_def: float = clampf(entity.get_effective_stat(Enums.Stat.PHYSICAL_DEFENSE), 0.0, 100.0)
	var mag_def: float = clampf(entity.get_effective_stat(Enums.Stat.MAGICAL_DEFENSE), 0.0, 100.0)
	_add_kv_row(center, "Phys. Mitigation", "%.0f%%" % phys_def, Color(0.85, 0.65, 0.4))
	_add_kv_row(center, "Magic Mitigation", "%.0f%%" % mag_def, Color(0.55, 0.65, 0.95))

	# Armor pools (refilled each turn)
	_add_kv_row(center, "Phys. Armor", "%d / turn" % entity.base_armor, Color(0.85, 0.65, 0.4))
	_add_kv_row(center, "Spirit Shield", "%d / turn" % entity.base_spirit_shield, Color(0.55, 0.65, 0.95))

	var armor_hint := Label.new()
	armor_hint.text = "Armor & shield absorb flat damage and refill each turn."
	armor_hint.add_theme_font_size_override("font_size", 11)
	armor_hint.add_theme_color_override("font_color", Color(0.5, 0.48, 0.42))
	armor_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(armor_hint)

	center.add_child(HSeparator.new())

	# Special mechanics
	var specials_header := Label.new()
	specials_header.text = "Special Effects"
	specials_header.add_theme_font_size_override("font_size", 16)
	specials_header.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	center.add_child(specials_header)

	var has_specials: bool = false

	var lifesteal: float = entity.get_item_lifesteal_percent()
	if lifesteal > 0.0:
		_add_bullet(center, "Lifesteal: %d%%" % int(lifesteal * 100), Color(0.4, 1.0, 0.4))
		has_specials = true
	var on_kill_heal: float = entity.get_on_kill_heal_percent()
	if on_kill_heal > 0.0:
		_add_bullet(center, "On Kill: Heal %d%% HP" % int(on_kill_heal * 100), Color(0.4, 1.0, 0.4))
		has_specials = true
	if entity.has_force_aoe() or entity.has_innate_force_aoe():
		_add_bullet(center, "Attacks hit all enemies", Color(1.0, 0.7, 0.3))
		has_specials = true
	var extra_hits: int = entity.get_extra_hit_count()
	if extra_hits > 0:
		_add_bullet(center, "+%d extra hit(s)" % extra_hits, Color(1.0, 0.85, 0.2))
		has_specials = true

	if not has_specials:
		_add_faded(center, "None")

	# === RIGHT: Skills + Elements + Passives ===
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_stretch_ratio = 1.0
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(right_scroll)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	right_scroll.add_child(right)

	# Skills
	var skills_header := Label.new()
	skills_header.text = "Active Skills"
	skills_header.add_theme_font_size_override("font_size", 16)
	skills_header.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	right.add_child(skills_header)

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

	# Element points
	var elem_header := Label.new()
	elem_header.text = "Element Points"
	elem_header.add_theme_font_size_override("font_size", 16)
	elem_header.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	right.add_child(elem_header)

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
		var color: Color = Constants.ELEMENT_COLORS.get(elem, Color.WHITE)
		_add_kv_row(right, elem_info[1], str(pts), color)

	if not has_elements:
		_add_faded(right, "No element gems equipped")

	right.add_child(HSeparator.new())

	# Passive abilities
	var passive_header := Label.new()
	passive_header.text = "Passive Abilities"
	passive_header.add_theme_font_size_override("font_size", 16)
	passive_header.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	right.add_child(passive_header)

	var effects: Array = passive_bonuses.get("special_effects", [])
	if effects.is_empty():
		_add_faded(right, "No passive abilities unlocked")
	else:
		for i in range(effects.size()):
			var effect_id: String = effects[i]
			var desc: String = PassiveEffects.get_description(effect_id)
			if not desc.is_empty():
				_add_bullet(right, desc, Color(0.7, 0.85, 1.0))


# === Equipment Section with Runewood Slots ===

func _build_equipment_section(parent: VBoxContainer, inv: GridInventory, _entity: CombatEntity) -> void:
	var equipped_armor: Dictionary = inv.get_equipped_armor_slots() if inv else {}
	var used_hands: int = inv.get_used_hand_slots() if inv else 0
	var available_hands: int = inv.get_available_hand_slots() if inv else 2

	# Two-column layout: Left = Weapons + Armor, Right = Jewelry + Rings
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(columns)

	# === LEFT COLUMN ===
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 8)
	columns.add_child(left_col)

	# Weapons section
	_add_section_label(left_col, "WEAPONS")
	var weapons_row := HBoxContainer.new()
	weapons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	weapons_row.add_theme_constant_override("separation", 6)
	for i in range(available_hands):
		weapons_row.add_child(_make_slot_icon(i < used_hands, 36))
	left_col.add_child(weapons_row)

	left_col.add_child(HSeparator.new())

	# Armor section
	_add_section_label(left_col, "ARMOR")

	# Helmet (centered, alone on top)
	_add_slot_with_label(left_col, "Helmet", equipped_armor.has(Enums.EquipmentCategory.HELMET))

	# Chest + Gloves (side by side)
	var chest_gloves_row := HBoxContainer.new()
	chest_gloves_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chest_gloves_row.add_theme_constant_override("separation", 16)
	chest_gloves_row.add_child(_make_labeled_slot("Chest", equipped_armor.has(Enums.EquipmentCategory.CHESTPLATE)))
	chest_gloves_row.add_child(_make_labeled_slot("Gloves", equipped_armor.has(Enums.EquipmentCategory.GLOVES)))
	left_col.add_child(chest_gloves_row)

	# Legs (centered)
	_add_slot_with_label(left_col, "Legs", equipped_armor.has(Enums.EquipmentCategory.LEGS))

	# Boots (centered)
	_add_slot_with_label(left_col, "Boots", equipped_armor.has(Enums.EquipmentCategory.BOOTS))

	# === RIGHT COLUMN ===
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 6)
	columns.add_child(right_col)

	# Jewelry section
	_add_section_label(right_col, "JEWELRY")

	# Necklace
	_add_slot_with_label(right_col, "Necklace", equipped_armor.has(Enums.EquipmentCategory.NECKLACE))

	right_col.add_child(HSeparator.new())

	# Rings — count equipped
	var ring_count: int = 0
	if inv:
		for pi_idx in range(inv.placed_items.size()):
			var placed: GridInventory.PlacedItem = inv.placed_items[pi_idx]
			if placed.item_data.item_type == Enums.ItemType.PASSIVE_GEAR and placed.item_data.armor_slot == Enums.EquipmentCategory.RING:
				ring_count += 1

	var rings_label := Label.new()
	rings_label.text = "Rings"
	rings_label.add_theme_font_size_override("font_size", 12)
	rings_label.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
	rings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_col.add_child(rings_label)

	var ring_columns := HBoxContainer.new()
	ring_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	ring_columns.add_theme_constant_override("separation", 12)
	right_col.add_child(ring_columns)

	# Left rings column (5 slots)
	var left_rings := VBoxContainer.new()
	left_rings.add_theme_constant_override("separation", 4)
	left_rings.alignment = BoxContainer.ALIGNMENT_CENTER
	var left_label := Label.new()
	left_label.text = "Left"
	left_label.add_theme_font_size_override("font_size", 11)
	left_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_rings.add_child(left_label)
	for i in range(5):
		left_rings.add_child(_make_slot_icon(i < ring_count, 22))
	ring_columns.add_child(left_rings)

	# Right rings column (5 slots)
	var right_rings := VBoxContainer.new()
	right_rings.add_theme_constant_override("separation", 4)
	right_rings.alignment = BoxContainer.ALIGNMENT_CENTER
	var right_label := Label.new()
	right_label.text = "Right"
	right_label.add_theme_font_size_override("font_size", 11)
	right_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_rings.add_child(right_label)
	for i in range(5):
		right_rings.add_child(_make_slot_icon((i + 5) < ring_count, 22))
	ring_columns.add_child(right_rings)


func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)


func _add_slot_with_label(parent: VBoxContainer, slot_name: String, filled: bool) -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.text = slot_name
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lbl)
	var center := CenterContainer.new()
	center.add_child(_make_slot_icon(filled, 36))
	box.add_child(center)
	parent.add_child(box)


func _make_labeled_slot(slot_name: String, filled: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.text = slot_name
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lbl)
	var center := CenterContainer.new()
	center.add_child(_make_slot_icon(filled, 36))
	box.add_child(center)
	return box


func _make_slot_icon(filled: bool, icon_size: int = 28) -> TextureRect:
	var tex_rect := TextureRect.new()
	tex_rect.texture = _SlotTex
	tex_rect.custom_minimum_size = Vector2(icon_size, icon_size)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if filled:
		tex_rect.modulate = Color(1.4, 1.2, 0.6, 1.0)  # Bright gold tint for equipped
	else:
		tex_rect.modulate = Color(0.55, 0.5, 0.45, 0.7)  # Dim for empty
	return tex_rect


# === Helpers ===

func _add_bar(parent: VBoxContainer, label_text: String, current: int, maximum: int, is_hp: bool) -> void:
	var lbl := Label.new()
	lbl.text = "%s: %d / %d" % [label_text, current, maximum]
	lbl.add_theme_font_size_override("font_size", 15)
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


func _add_stat_row(parent: VBoxContainer, stat_name: String, base: int, equip: int, passive: int, total: int) -> void:
	var row := HBoxContainer.new()
	var lbl_name := Label.new()
	lbl_name.text = stat_name
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.add_theme_font_size_override("font_size", 14)
	lbl_name.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58))
	row.add_child(lbl_name)

	var lbl_total := Label.new()
	lbl_total.text = str(total)
	lbl_total.add_theme_font_size_override("font_size", 14)
	var has_bonus: bool = equip > 0 or passive > 0
	lbl_total.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4) if has_bonus else Color(0.9, 0.85, 0.75))
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
		detail.add_theme_font_size_override("font_size", 11)
		detail.add_theme_color_override("font_color", Color(0.5, 0.48, 0.42))
		row.add_child(detail)

	parent.add_child(row)


func _add_skill_row(parent: VBoxContainer, skill: SkillData, is_innate: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = skill.display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75) if is_innate else Color(0.7, 0.85, 1.0))
	row.add_child(name_lbl)

	var source_lbl := Label.new()
	source_lbl.text = "(innate)" if is_innate else "(element)"
	source_lbl.add_theme_font_size_override("font_size", 11)
	source_lbl.add_theme_color_override("font_color", Color(0.5, 0.48, 0.42))
	row.add_child(source_lbl)

	if skill.mp_cost > 0:
		var mp_lbl := Label.new()
		mp_lbl.text = "%d MP" % skill.mp_cost
		mp_lbl.add_theme_font_size_override("font_size", 12)
		mp_lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		row.add_child(mp_lbl)

	parent.add_child(row)


func _add_kv_row(parent: VBoxContainer, key: String, value: String, value_color: Color) -> void:
	var row := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.add_theme_font_size_override("font_size", 14)
	k.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58))
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
	lbl.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38))
	parent.add_child(lbl)


func _get_passive_flat(stat_id: int, passive_mods: Array) -> int:
	var flat: float = 0.0
	for i in range(passive_mods.size()):
		var mod = passive_mods[i]
		if mod.stat == stat_id and not mod.is_percentage:
			flat += mod.value
	return int(flat)
