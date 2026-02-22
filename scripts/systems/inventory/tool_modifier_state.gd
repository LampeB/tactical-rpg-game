class_name ToolModifierState
extends RefCounted
## Runtime state tracking conditional modifiers affecting a single ACTIVE_TOOL.
## Not serialized - regenerated from placement data on each grid refresh.

var tool_placed_item: GridInventory.PlacedItem
var active_modifiers: Array = []  ## of {gem: PlacedItem, rule: ConditionalModifierRule}
var aggregate_stats: Dictionary = {}  ## Enums.Stat -> float
var status_effect_chance: float = 0.0  ## Chance to apply status effect (0.0 to 1.0)
var status_effect_type: Variant = null  ## Enums.StatusEffectType or null
var conditional_skills: Array = []  ## of SkillData
var force_aoe: bool = false  ## If true, attacks with this tool hit all enemies
var hp_cost_per_attack: int = 0  ## HP lost by the attacker on each basic attack
