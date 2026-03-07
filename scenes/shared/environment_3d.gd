extends Node3D
## Bridges Environment3D scene with DisplayManager graphics settings.

@onready var _world_env: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $DirectionalLight


func _ready() -> void:
	DisplayManager.apply_environment(_world_env, _sun)
	DisplayManager.graphics_changed.connect(_on_graphics_changed)


func _on_graphics_changed() -> void:
	DisplayManager.apply_environment(_world_env, _sun)
