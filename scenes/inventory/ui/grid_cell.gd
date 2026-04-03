extends Control
## STUB — awaiting rewrite (INV-R1)
## A single inventory grid cell with state-driven visuals.

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

@onready var _background: NinePatchRect = $Background


func _ready() -> void:
	var sz := Vector2(Constants.GRID_CELL_SIZE, Constants.GRID_CELL_SIZE)
	custom_minimum_size = sz
	size = sz


func setup(pos: Vector2i) -> void:
	grid_position = pos
	set_state(CellState.EMPTY)


func set_state(_state: CellState) -> void:
	cell_state = _state


func set_rarity_tint(_color: Color) -> void:
	pass


func set_glow(_enabled: bool) -> void:
	pass
