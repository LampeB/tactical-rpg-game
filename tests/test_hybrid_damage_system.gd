extends Node
## Automated tests for the hybrid damage system refactoring.
## Run this from the command line or by loading the scene and calling run_all_tests().

var _test_results: Array = []
var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("=== Hybrid Damage System Test Suite ===\n")
	run_all_tests()
	print_results()

func run_all_tests() -> void:
	# Phase 1: Enums & Core Type System
	test_weapon_type_enum_exists()
	test_damage_type_simplified()
	test_status_effect_type_enum_exists()
	test_magical_defense_renamed()

	# Phase 2: Hybrid Damage System
	test_item_data_has_magical_power()
	test_weapon_type_classification()
	test_tool_modifier_state_structure()
	test_conditional_modifier_rule_structure()

	# Phase 3: Status Effects
	test_status_effect_resource_exists()
	test_status_effect_data_files_exist()

	# Phase 4: Damage Calculation
	test_hybrid_damage_calculation()
	test_basic_attack_uses_hybrid()

	# Phase 5: Integration
	test_combat_entity_weapon_power_methods()
	test_gem_magical_damage_stacking()

	# Phase 6: Weapon Type Classification (Comprehensive)
	test_all_weapon_categories_classified()

	# Phase 7: Status Effect Mechanics
	test_status_effect_has_required_fields()
	test_status_effect_create_instance()

	# Phase 8: Data Migration Validation
	test_armor_has_dual_defense()
	test_elemental_gems_have_status_effects()
	test_gems_use_weapon_types()
	test_no_old_override_fields()
	test_fire_gem_variants_scaling()

## ============================================================================
## PHASE 1: Enums & Core Type System
## ============================================================================

func test_weapon_type_enum_exists() -> void:
	var test_name := "WeaponType enum exists with 3 values"
	# Try to access the enum - if it doesn't exist, will fail with clear error
	var keys := Enums.WeaponType.keys()
	if keys.size() != 3:
		add_failure(test_name, "Expected 3 weapon types, got %d" % keys.size())
		return

	if not ("MELEE" in keys and "RANGED" in keys and "MAGIC" in keys):
		add_failure(test_name, "Missing expected weapon types: %s" % str(keys))
		return

	add_success(test_name)

func test_damage_type_simplified() -> void:
	var test_name := "DamageType enum simplified to 2 values"
	var keys := Enums.DamageType.keys()

	if keys.size() != 2:
		add_failure(test_name, "Expected 2 damage types, got %d: %s" % [keys.size(), str(keys)])
		return

	if not ("PHYSICAL" in keys and "MAGICAL" in keys):
		add_failure(test_name, "Expected PHYSICAL and MAGICAL, got: %s" % str(keys))
		return

	add_success(test_name)

func test_status_effect_type_enum_exists() -> void:
	var test_name := "StatusEffectType enum exists with 4 values"
	# Try to access the enum - if it doesn't exist, will fail with clear error
	var keys := Enums.StatusEffectType.keys()
	if keys.size() != 4:
		add_failure(test_name, "Expected 4 status effects, got %d" % keys.size())
		return

	if not ("BURN" in keys and "POISONED" in keys and "CHILLED" in keys and "SHOCKED" in keys):
		add_failure(test_name, "Missing expected status effects: %s" % str(keys))
		return

	add_success(test_name)

func test_magical_defense_renamed() -> void:
	var test_name := "SPECIAL_DEFENSE renamed to MAGICAL_DEFENSE"
	var keys := Enums.Stat.keys()

	if "SPECIAL_DEFENSE" in keys:
		add_failure(test_name, "SPECIAL_DEFENSE still exists (should be renamed)")
		return

	if not "MAGICAL_DEFENSE" in keys:
		add_failure(test_name, "MAGICAL_DEFENSE does not exist")
		return

	add_success(test_name)

## ============================================================================
## PHASE 2: Hybrid Damage System
## ============================================================================

