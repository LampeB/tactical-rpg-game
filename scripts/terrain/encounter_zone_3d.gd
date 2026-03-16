@tool
class_name EncounterZone3D
extends Area3D
## @tool node defining a random encounter zone on the map.
## Shows a translucent blue circle gizmo in the editor.
## At runtime, detects the player and triggers random battles.
##
## NOTE: This is a class_name script — it CANNOT reference autoloads (GameManager,
## EventBus, etc.). The overworld scene script bridges those calls instead.

@export var zone_data: EncounterZoneData = null

@export var zone_radius: float = 15.0:
	set(value):
		zone_radius = value
		if is_inside_tree():
			_rebuild_gizmo()
			_rebuild_collision()

@export var encounter_rate: float = 1.0  ## Multiplier for base encounter rate

var _gizmo_mesh: MeshInstance3D = null
var _label: Label3D = null
var _collision: CollisionShape3D = null
var _player_inside: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_gizmo()
	else:
		# Runtime: invisible trigger zone
		collision_layer = 0
		collision_mask = 2  # Detects player (collision layer 2)
		_rebuild_collision()
		_clear_gizmo()

		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)


# ---------------------------------------------------------------------------
# Runtime API
# ---------------------------------------------------------------------------

func is_player_inside() -> bool:
	return _player_inside


func check_encounter() -> EncounterData:
	## Checks if a random encounter should trigger. Returns EncounterData or null.
	## NOTE: Cannot check GameManager flags here (class_name restriction).
	## The overworld should check disabled_flag before calling this.
	if not _player_inside or not zone_data:
		return null

	var chance: float = zone_data.base_encounter_chance * encounter_rate
	if randf() < chance:
		return zone_data.get_random_encounter()

	return null


# ---------------------------------------------------------------------------
# Signal callbacks (runtime only)
# ---------------------------------------------------------------------------

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		_player_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		_player_inside = false


# ---------------------------------------------------------------------------
# Editor gizmo
# ---------------------------------------------------------------------------

func _rebuild_gizmo() -> void:
	if not Engine.is_editor_hint():
		return
	_clear_gizmo()

	var disc := CylinderMesh.new()
	disc.top_radius = zone_radius
	disc.bottom_radius = zone_radius
	disc.height = 0.1
	disc.radial_segments = 32

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.5, 1.0, 0.15)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_gizmo_mesh = MeshInstance3D.new()
	_gizmo_mesh.mesh = disc
	_gizmo_mesh.material_override = mat
	_gizmo_mesh.name = "EditorGizmo"
	add_child(_gizmo_mesh)

	var zone_name: String = zone_data.zone_name if zone_data else "Encounter Zone"
	_label = Label3D.new()
	_label.text = zone_name
	_label.font_size = 24
	_label.modulate = Color(0.4, 0.7, 1.0)
	_label.position.y = 1.5
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.name = "EditorLabel"
	add_child(_label)


func _rebuild_collision() -> void:
	if Engine.is_editor_hint():
		return
	if _collision and is_instance_valid(_collision):
		_collision.queue_free()
		_collision = null

	_collision = CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = zone_radius
	shape.height = 20.0  # Tall enough to catch the player at any terrain height
	_collision.shape = shape
	_collision.name = "ZoneCollision"
	add_child(_collision)


func _clear_gizmo() -> void:
	if _gizmo_mesh and is_instance_valid(_gizmo_mesh):
		_gizmo_mesh.queue_free()
		_gizmo_mesh = null
	if _label and is_instance_valid(_label):
		_label.queue_free()
		_label = null
