extends Control
## A single inventory grid cell with sprite-based visuals and glow effect.
## Uses NinePatchRect with InventoryTheme sprites. Glow is an animated border overlay.

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

var _background: NinePatchRect
var _glow_overlay: PanelContainer
var _glow_style: StyleBoxFlat
var _glow_tween: Tween


func _ready() -> void:
	var sz := Vector2(Constants.GRID_CELL_SIZE, Constants.GRID_CELL_SIZE)
	custom_minimum_size = sz
	size = sz

	# Background — the main cell visual (sprite from theme)
	_background = NinePatchRect.new()
	_background.name = "Background"
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_apply_theme_texture()

	# Glow overlay — animated border, hidden by default
	_glow_style = StyleBoxFlat.new()
	_glow_style.bg_color = Color.TRANSPARENT
	_glow_style.border_color = Color(1.0, 0.85, 0.2, 1.0)
	_glow_style.set_border_width_all(2)
	_glow_style.set_corner_radius_all(1)

	_glow_overlay = PanelContainer.new()
	_glow_overlay.name = "GlowOverlay"
	_glow_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_overlay.add_theme_stylebox_override("panel", _glow_style)
	_glow_overlay.visible = false
	add_child(_glow_overlay)


func _apply_theme_texture() -> void:
	var cell_tex: Texture2D = InventoryTheme.get_cell_texture()
	if not cell_tex or not _background:
		return
	_background.texture = cell_tex
	var m: int = 3
	_background.patch_margin_left = m
	_background.patch_margin_top = m
	_background.patch_margin_right = m
	_background.patch_margin_bottom = m


func setup(pos: Vector2i) -> void:
	grid_position = pos
	set_state(CellState.EMPTY)


func set_state(new_state: CellState) -> void:
	cell_state = new_state
	if not _background:
		return

	match new_state:
		CellState.EMPTY:
			_background.modulate = Color.WHITE
		CellState.INACTIVE:
			_background.modulate = Color(0.20, 0.15, 0.12, 0.9)
		CellState.OCCUPIED:
			_background.modulate = Color(0.85, 0.85, 0.85, 1.0)
		CellState.VALID_DROP:
			_background.modulate = Color(0.4, 1.0, 0.4, 0.7)
		CellState.INVALID_DROP:
			_background.modulate = Color(1.0, 0.4, 0.4, 0.7)
		CellState.MODIFIER_HIGHLIGHT:
			_background.modulate = Color(1.0, 0.9, 0.3, 0.6)
		CellState.MODIFIER_REACH:
			_background.modulate = Color(0.6, 0.6, 1.0, 0.5)
		CellState.UPGRADEABLE:
			_background.modulate = Color(0.4, 1.0, 0.4, 0.8)
		CellState.PURCHASABLE:
			_background.modulate = Color(0.9, 0.7, 0.2, 0.7)
		CellState.SWAP_DROP:
			_background.modulate = Color(1.0, 0.85, 0.2, 0.7)
		CellState.INGREDIENT_MATCH:
			_background.modulate = Color(0.4, 0.9, 1.0, 0.7)
		_:
			_background.modulate = Color.WHITE


func set_rarity_tint(color: Color) -> void:
	if _background:
		color.a = 1.0
		_background.modulate = color


func set_glow(enabled: bool) -> void:
	if not _glow_overlay:
		return

	if enabled:
		_glow_overlay.visible = true
		# Start animated border color tween
		if _glow_tween:
			_glow_tween.kill()
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(_glow_style, "border_color", Color(1.0, 0.85, 0.2, 1.0), 0.5)
		_glow_tween.tween_property(_glow_style, "border_color", Color(1.0, 0.55, 0.0, 1.0), 0.5)
	else:
		_glow_overlay.visible = false
		if _glow_tween:
			_glow_tween.kill()
			_glow_tween = null
