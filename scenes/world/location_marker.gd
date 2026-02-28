extends Area3D
## Interactable location marker on the overworld map (3D version).

@export var location_data: LocationData

var _name_label: Label3D = null
var _visual: Node3D = null


func _ready() -> void:
	collision_layer = 4  # interactables layer
	collision_mask = 0

	if location_data:
		_build_visual()
		_update_visual_state()


func _build_visual() -> void:
	## Creates a 3D marker with a beacon pillar and floating label.
	# Beacon pillar (golden column)
	var pillar := CSGCylinder3D.new()
	pillar.name = "Beacon"
	pillar.radius = 0.3
	pillar.height = 3.0
	pillar.position.y = 1.5
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(1.0, 0.8, 0.2, 0.7)
	pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar_mat.emission_enabled = true
	pillar_mat.emission = Color(1.0, 0.8, 0.2)
	pillar_mat.emission_energy_multiplier = 0.5
	pillar.material = pillar_mat
	add_child(pillar)
	_visual = pillar

	# Floating name label
	_name_label = Label3D.new()
	_name_label.name = "NameLabel"
	_name_label.text = location_data.display_name
	_name_label.font_size = 48
	_name_label.position.y = 3.5
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.modulate = Color(1.0, 0.9, 0.5)
	_name_label.outline_size = 8
	_name_label.visible = false
	add_child(_name_label)

	# Collision shape (sphere for interaction)
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Constants.INTERACTION_RANGE
	collision.shape = sphere
	add_child(collision)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _update_visual_state() -> void:
	## Updates marker appearance based on unlock status.
	var is_unlocked := _check_unlocked()

	if not is_unlocked and not location_data.is_visible_when_locked:
		visible = false
	elif not is_unlocked and _visual:
		# Grey out the beacon
		var mat: StandardMaterial3D = _visual.material
		if mat:
			mat.albedo_color = Color(0.5, 0.5, 0.5, 0.4)
			mat.emission_enabled = false


func _check_unlocked() -> bool:
	## Returns true if this location is accessible.
	if location_data.unlock_flag.is_empty():
		return true
	return GameManager.has_flag(location_data.unlock_flag)


func get_location_data() -> LocationData:
	return location_data


func try_enter() -> void:
	## Attempts to enter this location. Shows message if locked, otherwise performs interaction.
	if not _check_unlocked():
		EventBus.show_message.emit("This location is locked.")
		return

	# Handle special location types
	match location_data.location_type:
		LocationData.LocationType.CAVE:
			_interact_cave()
			return
		LocationData.LocationType.TOWN:
			_interact_town()
			return

	# Default: Transition to location scene
	if not location_data.scene_path.is_empty():
		SceneManager.push_scene(location_data.scene_path, {
			"from_overworld": true,
			"entrance": location_data.entrance_position
		})

		# Mark as visited for fast travel
		if location_data.must_visit_first:
			GameManager.set_flag("visited_" + location_data.id)


func _on_mouse_entered() -> void:
	if _name_label:
		_name_label.visible = true


func _on_mouse_exited() -> void:
	if _name_label:
		_name_label.visible = false


# === Special Interactions (Development/Testing) ===


func _interact_cave() -> void:
	## Respawns all defeated encounters for testing.
	var flags_to_clear: Array = []

	for flag in GameManager.story_flags.keys():
		if flag.begins_with("defeated_enemy_"):
			flags_to_clear.append(flag)

	for flag in flags_to_clear:
		GameManager.story_flags.erase(flag)

	DebugLogger.log_info("Cave cleared %d defeated enemy flags" % flags_to_clear.size(), "LocationMarker")
	SaveManager.auto_save()

	var message := "Cave cleared %d defeated enemy flags. Enemies will respawn when you reload the area." % flags_to_clear.size()
	EventBus.show_message.emit(message)


func _interact_town() -> void:
	## Shows NPC list for testing (placeholder implementation).
	DebugLogger.log_info("Town interaction - NPC list (placeholder)", "LocationMarker")

	var npc_list := [
		"Blacksmith - Weapon upgrades and repairs",
		"Merchant - Buy and sell items",
		"Innkeeper - Rest and save",
		"Priest - Blessings and healing"
	]

	var message := "Available NPCs:\n" + "\n".join(npc_list)
	EventBus.show_message.emit(message)
