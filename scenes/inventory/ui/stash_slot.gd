extends PanelContainer
## A single row in the stash list showing an item's icon and name.

signal clicked(index: int)
signal hovered(item: ItemData, global_pos: Vector2)
signal exited()
signal use_requested(index: int)

var item_data: ItemData
var index: int
var _use_button: Button = null
var _is_returnable: bool = false


func setup(item: ItemData, idx: int, is_returnable: bool = false) -> void:
	item_data = item
	index = idx
	_is_returnable = is_returnable

	$HBox/Icon.texture = item.icon
	$HBox/NameLabel.text = item.display_name
	var rarity_color: Color = Constants.RARITY_COLORS.get(item.rarity, Color.WHITE)
	$HBox/NameLabel.add_theme_color_override("font_color", rarity_color)
	$HBox/TypeLabel.text = _get_type_text(item.item_type)

	# Tint returnable items amber
	if _is_returnable:
		self_modulate = Color(1.0, 0.9, 0.7)
	else:
		self_modulate = Color.WHITE

	# Add "Use" button for consumables with use_skill
	if item.item_type == Enums.ItemType.CONSUMABLE and item.use_skill:
		_use_button = Button.new()
		_use_button.text = "Use"
		_use_button.custom_minimum_size = Vector2(60, 0)
		_use_button.pressed.connect(_on_use_button_pressed)
		$HBox.add_child(_use_button)


func _get_type_text(item_type: Enums.ItemType) -> String:
	match item_type:
		Enums.ItemType.ACTIVE_TOOL: return "Tool"
		Enums.ItemType.PASSIVE_GEAR: return "Gear"
		Enums.ItemType.MODIFIER: return "Gem"
		Enums.ItemType.CONSUMABLE: return "Consumable"
		Enums.ItemType.MATERIAL: return "Material"
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)
	if event is InputEventMouseMotion:
		hovered.emit(item_data, event.global_position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		exited.emit()


func _on_use_button_pressed() -> void:
	use_requested.emit(index)


func set_upgradeable_highlight(enabled: bool) -> void:
	## Highlights this slot as upgradeable with green background and yellow outline
	if enabled:
		# Green tint with yellow outline
		self_modulate = Color(0.5, 1.0, 0.5)  # Brighter green
		add_theme_stylebox_override("panel", _create_upgradeable_style())
	else:
		# Reset to default
		if _is_returnable:
			self_modulate = Color(1.0, 0.9, 0.7)
		else:
			self_modulate = Color.WHITE
		remove_theme_stylebox_override("panel")


func _create_upgradeable_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 0.2, 0.8)  # Dark green background
	style.border_color = Color(1.0, 0.9, 0.2, 1.0)  # Yellow outline
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
