class_name BattleAreaData
extends Resource
## Marks a position on the map where battles take place.
## Large decorations within ARENA_RADIUS are removed during fights
## so combatants are visible. The full map is still rendered.

const ARENA_RADIUS := 7.0  ## Radius within which blocking decorations are cleared

@export var area_name: String = ""
@export var position: Vector3 = Vector3.ZERO  ## Center of the battle arena on the map
@export var rotation_y: float = 0.0  ## Y-axis rotation in radians (orients player/enemy sides)
