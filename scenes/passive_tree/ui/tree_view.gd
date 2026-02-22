extends Control
## Custom drawing control that renders the unified passive skill tree.
## Supports zoom (mouse wheel), pan (left-drag on empty / right-drag / middle-drag),
## pending node selection (double-click), and single-click node info.

signal node_selected(node_id: String)
signal node_double_clicked(node_id: String)
signal node_hovered(node_id: String)
signal node_exited()

const NODE_RADIUS := 28.0
const LINE_WIDTH := 3.0
const HOVER_RADIUS := 36.0
const ZOOM_MIN := 0.3
const ZOOM_MAX := 2.5
const ZOOM_STEP := 0.1

var _tree_data: PassiveTreeData = null
var _unlocked_ids: Array = []
var _starting_node_ids: Array = []  ## Root nodes available for this character
var _pending_ids: Array = []  ## Nodes queued for batch unlock
var _hovered_node_id: String = ""
var _selected_node_id: String = ""
var _available_ids: Array = []  ## Nodes whose prerequisites are met

# Zoom & Pan
var _zoom: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _is_panning: bool = false

# Colors
var _color_locked := Color(0.35, 0.35, 0.35)
var _color_available := Color(0.85, 0.7, 0.2)
var _color_unlocked := Color(0.2, 0.8, 0.3)
var _color_pending := Color(0.3, 0.7, 1.0)  ## Cyan for pending unlock
var _color_hovered := Color(1.0, 0.9, 0.5)
var _color_selected := Color(0.9, 0.5, 1.0)  ## Purple/magenta for selection
var _color_line_locked := Color(0.25, 0.25, 0.25)
var _color_line_unlocked := Color(0.3, 0.65, 0.3)
var _color_line_pending := Color(0.25, 0.55, 0.8)


func setup(tree_data: PassiveTreeData, unlocked: Array, starting_nodes: Array = []) -> void:
	_tree_data = tree_data
	_unlocked_ids = unlocked.duplicate()
	_starting_node_ids = starting_nodes.duplicate()
	_pending_ids.clear()
	_update_available()
	queue_redraw()


func update_unlocked(unlocked: Array) -> void:
	_unlocked_ids = unlocked.duplicate()
	_update_available()
	queue_redraw()


func set_selected(node_id: String) -> void:
	_selected_node_id = node_id
	queue_redraw()


func set_pending(pending: Array) -> void:
	_pending_ids = pending.duplicate()
	_update_available()
	queue_redraw()


func _update_available() -> void:
	_available_ids.clear()
	if not _tree_data:
		return
	# Treat unlocked + pending as "resolved" for prerequisite checking
	var resolved: Array = _unlocked_ids.duplicate()
	resolved.append_array(_pending_ids)

	for i in range(_tree_data.nodes.size()):
		var node: PassiveNodeData = _tree_data.nodes[i]
		if not node or _unlocked_ids.has(node.id) or _pending_ids.has(node.id):
			continue

		if node.prerequisites.is_empty():
			# Root node — only available if in this character's starting nodes
			if _starting_node_ids.has(node.id):
				_available_ids.append(node.id)
		else:
			# Non-root node — check prerequisites based on mode
			var prereqs_met: bool
			if node.prerequisite_mode == 1:
				# ANY mode: at least one prerequisite must be resolved
				prereqs_met = false
				for j in range(node.prerequisites.size()):
					if resolved.has(node.prerequisites[j]):
						prereqs_met = true
						break
			else:
				# ALL mode (default): every prerequisite must be resolved
				prereqs_met = true
				for j in range(node.prerequisites.size()):
					if not resolved.has(node.prerequisites[j]):
						prereqs_met = false
						break
			if prereqs_met:
				_available_ids.append(node.id)


# === Coordinate transforms ===

func _tree_to_screen(tree_pos: Vector2) -> Vector2:
	return tree_pos * _zoom + _pan_offset


func _screen_to_tree(screen_pos: Vector2) -> Vector2:
	return (screen_pos - _pan_offset) / _zoom


# === Drawing ===

