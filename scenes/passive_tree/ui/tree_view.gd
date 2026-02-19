extends Control
## Custom drawing control that renders the passive skill tree.
## Draws connection lines and node circles at positions defined in PassiveTreeData.
## Emits node_selected when the player clicks a node.

signal node_selected(node_id: String)
signal node_hovered(node_id: String)
signal node_exited()

const NODE_RADIUS := 28.0
const LINE_WIDTH := 3.0
const HOVER_RADIUS := 36.0

var _tree_data: PassiveTreeData = null
var _unlocked_ids: Array = []
var _hovered_node_id: String = ""
var _available_ids: Array = []  ## Nodes whose prerequisites are met

# Colors
var _color_locked := Color(0.35, 0.35, 0.35)
var _color_available := Color(0.85, 0.7, 0.2)
var _color_unlocked := Color(0.2, 0.8, 0.3)
var _color_hovered := Color(1.0, 0.9, 0.5)
var _color_line_locked := Color(0.25, 0.25, 0.25)
var _color_line_unlocked := Color(0.3, 0.65, 0.3)


func setup(tree_data: PassiveTreeData, unlocked: Array) -> void:
	_tree_data = tree_data
	_unlocked_ids = unlocked.duplicate()
	_update_available()
	queue_redraw()


func update_unlocked(unlocked: Array) -> void:
	_unlocked_ids = unlocked.duplicate()
	_update_available()
	queue_redraw()


func _update_available() -> void:
	_available_ids.clear()
	if not _tree_data:
		return
	for i in range(_tree_data.nodes.size()):
		var node: PassiveNodeData = _tree_data.nodes[i]
		if not node or _unlocked_ids.has(node.id):
			continue
		var prereqs_met: bool = true
		for j in range(node.prerequisites.size()):
			if not _unlocked_ids.has(node.prerequisites[j]):
				prereqs_met = false
				break
		if prereqs_met:
			_available_ids.append(node.id)


func _draw() -> void:
	if not _tree_data:
		return

	# Build lookup for node positions
	var positions: Dictionary = {}
	for i in range(_tree_data.nodes.size()):
		var node: PassiveNodeData = _tree_data.nodes[i]
		if node:
			positions[node.id] = node.position

	# Draw connection lines first (behind nodes)
	for i in range(_tree_data.nodes.size()):
		var node: PassiveNodeData = _tree_data.nodes[i]
		if not node:
			continue
		for j in range(node.prerequisites.size()):
			var prereq_id: String = node.prerequisites[j]
			if positions.has(prereq_id):
				var from_pos: Vector2 = positions[prereq_id]
				var to_pos: Vector2 = node.position
				var both_unlocked: bool = _unlocked_ids.has(node.id) and _unlocked_ids.has(prereq_id)
				var line_color: Color = _color_line_unlocked if both_unlocked else _color_line_locked
				draw_line(from_pos, to_pos, line_color, LINE_WIDTH, true)

	# Draw nodes
	for i in range(_tree_data.nodes.size()):
		var node: PassiveNodeData = _tree_data.nodes[i]
		if not node:
			continue
		var pos: Vector2 = node.position
		var is_unlocked: bool = _unlocked_ids.has(node.id)
		var is_available: bool = _available_ids.has(node.id)
		var is_hovered: bool = (_hovered_node_id == node.id)

		# Node fill color
		var fill_color: Color
		if is_unlocked:
			fill_color = _color_unlocked
		elif is_available:
			fill_color = _color_available
		else:
			fill_color = _color_locked

		# Draw outer ring if hovered
		if is_hovered:
			draw_circle(pos, NODE_RADIUS + 4.0, _color_hovered)

		# Draw filled circle
		draw_circle(pos, NODE_RADIUS, fill_color)

		# Draw border
		var border_color: Color = fill_color.lightened(0.3)
		_draw_circle_outline(pos, NODE_RADIUS, border_color, 2.0)

		# Draw icon if available, otherwise draw first letter
		if node.icon:
			var icon_size := Vector2(32, 32)
			var icon_rect := Rect2(pos - icon_size / 2.0, icon_size)
			draw_texture_rect(node.icon, icon_rect, false)
		else:
			# Draw abbreviated text
			var font: Font = ThemeDB.fallback_font
			var abbr: String = node.display_name.left(2).to_upper()
			var text_size: Vector2 = font.get_string_size(abbr, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
			draw_string(font, pos - Vector2(text_size.x / 2.0, -5.0), abbr, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)


func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var point_count: int = 32
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(point_count + 1):
		var angle: float = i * TAU / point_count
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	for i in range(point_count):
		draw_line(points[i], points[i + 1], color, width, true)


func _gui_input(event: InputEvent) -> void:
	if not _tree_data:
		return

	if event is InputEventMouseMotion:
		var old_hover: String = _hovered_node_id
		_hovered_node_id = _get_node_at(event.position)
		if _hovered_node_id != old_hover:
			queue_redraw()
			if not _hovered_node_id.is_empty():
				node_hovered.emit(_hovered_node_id)
			else:
				node_exited.emit()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_id: String = _get_node_at(event.position)
		if not clicked_id.is_empty():
			node_selected.emit(clicked_id)


func _get_node_at(pos: Vector2) -> String:
	if not _tree_data:
		return ""
	# Check in reverse order so topmost drawn nodes are clicked first
	for i in range(_tree_data.nodes.size() - 1, -1, -1):
		var node: PassiveNodeData = _tree_data.nodes[i]
		if node and pos.distance_to(node.position) <= HOVER_RADIUS:
			return node.id
	return ""
