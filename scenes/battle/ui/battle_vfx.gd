class_name BattleVFX
extends Node3D
## Spawns CPUParticles3D visual effects at 3D positions during combat.
## Each effect auto-frees after its lifetime.

## Default colors per VFX type (used when skill vfx_color is white/default).
const DEFAULT_COLORS: Dictionary = {
	# SkillVFX enum int values as keys
	0: Color.WHITE,                       # NONE
	1: Color(0.95, 0.95, 1.0),            # SLASH — bright white
	2: Color(1.0, 0.6, 0.15),             # POWER_SLASH — orange
	3: Color(0.9, 0.9, 1.0),              # STAB — pale white
	4: Color(0.7, 0.55, 0.35),            # BASH — earthy brown
	5: Color(1.0, 0.35, 0.1),             # FIRE — orange-red
	6: Color(0.5, 0.8, 1.0),              # ICE — light blue
	7: Color(0.85, 0.85, 1.0),            # LIGHTNING — pale electric
	8: Color(0.5, 0.15, 0.6),             # DARK — purple
	9: Color(0.3, 1.0, 0.4),              # HEAL — green
	10: Color(0.2, 0.8, 0.1),             # POISON — sickly green
	11: Color(1.0, 0.85, 0.3),            # BUFF — golden
	12: Color(1.0, 0.5, 0.15),            # EXPLOSION — orange
}


static func spawn_at(parent: Node3D, world_pos: Vector3, vfx_type: int, color_override: Color = Color.WHITE) -> void:
	## Spawn a VFX at the given world position. Auto-frees after completion.
	if vfx_type == 0:  # NONE
		return

	var color: Color = color_override
	if color == Color.WHITE:
		color = DEFAULT_COLORS.get(vfx_type, Color.WHITE)

	match vfx_type:
		1:  # SLASH
			_spawn_slash(parent, world_pos, color, 1.0)
		2:  # POWER_SLASH
			_spawn_slash(parent, world_pos, color, 1.6)
			_spawn_sparks(parent, world_pos, color, 12)
		3:  # STAB
			_spawn_stab(parent, world_pos, color)
		4:  # BASH
			_spawn_impact(parent, world_pos, color)
			_spawn_dust(parent, world_pos - Vector3(0, 0.5, 0))
		5:  # FIRE
			_spawn_fire(parent, world_pos, color)
		6:  # ICE
			_spawn_ice(parent, world_pos, color)
		7:  # LIGHTNING
			_spawn_lightning(parent, world_pos, color)
		8:  # DARK
			_spawn_dark(parent, world_pos, color)
		9:  # HEAL
			_spawn_heal(parent, world_pos, color)
		10:  # POISON
			_spawn_poison(parent, world_pos, color)
		11:  # BUFF
			_spawn_heal(parent, world_pos, color)
		12:  # EXPLOSION
			_spawn_explosion(parent, world_pos, color)


# === Effect Builders ===

static func _spawn_slash(parent: Node3D, pos: Vector3, color: Color, scale_mult: float) -> void:
	## Arc of particles sweeping in a slash motion.
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = int(16 * scale_mult)
	particles.lifetime = 0.35
	particles.explosiveness = 0.9
	particles.spread = 30.0
	particles.direction = Vector3(0, 1, 0)
	particles.initial_velocity_min = 2.0 * scale_mult
	particles.initial_velocity_max = 4.0 * scale_mult
	particles.gravity = Vector3.ZERO
	particles.damping_min = 4.0
	particles.damping_max = 6.0
	particles.scale_amount_min = 0.06 * scale_mult
	particles.scale_amount_max = 0.12 * scale_mult
	particles.color = color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.mesh = _make_quad_mesh(mat)
	parent.add_child(particles)
	_auto_free(particles, 0.6)


static func _spawn_sparks(parent: Node3D, pos: Vector3, color: Color, count: int) -> void:
	## Small sparks flying outward from impact point.
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = count
	particles.lifetime = 0.4
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.direction = Vector3(0, 1, 0)
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 6.0
	particles.gravity = Vector3(0, -5, 0)
	particles.scale_amount_min = 0.02
	particles.scale_amount_max = 0.05
	particles.color = color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.mesh = _make_quad_mesh(mat)
	parent.add_child(particles)
	_auto_free(particles, 0.7)


