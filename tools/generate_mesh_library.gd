@tool
extends EditorScript
## Generates the terrain MeshLibrary for GridMap usage.
## Run from Godot: File > Run (or Ctrl+Shift+X) with this script selected.

const BLOCKS := [
	{"name": "Grass",      "color": Color(0.35, 0.55, 0.25)},
	{"name": "Dirt",       "color": Color(0.45, 0.32, 0.18)},
	{"name": "Stone",      "color": Color(0.5, 0.5, 0.5)},
	{"name": "Water",      "color": Color(0.2, 0.4, 0.8, 0.7)},
	{"name": "Path",       "color": Color(0.6, 0.5, 0.35)},
	{"name": "Sand",       "color": Color(0.85, 0.77, 0.55)},
	{"name": "DarkGrass",  "color": Color(0.25, 0.4, 0.2)},
	{"name": "Snow",       "color": Color(0.9, 0.9, 0.95)},
]


func _run() -> void:
	var lib := MeshLibrary.new()

	for i in BLOCKS.size():
		lib.create_item(i)

		# Mesh
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1, 1, 1)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = BLOCKS[i].color
		if BLOCKS[i].color.a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = mat
		lib.set_item_mesh(i, mesh)
		lib.set_item_name(i, BLOCKS[i].name)

		# Collision — array of shape + transform pairs
		var shape := BoxShape3D.new()
		shape.size = Vector3(1, 1, 1)
		lib.set_item_shapes(i, [shape, Transform3D.IDENTITY])

	var err := ResourceSaver.save(lib, "res://assets/meshlibraries/terrain_library.tres")
	if err == OK:
		print("Terrain MeshLibrary saved successfully with %d blocks." % BLOCKS.size())
	else:
		push_error("Failed to save MeshLibrary: %s" % error_string(err))
