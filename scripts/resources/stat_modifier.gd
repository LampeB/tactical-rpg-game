class_name StatModifier
extends Resource
## A single stat modification: e.g., +5 Physical Attack or +10% Speed.

@export var stat: Enums.Stat = Enums.Stat.MAX_HP
@export var modifier_type: Enums.ModifierType = Enums.ModifierType.FLAT
@export var value: float = 0.0


static func get_stat_display_name(s: Enums.Stat) -> String:
	match s:
		Enums.Stat.MAX_HP: return "Max HP"
		Enums.Stat.MAX_MP: return "Max MP"
		Enums.Stat.SPEED: return "Speed"
		Enums.Stat.LUCK: return "Luck"
		Enums.Stat.PHYSICAL_ATTACK: return "Phys Atk"
		Enums.Stat.PHYSICAL_DEFENSE: return "Phys Def"
		Enums.Stat.MAGICAL_ATTACK: return "Mag Atk"
		Enums.Stat.MAGICAL_DEFENSE: return "Mag Def"
		Enums.Stat.CRITICAL_RATE: return "Crit Rate"
		Enums.Stat.CRITICAL_DAMAGE: return "Crit Dmg"
		Enums.Stat.PHYSICAL_SCALING: return "Phys Scaling"
		Enums.Stat.MAGICAL_SCALING: return "Mag Scaling"
	return "Unknown"


func get_description() -> String:
	var stat_name: String = StatModifier.get_stat_display_name(stat)
	var prefix := "+" if value >= 0 else ""
	if modifier_type == Enums.ModifierType.FLAT:
		return "%s%d %s" % [prefix, int(value), stat_name]
	else:
		return "%s%d%% %s" % [prefix, int(value), stat_name]
