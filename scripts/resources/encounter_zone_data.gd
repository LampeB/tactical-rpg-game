class_name EncounterZoneData
extends Resource
## Defines random encounter parameters for a map region.

@export_group("Identity")
@export var zone_id: String = ""  ## Unique identifier (e.g., "grasslands", "dark_forest")
@export var zone_name: String = ""  ## Display name (e.g., "Grasslands", "Dark Forest")

@export_group("Encounter Rate")
@export_range(0.0, 1.0) var base_encounter_chance: float = 0.08  ## 8% chance per check
@export var steps_between_checks: int = 10  ## Check for encounter every N steps

@export_group("Encounter Pool")
@export var encounters: Array[EncounterData] = []  ## Possible encounters in this zone
@export var encounter_weights: Array[float] = []  ## Relative probability (must match encounters.size)

@export_group("Restrictions")
@export var min_party_level: int = 0  ## Future-proofing for level requirements
@export var disabled_flag: String = ""  ## Story flag to disable encounters (e.g., "cleared_forest")


func get_random_encounter() -> EncounterData:
	## Returns a weighted random encounter from the pool.
	if encounters.is_empty():
		return null

	# Build weights array (equal weights if not specified)
	var weights := encounter_weights if encounter_weights.size() == encounters.size() else []

	if weights.is_empty():
		for i in range(encounters.size()):
			weights.append(1.0)

	# Calculate total weight
	var total_weight: float = 0.0
	for w in weights:
		total_weight += w

	if total_weight <= 0.0:
		return encounters[0]

	# Weighted random selection
	var roll := randf() * total_weight
	var cumulative := 0.0

	for i in range(encounters.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return encounters[i]

	return encounters[0]  # Fallback
