class_name WindApplicator
extends RefCounted
## Applies foliage_wind shader to MeshInstance3D nodes in a layer.

const _WIND_SHADER := "res://shaders/foliage_wind.gdshader"


static func apply_to_layer(generator: Node3D, layer_name: String, strength: float, speed: float, mesh_height: float) -> void:
	var layer: Node = null
	for i in range(generator.get_child_count()):
		if generator.get_child(i).name == layer_name:
			layer = generator.get_child(i)
			break
	if not layer:
		return
	if not ResourceLoader.exists(_WIND_SHADER):
		return
	var shader: Shader = load(_WIND_SHADER)
	if not shader:
		return

	var count: int = 0
	for i in range(layer.get_child_count()):
		_apply_recursive(layer.get_child(i), shader, strength, speed, mesh_height)
		count += 1
	print("[WindApplicator] Applied wind to %d items in %s." % [count, layer_name])


static func _apply_recursive(node: Node, shader: Shader, strength: float, speed: float, mesh_height: float) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh:
			var mesh_copy: Mesh = mi.mesh.duplicate()
			for si in range(mesh_copy.get_surface_count()):
				var orig_mat: Material = mesh_copy.surface_get_material(si)
				var wind_mat := ShaderMaterial.new()
				wind_mat.shader = shader
				if orig_mat is StandardMaterial3D:
					var std: StandardMaterial3D = orig_mat as StandardMaterial3D
					if std.albedo_texture:
						wind_mat.set_shader_parameter("base_texture", std.albedo_texture)
					if std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
						wind_mat.set_shader_parameter("alpha_scissor", std.alpha_scissor_threshold)
				wind_mat.set_shader_parameter("wind_strength", strength)
				wind_mat.set_shader_parameter("wind_speed", speed)
				wind_mat.set_shader_parameter("mesh_height", mesh_height)
				mesh_copy.surface_set_material(si, wind_mat)
			mi.mesh = mesh_copy
	for i in range(node.get_child_count()):
		_apply_recursive(node.get_child(i), shader, strength, speed, mesh_height)
