@tool
class_name BattleArea3D
extends Area3D
## @tool node marking a battle arena location on the map.
## Shows a translucent red circle gizmo in the editor.
## At runtime, the overworld uses these to preload battle backgrounds.

const ARENA_RADIUS := 7.0  ## Default radius for prop clearing during battles

@export var area_name: String = "":
	set(value):
		area_name = value
		if Engine.is_editor_hint():
			_update_label()

@export var arena_radius: float = 7.0:
	set(value):
		arena_radius = value
		if is_inside_tree():
			_rebuild_gizmo()

@export var rotation_offset_y: float = 0.0  ## Rotation for player/enemy sides

@export_group("Encounter")
@export var encounter_id: String = ""  ## Links to EncounterZoneData for enemy spawns

var _gizmo_mesh: MeshInstance3D = null
var _label: Label3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_gizmo()
	else:
		# Runtime: set up as invisible area (no visual needed)
		collision_layer = 0
		collision_mask = 0
		_clear_gizmo()


func _rebuild_gizmo() -> void:
	if not Engine.is_editor_hint():
		return
	_clear_gizmo()

	# Circle disc mesh
	var disc := CylinderMesh.new()
	disc.top_radius = arena_radius
	disc.bottom_radius = arena_radius
	disc.height = 0.1
	disc.radial_segments = 32

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.3, 0.1, 0.25)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_gizmo_mesh = MeshInstance3D.new()
	_gizmo_mesh.mesh = disc
	_gizmo_mesh.material_override = mat
	_gizmo_mesh.name = "EditorGizmo"
	add_child(_gizmo_mesh)

	# Label
	_label = Label3D.new()
	_label.text = area_name if area_name != "" else "Battle Area"
	_label.font_size = 32
	_label.modulate = Color(1.0, 0.4, 0.2)
	_label.position.y = 2.0
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.name = "EditorLabel"
	add_child(_label)


func _update_label() -> void:
	if _label:
		_label.text = area_name if area_name != "" else "Battle Area"


func _clear_gizmo() -> void:
	if _gizmo_mesh and is_instance_valid(_gizmo_mesh):
		_gizmo_mesh.queue_free()
		_gizmo_mesh = null
	if _label and is_instance_valid(_label):
		_label.queue_free()
		_label = null
