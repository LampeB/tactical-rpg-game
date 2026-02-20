class_name ToolModifierState
extends RefCounted
## Runtime state tracking conditional modifiers affecting a single ACTIVE_TOOL.
## Not serialized - regenerated from placement data on each grid refresh.

var tool_placed_item: GridInventory.PlacedItem
var active_modifiers: Array = []  ## of {gem: PlacedItem, rule: ConditionalModifierRule}
var aggregate_stats: Dictionary = {}  ## Enums.Stat -> float
var damage_type_override: Variant = null  ## Enums.DamageType or null
var conditional_skills: Array = []  ## of SkillData
