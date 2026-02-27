extends PanelContainer
## Fast travel selection menu for warping to visited locations.

signal location_selected(location_data: LocationData)

@onready var _location_list: ItemList = $MarginContainer/VBoxContainer/LocationList
@onready var _confirm_btn: Button = $MarginContainer/VBoxContainer/Buttons/ConfirmButton
@onready var _cancel_btn: Button = $MarginContainer/VBoxContainer/Buttons/CancelButton

var _available_locations: Array[LocationData] = []


func _ready() -> void:
	_confirm_btn.pressed.connect(_on_confirm)
	_cancel_btn.pressed.connect(_on_cancel)
	_location_list.item_selected.connect(_on_item_selected)
	visible = false


func open_menu(all_locations: Array[LocationData]) -> void:
	## Opens the menu with filtered locations (unlocked + visited + fast-travel-enabled).
	_available_locations.clear()
	_location_list.clear()

	# Filter to unlocked + visited + fast-travel-enabled locations
	for loc in all_locations:
		if not loc.allow_fast_travel_to:
			continue

		var is_unlocked := loc.unlock_flag.is_empty() or GameManager.has_flag(loc.unlock_flag)
		if not is_unlocked:
			continue

		if loc.must_visit_first and not GameManager.has_flag("visited_" + loc.id):
			continue

		_available_locations.append(loc)
		_location_list.add_item(loc.display_name, loc.icon)

	if _available_locations.is_empty():
		_location_list.add_item("No locations available", null)
		_confirm_btn.disabled = true
	else:
		_confirm_btn.disabled = false

	visible = true


func _on_item_selected(_index: int) -> void:
	_confirm_btn.disabled = false


func _on_confirm() -> void:
	var selected_idx := _location_list.get_selected_items()
	if selected_idx.is_empty() or _available_locations.is_empty():
		return

	var location: LocationData = _available_locations[selected_idx[0]]
	location_selected.emit(location)
	visible = false


func _on_cancel() -> void:
	visible = false
	# Re-enable player input (overworld will handle this via signal)
