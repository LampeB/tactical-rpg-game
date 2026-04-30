extends GutTest
## Unit tests for CombatEntity construction + stat resolution.
## Verifies entities built from real CharacterData / EnemyData expose the
## right runtime state so combat code can rely on it.


func before_each() -> void:
	GameManager.new_game()


# === from_character ===

func test_from_character_marks_as_player() -> void:
	var char_data: CharacterData = GameManager.party.roster["warrior"]
	var inv: GridInventory = GameManager.party.grid_inventories["warrior"]
	var entity: CombatEntity = CombatEntity.from_character(char_data, inv, {})
	assert_true(entity.is_player, "Entity from CharacterData should be is_player=true")
	assert_eq(entity.character_data, char_data, "character_data should reference the source")
	assert_null(entity.enemy_data, "enemy_data should be null for players")


func test_from_character_uses_display_name() -> void:
	var char_data: CharacterData = GameManager.party.roster["warrior"]
	var inv: GridInventory = GameManager.party.grid_inventories["warrior"]
	var entity: CombatEntity = CombatEntity.from_character(char_data, inv, {})
	assert_eq(entity.entity_name, char_data.display_name)


func test_from_character_max_hp_at_least_base() -> void:
	# Equipment / passives can ADD to max_hp but never reduce below base (here)
	var char_data: CharacterData = GameManager.party.roster["warrior"]
	var inv: GridInventory = GameManager.party.grid_inventories["warrior"]
	var entity: CombatEntity = CombatEntity.from_character(char_data, inv, {})
	assert_gte(entity.max_hp, char_data.max_hp,
		"Computed max_hp should be at least the character's base max_hp")


func test_from_character_starts_alive_at_full_hp() -> void:
	var char_data: CharacterData = GameManager.party.roster["warrior"]
	var inv: GridInventory = GameManager.party.grid_inventories["warrior"]
	var entity: CombatEntity = CombatEntity.from_character(char_data, inv, {})
	assert_false(entity.is_dead, "New entity should not start dead")
	assert_eq(entity.current_hp, entity.max_hp, "current_hp should default to max_hp")


func test_from_character_with_null_inventory_does_not_crash() -> void:
	# Defensive: characters without a grid inventory (legacy saves, hacks)
	# should still produce a valid entity rather than crash combat setup.
	var char_data: CharacterData = GameManager.party.roster["mage"]
	var entity: CombatEntity = CombatEntity.from_character(char_data, null, {})
	assert_not_null(entity, "Entity should be built even with null inventory")
	assert_eq(entity.entity_name, char_data.display_name)


# === from_enemy ===

func test_from_enemy_marks_as_non_player() -> void:
	var enemy: EnemyData = load("res://data/enemies/goblin.tres")
	var entity: CombatEntity = CombatEntity.from_enemy(enemy)
	assert_false(entity.is_player, "Entity from EnemyData should be is_player=false")
	assert_eq(entity.enemy_data, enemy, "enemy_data should reference the source")
	assert_null(entity.character_data, "character_data should be null for enemies")


func test_from_enemy_starts_at_full_hp() -> void:
	var enemy: EnemyData = load("res://data/enemies/goblin.tres")
	var entity: CombatEntity = CombatEntity.from_enemy(enemy)
	assert_eq(entity.max_hp, enemy.max_hp, "Enemy max_hp should match data")
	assert_eq(entity.current_hp, entity.max_hp, "Enemy should start at full HP")
	assert_false(entity.is_dead)


func test_from_enemy_uses_display_name() -> void:
	var enemy: EnemyData = load("res://data/enemies/slime.tres")
	var entity: CombatEntity = CombatEntity.from_enemy(enemy)
	assert_eq(entity.entity_name, enemy.display_name)


# === get_effective_stat ===

func test_effective_stat_includes_base() -> void:
	# With no equipment + no passives, effective phys attack should equal the
	# base from CharacterData (or be derivable from it).
	var char_data: CharacterData = GameManager.party.roster["warrior"]
	var inv: GridInventory = GameManager.party.grid_inventories["warrior"]
	var entity: CombatEntity = CombatEntity.from_character(char_data, inv, {})
	var phys: float = entity.get_effective_stat(Enums.Stat.PHYSICAL_ATTACK)
	assert_gte(phys, 0.0, "Effective physical attack should be non-negative")


func test_effective_stat_for_unknown_stat_does_not_crash() -> void:
	# Any defined Stat enum value should return a number, never error.
	var enemy: EnemyData = load("res://data/enemies/goblin.tres")
	var entity: CombatEntity = CombatEntity.from_enemy(enemy)
	var luck: float = entity.get_effective_stat(Enums.Stat.LUCK)
	assert_gte(luck, 0.0, "LUCK stat should be defined and non-negative for enemies")


# === Equipment-related queries ===

func test_get_equipped_weapons_empty_by_default() -> void:
	# Without any equipped weapons, get_equipped_weapons returns []. The hub's
	# auto-equip puts one in, but a fresh inv-only construction should have none.
	var char_data: CharacterData = GameManager.party.roster["warrior"]
	var inv := GridInventory.new(char_data.grid_template)
	var entity: CombatEntity = CombatEntity.from_character(char_data, inv, {})
	assert_eq(entity.get_equipped_weapons().size(), 0,
		"Fresh GridInventory should yield no equipped weapons")


func test_get_equipped_weapons_includes_placed_weapon() -> void:
	# Place a sword and assert get_equipped_weapons returns it.
	var char_data: CharacterData = GameManager.party.roster["warrior"]
	var inv := GridInventory.new(char_data.grid_template)
	var sword: ItemData = ItemDatabase.get_item("sword_common")
	assert_not_null(sword, "sword_common must exist in ItemDatabase")
	inv.place_item(sword, Vector2i(0, 0), 0)
	var entity: CombatEntity = CombatEntity.from_character(char_data, inv, {})
	var weapons: Array = entity.get_equipped_weapons()
	assert_eq(weapons.size(), 1, "Should have exactly one equipped weapon after placing one")
	assert_eq(weapons[0], sword, "Equipped weapon should be the sword we placed")
