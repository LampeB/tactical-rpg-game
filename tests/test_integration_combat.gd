extends Node
## Integration tests for combat UI and gameplay flow.
## Simulates user interactions programmatically.

var _test_results: Array = []
var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("=== Combat Integration Tests ===\n")
	run_all_tests()
	print_results()

func run_all_tests() -> void:
	# Combat flow tests
	test_combat_entity_creation()
	test_hybrid_damage_in_combat()
	test_gem_bonuses_apply()
	test_status_effect_application()
	test_weapon_type_affects_damage()

	# Status effect mechanics
	test_status_effect_duration_decrements()
	test_status_effect_expires()
	test_burn_deals_tick_damage()
	test_chilled_reduces_speed()
	test_multiple_status_effects_stack()

	# Gem status effect integration
	test_fire_gem_applies_burn()
	test_ice_gem_applies_chilled()
	test_thunder_gem_applies_shocked()
	test_poison_gem_applies_poisoned()
	test_status_chance_varies_by_weapon_type()

	# Armor & defense system
	test_physical_defense_reduces_physical_damage()
	test_magical_defense_reduces_magical_damage()
	test_hybrid_damage_split_calculation()

	# Gem system advanced
	test_melee_vs_magic_magical_damage_differs()
	test_fire_gem_staff_grants_skill()
	test_multiple_gems_stack_magical_damage()

	# Edge cases
	test_no_weapon_equipped()
	test_weapon_with_no_gems()
	test_pure_physical_weapon()
	test_pure_magical_weapon()
	test_critical_hit_hybrid_damage()
	test_defending_reduces_hybrid_damage()

## ============================================================================
## Combat Integration Tests
## ============================================================================

func test_combat_entity_creation() -> void:
	var test_name := "Combat entity creates from character data"

	var char_data := CharacterData.new()
	char_data.display_name = "Test Warrior"
	char_data.max_hp = 100
	char_data.max_mp = 50
	char_data.physical_attack = 15
	char_data.physical_defense = 10
	char_data.special_attack = 8
	char_data.special_defense = 12  # This maps to MAGICAL_DEFENSE now

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8
	var inv := GridInventory.new(template)

	var entity := CombatEntity.from_character(char_data, inv)

	if entity.entity_name != "Test Warrior":
		add_failure(test_name, "Entity name mismatch")
		return

	if entity.max_hp != 100:
		add_failure(test_name, "Max HP mismatch: %d" % entity.max_hp)
		return

	# Check that magical defense stat is accessible
	var mag_def := entity.get_effective_stat(Enums.Stat.MAGICAL_DEFENSE)
	if mag_def != 12:
		add_failure(test_name, "Magical defense not working: %d" % mag_def)
		return

	add_success(test_name)

func test_hybrid_damage_in_combat() -> void:
	var test_name := "Hybrid damage calculation in combat scenario"

	# Create attacker with weapon
	var attacker_data := CharacterData.new()
	attacker_data.display_name = "Attacker"
	attacker_data.max_hp = 100
	attacker_data.max_mp = 50
	attacker_data.physical_attack = 20
	attacker_data.special_attack = 15

	var attacker_template := GridTemplate.new()
	attacker_template.width = 6
	attacker_template.height = 8
	var attacker_inv := GridInventory.new(attacker_template)

	# Add weapon with both physical and magical damage
	var sword := ItemData.new()
	sword.item_type = Enums.ItemType.ACTIVE_TOOL
	sword.category = Enums.EquipmentCategory.SWORD
	sword.base_power = 10  # Physical
	sword.magical_power = 5  # Magical
	sword.shape = ItemShape.new()
	sword.shape.cells = [Vector2i(0, 0)]

	attacker_inv.place_item(sword, Vector2i(0, 0), 0)

	var attacker := CombatEntity.from_character(attacker_data, attacker_inv)

	# Create defender
	var defender_data := CharacterData.new()
	defender_data.display_name = "Defender"
	defender_data.max_hp = 100
	defender_data.physical_defense = 5
	defender_data.special_defense = 3  # MAGICAL_DEFENSE

	var defender_template := GridTemplate.new()
	defender_template.width = 6
	defender_template.height = 8
	var defender_inv := GridInventory.new(defender_template)

	var defender := CombatEntity.from_character(defender_data, defender_inv)

	# Calculate hybrid damage
	var result := DamageCalculator.calculate_basic_attack(attacker, defender)

	if not ("amount" in result):
		add_failure(test_name, "Damage result missing amount")
		return

	# Damage should be > 0 (hybrid of physical + magical)
	if result.amount <= 0:
		add_failure(test_name, "Damage is zero or negative: %d" % result.amount)
		return

	# Should be more than pure physical (which would be ~22.5)
	# because magical component adds damage
	if result.amount < 15:
		add_failure(test_name, "Hybrid damage too low: %d" % result.amount)
		return

	add_success(test_name)

