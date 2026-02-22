extends "res://scenes/passive_tree/ui/tree_view.gd"
## Editor canvas for the passive skill tree. Extends the gameplay TreeView
## to add node dragging, creation, deletion, and visual connection editing.

signal node_created(position: Vector2)
signal node_deleted(node_id: String)
signal node_moved(node_id: String, new_position: Vector2)
signal connection_toggled(from_id: String, to_id: String)

const DRAG_THRESHOLD := 5.0
const ARROW_SIZE := 10.0

var _dragging_node_id: String = ""
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_started: bool = false
var _mouse_down_pos: Vector2 = Vector2.ZERO
var _connecting_from_id: String = ""
var _mouse_pos: Vector2 = Vector2.ZERO

# Editor colors
var _color_node_base := Color(0.4, 0.5, 0.6)
var _color_line_base := Color(0.45, 0.45, 0.45)
var _color_connect_line := Color(0.3, 0.9, 0.4, 0.7)


func setup_editor(tree_data: PassiveTreeData) -> void:
	_tree_data = tree_data
	_unlocked_ids.clear()
	_pending_ids.clear()
	_available_ids.clear()
	_starting_node_ids.clear()
	_selected_node_id = ""
	_hovered_node_id = ""
	_dragging_node_id = ""
	_connecting_from_id = ""
	queue_redraw()


# === Drawing ===

func _draw() -> void:
	if not _tree_data:
		return

	var scaled_radius: float = NODE_RADIUS * _zoom
	var scaled_line_width: float = maxf(LINE_WIDTH * _zoom, 1.0)
	var scaled_font_size: int = maxi(int(14.0 * _zoom), 8)
	var arrow_len: float = ARROW_SIZE * _zoom

	# Draw connection lines with arrows
	for i in range(_tree_data.nodes.size()):
		var node: PassiveNodeData = _tree_data.nodes[i]
		if not node:
			continue
		for j in range(node.prerequisites.size()):
			var prereq_id: String = node.prerequisites[j]
			var prereq_node: PassiveNodeData = _tree_data.get_node_by_id(prereq_id)
			if not prereq_node:
				continue
			var from_pos: Vector2 = _tree_to_screen(prereq_node.position)
			var to_pos: Vector2 = _tree_to_screen(node.position)
			draw_line(from_pos, to_pos, _color_line_base, scaled_line_width, true)
			# Draw arrow at midpoint pointing from prereq toward node
			_draw_arrow(from_pos, to_pos, arrow_len, _color_line_base, scaled_line_width)

	# Draw rubber-band connection line
	if not _connecting_from_id.is_empty():
		var from_node: PassiveNodeData = _tree_data.get_node_by_id(_connecting_from_id)
		if from_node:
			var from_pos: Vector2 = _tree_to_screen(from_node.position)
			draw_line(from_pos, _mouse_pos, _color_connect_line, maxf(2.0 * _zoom, 1.0), true)

	# Draw nodes
	for i in range(_tree_data.nodes.size()):
		var node: PassiveNodeData = _tree_data.nodes[i]
		if not node:
			continue
		var pos: Vector2 = _tree_to_screen(node.position)
		var is_hovered: bool = (_hovered_node_id == node.id)
		var is_selected: bool = (_selected_node_id == node.id)
		var is_connect_source: bool = (_connecting_from_id == node.id)

		var fill_color: Color = _color_node_base
		if is_connect_source:
			fill_color = _color_connect_line

		# Hover ring
		if is_hovered and not is_selected:
			draw_circle(pos, scaled_radius + 4.0 * _zoom, _color_hovered)

		# Filled circle
		draw_circle(pos, scaled_radius, fill_color)

		# Border
		if is_selected:
			_draw_circle_outline(pos, scaled_radius, _color_selected, 4.0 * _zoom)
		else:
			var border_color: Color = fill_color.lightened(0.3)
			_draw_circle_outline(pos, scaled_radius, border_color, 2.0 * _zoom)

		# Label
		if node.icon:
			var icon_size := Vector2(32, 32) * _zoom
			var icon_rect := Rect2(pos - icon_size / 2.0, icon_size)
			draw_texture_rect(node.icon, icon_rect, false)
		else:
			var font: Font = ThemeDB.fallback_font
			var abbr: String = node.display_name.left(2).to_upper()
			var text_size: Vector2 = font.get_string_size(abbr, HORIZONTAL_ALIGNMENT_CENTER, -1, scaled_font_size)
			draw_string(font, pos - Vector2(text_size.x / 2.0, -5.0 * _zoom), abbr, HORIZONTAL_ALIGNMENT_CENTER, -1, scaled_font_size, Color.WHITE)

		# Draw node ID below the circle
		var font: Font = ThemeDB.fallback_font
		var id_font_size: int = maxi(int(10.0 * _zoom), 6)
		var id_text_size: Vector2 = font.get_string_size(node.id, HORIZONTAL_ALIGNMENT_CENTER, -1, id_font_size)
		draw_string(font, pos + Vector2(-id_text_size.x / 2.0, scaled_radius + 12.0 * _zoom), node.id, HORIZONTAL_ALIGNMENT_CENTER, -1, id_font_size, Color(0.7, 0.7, 0.7, 0.8))


