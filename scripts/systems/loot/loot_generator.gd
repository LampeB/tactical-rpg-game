class_name LootGenerator
## Static utility for rolling loot from LootTable resources.
## Used after combat victories and when opening chests.
##
## == How It Works ==
## Each LootEntry = one potential item drop.
## Want an item to drop multiple times? Add it to the pool multiple times!
##
## Example:
##   entries = [
##     {item: Potion, drop_chance: 0.8},  # 80% for first potion
##     {item: Potion, drop_chance: 0.8},  # 80% for second potion
##     {item: Sword, drop_chance: 0.1}    # 10% for sword
##   ]
##   Result: 0-2 potions (each rolled independently), 0-1 sword
##
## == Two Systems ==
##
## 1. DROP CHANCE (Recommended):
##    Each entry has independent drop chance (0.0 to 1.0).
##    - 0.1 = 10%, 0.5 = 50%, 1.0 = 100% guaranteed
##    All entries rolled separately.
##
## 2. WEIGHTED ROLLS (Legacy):
##    Uses weights, rolls X times, picks from pool.
##    Only used when all entries have drop_chance = 0.
##
## == Gold Drops ==
## Gold is separate (NOT in loot tables):
## - EnemyData.gold_reward (per enemy)
## - EncounterData.bonus_gold (bonus for clearing)


## Generate loot from an encounter (uses override table or per-enemy tables).
static func generate_loot(encounter: EncounterData, enemies: Array) -> Array:
	var items: Array = []

	if encounter.override_loot_table:
		items.append_array(roll_table(encounter.override_loot_table))
	else:
		for i in range(enemies.size()):
			var entity: CombatEntity = enemies[i]
			if entity.enemy_data and entity.enemy_data.loot_table:
				items.append_array(roll_table(entity.enemy_data.loot_table))

	return items



## Roll a single loot table and return the resulting items.
## Used by the battle system (via generate_loot) and chest system directly.
static func roll_table(table: LootTable) -> Array:
	var items: Array = []

	# Guaranteed drops always included
	for i in range(table.guaranteed_drops.size()):
		var item: ItemData = table.guaranteed_drops[i]
		if item:
			items.append(item)

	if table.entries.is_empty():
		return items

	# Check if table uses drop_chance system (any entry has drop_chance > 0)
	var uses_drop_chance: bool = false
	for i in range(table.entries.size()):
		var entry: LootEntry = table.entries[i]
		if entry.drop_chance > 0.0:
			uses_drop_chance = true
			break

	if uses_drop_chance:
		# Independent drop chance system - roll each item separately
		items.append_array(_roll_independent_chances(table.entries))
	else:
		# Weighted random roll system - old behavior
		items.append_array(_roll_weighted(table.entries, table.roll_count))

	return items


## Independent drop chance system: each entry is rolled separately.
## Each successful entry drops exactly 1 item.
static func _roll_independent_chances(entries: Array) -> Array:
	var items: Array = []

	for i in range(entries.size()):
		var entry: LootEntry = entries[i]
		if not entry.item:
			continue

		# Roll against drop chance - if successful, add 1 item
		if randf() <= entry.drop_chance:
			items.append(entry.item)

	return items


## Weighted random roll system: roll X times, pick from pool based on weights.
## Each successful roll adds exactly 1 item.
static func _roll_weighted(entries: Array, roll_count: int) -> Array:
	var items: Array = []

	var total_weight: float = 0.0
	for wi in range(entries.size()):
		var w_entry: LootEntry = entries[wi]
		total_weight += w_entry.weight

	if total_weight <= 0.0:
		return items

	for _roll in range(roll_count):
		var roll: float = randf() * total_weight
		var cumulative: float = 0.0
		for i in range(entries.size()):
			var entry: LootEntry = entries[i]
			cumulative += entry.weight
			if roll <= cumulative:
				if entry.item:
					items.append(entry.item)
				break

	return items
