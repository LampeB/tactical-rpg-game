extends Control
## A single 48x48 inventory grid cell with state-driven coloring.

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
}

var STATE_COLORS: Dictionary:
	get:
		return {
			CellState.EMPTY: UIColors.GRID_CELL_BG,
			CellState.INACTIVE: Color(0.1, 0.1, 0.1, 0.4),
			CellState.OCCUPIED: Color(0.3, 0.3, 0.4, 0.9),
			CellState.VALID_DROP: Color(0.2, 0.8, 0.2, 0.4),
			CellState.INVALID_DROP: Color(0.8, 0.2, 0.2, 0.4),
			CellState.MODIFIER_HIGHLIGHT: Color(1.0, 0.9, 0.3, 0.3),
			CellState.MODIFIER_REACH: Color(0.6, 0.6, 1.0, 0.3),
			CellState.UPGRADEABLE: Color(0.2, 0.9, 0.2, 0.6),
			CellState.PURCHASABLE: Color(0.7, 0.55, 0.0, 0.5),
		}

const BORDER_COLORS := {
	CellState.UPGRADEABLE: Color(1.0, 0.9, 0.2, 1.0),
}

var grid_position: Vector2i
var cell_state: CellState = CellState.EMPTY

@onready var _background: ColorRect = $Background
@onready var _border: ColorRect = $Border


func setup(pos: Vector2i) -> void:
	grid_position = pos
	set_state(CellState.EMPTY)


func set_state(state: CellState) -> void:
	cell_state = state
	if _background:
		_background.color = STATE_COLORS.get(state, STATE_COLORS[CellState.EMPTY])
		if state == CellState.OCCUPIED:
			# Fill the entire cell (no 1px inset) to remove grid lines under items
			_background.offset_left = 0.0
			_background.offset_top = 0.0
			_background.offset_right = 0.0
			_background.offset_bottom = 0.0
		else:
			# Restore 1px inset for visible grid lines
			_background.offset_left = 1.0
			_background.offset_top = 1.0
			_background.offset_right = -1.0
			_background.offset_bottom = -1.0
	if _border:
		if state == CellState.OCCUPIED:
			_border.visible = false
		else:
			_border.visible = true
			if BORDER_COLORS.has(state):
				_border.color = BORDER_COLORS[state]
			else:
				_border.color = UIColors.GRID_CELL_BORDER


func set_rarity_tint(color: Color) -> void:
	if _background:
		_background.color = color.darkened(0.4)