func _draw_arrow(from: Vector2, to: Vector2, arrow_len: float, color: Color, width: float) -> void:
	var dir: Vector2 = (to - from).normalized()
	if dir.length_squared() < 0.01:
		return
	var mid: Vector2 = (from + to) / 2.0
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = mid + dir * arrow_len * 0.5
	var left: Vector2 = mid - dir * arrow_len * 0.5 + perp * arrow_len * 0.4
	var right: Vector2 = mid - dir * arrow_len * 0.5 - perp * arrow_len * 0.4
	draw_line(tip, left, color, width, true)
	draw_line(tip, right, color, width, true)


# === Input ===

func _gui_input(event: InputEvent) -> void:
	if not _tree_data:
		return

	if event is InputEventMouseMotion:
		_mouse_pos = event.position

		if not _dragging_node_id.is_empty():
			# Dragging a node
			if not _drag_started:
				if event.position.distance_to(_mouse_down_pos) > DRAG_THRESHOLD:
					_drag_started = true
			if _drag_started:
				var node: PassiveNodeData = _tree_data.get_node_by_id(_dragging_node_id)
				if node:
					node.position = _screen_to_tree(event.position) + _drag_offset
					queue_redraw()
		elif _is_panning:
			_pan_offset += event.relative
			queue_redraw()
		else:
			# Hover detection
			var old_hover: String = _hovered_node_id
			_hovered_node_id = _get_node_at(event.position)
			if _hovered_node_id != old_hover:
				queue_redraw()

		# Redraw rubber-band line while connecting
		if not _connecting_from_id.is_empty():
			queue_redraw()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var clicked_id: String = _get_node_at(event.position)

				if event.double_click and clicked_id.is_empty():
					# Double-click on empty space — create new node
					var tree_pos: Vector2 = _screen_to_tree(event.position)
					node_created.emit(tree_pos)
					return

				if event.shift_pressed and not clicked_id.is_empty():
					# Shift+click on a node — toggle connection
					if _selected_node_id.is_empty() or _selected_node_id == clicked_id:
						# Start connection from this node
						_connecting_from_id = clicked_id
						_selected_node_id = clicked_id
						node_selected.emit(clicked_id)
						queue_redraw()
					else:
						# Complete connection: toggle prerequisite
						connection_toggled.emit(_selected_node_id, clicked_id)
						_connecting_from_id = ""
						queue_redraw()
					return

				# Clear connection mode on normal click
				_connecting_from_id = ""

				if not clicked_id.is_empty():
					# Click on node — select and prepare for drag
					_dragging_node_id = clicked_id
					_drag_started = false
					_mouse_down_pos = event.position
					var node: PassiveNodeData = _tree_data.get_node_by_id(clicked_id)
					if node:
						_drag_offset = node.position - _screen_to_tree(event.position)
					_selected_node_id = clicked_id
					node_selected.emit(clicked_id)
					queue_redraw()
				else:
					# Click on empty — deselect and start pan
					_selected_node_id = ""
					node_selected.emit("")
					_is_panning = true
					queue_redraw()
			else:
				# Left button released
				if not _dragging_node_id.is_empty() and _drag_started:
					var node: PassiveNodeData = _tree_data.get_node_by_id(_dragging_node_id)
					if node:
						node_moved.emit(_dragging_node_id, node.position)
				_dragging_node_id = ""
				_drag_started = false
				if _is_panning:
					_is_panning = false

		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				# Cancel connection mode on right click
				if not _connecting_from_id.is_empty():
					_connecting_from_id = ""
					queue_redraw()
				else:
					_is_panning = true
			else:
				_is_panning = false

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_apply_zoom(ZOOM_STEP, event.position)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_apply_zoom(-ZOOM_STEP, event.position)
