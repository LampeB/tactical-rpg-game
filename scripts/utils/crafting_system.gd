class_name CraftingSystem
extends RefCounted
## Stateless utility for crafting logic.
## Mirrors BackpackUpgradeSystem — all methods are static, no scene tree dependency.
## This is a class_name script; it CANNOT reference autoloads directly.
## Callers must pass party, story_flags, etc. as arguments.


## Returns true if the item satisfies the ingredient requirement:
## its ID starts with the ingredient's family AND its rarity >= the minimum.
static func item_matches(item: ItemData, ingredient: CraftingIngredient) -> bool:
	return item.id.begins_with(ingredient.item_family) \
		and int(item.rarity) >= int(ingredient.min_rarity)


## Returns true if the recipe is visible / unlocked.
## If the recipe has no unlock_flag it is always unlocked.
## Otherwise the flag must be present (truthy) in story_flags.
static func is_recipe_unlocked(recipe: CraftingRecipeData, story_flags: Dictionary) -> bool:
	return recipe.unlock_flag.is_empty() or story_flags.get(recipe.unlock_flag, false) == true


## Returns true if the party owns enough matching items (across all grids + stash)
## to satisfy every ingredient in the recipe.
static func can_craft(recipe: CraftingRecipeData, party: Party) -> bool:
	var pool: Array[ItemData] = []
	for stash_item in party.stash:
		pool.append(stash_item)
	for char_id: String in party.grid_inventories:
		var grid: GridInventory = party.grid_inventories[char_id]
		for placed in grid.placed_items:
			pool.append(placed.item_data)
	for ingredient in recipe.ingredients:
		var matched: int = 0
		var remaining: Array[ItemData] = []
		for item in pool:
			if matched < ingredient.quantity and item_matches(item, ingredient):
				matched += 1
			else:
				remaining.append(item)
		pool = remaining
		if matched < ingredient.quantity:
			return false
	return true


## Consume the items currently sitting in the craft-slot nodes.
## Each slot's assigned_item is identity-matched (is_same) against items in
## the party's stash and grid inventories, then removed.
## Returns the list of character IDs whose inventories were modified
## (so the caller can emit the appropriate signals).
static func consume_ingredients(slot_items: Array[ItemData], party: Party) -> Array[String]:
	var changed_characters: Array[String] = []
	for item in slot_items:
		if item == null:
			continue
		var removed: bool = false

		for stash_item in party.stash:
			if is_same(stash_item, item):
				party.remove_from_stash(item)
				removed = true
				break

		if not removed:
			for char_id: String in party.grid_inventories:
				if removed:
					break
				var grid: GridInventory = party.grid_inventories[char_id]
				for placed in grid.placed_items:
					if is_same(placed.item_data, item):
						grid.remove_item(placed)
						if not changed_characters.has(char_id):
							changed_characters.append(char_id)
						removed = true
						break
	return changed_characters
