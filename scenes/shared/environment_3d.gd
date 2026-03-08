extends Node3D
## Bridges Environment3D scene with DisplayManager graphics settings
## and applies the DayNightCycle lighting state each frame.

const _STARRY_SKY_SHADER := preload("res://scenes/shared/starry_sky.gdshader")

@onready var _world_env: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $DirectionalLight
@onready var _fill_light: DirectionalLight3D = $FillLight
@onready var _moon: DirectionalLight3D = $MoonLight

var _sky_shader_mat: ShaderMaterial
var _has_day_night: bool = false
## Base sun transform — yaw is preserved, only pitch changes with time of day.
var _sun_base_yaw: float = 0.0


func _ready() -> void:
	DisplayManager.apply_environment(_world_env, _sun)
	DisplayManager.graphics_changed.connect(_on_graphics_changed)

	# Cache sun yaw for pitch-only rotation
	_sun_base_yaw = _sun.rotation_degrees.y

	# Check if DayNightCycle autoload exists (not present in map editor)
	_has_day_night = Engine.has_singleton("DayNightCycle") or has_node("/root/DayNightCycle")

	# Replace ProceduralSkyMaterial with starry sky shader when day/night is active
	if _has_day_night and _world_env and _world_env.environment and _world_env.environment.sky:
		_sky_shader_mat = ShaderMaterial.new()
		_sky_shader_mat.shader = _STARRY_SKY_SHADER
		_world_env.environment.sky.sky_material = _sky_shader_mat


func _process(_delta: float) -> void:
	if not _has_day_night:
		return
	var state: Dictionary = DayNightCycle.get_lighting_state()
	_apply_day_night(state)


func _apply_day_night(state: Dictionary) -> void:
	# Sun
	var sun_energy: float = state.get("sun_energy", 1.2)
	var sun_color: Color = state.get("sun_color", Color(1.0, 0.96, 0.88))
	var sun_pitch: float = state.get("sun_pitch", -45.0)
	var sun_yaw: float = state.get("sun_yaw", _sun_base_yaw)
	_sun.light_energy = sun_energy
	_sun.light_color = sun_color
	_sun.rotation_degrees = Vector3(sun_pitch, sun_yaw, 0.0)

	# Fill light — proportional to sun (dimmer at night)
	var fill_ratio: float = sun_energy / 1.2  # 1.2 = noon sun energy
	_fill_light.light_energy = 0.3 * fill_ratio

	# Moon — cool white light, visible at night, affected by phase
	var moon_energy: float = state.get("moon_energy", 0.0)
	var moon_pitch: float = state.get("moon_pitch", -45.0)
	var moon_yaw: float = state.get("moon_yaw", 90.0)
	_moon.light_energy = moon_energy
	_moon.rotation_degrees = Vector3(moon_pitch, moon_yaw, 0.0)

	_moon.shadow_enabled = moon_energy > 0.01
	_moon.shadow_opacity = 0.2

	# Ambient light
	var env: Environment = _world_env.environment
	env.ambient_light_energy = state.get("ambient_energy", 0.4)
	env.ambient_light_color = state.get("ambient_color", Color(0.3, 0.3, 0.35))

	# Sky shader colors + stars + celestial discs
	if _sky_shader_mat:
		var sky_top: Color = state.get("sky_top", Color(0.4, 0.6, 0.9))
		var sky_hz: Color = state.get("sky_horizon", Color(0.7, 0.8, 0.95))
		var gnd_hz: Color = state.get("ground_horizon", Color(0.5, 0.55, 0.45))
		var gnd_bt: Color = state.get("ground_bottom", Color(0.15, 0.18, 0.12))
		_sky_shader_mat.set_shader_parameter("sky_top_color", Vector3(sky_top.r, sky_top.g, sky_top.b))
		_sky_shader_mat.set_shader_parameter("sky_horizon_color", Vector3(sky_hz.r, sky_hz.g, sky_hz.b))
		_sky_shader_mat.set_shader_parameter("ground_bottom_color", Vector3(gnd_bt.r, gnd_bt.g, gnd_bt.b))
		_sky_shader_mat.set_shader_parameter("ground_horizon_color", Vector3(gnd_hz.r, gnd_hz.g, gnd_hz.b))
		_sky_shader_mat.set_shader_parameter("star_visibility", state.get("star_visibility", 0.0))
		var mb: float = DayNightCycle.get_moon_brightness()
		_sky_shader_mat.set_shader_parameter("moon_brightness", mb)

		# Sun disc — direction TO the sun in the sky (opposite of where light shines)
		# DirectionalLight3D shines along local -Z, so +basis.z points back at the source
		var sun_dir: Vector3 = _sun.global_transform.basis.z
		_sky_shader_mat.set_shader_parameter("sun_direction", sun_dir)
		_sky_shader_mat.set_shader_parameter("sun_disk_color", Vector3(sun_color.r, sun_color.g, sun_color.b))
		_sky_shader_mat.set_shader_parameter("sun_energy_value", sun_energy)

		# Moon disc — same: +basis.z points toward where moon appears
		var moon_dir: Vector3 = _moon.global_transform.basis.z
		_sky_shader_mat.set_shader_parameter("moon_direction", moon_dir)
		_sky_shader_mat.set_shader_parameter("moon_phase_angle", mb * 2.0 - 1.0)


func _on_graphics_changed() -> void:
	DisplayManager.apply_environment(_world_env, _sun)
