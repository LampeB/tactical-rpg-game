extends Control
## A single inventory grid cell with state-driven visuals.
## Uses a single NinePatchRect with the cell sprite from InventoryTheme.

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

var STATE_COLORS: Dictionary:
	get:
		return {
			CellState.EMPTY: Color.WHITE,
			CellState.INACTIVE: Color(0.20, 0.15, 0.12, 0.9),
			CellState.OCCUPIED: Color(0.85, 0.85, 0.85, 1.0),
			CellState.VALID_DROP: Color(0.4, 1.0, 0.4, 0.7),
			CellState.INVALID_DROP: Color(1.0, 0.4, 0.4, 0.7),
			CellState.MODIFIER_HIGHLIGHT: Color(1.0, 0.9, 0.3, 0.6),
			CellState.MODIFIER_REACH: Color(0.6, 0.6, 1.0, 0.5),
			CellState.UPGRADEABLE: Color(0.4, 1.0, 0.4, 0.8),
			CellState.PURCHASABLE: Color(0.9, 0.7, 0.2, 0.7),
			CellState.SWAP_DROP: Color(1.0, 0.85, 0.2, 0.7),
			CellState.INGREDIENT_MATCH: Color(0.4, 0.9, 1.0, 0.7),
		}

var grid_position: Vector2i
var cell_state: CellState = CellState.EMPTY

@onready var _background: NinePatchRect = $Background


func _ready() -> void:
	var sz := Vector2(Constants.GRID_CELL_SIZE, Constants.GRID_CELL_SIZE)
	custom_minimum_size = sz
	size = sz
	_apply_theme_texture()


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


func set_state(state: CellState) -> void:
	cell_state = state
	if not _background:
		return
	_background.modulate = STATE_COLORS.get(state, Color.WHITE)


func set_rarity_tint(color: Color) -> void:
	if _background:
		color.a = 1.0
		_background.modulate = color
