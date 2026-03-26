@tool
extends Area3D
## Interactive marker that transitions to another map when the player interacts.
## Place directly in a map scene and set connection_data in the inspector.
## Shows a portal pillar in the editor. Link two markers across maps by setting
## matching connection_id / target_connection_id values — no manual coordinates needed.

@export var connection_data: MapConnection

var _name_label: Label3D = null
var _visual: Node3D = null


func _ready() -> void:
	if not Engine.is_editor_hint():
		collision_layer = 4  # interactables layer
		collision_mask = 0

	if connection_data:
		_build_visual()


func _build_visual() -> void:
	## Creates a 3D portal pillar with floating label (blue, distinct from golden locations).
	var pillar := CSGCylinder3D.new()
	pillar.name = "Portal"
	pillar.radius = 0.3
	pillar.height = 3.0
	pillar.position.y = 1.5
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.2, 0.5, 1.0, 0.7)
	pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar_mat.emission_enabled = true
	pillar_mat.emission = Color(0.2, 0.5, 1.0)
	pillar_mat.emission_energy_multiplier = 0.5
	pillar.material = pillar_mat
	add_child(pillar)
	_visual = pillar

	# Floating name label
	_name_label = Label3D.new()
	_name_label.name = "NameLabel"
	_name_label.text = connection_data.display_name
	_name_label.font_size = 48
	_name_label.position.y = 3.5
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.modulate = Color(0.5, 0.8, 1.0)
	_name_label.outline_size = 8
	_name_label.visible = false
	add_child(_name_label)

	# Collision shape (sphere for interaction)
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Constants.INTERACTION_RANGE
	collision.shape = sphere
	add_child(collision)

	if not Engine.is_editor_hint():
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)


func try_enter() -> void:
	## Attempts to transition to the target map.
	if not connection_data:
		return

	if not _check_unlocked():
		EventBus.show_message.emit("This path is locked.")
		return

	# Set target map before transitioning so the new overworld reads it in _ready()
	GameManager.current_map_id = connection_data.target_map_id
	# If linked by connection ID, store it so the target map can find the matching marker
	if not connection_data.target_connection_id.is_empty():
		GameManager.set_flag("target_connection_id", connection_data.target_connection_id)
		GameManager.set_flag("overworld_position", Vector3.ZERO)  # will be resolved on arrival
	else:
		GameManager.set_flag("target_connection_id", "")
		GameManager.set_flag("overworld_position", connection_data.target_spawn)

	var target_data: MapData = MapDatabase.get_map(connection_data.target_map_id)
	var scene_path: String = "res://scenes/world/local_map.tscn"
	if target_data and target_data.is_overworld:
		scene_path = "res://scenes/world/overworld.tscn"
	SceneManager.replace_scene(scene_path, {
		"map_id": connection_data.target_map_id,
	})


func get_display_name() -> String:
	return connection_data.display_name if connection_data else ""


func _check_unlocked() -> bool:
	if not connection_data or connection_data.unlock_flag.is_empty():
		return true
	return GameManager.has_flag(connection_data.unlock_flag)


func _on_mouse_entered() -> void:
	if _name_label:
		_name_label.visible = true


func _on_mouse_exited() -> void:
	if _name_label:
		_name_label.visible = false