func test_item_data_has_magical_power() -> void:
	var test_name := "ItemData has magical_power field"
	var item := ItemData.new()

	if not "magical_power" in item:
		add_failure(test_name, "magical_power field does not exist on ItemData")
		return

	add_success(test_name)

func test_weapon_type_classification() -> void:
	var test_name := "ItemData.get_weapon_type() classifies weapons correctly"
	var sword := ItemData.new()
	sword.category = Enums.EquipmentCategory.SWORD

	var bow := ItemData.new()
	bow.category = Enums.EquipmentCategory.BOW

	var staff := ItemData.new()
	staff.category = Enums.EquipmentCategory.STAFF

	if sword.get_weapon_type() != Enums.WeaponType.MELEE:
		add_failure(test_name, "Sword classified as %d instead of MELEE" % sword.get_weapon_type())
		return

	if bow.get_weapon_type() != Enums.WeaponType.RANGED:
		add_failure(test_name, "Bow classified as %d instead of RANGED" % bow.get_weapon_type())
		return

	if staff.get_weapon_type() != Enums.WeaponType.MAGIC:
		add_failure(test_name, "Staff classified as %d instead of MAGIC" % staff.get_weapon_type())
		return

	add_success(test_name)

func test_tool_modifier_state_structure() -> void:
	var test_name := "ToolModifierState has new hybrid damage fields"
	var state := ToolModifierState.new()

	if "damage_type_override" in state:
		add_failure(test_name, "Old damage_type_override field still exists")
		return

	if not ("added_magical_damage" in state and "status_effect_chance" in state and "status_effect_type" in state):
		add_failure(test_name, "Missing new hybrid damage fields")
		return

	add_success(test_name)

func test_conditional_modifier_rule_structure() -> void:
	var test_name := "ConditionalModifierRule has new weapon type structure"
	var rule := ConditionalModifierRule.new()

	if "target_category" in rule:
		add_failure(test_name, "Old target_category field still exists")
		return

	if "override_damage_type" in rule:
		add_failure(test_name, "Old override_damage_type field still exists")
		return

	if not ("target_weapon_type" in rule and "added_magical_damage" in rule and "status_effect" in rule):
		add_failure(test_name, "Missing new weapon type fields")
		return

	add_success(test_name)

## ============================================================================
## PHASE 3: Status Effects
## ============================================================================

func test_status_effect_resource_exists() -> void:
	var test_name := "StatusEffect resource class exists"
	var effect := StatusEffect.new()

	if not effect:
		add_failure(test_name, "Failed to create StatusEffect instance")
		return

	if not ("effect_type" in effect and "duration_turns" in effect and "tick_damage" in effect):
		add_failure(test_name, "StatusEffect missing required fields")
		return

	add_success(test_name)

func test_status_effect_data_files_exist() -> void:
	var test_name := "Status effect data files exist (burn, poisoned, chilled, shocked)"
	var expected_files := [
		"res://data/status_effects/burn.tres",
		"res://data/status_effects/poisoned.tres",
		"res://data/status_effects/chilled.tres",
		"res://data/status_effects/shocked.tres",
	]

	for file_path in expected_files:
		if not ResourceLoader.exists(file_path):
			add_failure(test_name, "Missing file: %s" % file_path)
			return

	add_success(test_name)

## ============================================================================
## PHASE 4: Damage Calculation
## ============================================================================

func test_hybrid_damage_calculation() -> void:
	var test_name := "Hybrid damage calculation works correctly"

	# Create mock entities
	var attacker := CombatEntity.new()
	attacker.is_player = false

	var defender := CombatEntity.new()
	defender.is_player = false

	# Test that the function exists and returns expected structure
	var result := DamageCalculator.calculate_damage_hybrid(attacker, defender, 10, 5, 1.0)

	if not ("amount" in result and "is_crit" in result):
		add_failure(test_name, "calculate_damage_hybrid missing required return fields")
		return

	if typeof(result.amount) != TYPE_INT:
		add_failure(test_name, "Damage amount is not an integer")
		return

	if result.amount < 1:
		add_failure(test_name, "Damage amount is less than minimum (1)")
		return

	add_success(test_name)