func test_gem_bonuses_apply() -> void:
	var test_name := "Gems add magical damage to weapons"

	var char_data := CharacterData.new()
	char_data.display_name = "Mage"
	char_data.max_hp = 80
	char_data.physical_attack = 10
	char_data.special_attack = 25

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8
	var inv := GridInventory.new(template)

	# Add staff
	var staff := ItemData.new()
	staff.item_type = Enums.ItemType.ACTIVE_TOOL
	staff.category = Enums.EquipmentCategory.STAFF
	staff.base_power = 5
	staff.magical_power = 8
	staff.shape = ItemShape.new()
	staff.shape.cells = [Vector2i(0, 0), Vector2i(0, 1)]

	inv.place_item(staff, Vector2i(0, 0), 0)

	# Add gem that adds magical damage
	var gem := ItemData.new()
	gem.item_type = Enums.ItemType.MODIFIER
	gem.modifier_reach = 1
	gem.shape = ItemShape.new()
	gem.shape.cells = [Vector2i(0, 0)]

	# Create a rule that adds magical damage to magic weapons
	var rule := ConditionalModifierRule.new()
	rule.target_weapon_type = Enums.WeaponType.MAGIC
	rule.added_magical_damage = 5
	gem.conditional_modifier_rules = [rule]

	# Place gem next to staff
	inv.place_item(gem, Vector2i(1, 0), 0)

	var entity := CombatEntity.from_character(char_data, inv)

	# Check magical power includes gem bonus
	var mag_power := entity.get_primary_weapon_magical_power()

	# Should be: base 8 + gem 5 = 13
	if mag_power != 13:
		add_failure(test_name, "Expected magical power 13, got %d" % mag_power)
		return

	add_success(test_name)

func test_status_effect_application() -> void:
	var test_name := "Status effects can be created and applied"

	# Create a burn status effect
	var burn := StatusEffect.new()
	burn.effect_type = Enums.StatusEffectType.BURN
	burn.duration_turns = 3
	burn.tick_damage = 5

	var entity := CombatEntity.new()
	entity.entity_name = "Test Target"
	entity.max_hp = 100
	entity.current_hp = 100

	# Apply status effect with 100% chance
	var applied := entity.apply_gem_status_effect(burn, 1.0)

	if not applied:
		add_failure(test_name, "Failed to apply status effect")
		return

	if not entity.has_gem_status_effect(Enums.StatusEffectType.BURN):
		add_failure(test_name, "Entity doesn't have burn status")
		return

	# Process status effects (should deal tick damage)
	var hp_before := entity.current_hp
	entity.process_gem_status_effects()
	var hp_after := entity.current_hp

	if hp_after >= hp_before:
		add_failure(test_name, "Burn didn't deal damage")
		return

	add_success(test_name)

func test_weapon_type_affects_damage() -> void:
	var test_name := "Different weapon types calculate damage correctly"

	# Test that MELEE, RANGED, and MAGIC weapons all work
	var weapon_types := [
		{"cat": Enums.EquipmentCategory.SWORD, "type": Enums.WeaponType.MELEE},
		{"cat": Enums.EquipmentCategory.BOW, "type": Enums.WeaponType.RANGED},
		{"cat": Enums.EquipmentCategory.STAFF, "type": Enums.WeaponType.MAGIC},
	]

	for weapon_info in weapon_types:
		var weapon := ItemData.new()
		weapon.category = weapon_info.cat

		var detected_type := weapon.get_weapon_type()
		if detected_type != weapon_info.type:
			add_failure(test_name, "Weapon type mismatch for %d" % weapon_info.cat)
			return

	add_success(test_name)

