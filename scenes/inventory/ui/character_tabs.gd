extends HBoxContainer
## Tab buttons for switching between squad members' inventory grids.

signal character_selected(character_id: String)

var _current_id: String = ""
var _buttons: Dictionary = {}  ## character_id -> Button


func setup(squad: Array, roster: Dictionary) -> void:
	# Clear existing
	for child in get_children():
		child.queue_free()
	_buttons.clear()

	for i in range(squad.size()):
		var char_id: String = squad[i]
		var char_data: CharacterData = roster.get(char_id)
		if not char_data:
			continue
		var btn := Button.new()
		btn.text = char_data.display_name
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_tab_pressed.bind(char_id))
		add_child(btn)
		_buttons[char_id] = btn


func select(character_id: String) -> void:
	_current_id = character_id
	for id in _buttons:
		_buttons[id].button_pressed = (id == character_id)


func _on_tab_pressed(character_id: String) -> void:
	if character_id == _current_id:
		# Re-press the already selected tab — keep it pressed
		_buttons[character_id].button_pressed = true
		return
	select(character_id)
	character_selected.emit(character_id)
