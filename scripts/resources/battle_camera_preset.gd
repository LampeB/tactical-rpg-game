class_name BattleCameraPreset
extends Resource
## A single camera angle definition for the battle system.
## Position and look offsets are relative to the arena center,
## rotated by the arena's Y rotation at runtime.

@export var preset_name: String = ""
@export var position_offset: Vector3 = Vector3(-3.5, 2.5, 1.5)
@export var look_offset: Vector3 = Vector3(3.0, 0.5, 0.0)
@export var fov: float = 40.0
@export var transition_duration: float = 0.5
## 0 = smooth move (cubic ease), 1 = dramatic orbit arc
@export_range(0, 1) var transition_type: int = 0
