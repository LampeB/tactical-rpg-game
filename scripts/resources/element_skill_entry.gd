class_name ElementSkillEntry
extends Resource
## A single entry in the element skill unlock table.
## Maps a set of required element points to a skill that becomes available.

## The skill unlocked when requirements are met.
@export var skill: SkillData
## Required element points. Keys are Enums.Element (int), values are minimum points needed.
## All requirements must be met (AND logic).
@export var required_points: Dictionary = {}
