extends Node2D

func _ready():
	print("=== Y-Sort Debug ===")
	print("Overworld y_sort_enabled: ", y_sort_enabled)
	
	var tilemap = get_node_or_null("TileMapLayer")
	if tilemap:
		print("TileMapLayer y_sort_enabled: ", tilemap.y_sort_enabled)
		print("TileMapLayer position: ", tilemap.position)
	
	var player = get_node_or_null("Player")
	if player:
		print("Player position: ", player.position)
