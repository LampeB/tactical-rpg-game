extends PanelContainer
## Tooltip popup showing item details on hover.

const FONT_SIZE := 12  ## Font size used for all dynamically-created labels in the tooltip

## When true, the tooltip stays in its layout position instead of floating.
var embedded: bool = false

## Track currently shown item to avoid redundant rebuilds (prevents flicker).
var _current_item: ItemData = null
var _current_placed: GridInventory.PlacedItem = null

@onready var _name_label: Label = $Margin/VBox/NameLabel
@onready var _rarity_label: Label = $Margin/VBox/RarityLabel
@onready var _type_label: Label = $Margin/VBox/TypeLabel
@onready var _price_label: Label = $Margin/VBox/PriceLabel
@onready var _stats_container: VBoxContainer = $Margin/VBox/StatsContainer
@onready var _comparison_container: VBoxContainer = $Margin/VBox/ComparisonContainer
@onready var _modifier_section: VBoxContainer = $Margin/VBox/ModifierSection
@onready var _modifier_list: VBoxContainer = $Margin/VBox/ModifierSection/ModifierList
@onready var _description_label: Label = $Margin/VBox/DescriptionLabel


func _ready() -> void:
	var tex: Texture2D = preload("res://assets/sprites/ui/theme/tooltip.png")
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = 5.0
	style.texture_margin_top = 5.0
	style.texture_margin_right = 5.0
	style.texture_margin_bottom = 5.0
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	style.modulate_color = Color(0.45, 0.4, 0.35, 1.0)
	add_theme_stylebox_override("panel", style)


func show_for_item(item: ItemData, placed: GridInventory.PlacedItem = null, grid_inv: GridInventory = null, screen_pos: Vector2 = Vector2.ZERO, price: int = -1, price_label: String = "Value") -> void:
	# Skip rebuild if already showing the same item (prevents flicker)
	if _current_item == item and _current_placed == placed and visible:
		return
	_current_item = item
	_current_placed = placed

	# Name with rarity color
	_name_label.text = item.display_name
	var rarity_color: Color = Constants.get_rarity_color(item.rarity)
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

	# Stats & comparison
	_clear_container(_stats_container)
	_clear_container(_comparison_container)
	for mod in item.stat_modifiers:
		if mod is StatModifier:
			var label: Label = Label.new()
			label.text = mod.get_description()
			UIThemes.set_font_size(label, FONT_SIZE)
			_stats_container.add_child(label)

	if item.base_power > 0:
		var phys_label: Label = Label.new()
		phys_label.text = "Physical Power: %d" % item.base_power
		UIThemes.set_font_size(phys_label, FONT_SIZE)
		_stats_container.add_child(phys_label)

	if item.magical_power > 0:
		var mag_label: Label = Label.new()
		mag_label.text = "Magical Power: %d" % item.magical_power
		UIThemes.set_font_size(mag_label, FONT_SIZE)
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

		# Element points
		if not item.element_points.is_empty():
			_modifier_section.visible = true
			_add_header_label("Element Points:", Color(0.7, 0.9, 1.0))
			for elem_key in item.element_points:
				var elem: int = elem_key
				var pts: int = item.element_points[elem_key]
				var elem_name: String = Enums.get_element_name(elem as Enums.Element)
				var elem_color: Color = Constants.ELEMENT_COLORS.get(elem, Color.WHITE)
				_add_modifier_label("  %s +%d" % [elem_name, pts], elem_color)

	elif item.is_modifiable():
		var has_innate: bool = item.innate_status_effect != null
		var modifiers: Array = grid_inv.get_modifiers_affecting(placed) if placed and grid_inv else []
		var state: ToolModifierState = grid_inv.get_tool_modifier_state(placed) if placed and grid_inv and item.item_type == Enums.ItemType.ACTIVE_TOOL else null
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

	# Legendary effects section
	var has_legendary: bool = not item.granted_effects.is_empty() \
		or item.extra_hit_count > 0 \
		or item.innate_force_aoe \
		or item.innate_lifesteal_percent > 0.0 \
		or item.on_kill_heal_percent > 0.0
	if has_legendary:
		_modifier_section.visible = true
		var legend_color := Color(1.0, 0.84, 0.0)
		_add_header_label("Legendary Effect:", legend_color)
		for eff in item.granted_effects:
			_add_modifier_label("  " + PassiveEffects.get_description(eff), legend_color)
		if item.extra_hit_count > 0:
			var pct: int = int(item.extra_hit_damage_fraction * 100)
			_add_modifier_label("  +%d extra hit(s) at %d%% damage" % [item.extra_hit_count, pct], legend_color)
		if item.innate_force_aoe:
			_add_modifier_label("  Attacks hit all enemies", legend_color)
		if item.innate_lifesteal_percent > 0.0:
			var ls_pct: int = int(item.innate_lifesteal_percent * 100)
			_add_modifier_label("  Lifesteal: heal %d%% of damage dealt" % ls_pct, legend_color)
		if item.on_kill_heal_percent > 0.0:
			var heal_pct: int = int(item.on_kill_heal_percent * 100)
			_add_modifier_label("  On kill: heal %d%% of max HP" % heal_pct, legend_color)

	# Comparison vs equipped
	_build_comparison(item, placed, grid_inv)

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
	_clear_container(_comparison_container)
	_modifier_section.visible = false
	_clear_container(_modifier_list)
	_description_label.text = "Left-click to purchase." if can_afford else "Not enough gold."
	_description_label.visible = true
	_position_at(screen_pos)
	visible = true


