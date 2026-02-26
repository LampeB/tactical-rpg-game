class_name CraftingIngredient
extends Resource
## A single ingredient slot in a crafting recipe.
## Accepts any item whose ID starts with item_family and whose rarity >= min_rarity.

@export var item_family: String = ""                          ## ID prefix: "sword", "bow", "fire_gem", etc.
@export var min_rarity: Enums.Rarity = Enums.Rarity.COMMON   ## Minimum rarity; higher rarities also accepted.
@export var quantity: int = 1                                  ## How many of this ingredient are needed.
