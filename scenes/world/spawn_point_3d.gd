@tool
class_name SpawnPoint3D
extends Node3D
## Draggable editor marker for player spawn position.
## Place one in your map scene — the overworld reads its position at runtime.
## Shows a green pillar in the editor for visibility.

var _visual: MeshInstance3D = null


func _ready() -> void:
	_build_visual()


func _build_visual() -> void:
	if _visual:
		return
	_visual = MeshInstance3D.new()
	_visual.name = "SpawnVisual"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.4
	cyl.height = 4.0
	_visual.mesh = cyl
	_visual.position.y = 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.3, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 1.0, 0.3)
	mat.emission_energy_multiplier = 0.4
	_visual.material_override = mat
	add_child(_visual)

	var label := Label3D.new()
	label.name = "Label"
	label.text = "SPAWN"
	label.font_size = 64
	label.position.y = 4.5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.3, 1.0, 0.4)
	label.outline_size = 8
	add_child(label)
