class_name StructurePiece
extends Resource
## Defines a single modular building piece from the Medieval Village MegaKit.

enum Category { WALL, FLOOR, ROOF, DOOR, WINDOW, STAIRS, CORNER, OVERHANG, BALCONY, PROP }

@export var id: String = ""
@export var scene_path: String = ""
@export var category: Category = Category.WALL
@export var display_name: String = ""
## Grid footprint in cells (width × depth). Most pieces are 1×1.
@export var footprint: Vector2i = Vector2i(1, 1)
