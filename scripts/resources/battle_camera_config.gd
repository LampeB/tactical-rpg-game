class_name BattleCameraConfig
extends Resource
## Collection of camera angle presets for each battle state/action.
## Edit in inspector or via the BattleCameraPreview scene.

@export_group("States")
@export var home: BattleCameraPreset            ## Default idle / enemy turn
@export var player_turn: BattleCameraPreset     ## When a player's turn starts
@export var victory: BattleCameraPreset         ## Victory state
@export var defeat: BattleCameraPreset          ## Defeat state

@export_group("Actions")
@export var attack: BattleCameraPreset          ## After choosing Attack
@export var skill: BattleCameraPreset           ## After choosing Skill
@export var item: BattleCameraPreset            ## After choosing Item
@export var defend: BattleCameraPreset          ## After choosing Defend
@export var flee: BattleCameraPreset            ## After choosing Flee
