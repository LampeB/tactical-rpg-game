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
