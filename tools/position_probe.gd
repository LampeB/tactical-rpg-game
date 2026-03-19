@tool
extends Node3D
## Drop this node anywhere in the scene, position it where you want the spawn point,
## then click "Print Position" in the inspector. Copy the output into target_spawn.

@export_tool_button("Print Position") var _print_btn := _print_position


func _print_position() -> void:
	print("Position: Vector3(%.1f, %.1f, %.1f)" % [
		global_position.x,
		global_position.y,
		global_position.z,
	])
	print("  → paste into target_spawn in your MapConnection resource")
