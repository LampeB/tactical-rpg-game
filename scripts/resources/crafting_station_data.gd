class_name CraftingStationData
extends Resource
## Data resource for a crafting station (e.g. a blacksmith).
## Loaded directly from res://data/crafting/<id>.tres by CraftingUI.

@export var id: String = ""
@export var display_name: String = ""   ## Shown as the window title, e.g. "Aldric's Forge".
@export var recipes: Array[CraftingRecipeData] = []
