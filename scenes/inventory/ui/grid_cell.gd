extends Control
## A single inventory grid cell. Draws itself via _draw() — no sprite dependency.

enum CellState {
	EMPTY,
	INACTIVE,
	OCCUPIED,
	VALID_DROP,
	INVALID_DROP,
	MODIFIER_HIGHLIGHT,
	MODIFIER_REACH,
	UPGRADEABLE,
	PURCHASABLE,
	SWAP_DROP,
	INGREDIENT_MATCH,
}

var grid_position: Vector2i
var cell_state: CellState = CellState.EMPTY

var _fill: Color = Color(0.91, 0.87, 0.80, 1.0)
var _border: Color = Color(0.68, 0.61, 0.52, 1.0)

var _glow_overlay: PanelContainer
var _glow_style: StyleBoxFlat
var _glow_tween: Tween


func _ready() -> void:
	var sz := Vector2(Constants.GRID_CELL_SIZE, Constants.GRID_CELL_SIZE)
	custom_minimum_size = sz
	size = sz

	_glow_style = StyleBoxFlat.new()
	_glow_style.bg_color = Color.TRANSPARENT
	_glow_style.border_color = Color(0.85, 0.66, 0.34, 1.0)
	_glow_style.set_border_width_all(2)
	_glow_style.set_corner_radius_all(1)

	_glow_overlay = PanelContainer.new()
	_glow_overlay.name = "GlowOverlay"
	_glow_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_overlay.add_theme_stylebox_override("panel", _glow_style)
	_glow_overlay.visible = false
	add_child(_glow_overlay)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _border)
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2.0, 2.0)), _fill)


func setup(pos: Vector2i) -> void:
	grid_position = pos
	set_state(CellState.EMPTY)


func set_state(new_state: CellState) -> void:
	cell_state = new_state
	match new_state:
		CellState.EMPTY:
			_fill   = Color(0.91, 0.87, 0.80, 1.0)
			_border = Color(0.68, 0.61, 0.52, 1.0)
		CellState.INACTIVE:
			_fill   = Color(0.76, 0.72, 0.66, 1.0)
			_border = Color(0.56, 0.51, 0.45, 1.0)
		CellState.OCCUPIED:
			_fill   = Color(0.88, 0.84, 0.77, 1.0)
			_border = Color(0.65, 0.58, 0.50, 1.0)
		CellState.VALID_DROP:
			_fill   = Color(0.68, 0.85, 0.68, 1.0)
			_border = Color(0.38, 0.62, 0.38, 1.0)
		CellState.INVALID_DROP:
			_fill   = Color(0.88, 0.62, 0.57, 1.0)
			_border = Color(0.68, 0.32, 0.28, 1.0)
		CellState.MODIFIER_HIGHLIGHT:
			_fill   = Color(0.80, 0.72, 0.42, 0.85)
			_border = Color(0.60, 0.52, 0.28, 1.0)
		CellState.MODIFIER_REACH:
			_fill   = Color(0.70, 0.76, 0.90, 0.85)
			_border = Color(0.40, 0.48, 0.72, 1.0)
		CellState.UPGRADEABLE:
			_fill   = Color(0.68, 0.85, 0.68, 1.0)
			_border = Color(0.38, 0.62, 0.38, 1.0)
		CellState.PURCHASABLE:
			_fill   = Color(0.90, 0.80, 0.52, 1.0)
			_border = Color(0.70, 0.58, 0.28, 1.0)
		CellState.SWAP_DROP:
			_fill   = Color(0.90, 0.86, 0.65, 0.95)
			_border = Color(0.70, 0.65, 0.35, 1.0)
		CellState.INGREDIENT_MATCH:
			_fill   = Color(0.65, 0.85, 0.88, 0.95)
			_border = Color(0.35, 0.62, 0.70, 1.0)
		_:
			_fill   = Color(0.91, 0.87, 0.80, 1.0)
			_border = Color(0.68, 0.61, 0.52, 1.0)
	queue_redraw()


func set_rarity_tint(_color: Color) -> void:
	pass  # Item visuals cover cells; tinting cells is no longer used.


func set_glow(enabled: bool) -> void:
	if not _glow_overlay:
		return
	if enabled:
		_glow_overlay.visible = true
		if _glow_tween:
			_glow_tween.kill()
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(_glow_style, "border_color", Color(0.85, 0.66, 0.34, 1.0), 0.5)
		_glow_tween.tween_property(_glow_style, "border_color", Color(0.69, 0.53, 0.27, 1.0), 0.5)
	else:
		_glow_overlay.visible = false
		if _glow_tween:
			_glow_tween.kill()
			_glow_tween = null