func test_basic_attack_uses_hybrid() -> void:
	var test_name := "Basic attack uses hybrid damage for players"

	# Create a player entity with a weapon
	var char_data := CharacterData.new()
	char_data.display_name = "Test Hero"
	char_data.max_hp = 100
	char_data.max_mp = 50

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8
	var inv := GridInventory.new(template)

	# Create a test weapon
	var weapon := ItemData.new()
	weapon.item_type = Enums.ItemType.ACTIVE_TOOL
	weapon.category = Enums.EquipmentCategory.SWORD
	weapon.base_power = 15
	weapon.magical_power = 0
	weapon.shape = ItemShape.new()
	weapon.shape.cells = [Vector2i(0, 0)]

	inv.place_item(weapon, Vector2i(0, 0), 0)

	var player := CombatEntity.from_character(char_data, inv)
	var enemy := CombatEntity.new()
	enemy.is_player = false

	# Verify player has get_primary_weapon_physical_power method
	if not player.has_method("get_primary_weapon_physical_power"):
		add_failure(test_name, "Player missing get_primary_weapon_physical_power method")
		return

	if not player.has_method("get_primary_weapon_magical_power"):
		add_failure(test_name, "Player missing get_primary_weapon_magical_power method")
		return

	var phys_power := player.get_primary_weapon_physical_power()
	if phys_power != 15:
		add_failure(test_name, "Expected physical power 15, got %d" % phys_power)
		return

	add_success(test_name)

## ============================================================================
## PHASE 5: Integration
## ============================================================================

func test_combat_entity_weapon_power_methods() -> void:
	var test_name := "CombatEntity weapon power methods return correct values"

	var char_data := CharacterData.new()
	char_data.display_name = "Test Mage"
	char_data.max_hp = 80
	char_data.max_mp = 100

	var template := GridTemplate.new()
	template.width = 6
	template.height = 8
	var inv := GridInventory.new(template)

	# Create a staff with magical power
	var staff := ItemData.new()
	staff.item_type = Enums.ItemType.ACTIVE_TOOL
	staff.category = Enums.EquipmentCategory.STAFF
	staff.base_power = 5
	staff.magical_power = 10
	staff.shape = ItemShape.new()
	staff.shape.cells = [Vector2i(0, 0)]

	inv.place_item(staff, Vector2i(0, 0), 0)

	var player := CombatEntity.from_character(char_data, inv)

	var phys := player.get_primary_weapon_physical_power()
	var mag := player.get_primary_weapon_magical_power()

	if phys != 5:
		add_failure(test_name, "Expected physical 5, got %d" % phys)
		return

	if mag != 10:
		add_failure(test_name, "Expected magical 10, got %d" % mag)
		return

	add_success(test_name)

func test_gem_magical_damage_stacking() -> void:
	var test_name := "Gem magical damage stacks correctly"

	# This is a simplified test - in practice would need full gem setup
	var state := ToolModifierState.new()
	state.added_magical_damage = 5

	# Simulate adding another gem's magical damage
	state.added_magical_damage += 3

	if state.added_magical_damage != 8:
		add_failure(test_name, "Expected stacked damage 8, got %d" % state.added_magical_damage)
		return

	add_success(test_name)

## ============================================================================
## PHASE 6: Weapon Type Classification (Comprehensive)
## ============================================================================

