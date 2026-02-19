class_name LootGenerator
## Static utility for rolling loot from LootTable resources.
## Used after combat victories and when opening chests.


## Generate loot from an encounter (uses override table or per-enemy tables).
static func generate_loot(encounter: EncounterData, enemies: Array) -> Array:
	var items: Array = []

	if encounter.override_loot_table:
		items.append_array(_roll_table(encounter.override_loot_table))
	else:
		for i in range(enemies.size()):
			var entity = enemies[i]
			if entity.enemy_data and entity.enemy_data.loot_table:
				items.append_array(_roll_table(entity.enemy_data.loot_table))

	return items


## Generate loot from a standalone table (for chests, events, etc.).
static func generate_from_table(table: LootTable) -> Array:
	return _roll_table(table)


static func _roll_table(table: LootTable) -> Array:
	var items: Array = []

	# Guaranteed drops always included
	for i in range(table.guaranteed_drops.size()):
		var item: ItemData = table.guaranteed_drops[i]
		if item:
			items.append(item)

	# Weighted random rolls
	if table.entries.is_empty():
		return items

	var total_weight: float = 0.0
	for i in range(table.entries.size()):
		var entry: LootEntry = table.entries[i]
		total_weight += entry.weight

	if total_weight <= 0.0:
		return items

	for _roll in range(table.roll_count):
		var roll: float = randf() * total_weight
		var cumulative: float = 0.0
		for i in range(table.entries.size()):
			var entry: LootEntry = table.entries[i]
			cumulative += entry.weight
			if roll <= cumulative:
				if entry.item:
					var count: int = entry.min_count
					if entry.max_count > entry.min_count:
						count = randi_range(entry.min_count, entry.max_count)
					for _c in range(count):
						items.append(entry.item)
				break

	return items
