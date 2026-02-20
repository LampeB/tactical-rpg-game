extends Control
## Settings menu for configuring game options and keybindings.

@onready var _keybind_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/KeybindContainer
@onready var _rebind_popup: Panel = $RebindPopup
@onready var _rebind_label: Label = $RebindPopup/MarginContainer/VBoxContainer/Label
@onready var _rebind_key_label: Label = $RebindPopup/MarginContainer/VBoxContainer/KeyLabel

var _waiting_for_input: bool = false
var _current_action: String = ""

# Friendly names for actions
const ACTION_NAMES := {
	"move_up": "Move Up",
	"move_down": "Move Down",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"interact": "Interact",
	"open_inventory": "Open Inventory",
	"escape": "Menu / Cancel",
	"rotate_item": "Rotate Item",
	"fast_travel": "Fast Travel",
}


func _ready() -> void:
	_populate_keybinds()
	_rebind_popup.hide()


func _populate_keybinds() -> void:
	# Clear existing children
	for child in _keybind_container.get_children():
		child.queue_free()

	# Create rows for each action
	for action_name in ACTION_NAMES.keys():
		var row := _create_keybind_row(action_name)
		_keybind_container.add_child(row)


func _create_keybind_row(action_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	# Action name label
	var name_label := Label.new()
	name_label.text = ACTION_NAMES[action_name]
	name_label.custom_minimum_size = Vector2(200, 0)
	row.add_child(name_label)

	# Current key label
	var key_label := Label.new()
	key_label.text = InputManager.get_action_key_name(action_name)
	key_label.custom_minimum_size = Vector2(150, 0)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(key_label)

	# Rebind button
	var rebind_btn := Button.new()
	rebind_btn.text = "Rebind"
	rebind_btn.custom_minimum_size = Vector2(100, 0)
	rebind_btn.pressed.connect(_on_rebind_pressed.bind(action_name, key_label))
	row.add_child(rebind_btn)

	# Reset button
	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.custom_minimum_size = Vector2(100, 0)
	reset_btn.pressed.connect(_on_reset_pressed.bind(action_name, key_label))
	row.add_child(reset_btn)

	return row


func _on_rebind_pressed(action_name: String, key_label: Label) -> void:
	_current_action = action_name
	_waiting_for_input = true

	_rebind_label.text = "Press a key for:\n%s" % ACTION_NAMES[action_name]
	_rebind_key_label.text = ""
	_rebind_popup.show()


func _on_reset_pressed(action_name: String, key_label: Label) -> void:
	InputManager.reset_action(action_name)
	key_label.text = InputManager.get_action_key_name(action_name)


func _input(event: InputEvent) -> void:
	if not _waiting_for_input:
		return

	if event is InputEventKey and event.pressed:
		# Apply the new binding
		InputManager.rebind_action(_current_action, event)

		# Update UI
		_rebind_key_label.text = "Bound to: %s" % OS.get_keycode_string(event.keycode)

		# Close popup after a short delay
		await get_tree().create_timer(0.5).timeout
		_waiting_for_input = false
		_rebind_popup.hide()

		# Refresh the keybind list
		_populate_keybinds()

		get_viewport().set_input_as_handled()


func _on_reset_all_pressed() -> void:
	InputManager.reset_all_actions()
	_populate_keybinds()


func _on_back_pressed() -> void:
	SceneManager.pop_scene()
