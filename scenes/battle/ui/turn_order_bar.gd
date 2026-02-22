extends PanelContainer
## Displays the next 10 turns in the turn order with visual indicators.

const ACTIVE_BG_COLOR: Color = Color(1.0, 0.84, 0.0, 0.3)
const ACTIVE_BORDER_COLOR: Color = Color(1.0, 0.84, 0.0, 0.8)
const PLAYER_BG_COLOR: Color = Color(0.2, 0.4, 0.6, 0.4)
const PLAYER_BORDER_COLOR: Color = Color(0.4, 0.7, 1.0, 0.6)
const ENEMY_BG_COLOR: Color = Color(0.6, 0.2, 0.2, 0.4)
const ENEMY_BORDER_COLOR: Color = Color(1.0, 0.4, 0.4, 0.6)

@onready var _turn_list: HBoxContainer = $MarginContainer/VBox/TurnList

var _turn_slots: Array = []


func refresh(turn_order: Array, current_entity: CombatEntity) -> void:
	# Clear existing turn slots
	for child in _turn_list.get_children():
		child.queue_free()
	_turn_slots.clear()

	# Create visual slot for each upcoming turn
	for i in range(turn_order.size()):
		var entity: CombatEntity = turn_order[i]
		var is_current: bool = (entity == current_entity)  # Check if this is the active entity

		# Create turn slot container with size based on position
		var slot: PanelContainer = PanelContainer.new()
		var base_width: float = 80.0
		var base_height: float = 60.0
		if i == 0:
			# First slot: 50% bigger (both width and height)
			slot.custom_minimum_size = Vector2(base_width * 1.5, base_height * 1.5)
		elif i == 1:
			# Second slot: 25% bigger (both width and height)
			slot.custom_minimum_size = Vector2(base_width * 1.25, base_height * 1.25)
		else:
			# Rest: normal size
			slot.custom_minimum_size = Vector2(base_width, base_height)

		# Create background style
		var style: StyleBoxFlat = StyleBoxFlat.new()
		if is_current:
			style.bg_color = ACTIVE_BG_COLOR
			style.border_color = ACTIVE_BORDER_COLOR
		elif entity.is_player:
			style.bg_color = PLAYER_BG_COLOR
			style.border_color = PLAYER_BORDER_COLOR
		else:
			style.bg_color = ENEMY_BG_COLOR
			style.border_color = ENEMY_BORDER_COLOR

		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4

		slot.add_theme_stylebox_override("panel", style)

		# Create content
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		slot.add_child(vbox)

		# Turn number
		var number_label: Label = Label.new()
		number_label.text = str(i + 1)
		number_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_SMALL)
		number_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(number_label)

		# Entity name
		var name_label: Label = Label.new()
		name_label.text = entity.entity_name
		name_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_DETAIL)
		if is_current:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1))
		elif entity.is_player:
			name_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1))
		else:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6, 1))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size = Vector2(76, 0)
		vbox.add_child(name_label)

		_turn_list.add_child(slot)
		_turn_slots.append(slot)
