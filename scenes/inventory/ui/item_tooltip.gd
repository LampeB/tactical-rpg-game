extends PanelContainer
## Tooltip popup showing item details on hover.

@onready var _name_label: Label = $Margin/VBox/NameLabel
@onready var _rarity_label: Label = $Margin/VBox/RarityLabel
@onready var _type_label: Label = $Margin/VBox/TypeLabel
@onready var _stats_container: VBoxContainer = $Margin/VBox/StatsContainer
@onready var _modifier_section: VBoxContainer = $Margin/VBox/ModifierSection
@onready var _modifier_list: VBoxContainer = $Margin/VBox/ModifierSection/ModifierList
@onready var _description_label: Label = $Margin/VBox/DescriptionLabel


func show_for_item(item: ItemData, placed: GridInventory.PlacedItem = null, grid_inv: GridInventory = null, screen_pos: Vector2 = Vector2.ZERO) -> void:
	# Name with rarity color
	_name_label.text = item.display_name
	var rarity_color: Color = Constants.RARITY_COLORS.get(item.rarity, Color.WHITE)
	_name_label.add_theme_color_override("font_color", rarity_color)

	# Rarity
	_rarity_label.text = Constants.RARITY_NAMES.get(item.rarity, "Common")
	_rarity_label.add_theme_color_override("font_color", rarity_color)

	# Type
	_type_label.text = _get_type_text(item.item_type)

	# Stats
	_clear_container(_stats_container)
	for mod in item.stat_modifiers:
		if mod is StatModifier:
			var label: Label = Label.new()
			label.text = mod.get_description()
			label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_DETAIL)
			_stats_container.add_child(label)

	if item.base_power > 0:
		var phys_label: Label = Label.new()
		phys_label.text = "Physical Power: %d" % item.base_power
		phys_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_DETAIL)
		_stats_container.add_child(phys_label)

	if item.magical_power > 0:
		var mag_label: Label = Label.new()
		mag_label.text = "Magical Power: %d" % item.magical_power
		mag_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_DETAIL)
		_stats_container.add_child(mag_label)

	# Modifier bonuses (for gems, show what they grant; for tools, show active gem bonuses)
	_modifier_section.visible = false
	_clear_container(_modifier_list)

	if item.item_type == Enums.ItemType.MODIFIER:
		# Show unconditional modifier bonuses
		if not item.modifier_bonuses.is_empty():
			_modifier_section.visible = true
			for mod in item.modifier_bonuses:
				if mod is StatModifier:
					_add_modifier_label(mod.get_description(), Color(1.0, 0.9, 0.3))

		# Show conditional rules grouped by target weapon type
		if not item.conditional_modifier_rules.is_empty():
			_modifier_section.visible = true
			for i in range(item.conditional_modifier_rules.size()):
				var rule: ConditionalModifierRule = item.conditional_modifier_rules[i]
				var weapon_type_name: String = _get_weapon_type_name(rule.target_weapon_type)
				_add_header_label("When near %s:" % weapon_type_name, Color(0.8, 0.8, 1.0))

				# Stat bonuses
				for j in range(rule.stat_bonuses.size()):
					var mod: StatModifier = rule.stat_bonuses[j]
					_add_modifier_label("  " + mod.get_description(), Color(1.0, 0.9, 0.3))

					# Status effect
				if rule.status_effect:
					var effect_name: String = _get_status_effect_name(rule.status_effect.effect_type)
					var chance_pct: int = int(rule.status_effect_chance * 100)
					_add_modifier_label("  %s (%d%% chance)" % [effect_name, chance_pct], Color(1.0, 0.7, 0.3))

				# Granted skills
				for j in range(rule.granted_skills.size()):
					var skill: SkillData = rule.granted_skills[j]
					_add_modifier_label("  Grants: %s" % skill.display_name, Color(0.6, 1.0, 0.6))

	elif item.item_type == Enums.ItemType.ACTIVE_TOOL and placed and grid_inv:
		# Show active unconditional modifier bonuses
		var modifiers: Array = grid_inv.get_modifiers_affecting(placed)
		if not modifiers.is_empty():
			_modifier_section.visible = true
			for i in range(modifiers.size()):
				var gem_placed: GridInventory.PlacedItem = modifiers[i]
				for gem_mod in gem_placed.item_data.modifier_bonuses:
					if gem_mod is StatModifier:
						_add_modifier_label("%s (from %s)" % [gem_mod.get_description(), gem_placed.item_data.display_name], Color(1.0, 0.9, 0.3))

		# Show active conditional effects
		var state: ToolModifierState = grid_inv.get_tool_modifier_state(placed)
		if state and not state.active_modifiers.is_empty():
			_modifier_section.visible = true

			# Status effect
			if state.status_effect_type != null:
				var effect_name: String = _get_status_effect_name(state.status_effect_type)
				var chance_pct: int = int(state.status_effect_chance * 100)
				_add_modifier_label("%s (%d%% chance)" % [effect_name, chance_pct], Color(1.0, 0.7, 0.3))

			# Aggregate stats from conditional modifiers
			var stat_keys: Array = state.aggregate_stats.keys()
			for i in range(stat_keys.size()):
				var stat: Enums.Stat = stat_keys[i]
				var value: float = state.aggregate_stats[stat]
				var stat_name: String = _get_stat_name(stat)
				var sign: String = "+" if value >= 0 else ""
				_add_modifier_label("%s%s %s (conditional)" % [sign, value, stat_name], Color(1.0, 0.9, 0.3))

			# Conditional skills
			for i in range(state.conditional_skills.size()):
				var skill: SkillData = state.conditional_skills[i]
				_add_modifier_label("Grants: %s" % skill.display_name, Color(0.6, 1.0, 0.6))

	# Description
	_description_label.text = item.description
	_description_label.visible = not item.description.is_empty()

	# Position near mouse, clamped to viewport
	_position_at(screen_pos)
	visible = true


