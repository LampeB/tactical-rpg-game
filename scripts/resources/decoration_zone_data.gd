class_name DecorationZoneData
extends Resource
## Defines a procedural decoration zone for seeded scatter placement.

@export var zone_name: String = ""
@export var rect: Rect2 = Rect2(0, 0, 10, 10)  ## XZ bounds (x, z, width, depth)

## Scene paths of decorations to scatter (can repeat for weighted probability).
@export var decoration_scenes: Array[String] = []

@export var count: int = 10
@export var min_spacing: float = 2.0
