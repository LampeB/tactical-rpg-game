extends Area2D
## Interactable NPC on the overworld. When the player enters range and presses
## [interact], the dialogue UI is pushed as a new scene.

@export var npc_id: String = ""

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _name_label: Label = $NameLabel
@onready var _interact_prompt: Label = $InteractPrompt

var _npc_data: NpcData = null
var _player_nearby: bool = false


func _ready() -> void:
	if npc_id.is_empty():
		DebugLogger.log_warn("NpcMarker has no npc_id set", "NpcMarker")
		return

	_npc_data = NpcDatabase.get_npc(npc_id)
	if not _npc_data:
		DebugLogger.log_warn("NPC not found: %s" % npc_id, "NpcMarker")
		return

	if _npc_data.sprite:
		_sprite.texture = _npc_data.sprite
	_name_label.text = _npc_data.display_name
	_interact_prompt.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_start_dialogue()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_nearby = true
		_interact_prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_nearby = false
		_interact_prompt.visible = false


func _start_dialogue() -> void:
	if not _npc_data:
		return
	# Save player position so the overworld can restore it when we pop back.
	var player := get_tree().get_first_node_in_group("player")
	if player:
		GameManager.set_flag("overworld_position", player.global_position)
	EventBus.dialogue_started.emit(npc_id)
	SceneManager.push_scene("res://scenes/dialogue/dialogue_ui.tscn", {"npc_id": npc_id})
