class_name PassiveTreeData
extends Resource
## Defines the unified passive skill tree shared by all characters.

@export var display_name: String = "" ## e.g. "Skill Tree"
@export var nodes: Array = [] ## of PassiveNodeData


func get_node_by_id(node_id: String) -> PassiveNodeData:
	for i in range(nodes.size()):
		var node: PassiveNodeData = nodes[i]
		if node and node.id == node_id:
			return node
	return null
