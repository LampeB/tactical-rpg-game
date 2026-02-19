extends HBoxContainer
## Displays the turn order as a horizontal row of name indicators.

const ACTIVE_COLOR: Color = Color(1.0, 0.84, 0.0)
const PLAYER_COLOR: Color = Color(0.4, 0.7, 1.0)
const ENEMY_COLOR: Color = Color(1.0, 0.4, 0.4)
const DEAD_COLOR: Color = Color(0.4, 0.4, 0.4, 0.5)

var _labels: Array = []


func refresh(turn_order: Array, current_entity: CombatEntity) -> void:
	for child in get_children():
		child.queue_free()
	_labels.clear()

	for i in range(turn_order.size()):
		var entity: CombatEntity = turn_order[i]
		var label: Label = Label.new()
		label.text = entity.entity_name
		label.add_theme_font_size_override("font_size", 13)

		if entity.is_dead:
			label.add_theme_color_override("font_color", DEAD_COLOR)
		elif entity == current_entity:
			label.add_theme_color_override("font_color", ACTIVE_COLOR)
		elif entity.is_player:
			label.add_theme_color_override("font_color", PLAYER_COLOR)
		else:
			label.add_theme_color_override("font_color", ENEMY_COLOR)

		add_child(label)
		_labels.append(label)

		# Add separator arrow
		if entity != turn_order.back():
			var arrow: Label = Label.new()
			arrow.text = ">"
			arrow.add_theme_font_size_override("font_size", 13)
			arrow.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			add_child(arrow)
