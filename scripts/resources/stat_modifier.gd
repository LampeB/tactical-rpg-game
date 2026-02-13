class_name StatModifier
extends Resource
## A single stat modification: e.g., +5 Physical Attack or +10% Speed.

@export var stat: Enums.Stat = Enums.Stat.MAX_HP
@export var modifier_type: Enums.ModifierType = Enums.ModifierType.FLAT
@export var value: float = 0.0

func get_description() -> String:
	var stat_name: String = Enums.Stat.keys()[stat].replace("_", " ").to_pascal_case()
	if modifier_type == Enums.ModifierType.FLAT:
		var sign := "+" if value >= 0 else ""
		return "%s%d %s" % [sign, int(value), stat_name]
	else:
		var sign := "+" if value >= 0 else ""
		return "%s%d%% %s" % [sign, int(value * 100), stat_name]
