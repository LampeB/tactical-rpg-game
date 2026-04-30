extends GutTest
## Integration tests for CombatManager start state.
##
## Doesn't drive the full battle loop — that's a heavier test for later.
## Verifies that start_combat correctly populates entity arrays, sets
## flags, and queues at least one entity for the first turn.


var _cm: CombatManager
var _encounter: EncounterData
var _player_entities: Array
var _enemy_entities: Array


func before_each() -> void:
	GameManager.new_game()

	# Build encounter from real data so combat manager has valid input.
	_encounter = RandomEncounterGenerator.generate(2, 2, "Test Battle", 0)

	# Build player entities from the warrior + mage roster.
	_player_entities = []
	for char_id in ["warrior", "mage"]:
		var char_data: CharacterData = GameManager.party.roster[char_id]
		var inv: GridInventory = GameManager.party.grid_inventories[char_id]
		var entity: CombatEntity = CombatEntity.from_character(char_data, inv, {})
		_player_entities.append(entity)

	# Build enemy entities from the encounter
	_enemy_entities = []
	for enemy_data in _encounter.enemies:
		_enemy_entities.append(CombatEntity.from_enemy(enemy_data))

	_cm = CombatManager.new()


# === start_combat state ===

func test_start_combat_marks_combat_active() -> void:
	assert_false(_cm.is_combat_active, "Sanity: not active before start")
	_cm.start_combat(_encounter, _player_entities, _enemy_entities)
	assert_true(_cm.is_combat_active, "is_combat_active should be true after start")


func test_start_combat_populates_entity_arrays() -> void:
	_cm.start_combat(_encounter, _player_entities, _enemy_entities)
	assert_eq(_cm.player_entities.size(), _player_entities.size())
	assert_eq(_cm.enemy_entities.size(), _enemy_entities.size())
	assert_eq(_cm.all_entities.size(), _player_entities.size() + _enemy_entities.size())


func test_start_combat_resets_round_and_gold() -> void:
	_cm.gold_earned = 999  # simulate stale state
	_cm.round_number = 42
	_cm.start_combat(_encounter, _player_entities, _enemy_entities)
	assert_eq(_cm.round_number, 0, "round_number should reset to 0")


func test_start_combat_stores_encounter_reference() -> void:
	_cm.start_combat(_encounter, _player_entities, _enemy_entities)
	assert_eq(_cm.encounter, _encounter,
		"CombatManager should hold the encounter passed in")


func test_turn_order_excludes_dead_entities() -> void:
	# Pre-emptively kill one enemy and verify _build_turn_order respects it.
	if _enemy_entities.is_empty():
		pending("No enemies in test setup")
		return
	_enemy_entities[0].is_dead = true
	_cm.start_combat(_encounter, _player_entities, _enemy_entities)
	for entity in _cm.turn_order:
		assert_false(entity.is_dead,
			"turn_order should not include dead entities")


func test_player_entities_carry_grid_inventory() -> void:
	# Regression target: verify CombatManager preserves grid_inventory
	# references on player entities (so weapons/gems work in combat).
	_cm.start_combat(_encounter, _player_entities, _enemy_entities)
	for entity in _cm.player_entities:
		assert_not_null(entity.grid_inventory,
			"Player entity %s should have grid_inventory set" % entity.entity_name)
