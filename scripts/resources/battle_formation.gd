class_name BattleFormation
extends Resource
## Defines where party members and enemies stand in battle.
## Positions are relative to the arena center.

@export var formation_name: String = ""

## Player positions relative to arena center (index 0 = first party member).
## Unused slots are ignored at runtime based on actual party size.
@export var player_positions: Array[Vector3] = [
	Vector3(-3.0, 0, 0.0),
	Vector3(-4.0, 0, 1.0),
	Vector3(-3.5, 0, -1.0),
	Vector3(-5.0, 0, 0.5),
]

## Enemy positions relative to arena center.
@export var enemy_positions: Array[Vector3] = [
	Vector3(3.0, 0, 0.0),
	Vector3(4.0, 0, 1.0),
	Vector3(3.5, 0, -1.0),
	Vector3(5.0, 0, 0.5),
]
