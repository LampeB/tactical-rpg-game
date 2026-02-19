class_name PassiveTreeData
extends Resource
## Defines the full passive skill tree for a character.

@export var character_id: String = ""
@export var display_name: String = "" ## e.g. "Warrior's Path"
@export var nodes: Array = [] ## of PassiveNodeData


func get_node_by_id(node_id: String) -> PassiveNodeData:
	for i in range(nodes.size()):
		var node: PassiveNodeData = nodes[i]
		if node and node.id == node_id:
			return node
	return null
