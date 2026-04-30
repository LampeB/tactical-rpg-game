class_name RandomEncounterGenerator
extends RefCounted
## Builds an in-memory EncounterData with random enemies pulled from data/enemies/.
## Used by missions that don't specify a fixed encounter path.

const ENEMIES_DIR := "res://data/enemies/"


static func generate(
	min_enemies: int = 1,
	max_enemies: int = 5,
	display_name: String = "Random Encounter",
	bonus_gold: int = 0
) -> EncounterData:
	var enemy_pool: Array[EnemyData] = _load_all_enemies()
	if enemy_pool.is_empty():
		push_error("RandomEncounterGenerator: no enemies found in %s" % ENEMIES_DIR)
		return null

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var lo: int = max(1, min_enemies)
	var hi: int = max(lo, max_enemies)
	var count: int = rng.randi_range(lo, hi)

	var encounter := EncounterData.new()
	encounter.id = "random_%d" % rng.randi()
	encounter.display_name = display_name
	encounter.can_flee = true
	encounter.bonus_gold = bonus_gold

	var enemies: Array[EnemyData] = []
	for i in range(count):
		var enemy: EnemyData = enemy_pool[rng.randi() % enemy_pool.size()]
		enemies.append(enemy)
	encounter.enemies = enemies

	return encounter


static func _load_all_enemies() -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	var dir := DirAccess.open(ENEMIES_DIR)
	if not dir:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource: Resource = load(ENEMIES_DIR + file_name)
			if resource is EnemyData:
				result.append(resource)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result