static func _spawn_stab(parent: Node3D, pos: Vector3, color: Color) -> void:
	## Quick narrow burst forward.
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.25
	particles.explosiveness = 1.0
	particles.spread = 10.0
	particles.direction = Vector3(1, 0, 0)
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3.ZERO
	particles.damping_min = 6.0
	particles.damping_max = 8.0
	particles.scale_amount_min = 0.03
	particles.scale_amount_max = 0.06
	particles.color = color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.mesh = _make_quad_mesh(mat)
	parent.add_child(particles)
	_auto_free(particles, 0.5)


static func _spawn_impact(parent: Node3D, pos: Vector3, color: Color) -> void:
	## Ring burst outward from center (bash/blunt impact).
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 0.35
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.flatness = 0.8
	particles.direction = Vector3(0, 0, 0)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0, -3, 0)
	particles.scale_amount_min = 0.04
	particles.scale_amount_max = 0.08
	particles.color = color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.mesh = _make_quad_mesh(mat)
	parent.add_child(particles)
	_auto_free(particles, 0.6)


static func _spawn_dust(parent: Node3D, pos: Vector3) -> void:
	## Ground dust puff.
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 10
	particles.lifetime = 0.5
	particles.explosiveness = 0.8
	particles.spread = 180.0
	particles.flatness = 1.0
	particles.direction = Vector3(0, 1, 0)
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 1.5
	particles.gravity = Vector3(0, -1, 0)
	particles.scale_amount_min = 0.05
	particles.scale_amount_max = 0.12
	particles.color = Color(0.6, 0.55, 0.45, 0.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.55, 0.45, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.mesh = _make_quad_mesh(mat)
	parent.add_child(particles)
	_auto_free(particles, 0.8)


static func _spawn_fire(parent: Node3D, pos: Vector3, color: Color) -> void:
	## Fire burst with rising embers.
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 24
	particles.lifetime = 0.5
	particles.explosiveness = 0.85
	particles.spread = 60.0
	particles.direction = Vector3(0, 1, 0)
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 3.5
	particles.gravity = Vector3(0, 2, 0)
	particles.scale_amount_min = 0.04
	particles.scale_amount_max = 0.1
	# Color gradient: orange -> red -> dark
	particles.color = color
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, color)
	color_ramp.add_point(0.5, Color(1.0, 0.2, 0.0))
	color_ramp.set_color(1, Color(0.3, 0.05, 0.0, 0.0))
	particles.color_ramp = color_ramp
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.mesh = _make_quad_mesh(mat)
	parent.add_child(particles)
	_auto_free(particles, 0.8)


static func _spawn_ice(parent: Node3D, pos: Vector3, color: Color) -> void:
	## Ice crystal shatter — sharp outward burst with fade.
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 18
	particles.lifetime = 0.45
	particles.explosiveness = 0.95
	particles.spread = 120.0
	particles.direction = Vector3(0, 0.5, 0)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.5
	particles.gravity = Vector3(0, -4, 0)
	particles.damping_min = 2.0
	particles.damping_max = 4.0
	particles.scale_amount_min = 0.03
	particles.scale_amount_max = 0.08
	particles.color = color
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(0.8, 0.95, 1.0))
	color_ramp.set_color(1, Color(0.3, 0.6, 1.0, 0.0))
	particles.color_ramp = color_ramp
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.mesh = _make_quad_mesh(mat)
	parent.add_child(particles)
	_auto_free(particles, 0.7)


static func _spawn_lightning(parent: Node3D, pos: Vector3, color: Color) -> void:
	## Electric sparks — fast, bright, chaotic.
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 22
	particles.lifetime = 0.3
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.direction = Vector3(0, 1, 0)
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 8.0
	particles.gravity = Vector3.ZERO
	particles.damping_min = 8.0
	particles.damping_max = 12.0
	particles.scale_amount_min = 0.02
	particles.scale_amount_max = 0.05
	particles.color = color
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(1.0, 1.0, 1.0))
	color_ramp.add_point(0.3, color)
	color_ramp.set_color(1, Color(0.4, 0.4, 1.0, 0.0))
	particles.color_ramp = color_ramp
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.mesh = _make_quad_mesh(mat)
	parent.add_child(particles)
	_auto_free(particles, 0.5)


