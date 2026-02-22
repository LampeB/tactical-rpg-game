class_name PassiveNodeData
extends Resource
## Definition of a single node in a character's passive skill tree.

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Bonuses")
## Stat bonuses applied when this node is unlocked (reuses StatModifier).
@export var stat_modifiers: Array = [] ## of StatModifier
## Special combat effect granted by this node (e.g. "lifesteal_5", "counter_attack").
@export var special_effect_id: String = ""

@export_group("Cost & Requirements")
@export var gold_cost: int = 50
## IDs of nodes that must be unlocked before this one.
@export var prerequisites: Array[String] = []
## 0 = ALL prerequisites required (default), 1 = ANY one prerequisite suffices.
@export var prerequisite_mode: int = 0

@export_group("UI")
## Position in the tree canvas (pixels from top-left).
@export var position: Vector2 = Vector2.ZERO
