class_name CraftingRecipeData
extends Resource
## Data resource for a single crafting recipe.
## unlock_flag: if non-empty, the recipe is only visible after GameManager.get_flag(unlock_flag) is true.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var ingredients: Array[CraftingIngredient] = []
@export var result_item_id: String = ""
@export var unlock_flag: String = ""  ## Empty = always known. Non-empty = requires this flag to be set.