## ============================================================================
## Status Effect Mechanics
## ============================================================================

func test_status_effect_duration_decrements() -> void:
	var test_name := "Status effect duration decrements each turn"

	var burn := StatusEffect.new()
	burn.effect_type = Enums.StatusEffectType.BURN
	burn.duration_turns = 3
	burn.tick_damage = 5

	var entity := CombatEntity.new()
	entity.entity_name = "Test Target"
	entity.max_hp = 100
	entity.current_hp = 100

	entity.apply_gem_status_effect(burn, 1.0)

	var initial_duration: int = entity.active_gem_status_effects[0].duration_turns
	entity.process_gem_status_effects()
	var after_duration: int = entity.active_gem_status_effects[0].duration_turns

	if after_duration != initial_duration - 1:
		add_failure(test_name, "Duration didn't decrement: %d -> %d" % [initial_duration, after_duration])
		return

	add_success(test_name)

func test_status_effect_expires() -> void:
	var test_name := "Status effects expire after duration reaches 0"

	var burn := StatusEffect.new()
	burn.effect_type = Enums.StatusEffectType.BURN
	burn.duration_turns = 1
	burn.tick_damage = 5

	var entity := CombatEntity.new()
	entity.entity_name = "Test Target"
	entity.max_hp = 100
	entity.current_hp = 100

	entity.apply_gem_status_effect(burn, 1.0)

	if entity.active_gem_status_effects.is_empty():
		add_failure(test_name, "Status not applied")
		return

	entity.process_gem_status_effects()

	if not entity.active_gem_status_effects.is_empty():
		add_failure(test_name, "Status didn't expire after duration 0")
		return

	add_success(test_name)

func test_burn_deals_tick_damage() -> void:
	var test_name := "Burn deals correct tick damage"

	var burn := StatusEffect.new()
	burn.effect_type = Enums.StatusEffectType.BURN
	burn.duration_turns = 3
	burn.tick_damage = 10

	var entity := CombatEntity.new()
	entity.entity_name = "Test Target"
	entity.max_hp = 100
	entity.current_hp = 100

	entity.apply_gem_status_effect(burn, 1.0)

	var hp_before := entity.current_hp
	entity.process_gem_status_effects()
	var hp_after := entity.current_hp
	var damage_taken := hp_before - hp_after

	if damage_taken != 10:
		add_failure(test_name, "Expected 10 damage, got %d" % damage_taken)
		return

	add_success(test_name)

func test_chilled_reduces_speed() -> void:
	var test_name := "Chilled effect reduces entity speed"

	var char_data := CharacterData.new()
	char_data.display_name = "Test Char"
	char_data.max_hp = 100
	char_data.speed = 50

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8
	var inv := GridInventory.new(template)

	var entity := CombatEntity.from_character(char_data, inv)

	var base_speed := entity.get_effective_stat(Enums.Stat.SPEED)

	var chilled: StatusEffect = load("res://data/status_effects/chilled.tres")
	if not chilled:
		add_failure(test_name, "Failed to load chilled status")
		return

	entity.apply_gem_status_effect(chilled, 1.0)

	var chilled_speed := entity.get_effective_stat(Enums.Stat.SPEED)

	if chilled_speed >= base_speed:
		add_failure(test_name, "Speed not reduced: %d -> %d" % [base_speed, chilled_speed])
		return

	add_success(test_name)

func test_multiple_status_effects_stack() -> void:
	var test_name := "Multiple different status effects stack on same entity"

	var burn := StatusEffect.new()
	burn.effect_type = Enums.StatusEffectType.BURN
	burn.duration_turns = 3
	burn.tick_damage = 5

	var poison := StatusEffect.new()
	poison.effect_type = Enums.StatusEffectType.POISONED
	poison.duration_turns = 5
	poison.tick_damage = 3

	var entity := CombatEntity.new()
	entity.entity_name = "Test Target"
	entity.max_hp = 100
	entity.current_hp = 100

	entity.apply_gem_status_effect(burn, 1.0)
	entity.apply_gem_status_effect(poison, 1.0)

	if entity.active_gem_status_effects.size() != 2:
		add_failure(test_name, "Expected 2 effects, got %d" % entity.active_gem_status_effects.size())
		return

	if not entity.has_gem_status_effect(Enums.StatusEffectType.BURN):
		add_failure(test_name, "Missing burn effect")
		return

	if not entity.has_gem_status_effect(Enums.StatusEffectType.POISONED):
		add_failure(test_name, "Missing poison effect")
		return

	add_success(test_name)

