class_name StatusEffect
extends Resource
## Represents a status effect that can be applied to combat entities.

@export var effect_type: Enums.StatusEffectType = Enums.StatusEffectType.BURN
@export var duration_turns: int = 3
@export var tick_damage: int = 0  ## For Burn/Poison - base damage per stack per turn
@export var max_tick_damage: int = 0  ## Per-turn damage cap (0 = uncapped). damage = min(stacks * tick_damage, max_tick_damage)
@export var stat_modifier: StatModifier = null  ## For Chilled (speed reduction)
@export var skip_turn_chance: float = 0.0  ## For Shocked - chance to skip turn (0.0 to 1.0)

## Creates a copy of this status effect with full duration
func create_instance() -> StatusEffect:
	var instance := StatusEffect.new()
	instance.effect_type = effect_type
	instance.duration_turns = duration_turns
	instance.tick_damage = tick_damage
	instance.max_tick_damage = max_tick_damage
	instance.stat_modifier = stat_modifier
	instance.skip_turn_chance = skip_turn_chance
	return instance
