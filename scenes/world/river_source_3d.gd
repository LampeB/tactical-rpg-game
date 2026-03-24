@tool
class_name RiverSource3D
extends Node3D
## Draggable editor marker for river starting point.
## Place on a mountain/hill, then click "generate_rivers" on HeightmapTerrain3D
## to trace rivers downhill from all RiverSource3D markers.
## Shows a blue pillar in the editor.

var _visual: MeshInstance3D = null


func _ready() -> void:
	_build_visual()


func _build_visual() -> void:
	if _visual:
		return
	_visual = MeshInstance3D.new()
	_visual.name = "RiverVisual"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.3
	cyl.height = 5.0
	_visual.mesh = cyl
	_visual.position.y = 2.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 1.0, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.5, 1.0)
	mat.emission_energy_multiplier = 0.5
	_visual.material_override = mat
	add_child(_visual)

	var label := Label3D.new()
	label.name = "Label"
	label.text = "RIVER"
	label.font_size = 64
	label.position.y = 5.5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.4, 0.7, 1.0)
	label.outline_size = 8
	add_child(label)
