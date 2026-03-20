class_name PropDefinition
extends Resource
## Defines a scatterable prop: its scene, placement rules, and physics.

enum CollisionType { NONE, BLOCKING }  ## NONE = visual only, BLOCKING = player can't walk through

@export var id: String = ""
@export var scene_path: String = ""  ## Path to .gltf or .tscn
@export var collision_type: CollisionType = CollisionType.NONE

@export_group("Placement")
## Which splatmap layers this prop can spawn on (bitmask: bit 0=layer0, bit 1=layer1, etc.)
@export_flags("Layer 0 (Grass)", "Layer 1 (Dirt)", "Layer 2 (Rock)", "Layer 3 (Snow)") var allowed_layers: int = 1
@export var density: float = 0.5  ## Props per unit area (higher = more dense)
@export var min_slope: float = 0.0  ## Minimum terrain slope (0 = flat)
@export var max_slope: float = 30.0  ## Maximum terrain slope in degrees

@export_group("Transform")
@export var min_scale: float = 0.8
@export var max_scale: float = 1.2
@export var random_rotation_y: bool = true  ## Random Y rotation
@export var align_to_normal: bool = false  ## Tilt prop to match terrain normal

@export_group("LOD")
## Distance at which this prop becomes invisible. 0 = no culling.
## Typical values: trees 120, rocks 80, bushes 60, grass 40.
@export var lod_distance: float = 0.0

@export_group("Island")
## Which island this prop can spawn on (overworld only). 0 = any island, 1+ = specific island index.
@export var allowed_island: int = 0
## When true, this prop only spawns inside forest zones (where forest_density > 0).
@export var forest_only: bool = false

@export_group("Wind")
@export var affected_by_wind: bool = false  ## Apply foliage wind shader