static func _spawn_dark(parent: Node3D, pos: Vector3, color: Color) -> void:
	## Dark wisps swirling inward then dissipating.
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 16
	particles.lifetime = 0.6
	particles.explosiveness = 0.7
	particles.spread = 180.0
	particles.direction = Vector3(0, 0.5, 0)
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 2.0
	particles.gravity = Vector3(0, 1, 0)
	particles.scale_amount_min = 0.05
	particles.scale_amount_max = 0.12
	particles.color = color
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, color)
	color_ramp.add_point(0.6, Color(0.2, 0.0, 0.3, 0.8))
	color_ramp.set_color(1, Color(0.05, 0.0, 0.1, 0.0))
	particles.color_ramp = color_ramp
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.mesh = _make_quad_mesh(mat)
	parent.add_child(particles)
	_auto_free(particles, 0.9)


static func _spawn_heal(parent: Node3D, pos: Vector3, color: Color) -> void:
	## Rising sparkles around the target (heal/buff).
	var particles := CPUParticles3D.new()
	particles.position = pos - Vector3(0, 0.5, 0)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 0.8
	particles.explosiveness = 0.3
	particles.spread = 30.0
	particles.direction = Vector3(0, 1, 0)
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.5
	particles.gravity = Vector3(0, 1, 0)
	particles.scale_amount_min = 0.02
	particles.scale_amount_max = 0.05
	particles.color = color
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(1, 1, 1, 0.0))
	color_ramp.add_point(0.2, color)
	color_ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	particles.color_ramp = color_ramp
	# Emit in a small cylinder around the target
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.mesh = _make_quad_mesh(mat)
	parent.add_child(particles)
	_auto_free(particles, 1.2)


static func _spawn_poison(parent: Node3D, pos: Vector3, color: Color) -> void:
	## Sickly green bubbles rising slowly.
	var particles := CPUParticles3D.new()
	particles.position = pos - Vector3(0, 0.3, 0)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 14
	particles.lifetime = 0.7
	particles.explosiveness = 0.4
	particles.spread = 40.0
	particles.direction = Vector3(0, 1, 0)
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 1.5
	particles.gravity = Vector3(0, 0.5, 0)
	particles.scale_amount_min = 0.03
	particles.scale_amount_max = 0.07
	particles.color = color
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, color)
	color_ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	particles.color_ramp = color_ramp
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.mesh = _make_quad_mesh(mat)
	parent.add_child(particles)
	_auto_free(particles, 1.0)


static func _spawn_explosion(parent: Node3D, pos: Vector3, color: Color) -> void:
	## Large radial burst with shockwave ring.
	# Inner fireball
	_spawn_fire(parent, pos, color)
	# Outer ring
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 0.45
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.flatness = 0.6
	particles.direction = Vector3(0, 0, 0)
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 7.0
	particles.gravity = Vector3(0, -2, 0)
	particles.scale_amount_min = 0.05
	particles.scale_amount_max = 0.12
	particles.color = color
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(1.0, 0.9, 0.6))
	color_ramp.add_point(0.4, color)
	color_ramp.set_color(1, Color(0.3, 0.1, 0.0, 0.0))
	particles.color_ramp = color_ramp
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.mesh = _make_quad_mesh(mat)
	parent.add_child(particles)
	_auto_free(particles, 0.8)


# === Utilities ===

static func _make_quad_mesh(material: StandardMaterial3D) -> QuadMesh:
	## Create a small quad mesh for billboard particles.
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.1, 0.1)
	mesh.material = material
	return mesh


static func _auto_free(node: Node, delay: float) -> void:
	## Queue-free a node after a delay using a SceneTreeTimer.
	if not node.is_inside_tree():
		node.tree_entered.connect(func() -> void:
			node.get_tree().create_timer(delay).timeout.connect(func() -> void:
				if is_instance_valid(node):
					node.queue_free()
			)
		, CONNECT_ONE_SHOT)
	else:
		node.get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(node):
				node.queue_free()
		)