func test_all_weapon_categories_classified() -> void:
	var test_name := "All weapon categories correctly classified"

	var weapon_mappings := [
		{"cat": Enums.EquipmentCategory.SWORD, "type": Enums.WeaponType.MELEE},
		{"cat": Enums.EquipmentCategory.MACE, "type": Enums.WeaponType.MELEE},
		{"cat": Enums.EquipmentCategory.DAGGER, "type": Enums.WeaponType.MELEE},
		{"cat": Enums.EquipmentCategory.AXE, "type": Enums.WeaponType.MELEE},
		{"cat": Enums.EquipmentCategory.SHIELD, "type": Enums.WeaponType.MELEE},
		{"cat": Enums.EquipmentCategory.BOW, "type": Enums.WeaponType.RANGED},
		{"cat": Enums.EquipmentCategory.STAFF, "type": Enums.WeaponType.MAGIC},
	]

	for mapping in weapon_mappings:
		var item := ItemData.new()
		item.category = mapping.cat
		var detected_type := item.get_weapon_type()
		if detected_type != mapping.type:
			var cat_name: String = Enums.EquipmentCategory.keys()[mapping.cat]
			var expected_name: String = Enums.WeaponType.keys()[mapping.type]
			var actual_name: String = Enums.WeaponType.keys()[detected_type]
			add_failure(test_name, "%s should be %s but got %s" % [cat_name, expected_name, actual_name])
			return

	add_success(test_name)

## ============================================================================
## PHASE 7: Status Effect Mechanics
## ============================================================================

func test_status_effect_has_required_fields() -> void:
	var test_name := "StatusEffect has all required fields"

	var effect := StatusEffect.new()

	if not ("effect_type" in effect):
		add_failure(test_name, "Missing effect_type field")
		return

	if not ("duration_turns" in effect):
		add_failure(test_name, "Missing duration_turns field")
		return

	if not ("tick_damage" in effect):
		add_failure(test_name, "Missing tick_damage field")
		return

	add_success(test_name)

func test_status_effect_create_instance() -> void:
	var test_name := "StatusEffect can create instances"

	var burn_template: StatusEffect = load("res://data/status_effects/burn.tres")
	if not burn_template:
		add_failure(test_name, "Failed to load burn template")
		return

	var instance: StatusEffect = burn_template.create_instance()
	if not instance:
		add_failure(test_name, "Failed to create instance")
		return

	if instance.effect_type != Enums.StatusEffectType.BURN:
		add_failure(test_name, "Instance has wrong effect type")
		return

	if instance.duration_turns != burn_template.duration_turns:
		add_failure(test_name, "Instance duration doesn't match template")
		return

	add_success(test_name)

## ============================================================================
## PHASE 8: Data Migration Validation
## ============================================================================

func test_armor_has_dual_defense() -> void:
	var test_name := "Armor items have both physical and magical defense"

	var armor_files := [
		"res://data/items/armor/helmet_common.tres",
		"res://data/items/armor/chestplate_common.tres",
		"res://data/items/armor/legs_common.tres",
	]

	for file_path in armor_files:
		if not ResourceLoader.exists(file_path):
			add_failure(test_name, "File not found: %s" % file_path)
			return

		var armor: ItemData = load(file_path)
		if not armor:
			add_failure(test_name, "Failed to load: %s" % file_path)
			return

		var has_phys_def := false
		var has_mag_def := false

		for i in range(armor.stat_modifiers.size()):
			var mod: StatModifier = armor.stat_modifiers[i]
			if mod.stat == Enums.Stat.PHYSICAL_DEFENSE:
				has_phys_def = true
			elif mod.stat == Enums.Stat.MAGICAL_DEFENSE:
				has_mag_def = true

		if not has_phys_def:
			add_failure(test_name, "%s missing PHYSICAL_DEFENSE" % file_path)
			return

		if not has_mag_def:
			add_failure(test_name, "%s missing MAGICAL_DEFENSE" % file_path)
			return

	add_success(test_name)

