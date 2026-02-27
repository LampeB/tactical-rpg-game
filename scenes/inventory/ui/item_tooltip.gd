extends PanelContainer
## Tooltip popup showing item details on hover.

const FONT_SIZE := 12  ## Font size used for all dynamically-created labels in the tooltip

@onready var _name_label: Label = $Margin/VBox/NameLabel
@onready var _rarity_label: Label = $Margin/VBox/RarityLabel
@onready var _type_label: Label = $Margin/VBox/TypeLabel
@onready var _price_label: Label = $Margin/VBox/PriceLabel
@onready var _stats_container: VBoxContainer = $Margin/VBox/StatsContainer
@onready var _modifier_section: VBoxContainer = $Margin/VBox/ModifierSection
@onready var _modifier_list: VBoxContainer = $Margin/VBox/ModifierSection/ModifierList
@onready var _description_label: Label = $Margin/VBox/DescriptionLabel


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.82)
	style.corner_radius_top_left    = 4
	style.corner_radius_top_right   = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)


func show_for_item(item: ItemData, placed: GridInventory.PlacedItem = null, grid_inv: GridInventory = null, screen_pos: Vector2 = Vector2.ZERO, price: int = -1, price_label: String = "Value") -> void:
	# Name with rarity color
	_name_label.text = item.display_name
	var rarity_color: Color = Constants.RARITY_COLORS.get(item.rarity, Color.WHITE)
	_name_label.add_theme_color_override("font_color", rarity_color)

	# Rarity
	_rarity_label.text = Constants.RARITY_NAMES.get(item.rarity, "Common")
	_rarity_label.add_theme_color_override("font_color", rarity_color)

	# Type (with hand requirement for weapons)
	var type_text := Enums.get_item_type_name(item.item_type)
	if item.item_type == Enums.ItemType.ACTIVE_TOOL and item.hand_slots_required > 0:
		type_text += "  ·  %s" % ("1 Hand" if item.hand_slots_required == 1 else "2 Hands")
	_type_label.text = type_text

	# Price (shown only when explicitly provided, e.g. in the shop)
	if price > 0:
		_price_label.text = "%s: %dg" % [price_label, price]
		_price_label.visible = true
	else:
		_price_label.visible = false

	# Stats
	_clear_container(_stats_container)
	for mod in item.stat_modifiers:
		if mod is StatModifier:
			var label: Label = Label.new()
			label.text = mod.get_description()
			label.add_theme_font_size_override("font_size", FONT_SIZE)
			_stats_container.add_child(label)

	if item.base_power > 0:
		var phys_label: Label = Label.new()
		phys_label.text = "Physical Power: %d" % item.base_power
		phys_label.add_theme_font_size_override("font_size", FONT_SIZE)
		_stats_container.add_child(phys_label)

	if item.magical_power > 0:
		var mag_label: Label = Label.new()
		mag_label.text = "Magical Power: %d" % item.magical_power
		mag_label.add_theme_font_size_override("font_size", FONT_SIZE)
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
				var weapon_type_name: String = Enums.get_weapon_type_name(rule.target_weapon_type)
				_add_header_label("When near %s:" % weapon_type_name, Color(0.8, 0.8, 1.0))

				# Stat bonuses
				for j in range(rule.stat_bonuses.size()):
					var bonus_mod: StatModifier = rule.stat_bonuses[j]
					_add_modifier_label("  " + bonus_mod.get_description(), Color(1.0, 0.9, 0.3))

				# Status effect
				if rule.status_effect:
					var effect_name: String = Enums.get_status_effect_name(rule.status_effect.effect_type)
					var chance_pct: int = int(rule.status_effect_chance * 100)
					_add_modifier_label("  %s (%d%% chance)" % [effect_name, chance_pct], Color(1.0, 0.7, 0.3))

				# Granted skills
				for gs in range(rule.granted_skills.size()):
					var skill: SkillData = rule.granted_skills[gs]
					_add_modifier_label("  Grants: %s" % skill.display_name, Color(0.6, 1.0, 0.6))

	elif item.item_type == Enums.ItemType.ACTIVE_TOOL:
		var has_innate: bool = item.innate_status_effect != null
		var modifiers: Array = grid_inv.get_modifiers_affecting(placed) if placed and grid_inv else []
		var state: ToolModifierState = grid_inv.get_tool_modifier_state(placed) if placed and grid_inv else null
		var has_gem_effects: bool = not modifiers.is_empty() or (state and not state.active_modifiers.is_empty())

		# ── Innate section ───────────────────────────────────────────────────
		if has_innate:
			_modifier_section.visible = true
			if has_gem_effects:
				_add_header_label("Innate:", Color(0.6, 0.85, 1.0))
			var effect_name: String = Enums.get_status_effect_name(item.innate_status_effect.effect_type)
			var chance_pct: int = int(item.innate_status_effect_chance * 100)
			var indent: String = "  " if has_gem_effects else ""
			_add_modifier_label("%s%s: %d%%  ·  +%d stack (+%d on crit)" % [indent, effect_name, chance_pct, item.innate_status_stacks, item.innate_crit_status_stacks], Color(1.0, 0.7, 0.3))

		# ── Gem section ───────────────────────────────────────────────────────
		if has_gem_effects:
			_modifier_section.visible = true
			if has_innate:
				_add_header_label("From gems:", Color(1.0, 0.9, 0.3))

			# Unconditional stat bonuses from each gem
			for gi in range(modifiers.size()):
				var gem_placed: GridInventory.PlacedItem = modifiers[gi]
				for gem_mod in gem_placed.item_data.modifier_bonuses:
					if gem_mod is StatModifier:
						var indent: String = "  " if has_innate else ""
						_add_modifier_label("%s%s (from %s)" % [indent, gem_mod.get_description(), gem_placed.item_data.display_name], Color(1.0, 0.9, 0.3))

			if state and not state.active_modifiers.is_empty():
				var indent: String = "  " if has_innate else ""

				# Status effect from gems (read from active_modifiers, not state.status_effect_type)
				for mod_entry in state.active_modifiers:
					var rule: ConditionalModifierRule = mod_entry.get("rule")
					if rule and rule.status_effect:
						var effect_name: String = Enums.get_status_effect_name(rule.status_effect.effect_type)
						var chance_pct: int = int(rule.status_effect_chance * 100)
						_add_modifier_label("%s%s: %d%%  ·  +%d stack (+%d on crit)" % [indent, effect_name, chance_pct, rule.status_stacks, rule.status_crit_stacks], Color(1.0, 0.7, 0.3))

				# Aggregate conditional stats
				var stat_keys: Array = state.aggregate_stats.keys()
				for si in range(stat_keys.size()):
					var stat: Enums.Stat = stat_keys[si]
					var value: float = state.aggregate_stats[stat]
					var prefix: String = "+" if value >= 0 else ""
					_add_modifier_label("%s%s%d %s" % [indent, prefix, int(value), Enums.get_stat_name(stat)], Color(1.0, 0.9, 0.3))

				# Conditional skills
				for sk in range(state.conditional_skills.size()):
					var skill: SkillData = state.conditional_skills[sk]
					_add_modifier_label("%sGrants: %s" % [indent, skill.display_name], Color(0.6, 1.0, 0.6))

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
	_price_label.visible = false
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


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _add_header_label(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	_modifier_list.add_child(label)


func _add_modifier_label(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	_modifier_list.add_child(label)


