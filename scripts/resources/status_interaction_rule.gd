class_name StatusInteractionRule
extends Resource
## Defines what happens when two status effects interact.
## Example: Burn + Ice = Cancel, Oil + Fire = Amplify damage

@export var status_a: StatusEffectData
@export var status_b: StatusEffectData
@export var interaction: Enums.StatusInteraction = Enums.StatusInteraction.CANCEL

## For AMPLIFY: damage multiplier applied.
@export var amplify_multiplier: float = 2.0

## For TRANSFORM: what both statuses become.
@export var transform_into: StatusEffectData

## For TRIGGER: immediate damage dealt.
@export var trigger_damage: int = 0
@export var trigger_damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
