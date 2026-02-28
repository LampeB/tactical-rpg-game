class_name VoxModel
extends MeshInstance3D
## Convenience node that loads and displays a MagicaVoxel .vox model.
##
## Set [member vox_path] in the Inspector or call [method load_model] at runtime.

## Path to the .vox file (res:// or user://).
@export_file("*.vox") var vox_path: String = ""

## World units per voxel cube. Default 0.1 makes a 16-voxel character ~1.6 units tall.
@export var voxel_size: float = 0.1


func _ready() -> void:
	if not vox_path.is_empty():
		load_model(vox_path, voxel_size)


func load_model(path: String, size: float = 0.1) -> void:
	## Loads a .vox file and assigns the resulting mesh.
	mesh = VoxImporter.load_vox(path, size)