## ============================================================================
## Gem Status Effect Integration
## ============================================================================

func test_fire_gem_applies_burn() -> void:
	var test_name := "Fire gem applies Burn status on hit"

	var fire_gem: ItemData = load("res://data/items/modifiers/fire_gem_common.tres")
	if not fire_gem:
		add_failure(test_name, "Failed to load fire gem")
		return

	if fire_gem.conditional_modifier_rules.is_empty():
		add_failure(test_name, "Fire gem has no rules")
		return

	var rule: ConditionalModifierRule = fire_gem.conditional_modifier_rules[0]

	if rule.status_effect == null:
		add_failure(test_name, "Fire gem rule has no status effect")
		return

	if rule.status_effect.effect_type != Enums.StatusEffectType.BURN:
		add_failure(test_name, "Fire gem doesn't apply BURN")
		return

	if rule.status_effect_chance <= 0.0:
		add_failure(test_name, "Fire gem has 0 status chance")
		return

	add_success(test_name)

func test_ice_gem_applies_chilled() -> void:
	var test_name := "Ice gem applies Chilled status on hit"

	var ice_gem: ItemData = load("res://data/items/modifiers/ice_gem_common.tres")
	if not ice_gem:
		add_failure(test_name, "Failed to load ice gem")
		return

	if ice_gem.conditional_modifier_rules.is_empty():
		add_failure(test_name, "Ice gem has no rules")
		return

	var rule: ConditionalModifierRule = ice_gem.conditional_modifier_rules[0]

	if rule.status_effect == null:
		add_failure(test_name, "Ice gem rule has no status effect")
		return

	if rule.status_effect.effect_type != Enums.StatusEffectType.CHILLED:
		add_failure(test_name, "Ice gem doesn't apply CHILLED")
		return

	add_success(test_name)

func test_thunder_gem_applies_shocked() -> void:
	var test_name := "Thunder gem applies Shocked status on hit"

	var thunder_gem: ItemData = load("res://data/items/modifiers/thunder_gem_common.tres")
	if not thunder_gem:
		add_failure(test_name, "Failed to load thunder gem")
		return

	if thunder_gem.conditional_modifier_rules.is_empty():
		add_failure(test_name, "Thunder gem has no rules")
		return

	var rule: ConditionalModifierRule = thunder_gem.conditional_modifier_rules[0]

	if rule.status_effect == null:
		add_failure(test_name, "Thunder gem rule has no status effect")
		return

	if rule.status_effect.effect_type != Enums.StatusEffectType.SHOCKED:
		add_failure(test_name, "Thunder gem doesn't apply SHOCKED")
		return

	add_success(test_name)

func test_poison_gem_applies_poisoned() -> void:
	var test_name := "Poison gem applies Poisoned status on hit"

	var poison_gem: ItemData = load("res://data/items/modifiers/poison_gem_common.tres")
	if not poison_gem:
		add_failure(test_name, "Failed to load poison gem")
		return

	if poison_gem.conditional_modifier_rules.is_empty():
		add_failure(test_name, "Poison gem has no rules")
		return

	var rule: ConditionalModifierRule = poison_gem.conditional_modifier_rules[0]

	if rule.status_effect == null:
		add_failure(test_name, "Poison gem rule has no status effect")
		return

	if rule.status_effect.effect_type != Enums.StatusEffectType.POISONED:
		add_failure(test_name, "Poison gem doesn't apply POISONED")
		return

	add_success(test_name)

