class_name ItemShape
extends Resource
## Defines the tetris-like shape of an item on the inventory grid.
## Each shape is a set of Vector2i offsets relative to the pivot.

@export var id: String = ""
@export var display_name: String = ""

## Array of Vector2i: each entry is a cell offset from the pivot (0,0).
## Example: L-shape = [(0,0), (0,1), (0,2), (1,2)]
@export var cells: Array[Vector2i] = [Vector2i.ZERO]

## How many 90-degree rotations are valid (1 = no rotation, 2 = 180 only, 4 = all)
@export_range(1, 4) var rotation_states: int = 1

func get_width() -> int:
	var max_x := 0
	for cell in cells:
		max_x = maxi(max_x, cell.x)
	return max_x + 1

func get_height() -> int:
	var max_y := 0
	for cell in cells:
		max_y = maxi(max_y, cell.y)
	return max_y + 1

## Returns cells rotated 90 degrees clockwise the given number of times.
func get_rotated_cells(rotations: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = cells.duplicate()
	for i in range(rotations % rotation_states):
		var rotated: Array[Vector2i] = []
		for c in result:
			rotated.append(Vector2i(-c.y, c.x))
		# Normalize so all coords are non-negative
		var min_x := 0
		var min_y := 0
		for rc in rotated:
			min_x = mini(min_x, rc.x)
			min_y = mini(min_y, rc.y)
		var normalized: Array[Vector2i] = []
		for nc in rotated:
			normalized.append(Vector2i(nc.x - min_x, nc.y - min_y))
		result = normalized
	return result
