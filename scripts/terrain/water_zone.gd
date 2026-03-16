class_name WaterZone
extends Resource
## Defines a placed water body: position, size, shape, and visual properties.

enum Shape { RECTANGLE, ELLIPSE }

@export var id: String = ""
@export var center: Vector3 = Vector3.ZERO  ## World-space center (XZ) + water level (Y)
@export var size: Vector2 = Vector2(20, 20)  ## Width × depth in world units (bounding box)
@export var shape: Shape = Shape.RECTANGLE
@export var shallow_color: Color = Color(0.2, 0.5, 0.7, 0.6)
@export var deep_color: Color = Color(0.05, 0.15, 0.3, 0.85)
@export var wave_speed: float = 0.3
@export var wave_strength: float = 0.05
