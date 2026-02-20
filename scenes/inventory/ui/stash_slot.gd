extends PanelContainer
## A single row in the stash list showing an item's icon and name.

signal clicked(index: int)
signal hovered(item: ItemData, global_pos: Vector2)
signal exited()
signal use_requested(index: int)

var item_data: ItemData
var index: int
var _use_button: Button = null


func setup(item: ItemData, idx: int) -> void:
	item_data = item
	index = idx
	$HBox/Icon.texture = item.icon
	$HBox/NameLabel.text = item.display_name
	var rarity_color: Color = Constants.RARITY_COLORS.get(item.rarity, Color.WHITE)
	$HBox/NameLabel.add_theme_color_override("font_color", rarity_color)
	$HBox/TypeLabel.text = _get_type_text(item.item_type)

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
