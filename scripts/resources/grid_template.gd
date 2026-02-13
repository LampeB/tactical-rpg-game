class_name GridTemplate
extends Resource
## Defines the shape of a character's inventory grid.
## Not all cells in the bounding box need to be active — grids can be non-rectangular.

@export var id: String = ""
@export var display_name: String = ""

## Grid dimensions (bounding box).
@export var width: int = 6
@export var height: int = 6

## Active cells within the bounding box. If empty, all cells are active.
## Each Vector2i is a (col, row) coordinate that IS usable.
@export var active_cells: Array[Vector2i] = []

## Whether to treat empty active_cells as "all cells active".
func get_active_cells() -> Array[Vector2i]:
	if active_cells.is_empty():
		# Default: all cells are active
		var all_cells: Array[Vector2i] = []
		for y in range(height):
			for x in range(width):
				all_cells.append(Vector2i(x, y))
		return all_cells
	return active_cells

func is_cell_active(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
		return false
	if active_cells.is_empty():
		return true
	return pos in active_cells

func get_total_active_cells() -> int:
	if active_cells.is_empty():
		return width * height
	return active_cells.size()