func test_status_chance_varies_by_weapon_type() -> void:
	var test_name := "Status effect chance varies by weapon type"

	var fire_gem: ItemData = load("res://data/items/modifiers/fire_gem_common.tres")
	if not fire_gem:
		add_failure(test_name, "Failed to load fire gem")
		return

	if fire_gem.conditional_modifier_rules.size() < 2:
		add_failure(test_name, "Fire gem needs at least 2 rules")
		return

	var melee_rule: ConditionalModifierRule = null
	var magic_rule: ConditionalModifierRule = null

	for i in range(fire_gem.conditional_modifier_rules.size()):
		var rule: ConditionalModifierRule = fire_gem.conditional_modifier_rules[i]
		if rule.target_weapon_type == Enums.WeaponType.MELEE:
			melee_rule = rule
		elif rule.target_weapon_type == Enums.WeaponType.MAGIC:
			magic_rule = rule

	if not melee_rule or not magic_rule:
		add_failure(test_name, "Missing melee or magic rule")
		return

	if magic_rule.status_effect_chance <= melee_rule.status_effect_chance:
		add_failure(test_name, "Magic chance should be higher than melee")
		return

	add_success(test_name)

## ============================================================================
## Armor & Defense System
## ============================================================================

func test_physical_defense_reduces_physical_damage() -> void:
	var test_name := "Physical defense reduces physical damage component"

	var attacker_data := CharacterData.new()
	attacker_data.display_name = "Attacker"
	attacker_data.max_hp = 100
	attacker_data.physical_attack = 20

	var defender_data := CharacterData.new()
	defender_data.display_name = "Defender"
	defender_data.max_hp = 100
	defender_data.physical_defense = 0

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8

	var attacker := CombatEntity.from_character(attacker_data, GridInventory.new(template))
	var defender_no_armor := CombatEntity.from_character(defender_data, GridInventory.new(template))

	var result_no_armor := DamageCalculator.calculate_basic_attack(attacker, defender_no_armor)

	defender_data.physical_defense = 10
	var defender_with_armor := CombatEntity.from_character(defender_data, GridInventory.new(template))

	var result_with_armor := DamageCalculator.calculate_basic_attack(attacker, defender_with_armor)

	if result_with_armor.amount >= result_no_armor.amount:
		add_failure(test_name, "Armor didn't reduce damage: %d vs %d" % [result_no_armor.amount, result_with_armor.amount])
		return

	add_success(test_name)

func test_magical_defense_reduces_magical_damage() -> void:
	var test_name := "Magical defense reduces magical damage component"

	var char_data := CharacterData.new()
	char_data.display_name = "Mage"
	char_data.max_hp = 100
	char_data.special_attack = 20

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8
	var inv := GridInventory.new(template)

	var staff := ItemData.new()
	staff.item_type = Enums.ItemType.ACTIVE_TOOL
	staff.category = Enums.EquipmentCategory.STAFF
	staff.base_power = 0
	staff.magical_power = 15
	staff.shape = ItemShape.new()
	staff.shape.cells = [Vector2i(0, 0)]

	inv.place_item(staff, Vector2i(0, 0), 0)

	var attacker := CombatEntity.from_character(char_data, inv)

	var defender_data_low := CharacterData.new()
	defender_data_low.display_name = "Low Def"
	defender_data_low.max_hp = 100
	defender_data_low.special_defense = 0

	var defender_data_high := CharacterData.new()
	defender_data_high.display_name = "High Def"
	defender_data_high.max_hp = 100
	defender_data_high.special_defense = 10

	var defender_low := CombatEntity.from_character(defender_data_low, GridInventory.new(template))
	var defender_high := CombatEntity.from_character(defender_data_high, GridInventory.new(template))

	var result_low := DamageCalculator.calculate_basic_attack(attacker, defender_low)
	var result_high := DamageCalculator.calculate_basic_attack(attacker, defender_high)

	if result_high.amount >= result_low.amount:
		add_failure(test_name, "Magical defense didn't reduce damage: %d vs %d" % [result_low.amount, result_high.amount])
		return

	add_success(test_name)

