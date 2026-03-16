class_name PlacedStructure
extends Resource
## A single structure piece placed in the world. Stored in HeightmapData.

@export var piece_id: String = ""  ## References StructurePiece.id
@export var scene_path: String = ""  ## Direct path to a .tscn prefab (bypasses StructureRegistry)
@export var position: Vector3 = Vector3.ZERO  ## World-space position
@export var rotation_y: float = 0.0  ## Y-axis rotation in radians (0, PI/2, PI, 3PI/2 for 90° snaps)
@export var scale_factor: float = 1.0
