extends GutTest
## Unit tests for crafting recipes.
##
## Recipes live inside CraftingStationData.tres files in data/crafting/.
## We don't test the crafting UI flow — instead we verify recipe data
## integrity: each recipe's result_item_id resolves to a real ItemData,
## ingredients are well-formed, ids are unique.

const STATIONS_DIR := "res://data/crafting/"


func _load_all_stations() -> Array:
	var result: Array = []
	var dir := DirAccess.open(STATIONS_DIR)
	if not dir:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var resource: Resource = load(STATIONS_DIR + entry)
			if resource is CraftingStationData:
				result.append(resource)
		entry = dir.get_next()
	dir.list_dir_end()
	return result


func test_at_least_one_crafting_station_exists() -> void:
	var stations: Array = _load_all_stations()
	assert_gt(stations.size(), 0,
		"Expected at least one CraftingStationData in data/crafting/")


func test_each_station_has_id_and_display_name() -> void:
	for station in _load_all_stations():
		assert_ne(station.id, "",
			"CraftingStationData id should not be empty")
		assert_ne(station.display_name, "",
			"Station '%s' has no display_name" % station.id)


func test_every_recipe_result_item_id_resolves() -> void:
	# This is the high-value cross-check — catches typos and renamed items
	# at the recipe level, not just the .tres file level.
	for station in _load_all_stations():
		for recipe in station.recipes:
			if recipe.result_item_id == "":
				continue  # Recipe with no result_item_id is malformed; flagged below
			var item: ItemData = ItemDatabase.get_item(recipe.result_item_id)
			assert_not_null(item,
				"Recipe '%s' on station '%s' references unknown result_item_id '%s'" % [
					recipe.id, station.id, recipe.result_item_id
				])


func test_every_recipe_has_result_item_id() -> void:
	for station in _load_all_stations():
		for recipe in station.recipes:
			assert_ne(recipe.result_item_id, "",
				"Recipe '%s' on station '%s' has empty result_item_id" % [
					recipe.id, station.id
				])


func test_every_recipe_has_at_least_one_ingredient() -> void:
	for station in _load_all_stations():
		for recipe in station.recipes:
			assert_gt(recipe.ingredients.size(), 0,
				"Recipe '%s' has zero ingredients (would auto-craft)" % recipe.id)


func test_recipe_ids_unique_within_station() -> void:
	for station in _load_all_stations():
		var seen: Dictionary = {}
		for recipe in station.recipes:
			assert_false(seen.has(recipe.id),
				"Duplicate recipe id '%s' in station '%s'" % [recipe.id, station.id])
			seen[recipe.id] = true
