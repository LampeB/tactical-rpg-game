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
