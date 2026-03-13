class_name PassiveTreeData
extends Resource
## Defines the unified passive skill tree shared by all characters.

@export var display_name: String = "" ## e.g. "Skill Tree"
@export var nodes: Array[PassiveNodeData] = []


func get_node_by_id(node_id: String) -> PassiveNodeData:
	for i in range(nodes.size()):
		var node: PassiveNodeData = nodes[i]
		if node and node.id == node_id:
			return node
	return null


## Build a bidirectional adjacency map from prerequisite connections.
## Returns Dictionary { node_id: Array[String] of neighbor ids }.
func get_neighbor_map() -> Dictionary:
	var neighbors: Dictionary = {}
	for i in range(nodes.size()):
		var node: PassiveNodeData = nodes[i]
		if not node:
			continue
		if not neighbors.has(node.id):
			neighbors[node.id] = []
		for j in range(node.prerequisites.size()):
			var prereq_id: String = node.prerequisites[j]
			# Add bidirectional link
			if not neighbors.has(prereq_id):
				neighbors[prereq_id] = []
			if not neighbors[node.id].has(prereq_id):
				neighbors[node.id].append(prereq_id)
			if not neighbors[prereq_id].has(node.id):
				neighbors[prereq_id].append(node.id)
	return neighbors
