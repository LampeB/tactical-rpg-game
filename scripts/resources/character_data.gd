class_name CharacterData
extends Resource
## Definition of a character archetype (base stats, grid template, etc.)

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""
@export var character_class: String = ""  ## Class name (e.g., "Rogue", "Warrior", "Mage")
@export_multiline var description: String = ""
@export var portrait: Texture2D
@export var sprite: Texture2D

@export_group("Base Stats")
@export var max_hp: int = 100
@export var max_mp: int = 30
@export var speed: int = 10
@export var luck: int = 5
@export var physical_attack: int = 10
@export var physical_defense: int = 10
@export var magical_attack: int = 10
@export var magical_defense: int = 10

@export_group("Inventory")
## The grid template this character uses for inventory (fallback when backpack_tiers is empty).
@export var grid_template: GridTemplate
## Ordered array of BackpackTierConfig (index 0 = Tier 1 … index 5 = Tier 6).
## When populated, this drives inventory size instead of grid_template directly.
@export var backpack_tiers: Array[BackpackTierConfig] = []

@export_group("Passive Tree")
## Node IDs in the unified skill tree where this character can start unlocking.
@export var starting_passive_nodes: Array[String] = []

@export_group("3D Model")
## Custom 3D model scene. Null = CSG placeholder from CSGCharacterFactory.
@export var model_scene: PackedScene
## Scale multiplier for the 3D model.
@export var model_scale: float = 1.0

@export_group("Skills")
## Innate skills (not from items).
@export var innate_skills: Array[SkillData] = []

func get_base_stat(stat: Enums.Stat) -> int:
	match stat:
		Enums.Stat.MAX_HP: return max_hp
		Enums.Stat.MAX_MP: return max_mp
		Enums.Stat.SPEED: return speed
		Enums.Stat.LUCK: return luck
		Enums.Stat.PHYSICAL_ATTACK: return physical_attack
		Enums.Stat.PHYSICAL_DEFENSE: return physical_defense
		Enums.Stat.MAGICAL_ATTACK: return magical_attack
		Enums.Stat.MAGICAL_DEFENSE: return magical_defense
		Enums.Stat.CRITICAL_RATE: return 0
		Enums.Stat.CRITICAL_DAMAGE: return 0
	return 0
