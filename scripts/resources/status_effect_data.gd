class_name StatusEffectData
extends Resource
## Definition of a status effect (poison, burn, buff, debuff, etc.)

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Classification")
@export var category: Enums.StatusCategory = Enums.StatusCategory.DAMAGE_OVER_TIME

@export_group("Duration")
## Number of turns this effect lasts. -1 = permanent until removed.
@export var duration: int = 3
## Whether duration ticks down at turn start (true) or turn end (false).
@export var tick_on_start: bool = true

@export_group("Effects")
## Damage per tick (for DoT effects).
@export var tick_damage: int = 0
@export var tick_damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
## Stat modifications while active.
@export var stat_modifiers: Array = [] ## of StatModifier
## Speed multiplier (for freeze/slow/haste). 1.0 = normal.
@export var speed_multiplier: float = 1.0
## Damage taken multiplier (for vulnerability/resistance). 1.0 = normal.
@export var damage_taken_multiplier: float = 1.0

@export_group("Restrictions")
## If true, the affected entity cannot act.
@export var prevents_action: bool = false
## If true, the affected entity cannot use skills.
@export var prevents_skills: bool = false

@export_group("Stacking")
## Whether multiple instances can stack.
@export var stackable: bool = false
## Maximum stacks if stackable.
@export var max_stacks: int = 1
