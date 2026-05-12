extends PanelContainer
## A single grid cell in the stash showing an item's icon.

signal clicked(index: int)
signal hovered(item: ItemData, global_pos: Vector2)
signal exited()
signal use_requested(index: int)
signal discard_requested(index: int)

var item_data: ItemData
var index: int
var _is_returnable: bool = false


func _ready() -> void:
	_restore_base_style()


func _restore_base_style() -> void:
	var slot_colors: Array = Constants.RARITY_SLOT_COLORS.get(
		item_data.rarity if item_data else Enums.Rarity.COMMON, [])
	var stripe_color: Color = slot_colors[1] if slot_colors.size() >= 2 else Color(0.45, 0.40, 0.33, 1.0)
	stripe_color.a = 1.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.91, 0.87, 0.80, 1.0)
	style.border_color = stripe_color
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 4
	style.content_margin_left = 2.0
	style.content_margin_top = 2.0
	style.content_margin_right = 2.0
	style.content_margin_bottom = 2.0
	add_theme_stylebox_override("panel", style)


func setup(item: ItemData, idx: int, is_returnable: bool = false) -> void:
	item_data = item
	index = idx
	_is_returnable = is_returnable
	$Icon.texture = item.icon
	tooltip_text = item.display_name
	_restore_base_style()
	if _is_returnable:
		self_modulate = Color(1.0, 0.9, 0.7)
	else:
		self_modulate = Color.WHITE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)
	if event is InputEventMouseMotion:
		hovered.emit(item_data, event.global_position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		exited.emit()


func set_upgradeable_highlight(enabled: bool) -> void:
	if enabled:
		self_modulate = Color(0.5, 1.0, 0.5)
		add_theme_stylebox_override("panel", _create_upgradeable_style())
	else:
		if _is_returnable:
			self_modulate = Color(1.0, 0.9, 0.7)
		else:
			self_modulate = Color.WHITE
		_restore_base_style()


func set_ingredient_highlight(enabled: bool) -> void:
	if enabled:
		self_modulate = Color(0.5, 0.9, 1.0)
	else:
		if _is_returnable:
			self_modulate = Color(1.0, 0.9, 0.7)
		else:
			self_modulate = Color.WHITE


func _create_upgradeable_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 0.2, 0.8)
	style.border_color = Color(1.0, 0.9, 0.2, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 1.0
	style.content_margin_top = 1.0
	style.content_margin_right = 1.0
	style.content_margin_bottom = 1.0
	return style
