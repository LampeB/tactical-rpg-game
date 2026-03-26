extends "res://scenes/world/base_map.gd"
## Local map controller — smaller explorable areas (forests, caves, towns).
## No fast travel, no day/night cycle management, no terrain caching.


func _start_music() -> void:
	## TODO: Read music_id from MapData when the field is added.
	AudioManager.play_music("town")
	AudioManager.play_ambient("nature")