## Show a tooltip for a purchasable backpack cell.
func show_for_cell_purchase(cost: int, can_afford: bool, screen_pos: Vector2) -> void:
	_name_label.text = "Unlock Cell"
	_name_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.1))
	_rarity_label.text = ""
	_type_label.text = "Cost: %d gold" % cost
	if can_afford:
		_type_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	else:
		_type_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_clear_container(_stats_container)
	_modifier_section.visible = false
	_clear_container(_modifier_list)
	_description_label.text = "Left-click to purchase." if can_afford else "Not enough gold."
	_description_label.visible = true
	_position_at(screen_pos)
	visible = true


func hide_tooltip() -> void:
	visible = false


func _position_at(screen_pos: Vector2) -> void:
	# Wait one frame for size to update, then clamp
	await get_tree().process_frame
	var viewport_size: Vector2 = get_viewport_rect().size
	var tooltip_size: Vector2 = size
	var pos: Vector2 = screen_pos + Vector2(16, 16)  # Offset from cursor
	pos.x = minf(pos.x, viewport_size.x - tooltip_size.x - 8)
	pos.y = minf(pos.y, viewport_size.y - tooltip_size.y - 8)
	pos.x = maxf(pos.x, 8)
	pos.y = maxf(pos.y, 8)
	global_position = pos


func _get_type_text(item_type: Enums.ItemType) -> String:
	match item_type:
		Enums.ItemType.ACTIVE_TOOL: return "Active Tool"
		Enums.ItemType.PASSIVE_GEAR: return "Passive Gear"
		Enums.ItemType.MODIFIER: return "Modifier"
		Enums.ItemType.CONSUMABLE: return "Consumable"
		Enums.ItemType.MATERIAL: return "Material"
	return ""


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _add_header_label(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_DETAIL)
	label.add_theme_color_override("font_color", color)
	_modifier_list.add_child(label)


func _add_modifier_label(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_DETAIL)
	label.add_theme_color_override("font_color", color)
	_modifier_list.add_child(label)


func _get_category_name(category: Enums.EquipmentCategory) -> String:
	match category:
		Enums.EquipmentCategory.SWORD: return "Sword"
		Enums.EquipmentCategory.MACE: return "Mace"
		Enums.EquipmentCategory.BOW: return "Bow"
		Enums.EquipmentCategory.STAFF: return "Staff"
		Enums.EquipmentCategory.DAGGER: return "Dagger"
		Enums.EquipmentCategory.SHIELD: return "Shield"
		Enums.EquipmentCategory.HELMET: return "Helmet"
		Enums.EquipmentCategory.CHESTPLATE: return "Chestplate"
		Enums.EquipmentCategory.BOOTS: return "Boots"
		Enums.EquipmentCategory.RING: return "Ring"
	return "Unknown"


func _get_damage_type_name(damage_type: Enums.DamageType) -> String:
	match damage_type:
		Enums.DamageType.PHYSICAL: return "Physical"
		Enums.DamageType.MAGICAL: return "Magical"
	return "Unknown"


func _get_stat_name(stat: Enums.Stat) -> String:
	match stat:
		Enums.Stat.MAX_HP: return "Max HP"
		Enums.Stat.MAX_MP: return "Max MP"
		Enums.Stat.PHYSICAL_ATTACK: return "Phys Atk"
		Enums.Stat.PHYSICAL_DEFENSE: return "Phys Def"
		Enums.Stat.MAGICAL_ATTACK: return "Mag Atk"
		Enums.Stat.MAGICAL_DEFENSE: return "Magical Def"
		Enums.Stat.SPEED: return "Speed"
		Enums.Stat.LUCK: return "Luck"
		Enums.Stat.CRITICAL_RATE: return "Crit Rate"
		Enums.Stat.CRITICAL_DAMAGE: return "Crit Dmg"
		Enums.Stat.PHYSICAL_SCALING: return "Phys Scaling"
		Enums.Stat.MAGICAL_SCALING: return "Mag Scaling"
	return "Unknown"


func _get_status_effect_name(effect_type: Enums.StatusEffectType) -> String:
	match effect_type:
		Enums.StatusEffectType.BURN: return "Burn"
		Enums.StatusEffectType.POISONED: return "Poisoned"
		Enums.StatusEffectType.CHILLED: return "Chilled"
		Enums.StatusEffectType.SHOCKED: return "Shocked"
	return "Unknown"


func _get_weapon_type_name(weapon_type: Enums.WeaponType) -> String:
	match weapon_type:
		Enums.WeaponType.MELEE: return "Melee Weapons"
		Enums.WeaponType.RANGED: return "Ranged Weapons"
		Enums.WeaponType.MAGIC: return "Magic Weapons"
	return "Unknown"
