class_name ItemUpgradeSystem
extends RefCounted
## System for upgrading items by combining identical items of the same rarity.
## Example: Common Dagger + Common Dagger = Uncommon Dagger

## Check if two items can be combined for an upgrade.
static func can_upgrade(item1: ItemData, item2: ItemData) -> bool:
	if not item1 or not item2:
		return false

	# Must be same item ID
	if item1.id != item2.id:
		return false

	# Must be same rarity
	if item1.rarity != item2.rarity:
		return false

	# Can't upgrade UNIQUE (max rarity)
	if item1.rarity == Enums.Rarity.UNIQUE:
		return false

	return true


## Returns the next rarity level.
static func get_next_rarity(current_rarity: Enums.Rarity) -> Enums.Rarity:
	match current_rarity:
		Enums.Rarity.COMMON:
			return Enums.Rarity.UNCOMMON
		Enums.Rarity.UNCOMMON:
			return Enums.Rarity.RARE
		Enums.Rarity.RARE:
			return Enums.Rarity.ELITE
		Enums.Rarity.ELITE:
			return Enums.Rarity.LEGENDARY
		Enums.Rarity.LEGENDARY:
			return Enums.Rarity.UNIQUE
		_:
			return current_rarity


## Returns the stat multiplier for the given rarity.
static func get_rarity_stat_multiplier(rarity: Enums.Rarity) -> float:
	match rarity:
		Enums.Rarity.COMMON:
			return 1.0
		Enums.Rarity.UNCOMMON:
			return 1.3
		Enums.Rarity.RARE:
			return 1.7
		Enums.Rarity.ELITE:
			return 2.2
		Enums.Rarity.LEGENDARY:
			return 3.0
		Enums.Rarity.UNIQUE:
			return 4.0
		_:
			return 1.0


## Creates an upgraded version of the item at the next rarity level.
## NOTE: This creates a new ItemData resource in memory (not saved to disk).
static func create_upgraded_item(base_item: ItemData) -> ItemData:
	var upgraded := ItemData.new()

	# Copy base properties
	upgraded.id = base_item.id
	upgraded.display_name = _get_upgraded_name(base_item)
	upgraded.description = base_item.description
	upgraded.icon = base_item.icon
	upgraded.item_type = base_item.item_type
	upgraded.category = base_item.category
	upgraded.rarity = get_next_rarity(base_item.rarity)
	upgraded.hand_slots_required = base_item.hand_slots_required
	upgraded.armor_slot = base_item.armor_slot
	upgraded.bonus_hand_slots = base_item.bonus_hand_slots
	upgraded.shape = base_item.shape
	upgraded.modifier_reach = base_item.modifier_reach
	upgraded.granted_skills = base_item.granted_skills.duplicate()
	upgraded.use_skill = base_item.use_skill  # For consumables

	# Upgrade numeric stats - each upgrade is 1.5x the base item
	var stat_scale := 1.5

	upgraded.base_power = roundi(base_item.base_power * stat_scale)
	upgraded.magical_power = roundi(base_item.magical_power * stat_scale)
	upgraded.base_price = roundi(base_item.base_price * stat_scale * 1.5)

	# Upgrade stat modifiers
	upgraded.stat_modifiers = []
	for i in range(base_item.stat_modifiers.size()):
		var old_mod: StatModifier = base_item.stat_modifiers[i]
		var new_mod := StatModifier.new()
		new_mod.stat = old_mod.stat
		new_mod.modifier_type = old_mod.modifier_type
		new_mod.value = old_mod.value * stat_scale
		upgraded.stat_modifiers.append(new_mod)

	# Upgrade modifier bonuses (for gems)
	upgraded.modifier_bonuses = []
	for i in range(base_item.modifier_bonuses.size()):
		var old_mod: StatModifier = base_item.modifier_bonuses[i]
		var new_mod := StatModifier.new()
		new_mod.stat = old_mod.stat
		new_mod.modifier_type = old_mod.modifier_type
		new_mod.value = old_mod.value * stat_scale
		upgraded.modifier_bonuses.append(new_mod)

	# Upgrade conditional modifier rules (for gems - deep copy and scale stat bonuses)
	upgraded.conditional_modifier_rules = []
	for i in range(base_item.conditional_modifier_rules.size()):
		var old_rule: ConditionalModifierRule = base_item.conditional_modifier_rules[i]
		var new_rule := ConditionalModifierRule.new()
		new_rule.target_weapon_type = old_rule.target_weapon_type
		new_rule.status_effect = old_rule.status_effect
		new_rule.status_effect_chance = minf(old_rule.status_effect_chance * stat_scale, 0.9)
		new_rule.granted_skills = old_rule.granted_skills.duplicate()

		# Scale stat bonuses within the rule
		new_rule.stat_bonuses = []
		for j in range(old_rule.stat_bonuses.size()):
			var old_mod: StatModifier = old_rule.stat_bonuses[j]
			var new_mod := StatModifier.new()
			new_mod.stat = old_mod.stat
			new_mod.modifier_type = old_mod.modifier_type
			new_mod.value = old_mod.value * stat_scale
			new_rule.stat_bonuses.append(new_mod)

		upgraded.conditional_modifier_rules.append(new_rule)

	return upgraded


## Returns an upgraded display name with rarity prefix.
static func _get_upgraded_name(item: ItemData) -> String:
	var next_rarity := get_next_rarity(item.rarity)
	var prefix := ""

	match next_rarity:
		Enums.Rarity.UNCOMMON:
			prefix = "Fine "
		Enums.Rarity.RARE:
			prefix = "Superior "
		Enums.Rarity.ELITE:
			prefix = "Elite "
		Enums.Rarity.LEGENDARY:
			prefix = "Legendary "
		Enums.Rarity.UNIQUE:
			prefix = "Mythic "

	# Remove existing prefix if present
	var base_name := item.display_name
	var prefixes := ["Fine ", "Superior ", "Elite ", "Legendary ", "Mythic "]
	for p in prefixes:
		if base_name.begins_with(p):
			base_name = base_name.substr(p.length())
			break

	return prefix + base_name
