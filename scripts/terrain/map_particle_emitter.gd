@tool
extends Node3D
## Particle emitter for map decoration. Configure via exports in the inspector.
## The preset sets initial values — after that, tweak any field directly.

enum ParticlePreset { CUSTOM, CAMPFIRE, FIREFLIES, DUST_MOTES, LEAVES_FALLING, MIST, WATER_SPLASH, MAGIC_SPARKLE }

@export var preset: ParticlePreset = ParticlePreset.CAMPFIRE:
	set(value):
		preset = value
		if Engine.is_editor_hint() and is_inside_tree():
			_load_preset()
			_rebuild()

@export_group("Settings")
@export var particle_color: Color = Color(1.0, 0.5, 0.1, 0.9):
	set(v): particle_color = v; _rebuild()
@export var particle_color_end: Color = Color(1.0, 0.1, 0.0, 0.0):
	set(v): particle_color_end = v; _rebuild()
@export var particle_count: int = 30:
	set(v): particle_count = v; _rebuild()
@export var particle_lifetime: float = 1.5:
	set(v): particle_lifetime = v; _rebuild()
@export var emission_box: Vector3 = Vector3(0.3, 0.05, 0.3):
	set(v): emission_box = v; _rebuild()
@export var particle_speed: float = 1.5:
	set(v): particle_speed = v; _rebuild()
@export var particle_size: float = 0.08:
	set(v): particle_size = v; _rebuild()
@export var gravity: Vector3 = Vector3(0, 0.5, 0):
	set(v): gravity = v; _rebuild()
@export var spread_angle: float = 20.0:
	set(v): spread_angle = v; _rebuild()
@export var direction: Vector3 = Vector3(0, 1, 0):
	set(v): direction = v; _rebuild()

var _particles: GPUParticles3D = null
var _label: Label3D = null


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		_label = Label3D.new()
		_label.position.y = 1.5
		_label.font_size = 24
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.modulate = Color(1.0, 0.7, 0.3)
		_label.text = ParticlePreset.keys()[preset]
		add_child(_label)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _particles:
		_particles.queue_free()
	_particles = GPUParticles3D.new()
	_particles.amount = particle_count
	_particles.lifetime = particle_lifetime
	_particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = emission_box
	mat.direction = direction
	mat.spread = spread_angle
	mat.initial_velocity_min = particle_speed * 0.5
	mat.initial_velocity_max = particle_speed
	mat.gravity = gravity
	mat.scale_min = particle_size * 0.5
	mat.scale_max = particle_size

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([particle_color, particle_color_end])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	_particles.process_material = mat

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.05, 0.05)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	mesh.material = draw_mat
	_particles.draw_pass_1 = mesh

	add_child(_particles)

	if _label:
		_label.text = ParticlePreset.keys()[preset]


func _load_preset() -> void:
	match preset:
		ParticlePreset.CAMPFIRE:
			particle_color = Color(1.0, 0.5, 0.1, 0.9); particle_color_end = Color(1.0, 0.1, 0.0, 0.0)
			particle_count = 30; particle_lifetime = 1.5; emission_box = Vector3(0.3, 0.05, 0.3)
			particle_speed = 1.5; particle_size = 0.08; gravity = Vector3(0, 0.5, 0)
			spread_angle = 20.0; direction = Vector3(0, 1, 0)
		ParticlePreset.FIREFLIES:
			particle_color = Color(0.5, 1.0, 0.3, 0.9); particle_color_end = Color(0.2, 0.8, 0.1, 0.0)
			particle_count = 15; particle_lifetime = 4.0; emission_box = Vector3(3.0, 1.0, 3.0)
			particle_speed = 0.3; particle_size = 0.06; gravity = Vector3(0, 0.1, 0)
			spread_angle = 180.0; direction = Vector3(0, 1, 0)
		ParticlePreset.DUST_MOTES:
			particle_color = Color(1.0, 0.95, 0.7, 0.5); particle_color_end = Color(1.0, 0.9, 0.6, 0.0)
			particle_count = 25; particle_lifetime = 5.0; emission_box = Vector3(4.0, 2.0, 4.0)
			particle_speed = 0.15; particle_size = 0.04; gravity = Vector3(0, 0.05, 0)
			spread_angle = 180.0; direction = Vector3(0, 1, 0)
		ParticlePreset.LEAVES_FALLING:
			particle_color = Color(0.04, 0.27, 0.03, 0.9); particle_color_end = Color(0.03, 0.39, 0.0, 0.0)
			particle_count = 300; particle_lifetime = 4.0; emission_box = Vector3(0.5, 0.5, 0.5)
			particle_speed = 0.02; particle_size = 0.1; gravity = Vector3(0, -1, 0)
			spread_angle = 0.0; direction = Vector3(0, -10, 0)
		ParticlePreset.MIST:
			particle_color = Color(0.8, 0.85, 0.9, 0.3); particle_color_end = Color(0.7, 0.75, 0.8, 0.0)
			particle_count = 15; particle_lifetime = 6.0; emission_box = Vector3(5.0, 0.2, 5.0)
			particle_speed = 0.2; particle_size = 0.5; gravity = Vector3(0, 0.1, 0)
			spread_angle = 180.0; direction = Vector3(0, 1, 0)
		ParticlePreset.WATER_SPLASH:
			particle_color = Color(0.4, 0.6, 0.9, 0.6); particle_color_end = Color(0.3, 0.5, 0.8, 0.0)
			particle_count = 10; particle_lifetime = 1.0; emission_box = Vector3(1.0, 0.05, 1.0)
			particle_speed = 1.0; particle_size = 0.05; gravity = Vector3(0, -2.0, 0)
			spread_angle = 30.0; direction = Vector3(0, 1, 0)
		ParticlePreset.MAGIC_SPARKLE:
			particle_color = Color(0.8, 0.6, 1.0, 0.9); particle_color_end = Color(0.4, 0.8, 1.0, 0.0)
			particle_count = 30; particle_lifetime = 2.0; emission_box = Vector3(0.5, 0.5, 0.5)
			particle_speed = 0.5; particle_size = 0.06; gravity = Vector3(0, 0.3, 0)
			spread_angle = 180.0; direction = Vector3(0, 1, 0)
