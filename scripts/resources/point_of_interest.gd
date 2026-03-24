class_name PointOfInterest
extends Resource
## A named point of interest placed on the procedural terrain.
## Used by the road generator (roads route toward POIs) and the overworld
## (spawn encounter zones, dungeon entrances, NPC camps, etc.).

enum Type {
	DUNGEON = 0,  ## Underground entrance — dark valleys, hillsides
	RUINS   = 1,  ## Ancient structure — elevated hilltops, forest clearings
	CAMP    = 2,  ## Enemy camp — flat ground near water
	SHRINE  = 3,  ## Sacred site — elevated or near a river
	CITY    = 4,  ## Major settlement — shops, quests, safe zone
	VILLAGE = 5,  ## Small settlement — few NPCs, rest point
	GATE    = 6,  ## Mountain gate / barrier — blocks a pass until unlocked
	BRIDGE  = 7,  ## River bridge — blocks crossing until repaired/unlocked
}

@export var id: String = ""
@export var type: Type = Type.RUINS
@export var display_name: String = ""
## World-space position on the terrain surface.
@export var position: Vector3 = Vector3.ZERO
## Story flag required to unlock this POI (gates, bridges). Empty = always open.
@export var unlock_flag: String = ""