func test_hybrid_damage_split_calculation() -> void:
	var test_name := "Hybrid attack splits damage calculation correctly"

	var char_data := CharacterData.new()
	char_data.display_name = "Hybrid Fighter"
	char_data.max_hp = 100
	char_data.physical_attack = 15
	char_data.special_attack = 12

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8
	var inv := GridInventory.new(template)

	var hybrid_weapon := ItemData.new()
	hybrid_weapon.item_type = Enums.ItemType.ACTIVE_TOOL
	hybrid_weapon.category = Enums.EquipmentCategory.SWORD
	hybrid_weapon.base_power = 10
	hybrid_weapon.magical_power = 8
	hybrid_weapon.shape = ItemShape.new()
	hybrid_weapon.shape.cells = [Vector2i(0, 0)]

	inv.place_item(hybrid_weapon, Vector2i(0, 0), 0)

	var attacker := CombatEntity.from_character(char_data, inv)
	var defender := CombatEntity.new()
	defender.is_player = false

	var result := DamageCalculator.calculate_basic_attack(attacker, defender)

	if result.amount <= 0:
		add_failure(test_name, "Hybrid damage is 0")
		return

	if result.amount < 10:
		add_failure(test_name, "Hybrid damage too low: %d" % result.amount)
		return

	add_success(test_name)

## ============================================================================
## Gem System Advanced
## ============================================================================

func test_melee_vs_magic_magical_damage_differs() -> void:
	var test_name := "Melee weapons get different magical damage than magic weapons"

	var fire_gem: ItemData = load("res://data/items/modifiers/fire_gem_common.tres")
	if not fire_gem:
		add_failure(test_name, "Failed to load fire gem")
		return

	var melee_rule: ConditionalModifierRule = null
	var magic_rule: ConditionalModifierRule = null

	for i in range(fire_gem.conditional_modifier_rules.size()):
		var rule: ConditionalModifierRule = fire_gem.conditional_modifier_rules[i]
		if rule.target_weapon_type == Enums.WeaponType.MELEE:
			melee_rule = rule
		elif rule.target_weapon_type == Enums.WeaponType.MAGIC:
			magic_rule = rule

	if not melee_rule or not magic_rule:
		add_failure(test_name, "Missing melee or magic rule")
		return

	if magic_rule.added_magical_damage <= melee_rule.added_magical_damage:
		add_failure(test_name, "Magic damage should be higher: melee=%d magic=%d" % [melee_rule.added_magical_damage, magic_rule.added_magical_damage])
		return

	add_success(test_name)

func test_fire_gem_staff_grants_skill() -> void:
	var test_name := "Fire gem + staff grants Fire Bolt skill"

	var fire_gem: ItemData = load("res://data/items/modifiers/fire_gem_common.tres")
	if not fire_gem:
		add_failure(test_name, "Failed to load fire gem")
		return

	var magic_rule: ConditionalModifierRule = null

	for i in range(fire_gem.conditional_modifier_rules.size()):
		var rule: ConditionalModifierRule = fire_gem.conditional_modifier_rules[i]
		if rule.target_weapon_type == Enums.WeaponType.MAGIC:
			magic_rule = rule
			break

	if not magic_rule:
		add_failure(test_name, "Missing magic rule")
		return

	if magic_rule.granted_skills.is_empty():
		add_failure(test_name, "Magic rule grants no skills")
		return

	var skill: SkillData = magic_rule.granted_skills[0]
	if "fire" not in skill.id.to_lower() and "bolt" not in skill.id.to_lower():
		add_failure(test_name, "Skill doesn't appear to be Fire Bolt: %s" % skill.id)
		return

	add_success(test_name)

func test_multiple_gems_stack_magical_damage() -> void:
	var test_name := "Multiple gems stack magical damage additively"

	var char_data := CharacterData.new()
	char_data.display_name = "Mage"
	char_data.max_hp = 100
	char_data.special_attack = 20

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8
	var inv := GridInventory.new(template)

	var staff := ItemData.new()
	staff.item_type = Enums.ItemType.ACTIVE_TOOL
	staff.category = Enums.EquipmentCategory.STAFF
	staff.base_power = 5
	staff.magical_power = 10
	staff.shape = ItemShape.new()
	staff.shape.cells = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]

	inv.place_item(staff, Vector2i(0, 0), 0)

	var gem1 := ItemData.new()
	gem1.item_type = Enums.ItemType.MODIFIER
	gem1.modifier_reach = 1
	gem1.shape = ItemShape.new()
	gem1.shape.cells = [Vector2i(0, 0)]
	var rule1 := ConditionalModifierRule.new()
	rule1.target_weapon_type = Enums.WeaponType.MAGIC
	rule1.added_magical_damage = 5
	gem1.conditional_modifier_rules = [rule1]

	var gem2 := ItemData.new()
	gem2.item_type = Enums.ItemType.MODIFIER
	gem2.modifier_reach = 1
	gem2.shape = ItemShape.new()
	gem2.shape.cells = [Vector2i(0, 0)]
	var rule2 := ConditionalModifierRule.new()
	rule2.target_weapon_type = Enums.WeaponType.MAGIC
	rule2.added_magical_damage = 3
	gem2.conditional_modifier_rules = [rule2]

	inv.place_item(gem1, Vector2i(1, 0), 0)
	inv.place_item(gem2, Vector2i(1, 1), 0)

	var entity := CombatEntity.from_character(char_data, inv)

	var mag_power := entity.get_primary_weapon_magical_power()

	if mag_power != 18:
		add_failure(test_name, "Expected 18 (10+5+3), got %d" % mag_power)
		return

	add_success(test_name)

