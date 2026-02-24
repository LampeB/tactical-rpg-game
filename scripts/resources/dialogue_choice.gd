class_name DialogueChoice
extends Resource
## A single player-selectable option at the end of a dialogue conversation.

@export var text: String = ""
@export var next_conversation_id: String = ""  ## Branch to jump to. "" = end dialogue.
@export var action: String = ""               ## Special action: "end" | "open_shop:<id>" | ""
@export var set_flag: String = ""             ## GameManager flag to set when chosen.
@export var set_flag_value: Variant = true    ## Value to assign to set_flag.
