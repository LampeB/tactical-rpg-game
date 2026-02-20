extends Node
## Manages custom input bindings and persists them across sessions.

const SAVE_PATH := "user://input_bindings.json"

var custom_bindings: Dictionary = {}  ## action_name -> Array of InputEvent


func _ready() -> void:
	load_bindings()


## Loads custom bindings from save file and applies them.
func load_bindings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_error("Failed to parse input bindings JSON")
		return

	var data: Dictionary = json.data
	custom_bindings = {}

	# Deserialize and apply bindings
	for action_name in data.keys():
		var events_data: Array = data[action_name]
		var events: Array[InputEvent] = []

		for event_dict in events_data:
			var event := _deserialize_event(event_dict)
			if event:
				events.append(event)

		if events.size() > 0:
			custom_bindings[action_name] = events
			_apply_action_bindings(action_name, events)


## Saves current custom bindings to file.
func save_bindings() -> void:
	var data := {}

	for action_name in custom_bindings.keys():
		var events: Array = custom_bindings[action_name]
		var events_data: Array = []

		for event in events:
			events_data.append(_serialize_event(event))

		data[action_name] = events_data

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("Failed to open input bindings file for writing")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## Sets a new binding for an action (replaces all existing bindings).
func rebind_action(action_name: String, new_event: InputEvent) -> void:
	if not InputMap.has_action(action_name):
		push_error("Action '%s' does not exist" % action_name)
		return

	# Clear existing bindings
	InputMap.action_erase_events(action_name)

	# Add new binding
	InputMap.action_add_event(action_name, new_event)

	# Store in custom bindings
	custom_bindings[action_name] = [new_event]

	save_bindings()


## Resets an action to its default bindings.
func reset_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		return

	custom_bindings.erase(action_name)

	# Clear and reload from project settings
	InputMap.action_erase_events(action_name)
	var default_events := _get_default_action_events(action_name)
	for event in default_events:
		InputMap.action_add_event(action_name, event)

	save_bindings()


## Resets all actions to default bindings.
func reset_all_actions() -> void:
	for action_name in InputMap.get_actions():
		reset_action(action_name)


## Gets the current primary binding for an action.
func get_action_keycode(action_name: String) -> int:
	var events := InputMap.action_get_events(action_name)
	if events.size() > 0 and events[0] is InputEventKey:
		return events[0].keycode
	return 0


## Gets human-readable key name for an action.
func get_action_key_name(action_name: String) -> String:
	var keycode := get_action_keycode(action_name)
	if keycode == 0:
		return "None"
	return OS.get_keycode_string(keycode)


func _apply_action_bindings(action_name: String, events: Array) -> void:
	InputMap.action_erase_events(action_name)
	for event in events:
		InputMap.action_add_event(action_name, event)


func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {
			"type": "key",
			"keycode": event.keycode,
			"physical_keycode": event.physical_keycode,
			"key_label": event.key_label,
			"unicode": event.unicode,
			"location": event.location,
			"ctrl_pressed": event.ctrl_pressed,
			"shift_pressed": event.shift_pressed,
			"alt_pressed": event.alt_pressed,
			"meta_pressed": event.meta_pressed,
		}
	return {}


func _deserialize_event(data: Dictionary) -> InputEvent:
	if data.get("type") == "key":
		var event := InputEventKey.new()
		event.keycode = data.get("keycode", 0)
		event.physical_keycode = data.get("physical_keycode", 0)
		event.key_label = data.get("key_label", 0)
		event.unicode = data.get("unicode", 0)
		event.location = data.get("location", 0)
		event.ctrl_pressed = data.get("ctrl_pressed", false)
		event.shift_pressed = data.get("shift_pressed", false)
		event.alt_pressed = data.get("alt_pressed", false)
		event.meta_pressed = data.get("meta_pressed", false)
		return event
	return null


func _get_default_action_events(action_name: String) -> Array:
	# Get default events from ProjectSettings
	var property_name := "input/" + action_name
	if not ProjectSettings.has_setting(property_name):
		return []

	var action_data: Dictionary = ProjectSettings.get_setting(property_name)
	return action_data.get("events", [])
