class_name MissionLauncher
extends RefCounted
## Pure helpers for launching missions from the hub.
##
## The actual scene push + battle background pre-load lives in mission_board.gd
## because they have hard-to-test side effects (PackedScene.load, mutating
## GameManager state). The data-dict construction is extracted HERE so it can
## be unit tested in isolation.
##
## Regression target: 2026-04-30 bug where grid_inventories was missing from
## the data dict, leaving battle entities with empty inventories. The test for
## this helper makes that class of bug impossible to ship silently.

const BATTLE_MAP_ID := "forest_clearing"
const BATTLE_ARENA_CENTER := Vector3(128.0, 3.0, 145.0)


static func build_battle_data(
	mission: MissionData,
	encounter: EncounterData,
	party_grid_inventories: Dictionary
) -> Dictionary:
	## Builds the data dict that gets passed to battle.tscn via SceneManager.
	## Battle reads:
	##   - "encounter"          (EncounterData) required for combat setup
	##   - "map_id"             (String)        identifies battle map for bg setup
	##   - "fight_position"     (Vector3)       arena center / camera target
	##   - "grid_inventories"   (Dictionary)    char_id -> GridInventory; required
	##                                          for player entity construction
	## All four keys MUST be present. Adding a new field battle reads requires
	## adding it here AND updating the test.
	return {
		"encounter": encounter,
		"map_id": BATTLE_MAP_ID,
		"fight_position": BATTLE_ARENA_CENTER,
		"grid_inventories": party_grid_inventories,
	}


## Resolves the EncounterData a mission should run.
## - If mission.encounter_path is set and resolves to a valid EncounterData,
##   loads + returns that resource (mission designers fight EXACTLY the
##   roster they specified — no random spawn).
## - Otherwise falls back to the random generator using the mission's
##   enemy_count_min/max, display_name, and gold_reward.
##
## Each call returns a fresh EncounterData instance (or the loaded resource);
## callers shouldn't mutate it expecting isolation across calls.
static func resolve_encounter(mission: MissionData) -> EncounterData:
	if mission == null:
		return null
	if mission.encounter_path != "" and ResourceLoader.exists(mission.encounter_path):
		var loaded: Resource = load(mission.encounter_path)
		if loaded is EncounterData:
			return loaded as EncounterData
		push_warning("[MissionLauncher] %s loaded but is not EncounterData — falling back to random" % mission.encounter_path)
	return RandomEncounterGenerator.generate(
		mission.enemy_count_min,
		mission.enemy_count_max,
		mission.display_name,
		mission.gold_reward,
	)


## Computes what should change in GameManager when a mission's battle ends.
## Returns a dict with:
##   - "complete": bool   — true if this mission should be marked completed now
##   - "xp_awarded": int  — XP to record (0 if no reward / already claimed)
## Caller applies the changes via GameManager.mark_mission_complete() and
## GameManager.set_flag(). Pure (no autoload access) so it's unit-testable.
##
## Idempotent: if `already_completed` already contains the mission id,
## returns no-op (complete=false, xp_awarded=0). Repeating a finished mission
## should not re-award XP — bookkeeping responsibility lives with the caller
## via the already_completed input.
static func compute_battle_outcome(
	mission: MissionData,
	victory: bool,
	already_completed: Array,
) -> Dictionary:
	if mission == null:
		return {"complete": false, "xp_awarded": 0}
	if not victory:
		return {"complete": false, "xp_awarded": 0}
	if mission.id in already_completed:
		return {"complete": false, "xp_awarded": 0}
	return {
		"complete": true,
		"xp_awarded": maxi(mission.xp_reward, 0),
	}
