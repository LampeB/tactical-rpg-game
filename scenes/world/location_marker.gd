extends Area2D
## Interactable location marker on the overworld map.

@export var location_data: LocationData

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _label: Label = $Label


func _ready() -> void:
	collision_layer = 4  # interactables layer
	collision_mask = 0

	if location_data:
		_sprite.texture = location_data.icon
		_label.text = location_data.display_name
		_label.visible = false
		_update_visual_state()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _update_visual_state() -> void:
	## Updates marker appearance based on unlock status.
	var is_unlocked := _check_unlocked()

	if not is_unlocked and not location_data.is_visible_when_locked:
		visible = false
	elif not is_unlocked:
		modulate = Color(0.5, 0.5, 0.5, 0.6)  # Greyed out
	else:
		modulate = Color.WHITE


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
		LocationData.LocationType.LAKE:
			_interact_lake()
			return
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
	_label.visible = true


func _on_mouse_exited() -> void:
	_label.visible = false


# === Special Interactions (Development/Testing) ===

func _interact_lake() -> void:
	## Heals all party members' HP and mana to full.
	if not GameManager.party:
		DebugLogger.log_warning("No party to heal", "LocationMarker")
		return

	var healed_count := 0

	# Heal all characters in roster (roster is Dictionary: character_id -> CharacterData)
	for char_id in GameManager.party.roster.keys():
		# Get passive tree for max HP/MP calculation
		var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()

		# Get max values and set current to max
		var max_hp: int = GameManager.party.get_max_hp(char_id, tree)
		var max_mp: int = GameManager.party.get_max_mp(char_id, tree)

		GameManager.party.set_current_hp(char_id, max_hp, tree)
		GameManager.party.set_current_mp(char_id, max_mp, tree)
		healed_count += 1

	DebugLogger.log_info("Lake healed %d characters to full HP/MP" % healed_count, "LocationMarker")
	EventBus.show_message.emit("The lake's waters restore your party to full health!")
	SaveManager.auto_save()


func _interact_cave() -> void:
	## Respawns all defeated encounters for testing.
	var flags_to_clear: Array = []

	# Find all defeated_enemy_* flags
	for flag in GameManager.story_flags.keys():
		if flag.begins_with("defeated_enemy_"):
			flags_to_clear.append(flag)

	# Clear them
	for flag in flags_to_clear:
		GameManager.story_flags.erase(flag)

	DebugLogger.log_info("Cave cleared %d defeated enemy flags" % flags_to_clear.size(), "LocationMarker")
	SaveManager.auto_save()

	# Show message - enemies will respawn on next scene load
	var message := "Cave cleared %d defeated enemy flags. Enemies will respawn when you reload the area." % flags_to_clear.size()
	EventBus.show_message.emit(message)


func _interact_town() -> void:
	## Shows NPC list for testing (placeholder implementation).
	DebugLogger.log_info("Town interaction - NPC list (placeholder)", "LocationMarker")

	# For now, just show a simple message
	# TODO: Create proper NPC selection UI
	var npc_list := [
		"Blacksmith - Weapon upgrades and repairs",
		"Merchant - Buy and sell items",
		"Innkeeper - Rest and save",
		"Priest - Blessings and healing"
	]

	var message := "Available NPCs:\n" + "\n".join(npc_list)
	EventBus.show_message.emit(message)
