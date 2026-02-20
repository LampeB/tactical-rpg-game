extends Control
## A single 48x48 inventory grid cell with state-driven coloring.

enum CellState {
	EMPTY,
	INACTIVE,
	OCCUPIED,
	VALID_DROP,
	INVALID_DROP,
	MODIFIER_HIGHLIGHT,
	UPGRADEABLE,
}

const STATE_COLORS := {
	CellState.EMPTY: Color(0.2, 0.2, 0.3, 0.8),
	CellState.INACTIVE: Color(0.1, 0.1, 0.1, 0.4),
	CellState.OCCUPIED: Color(0.3, 0.3, 0.4, 0.9),
	CellState.VALID_DROP: Color(0.2, 0.8, 0.2, 0.4),
	CellState.INVALID_DROP: Color(0.8, 0.2, 0.2, 0.4),
	CellState.MODIFIER_HIGHLIGHT: Color(1.0, 0.9, 0.3, 0.3),
	CellState.UPGRADEABLE: Color(0.2, 0.9, 0.2, 0.6),  # Green background
}

const BORDER_COLORS := {
	CellState.UPGRADEABLE: Color(1.0, 0.9, 0.2, 1.0),  # Yellow border for upgradeable
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
	if _border:
		# Apply special border color for upgradeable state
		if BORDER_COLORS.has(state):
			_border.color = BORDER_COLORS[state]
		else:
			_border.color = Color(0.4, 0.4, 0.5, 1.0)  # Default border


func set_rarity_tint(color: Color) -> void:
	if _background:
		_background.color = color.darkened(0.4)
