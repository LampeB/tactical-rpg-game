class_name EnemyData
extends Resource
## Definition of an enemy type.

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var sprite: Texture2D

@export_group("Stats")
@export var max_hp: int = 50
@export var speed: int = 8
@export var physical_attack: int = 8
@export var physical_defense: int = 5
@export var magical_attack: int = 5
@export var magical_defense: int = 5

@export_group("3D Model")
## Custom 3D model scene. Null = CSG placeholder from CSGCharacterFactory.
@export var model_scene: PackedScene
## Scale multiplier for the 3D model.
@export var model_scale: float = 1.0
## CSG placeholder tint color.
@export var model_color: Color = Color(0.8, 0.2, 0.2)

@export_group("Combat")
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
@export var skills: Array[SkillData] = []
## Gold rewarded on defeat.
@export var gold_reward: int = 10

@export_group("Loot")
## Loot table used when this enemy is defeated.
@export var loot_table: LootTable

func get_base_stat(stat: Enums.Stat) -> int:
	match stat:
		Enums.Stat.MAX_HP: return max_hp
		Enums.Stat.SPEED: return speed
		Enums.Stat.PHYSICAL_ATTACK: return physical_attack
		Enums.Stat.PHYSICAL_DEFENSE: return physical_defense
		Enums.Stat.MAGICAL_ATTACK: return magical_attack
		Enums.Stat.MAGICAL_DEFENSE: return magical_defense
	return 0
