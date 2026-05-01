extends GutTest
## Unit tests for CombatEntity damage/heal/MP/status methods.
## Pinning these prevents subtle regressions in combat math (overflow,
## armor mis-application, dead-state edge cases).


var _entity: CombatEntity


func before_each() -> void:
	# Build a fresh enemy entity so tests aren't entangled with player setup.
	var enemy_data: EnemyData = load("res://data/enemies/goblin.tres")
	_entity = CombatEntity.from_enemy(enemy_data)


# === take_damage ===

func test_take_damage_reduces_current_hp() -> void:
	var hp_before: int = _entity.current_hp
	_entity.take_damage(5, Enums.DamageType.PHYSICAL)
	assert_eq(_entity.current_hp, hp_before - 5,
		"take_damage(5) should reduce HP by 5")


func test_take_damage_returns_actual_amount_dealt() -> void:
	var actual: int = _entity.take_damage(7, Enums.DamageType.PHYSICAL)
	assert_eq(actual, 7, "Returned actual damage should equal the amount dealt")


func test_take_damage_caps_at_current_hp() -> void:
	# Hit for more than max HP — should kill, not return more than current
	var hp_before: int = _entity.current_hp
	var actual: int = _entity.take_damage(99999, Enums.DamageType.PHYSICAL)
	assert_eq(actual, hp_before, "Excessive damage should cap at current_hp")
	assert_eq(_entity.current_hp, 0)
	assert_true(_entity.is_dead, "Entity at 0 HP should be marked is_dead")


func test_take_damage_does_not_go_below_zero() -> void:
	_entity.take_damage(99999, Enums.DamageType.PHYSICAL)
	assert_eq(_entity.current_hp, 0, "current_hp should clamp to 0")


func test_physical_armor_absorbs_first() -> void:
	_entity.physical_armor = 10
	var hp_before: int = _entity.current_hp
	_entity.take_damage(5, Enums.DamageType.PHYSICAL)
	assert_eq(_entity.current_hp, hp_before, "5 damage absorbed by armor; HP unchanged")
	assert_eq(_entity.physical_armor, 5, "Armor reduced from 10 to 5")


func test_physical_armor_partial_absorption() -> void:
	_entity.physical_armor = 3
	var hp_before: int = _entity.current_hp
	_entity.take_damage(10, Enums.DamageType.PHYSICAL)
	assert_eq(_entity.physical_armor, 0, "All 3 armor consumed")
	assert_eq(_entity.current_hp, hp_before - 7, "Remaining 7 damage hits HP")


func test_spirit_shield_absorbs_magical() -> void:
	_entity.spirit_shield = 10
	var hp_before: int = _entity.current_hp
	_entity.take_damage(5, Enums.DamageType.MAGICAL)
	assert_eq(_entity.current_hp, hp_before, "Magical damage absorbed by spirit_shield")
	assert_eq(_entity.spirit_shield, 5)


func test_armor_does_not_absorb_magical() -> void:
	_entity.physical_armor = 10
	_entity.spirit_shield = 0
	var hp_before: int = _entity.current_hp
	_entity.take_damage(5, Enums.DamageType.MAGICAL)
	assert_eq(_entity.physical_armor, 10, "Physical armor should not absorb magical damage")
	assert_eq(_entity.current_hp, hp_before - 5, "Magical damage hits HP directly")


func test_shield_hp_absorbs_either_type() -> void:
	_entity.shield_hp = 10
	var hp_before: int = _entity.current_hp
	_entity.take_damage(5, Enums.DamageType.MAGICAL)
	assert_eq(_entity.current_hp, hp_before, "Generic shield absorbs magical")
	assert_eq(_entity.shield_hp, 5)


# === heal ===

func test_heal_increases_hp() -> void:
	_entity.current_hp = 1
	var actual: int = _entity.heal(20)
	assert_eq(_entity.current_hp, 21)
	assert_eq(actual, 20, "Returned actual healing should equal amount when below cap")


func test_heal_caps_at_max_hp() -> void:
	_entity.current_hp = _entity.max_hp - 5
	var actual: int = _entity.heal(99999)
	assert_eq(_entity.current_hp, _entity.max_hp, "Heal should not exceed max_hp")
	assert_eq(actual, 5, "Returned actual = amount needed to reach cap, not requested amount")


# === MP ===

func test_spend_mp_reduces_current_mp() -> void:
	_entity.current_mp = 50
	_entity.spend_mp(15)
	assert_eq(_entity.current_mp, 35)


func test_spend_mp_clamps_to_zero() -> void:
	_entity.current_mp = 5
	_entity.spend_mp(100)
	assert_eq(_entity.current_mp, 0, "spend_mp should clamp to 0, not go negative")


func test_restore_mp_increases_then_caps() -> void:
	_entity.current_mp = 0
	_entity.max_mp = 30
	var actual: int = _entity.restore_mp(50)
	assert_eq(_entity.current_mp, 30)
	assert_eq(actual, 30, "restore_mp returns the amount needed to reach max")
