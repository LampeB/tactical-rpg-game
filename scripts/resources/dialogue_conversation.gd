class_name DialogueConversation
extends Resource
## One branch in an NPC's dialogue tree.
## The first conversation whose condition is satisfied will be shown.

@export var id: String = ""
@export var condition_flag: String = ""    ## Show only when GameManager flag matches condition_value.
@export var condition_value: Variant = true
@export var lines: Array[String] = []     ## Lines of NPC dialogue, shown one at a time.
@export var choices: Array[DialogueChoice] = []  ## Player choices shown after all lines.
@export var auto_next_id: String = ""     ## If no choices, jump to this conversation id ("" = end).