func _draw() -> void:
	if not _tree_data:
		return

	var scaled_radius: float = NODE_RADIUS * _zoom
	var scaled_line_width: float = maxf(LINE_WIDTH * _zoom, 1.0)
	var scaled_font_size: int = maxi(int(14.0 * _zoom), 8)

	# Draw connection lines first (behind nodes)
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
			var both_unlocked: bool = _unlocked_ids.has(node.id) and _unlocked_ids.has(prereq_id)
			var both_pending_or_unlocked: bool = (_unlocked_ids.has(node.id) or _pending_ids.has(node.id)) and (_unlocked_ids.has(prereq_id) or _pending_ids.has(prereq_id))
			var line_color: Color
			if both_unlocked:
				line_color = _color_line_unlocked
			elif both_pending_or_unlocked:
				line_color = _color_line_pending
			else:
				line_color = _color_line_locked
			draw_line(from_pos, to_pos, line_color, scaled_line_width, true)

	# Draw nodes
	for i in range(_tree_data.nodes.size()):
		var node: PassiveNodeData = _tree_data.nodes[i]
		if not node:
			continue
		var pos: Vector2 = _tree_to_screen(node.position)
		var is_unlocked: bool = _unlocked_ids.has(node.id)
		var is_pending: bool = _pending_ids.has(node.id)
		var is_available: bool = _available_ids.has(node.id)
		var is_hovered: bool = (_hovered_node_id == node.id)
		var is_selected: bool = (_selected_node_id == node.id)

		# Node fill color
		var fill_color: Color
		if is_unlocked:
			fill_color = _color_unlocked
		elif is_pending:
			fill_color = _color_pending
		elif is_available:
			fill_color = _color_available
		else:
			fill_color = _color_locked

		# Draw outer ring if hovered (but not if selected)
		if is_hovered and not is_selected:
			draw_circle(pos, scaled_radius + 4.0 * _zoom, _color_hovered)

		# Draw filled circle
		draw_circle(pos, scaled_radius, fill_color)

		# Draw border (thicker and colored if selected)
		if is_selected:
			_draw_circle_outline(pos, scaled_radius, _color_selected, 4.0 * _zoom)
		else:
			var border_color: Color = fill_color.lightened(0.3)
			_draw_circle_outline(pos, scaled_radius, border_color, 2.0 * _zoom)

		# Draw icon if available, otherwise draw first letter
		if node.icon:
			var icon_size := Vector2(32, 32) * _zoom
			var icon_rect := Rect2(pos - icon_size / 2.0, icon_size)
			draw_texture_rect(node.icon, icon_rect, false)
		else:
			# Draw abbreviated text
			var font: Font = ThemeDB.fallback_font
			var abbr: String = node.display_name.left(2).to_upper()
			var text_size: Vector2 = font.get_string_size(abbr, HORIZONTAL_ALIGNMENT_CENTER, -1, scaled_font_size)
			draw_string(font, pos - Vector2(text_size.x / 2.0, -5.0 * _zoom), abbr, HORIZONTAL_ALIGNMENT_CENTER, -1, scaled_font_size, Color.WHITE)


func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var point_count: int = 32
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(point_count + 1):
		var angle: float = i * TAU / point_count
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	for i in range(point_count):
		draw_line(points[i], points[i + 1], color, width, true)


# === Input ===

func _gui_input(event: InputEvent) -> void:
	if not _tree_data:
		return

	if event is InputEventMouseMotion:
		if _is_panning:
			_pan_offset += event.relative
			queue_redraw()
		else:
			var old_hover: String = _hovered_node_id
			_hovered_node_id = _get_node_at(event.position)
			if _hovered_node_id != old_hover:
				queue_redraw()
				if not _hovered_node_id.is_empty():
					node_hovered.emit(_hovered_node_id)
				else:
					node_exited.emit()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var clicked_id: String = _get_node_at(event.position)
				if event.double_click and not clicked_id.is_empty():
					# Double-click on a node — queue/unqueue for batch unlock
					node_double_clicked.emit(clicked_id)
				elif not clicked_id.is_empty():
					# Single click on node — select it for info
					node_selected.emit(clicked_id)
				else:
					# Click on empty space — start panning
					_is_panning = true
			else:
				# Left button released
				if _is_panning:
					_is_panning = false

		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_apply_zoom(ZOOM_STEP, event.position)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_apply_zoom(-ZOOM_STEP, event.position)


func _apply_zoom(delta: float, cursor_pos: Vector2) -> void:
	var old_zoom: float = _zoom
	_zoom = clampf(_zoom + delta, ZOOM_MIN, ZOOM_MAX)
	if _zoom == old_zoom:
		return
	# Keep the point under cursor fixed: adjust pan offset
	var tree_pos: Vector2 = (cursor_pos - _pan_offset) / old_zoom
	_pan_offset = cursor_pos - tree_pos * _zoom
	queue_redraw()


func _get_node_at(screen_pos: Vector2) -> String:
	if not _tree_data:
		return ""
	var tree_pos: Vector2 = _screen_to_tree(screen_pos)
	# Check in reverse order so topmost drawn nodes are clicked first
	for i in range(_tree_data.nodes.size() - 1, -1, -1):
		var node: PassiveNodeData = _tree_data.nodes[i]
		if node and tree_pos.distance_to(node.position) <= HOVER_RADIUS:
			return node.id
	return ""