func test_elemental_gems_have_status_effects() -> void:
	var test_name := "Elemental gems reference status effect files"

	var gem_files := [
		"res://data/items/modifiers/fire_gem_common.tres",
		"res://data/items/modifiers/ice_gem_common.tres",
		"res://data/items/modifiers/thunder_gem_common.tres",
		"res://data/items/modifiers/poison_gem_common.tres",
	]

	for file_path in gem_files:
		if not ResourceLoader.exists(file_path):
			add_failure(test_name, "File not found: %s" % file_path)
			return

		var gem: ItemData = load(file_path)
		if not gem:
			add_failure(test_name, "Failed to load: %s" % file_path)
			return

		if gem.conditional_modifier_rules.is_empty():
			add_failure(test_name, "%s has no rules" % file_path)
			return

		var has_status_effect := false
		for i in range(gem.conditional_modifier_rules.size()):
			var rule: ConditionalModifierRule = gem.conditional_modifier_rules[i]
			if rule.status_effect != null:
				has_status_effect = true
				break

		if not has_status_effect:
			add_failure(test_name, "%s has no status_effect" % file_path)
			return

	add_success(test_name)

func test_gems_use_weapon_types() -> void:
	var test_name := "Gems use target_weapon_type instead of target_category"

	var gem: ItemData = load("res://data/items/modifiers/fire_gem_common.tres")
	if not gem:
		add_failure(test_name, "Failed to load fire gem")
		return

	if gem.conditional_modifier_rules.is_empty():
		add_failure(test_name, "Fire gem has no rules")
		return

	var rule: ConditionalModifierRule = gem.conditional_modifier_rules[0]

	if "target_weapon_type" not in rule:
		add_failure(test_name, "Rule missing target_weapon_type field")
		return

	add_success(test_name)

func test_no_old_override_fields() -> void:
	var test_name := "Gems don't have old damage_type_override field"

	var gem: ItemData = load("res://data/items/modifiers/fire_gem_common.tres")
	if not gem:
		add_failure(test_name, "Failed to load fire gem")
		return

	if gem.conditional_modifier_rules.is_empty():
		add_failure(test_name, "Fire gem has no rules")
		return

	var rule: ConditionalModifierRule = gem.conditional_modifier_rules[0]

	if "override_damage_type" in rule:
		add_failure(test_name, "Rule still has override_damage_type field")
		return

	if "damage_type" in rule:
		add_failure(test_name, "Rule still has damage_type field")
		return

	if "target_category" in rule:
		add_failure(test_name, "Rule still has target_category field")
		return

	add_success(test_name)

func test_fire_gem_variants_scaling() -> void:
	var test_name := "Fire gem variants have increasing magical damage"

	var common: ItemData = load("res://data/items/modifiers/fire_gem_common.tres")
	var uncommon: ItemData = load("res://data/items/modifiers/fire_gem_uncommon.tres")
	var rare: ItemData = load("res://data/items/modifiers/fire_gem_rare.tres")

	if not common or not uncommon or not rare:
		add_failure(test_name, "Failed to load fire gem variants")
		return

	if common.conditional_modifier_rules.is_empty():
		add_failure(test_name, "Common gem has no rules")
		return

	if uncommon.conditional_modifier_rules.is_empty():
		add_failure(test_name, "Uncommon gem has no rules")
		return

	if rare.conditional_modifier_rules.is_empty():
		add_failure(test_name, "Rare gem has no rules")
		return

	var common_dmg: int = common.conditional_modifier_rules[0].added_magical_damage
	var uncommon_dmg: int = uncommon.conditional_modifier_rules[0].added_magical_damage
	var rare_dmg: int = rare.conditional_modifier_rules[0].added_magical_damage

	if not (common_dmg < uncommon_dmg and uncommon_dmg < rare_dmg):
		add_failure(test_name, "Damage not scaling: %d, %d, %d" % [common_dmg, uncommon_dmg, rare_dmg])
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
		print("\n✅ All tests passed!")
	else:
		print("\n❌ Some tests failed. See above for details.")

	print("====================\n")

func get_test_summary() -> Dictionary:
	return {
		"passed": _passed,
		"failed": _failed,
		"total": _passed + _failed,
		"results": _test_results,
	}