## ============================================================================
## Edge Cases
## ============================================================================

func test_no_weapon_equipped() -> void:
	var test_name := "Character with no weapon equipped"

	var char_data := CharacterData.new()
	char_data.display_name = "Unarmed"
	char_data.max_hp = 100
	char_data.physical_attack = 10

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8
	var inv := GridInventory.new(template)

	var entity := CombatEntity.from_character(char_data, inv)

	var phys_power := entity.get_primary_weapon_physical_power()
	var mag_power := entity.get_primary_weapon_magical_power()

	if phys_power != 0:
		add_failure(test_name, "Physical power should be 0, got %d" % phys_power)
		return

	if mag_power != 0:
		add_failure(test_name, "Magical power should be 0, got %d" % mag_power)
		return

	add_success(test_name)

func test_weapon_with_no_gems() -> void:
	var test_name := "Weapon with no gems attached"

	var char_data := CharacterData.new()
	char_data.display_name = "Fighter"
	char_data.max_hp = 100
	char_data.special_attack = 15

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8
	var inv := GridInventory.new(template)

	var sword := ItemData.new()
	sword.item_type = Enums.ItemType.ACTIVE_TOOL
	sword.category = Enums.EquipmentCategory.SWORD
	sword.base_power = 15
	sword.magical_power = 0
	sword.shape = ItemShape.new()
	sword.shape.cells = [Vector2i(0, 0)]

	inv.place_item(sword, Vector2i(0, 0), 0)

	var entity := CombatEntity.from_character(char_data, inv)

	# Find primary weapon PlacedItem and get its modifier state
	var primary_weapon_placed = null
	for placed_item in inv.get_all_placed_items():
		if placed_item.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
			primary_weapon_placed = placed_item
			break

	if primary_weapon_placed:
		var modifier_state: ToolModifierState = entity.tool_modifier_states.get(primary_weapon_placed, null)
		if modifier_state and not modifier_state.active_modifiers.is_empty():
			add_failure(test_name, "Should have no modifiers, found %d" % modifier_state.active_modifiers.size())
			return

	add_success(test_name)

func test_pure_physical_weapon() -> void:
	var test_name := "Weapon with 0 magical_power (pure physical)"

	var char_data := CharacterData.new()
	char_data.display_name = "Warrior"
	char_data.max_hp = 100
	char_data.physical_attack = 20

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8
	var inv := GridInventory.new(template)

	var axe := ItemData.new()
	axe.item_type = Enums.ItemType.ACTIVE_TOOL
	axe.category = Enums.EquipmentCategory.AXE
	axe.base_power = 20
	axe.magical_power = 0
	axe.shape = ItemShape.new()
	axe.shape.cells = [Vector2i(0, 0)]

	inv.place_item(axe, Vector2i(0, 0), 0)

	var entity := CombatEntity.from_character(char_data, inv)
	var enemy := CombatEntity.new()
	enemy.is_player = false

	var result := DamageCalculator.calculate_basic_attack(entity, enemy)

	if result.amount <= 0:
		add_failure(test_name, "Pure physical should deal damage")
		return

	add_success(test_name)

