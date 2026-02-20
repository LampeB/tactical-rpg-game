extends Area2D
## Invisible zone that triggers random encounters when player walks through.

@export var zone_data: EncounterZoneData

var _player_inside: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # detects player

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_inside = false


func is_player_inside() -> bool:
	return _player_inside


func check_encounter() -> EncounterData:
	## Checks if an encounter should trigger. Returns EncounterData or null.
	if not _player_inside or not zone_data:
		return null

	# Check if disabled by story flag
	if not zone_data.disabled_flag.is_empty() and GameManager.has_flag(zone_data.disabled_flag):
		return null

	# Roll for encounter
	if randf() < zone_data.base_encounter_chance:
		return zone_data.get_random_encounter()

	return null