func hide_tooltip() -> void:
	_current_item = null
	_current_placed = null
	if embedded:
		show_empty_state()
		return
	visible = false


## Clear all content and show a placeholder. Used in embedded mode.
func show_empty_state() -> void:
	_name_label.text = ""
	_rarity_label.text = ""
	_type_label.text = ""
	_price_label.visible = false
	_clear_container(_stats_container)
	_clear_container(_comparison_container)
	_modifier_section.visible = false
	_clear_container(_modifier_list)
	_description_label.text = "Hover an item to see details"
	_description_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
	_description_label.visible = true
	visible = true


func _position_at(_screen_pos: Vector2) -> void:
	if embedded:
		return
	# Wait one frame for size to update, then anchor to fixed screen position
	await get_tree().process_frame
	var viewport_size: Vector2 = get_viewport_rect().size
	var tooltip_size: Vector2 = size
	# Fixed position: right side, vertically centered
	var margin: float = 16.0
	var pos: Vector2
	pos.x = viewport_size.x - tooltip_size.x - margin
	pos.y = (viewport_size.y - tooltip_size.y) / 2.0
	global_position = pos


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _add_header_label(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	UIThemes.set_font_size(label, FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	_modifier_list.add_child(label)


func _add_modifier_label(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	UIThemes.set_font_size(label, FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	_modifier_list.add_child(label)


# ─── Comparison vs equipped ──────────────────────────────────────────────────

const COLOR_UPGRADE := Color(0.3, 1.0, 0.3)
const COLOR_DOWNGRADE := Color(1.0, 0.3, 0.3)
const COLOR_COMPARISON_HEADER := Color(0.7, 0.7, 0.7)


func _build_comparison(item: ItemData, placed: GridInventory.PlacedItem, grid_inv: GridInventory) -> void:
	if not grid_inv:
		return

	# Only compare equippable items (armor and weapons)
	var is_armor := item.item_type == Enums.ItemType.PASSIVE_GEAR
	var is_weapon := item.item_type == Enums.ItemType.ACTIVE_TOOL
	if not is_armor and not is_weapon:
		return

	# Collect equipped items to compare against
	var compare_targets: Array = []  # Array of {item: ItemData, placed: PlacedItem}

	if is_armor:
		var armor_slots: Dictionary = grid_inv.get_equipped_armor_slots()
		var slot_placed: GridInventory.PlacedItem = armor_slots.get(item.armor_slot)
		if slot_placed and not (placed and slot_placed == placed):
			compare_targets.append({"item": slot_placed.item_data, "placed": slot_placed, "hand": ""})
		elif not slot_placed and not placed:
			# Stash item, empty slot → compare vs nothing
			compare_targets.append({"item": null, "placed": null, "hand": ""})
	else:
		# Weapon: collect ALL equipped weapons with hand labels (skip self)
		var hand_names: Array[String] = ["Main Hand", "Off Hand"]
		var weapon_index: int = 0
		for pi_idx in range(grid_inv.placed_items.size()):
			var pi: GridInventory.PlacedItem = grid_inv.placed_items[pi_idx]
			if pi.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
				var hand_label: String = hand_names[weapon_index] if weapon_index < hand_names.size() else "Hand %d" % (weapon_index + 1)
				weapon_index += 1
				if placed and pi == placed:
					continue
				compare_targets.append({"item": pi.item_data, "placed": pi, "hand": hand_label})
		# Stash weapon with no weapons equipped → compare vs empty
		if compare_targets.is_empty() and not placed:
			compare_targets.append({"item": null, "placed": null, "hand": ""})

	if compare_targets.is_empty():
		return

	# Show comparison for each target
	for target_idx in range(compare_targets.size()):
		var target: Dictionary = compare_targets[target_idx]
		var equipped_item: ItemData = target["item"]
		var hand: String = target.get("hand", "")
		_add_comparison_vs(item, equipped_item, hand)


func _add_comparison_vs(hovered_item: ItemData, equipped_item: ItemData, hand: String = "") -> void:
	## Add comparison labels for hovered_item vs one equipped_item (or null for empty slot).
	var hovered_stats := _collect_stat_values(hovered_item)
	var equipped_stats: Dictionary = _collect_stat_values(equipped_item) if equipped_item else {}

	# Collect all stats from both items
	var all_stats: Dictionary = {}
	for stat_key in hovered_stats:
		all_stats[stat_key] = true
	for stat_key in equipped_stats:
		all_stats[stat_key] = true

	var delta_entries: Array = []

	# Power comparisons
	var hovered_phys: int = hovered_item.base_power
	var equipped_phys: int = equipped_item.base_power if equipped_item else 0
	if hovered_phys - equipped_phys != 0:
		delta_entries.append({"name": "Phys Power", "delta": hovered_phys - equipped_phys, "is_pct": false})

	var hovered_mag: int = hovered_item.magical_power
	var equipped_mag: int = equipped_item.magical_power if equipped_item else 0
	if hovered_mag - equipped_mag != 0:
		delta_entries.append({"name": "Mag Power", "delta": hovered_mag - equipped_mag, "is_pct": false})

	# Stat modifier comparisons
	for stat_key in all_stats:
		var stat: Enums.Stat = stat_key as Enums.Stat
		var stat_name: String = Enums.get_stat_name(stat)
		var hovered_flat: float = hovered_stats.get(stat, {}).get("flat", 0.0)
		var equipped_flat: float = equipped_stats.get(stat, {}).get("flat", 0.0)
		var hovered_pct: float = hovered_stats.get(stat, {}).get("pct", 0.0)
		var equipped_pct: float = equipped_stats.get(stat, {}).get("pct", 0.0)

		var flat_delta: float = hovered_flat - equipped_flat
		var pct_delta: float = hovered_pct - equipped_pct

		if abs(flat_delta) > 0.01:
			delta_entries.append({"name": stat_name, "delta": flat_delta, "is_pct": false})
		if abs(pct_delta) > 0.01:
			delta_entries.append({"name": stat_name, "delta": pct_delta, "is_pct": true})

	if delta_entries.is_empty():
		return

	# Header
	var header_text: String
	if equipped_item:
		var rarity_name: String = Constants.RARITY_NAMES.get(equipped_item.rarity, "Common")
		if hand.is_empty():
			header_text = "vs. %s (%s):" % [equipped_item.display_name, rarity_name]
		else:
			header_text = "vs. %s (%s) [%s]:" % [equipped_item.display_name, rarity_name, hand]
	else:
		header_text = "vs. Empty Slot:"
	var header := Label.new()
	header.text = header_text
	UIThemes.set_font_size(header, FONT_SIZE)
	header.add_theme_color_override("font_color", COLOR_COMPARISON_HEADER)
	_comparison_container.add_child(header)

	# Delta labels
	for entry_idx in range(delta_entries.size()):
		var entry: Dictionary = delta_entries[entry_idx]
		var delta_val: float = entry["delta"]
		var is_pct: bool = entry["is_pct"]
		var stat_name: String = entry["name"]

		var arrow: String
		var color: Color
		if delta_val > 0:
			arrow = "▲"
			color = COLOR_UPGRADE
		else:
			arrow = "▼"
			color = COLOR_DOWNGRADE

		var value_str: String
		if is_pct:
			value_str = "%s %+.0f%% %s" % [arrow, delta_val, stat_name]
		else:
			value_str = "%s %+.0f %s" % [arrow, delta_val, stat_name]

		var lbl := Label.new()
		lbl.text = value_str
		UIThemes.set_font_size(lbl, FONT_SIZE)
		lbl.add_theme_color_override("font_color", color)
		_comparison_container.add_child(lbl)


func _collect_stat_values(item: ItemData) -> Dictionary:
	## Returns {Enums.Stat -> {"flat": float, "pct": float}} for an item's stat_modifiers.
	var result: Dictionary = {}
	if not item:
		return result
	for mod_idx in range(item.stat_modifiers.size()):
		var mod: StatModifier = item.stat_modifiers[mod_idx]
		if not result.has(mod.stat):
			result[mod.stat] = {"flat": 0.0, "pct": 0.0}
		if mod.modifier_type == Enums.ModifierType.FLAT:
			result[mod.stat]["flat"] += mod.value
		else:
			result[mod.stat]["pct"] += mod.value
	return result