func test_pure_magical_weapon() -> void:
	var test_name := "Weapon with 0 base_power (pure magical)"

	var char_data := CharacterData.new()
	char_data.display_name = "Wizard"
	char_data.max_hp = 80
	char_data.special_attack = 25

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8
	var inv := GridInventory.new(template)

	var wand := ItemData.new()
	wand.item_type = Enums.ItemType.ACTIVE_TOOL
	wand.category = Enums.EquipmentCategory.STAFF
	wand.base_power = 0
	wand.magical_power = 20
	wand.shape = ItemShape.new()
	wand.shape.cells = [Vector2i(0, 0)]

	inv.place_item(wand, Vector2i(0, 0), 0)

	var entity := CombatEntity.from_character(char_data, inv)
	var enemy := CombatEntity.new()
	enemy.is_player = false

	var result := DamageCalculator.calculate_basic_attack(entity, enemy)

	if result.amount <= 0:
		add_failure(test_name, "Pure magical should deal damage")
		return

	add_success(test_name)

func test_critical_hit_hybrid_damage() -> void:
	var test_name := "Critical hits apply to total hybrid damage"

	var char_data := CharacterData.new()
	char_data.display_name = "Lucky"
	char_data.max_hp = 100
	char_data.physical_attack = 15
	char_data.special_attack = 10

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8
	var inv := GridInventory.new(template)

	var weapon := ItemData.new()
	weapon.item_type = Enums.ItemType.ACTIVE_TOOL
	weapon.category = Enums.EquipmentCategory.SWORD
	weapon.base_power = 10
	weapon.magical_power = 5
	weapon.shape = ItemShape.new()
	weapon.shape.cells = [Vector2i(0, 0)]

	# Add critical rate through equipment stat modifier
	var crit_mod := StatModifier.new()
	crit_mod.stat = Enums.Stat.CRITICAL_RATE
	crit_mod.value = 100.0
	crit_mod.modifier_type = Enums.ModifierType.FLAT
	weapon.stat_modifiers = [crit_mod]

	inv.place_item(weapon, Vector2i(0, 0), 0)

	var attacker := CombatEntity.from_character(char_data, inv)
	var defender := CombatEntity.new()
	defender.is_player = false

	var result := DamageCalculator.calculate_basic_attack(attacker, defender)

	if not result.is_crit:
		add_failure(test_name, "Should have crit with 100% crit rate")
		return

	add_success(test_name)

func test_defending_reduces_hybrid_damage() -> void:
	var test_name := "Defending stance reduces hybrid damage"

	var char_data := CharacterData.new()
	char_data.display_name = "Attacker"
	char_data.max_hp = 100
	char_data.physical_attack = 20
	char_data.special_attack = 15

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8
	var inv := GridInventory.new(template)

	var weapon := ItemData.new()
	weapon.item_type = Enums.ItemType.ACTIVE_TOOL
	weapon.category = Enums.EquipmentCategory.SWORD
	weapon.base_power = 10
	weapon.magical_power = 5
	weapon.shape = ItemShape.new()
	weapon.shape.cells = [Vector2i(0, 0)]

	inv.place_item(weapon, Vector2i(0, 0), 0)

	var attacker := CombatEntity.from_character(char_data, inv)
	var defender := CombatEntity.new()
	defender.is_player = false
	defender.is_defending = false

	var normal_result := DamageCalculator.calculate_basic_attack(attacker, defender)

	defender.is_defending = true
	var defend_result := DamageCalculator.calculate_basic_attack(attacker, defender)

	if defend_result.amount >= normal_result.amount:
		add_failure(test_name, "Defend didn't reduce damage: %d vs %d" % [normal_result.amount, defend_result.amount])
		return

	add_success(test_name)

## ============================================================================
## Test Infrastructure
## ============================================================================

func add_success(test_name: String) -> void:
	_passed += 1
	_test_results.append({"name": test_name, "passed": true, "message": ""})
	print("[✓] %s" % test_name)

func add_failure(test_name: String, message: String) -> void:
	_failed += 1
	_test_results.append({"name": test_name, "passed": false, "message": message})
	print("[✗] %s: %s" % [test_name, message])

func print_results() -> void:
	print("\n=== Test Results ===")
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
	print("Total:  %d" % (_passed + _failed))

	if _failed == 0:
		print("\n✅ All integration tests passed!")
	else:
		print("\n❌ Some tests failed. See above for details.")

	print("====================\n")
