extends Node
## Global audio manager. Handles music playback with crossfading, SFX,
## and ambient loops. Connects to EventBus for automatic audio triggers.

# --- Music tracks ---
const MUSIC := {
	"main_menu": "res://assets/audio/music/Main Menu Theme.wav",
	"menu": "res://assets/audio/music/Menu Theme.wav",
	"overworld": "res://assets/audio/music/Overworld Exploration.wav",
	"battle": "res://assets/audio/music/Battle Theme.wav",
	"boss_battle": "res://assets/audio/music/boss battle theme.wav",
	"town_shop": "res://assets/audio/music/Town_Shop.wav",
	"inn": "res://assets/audio/music/Inn.wav",
	"victory": "res://assets/audio/music/Victory Fanfare.wav",
	"defeat": "res://assets/audio/music/Defeat Theme.wav",
}

# --- SFX paths ---
const SFX := {
	# Combat
	"slash": "res://assets/audio/sfx/combat/slash.ogg",
	"heavy_slash": "res://assets/audio/sfx/combat/heavy_slash.wav",
	"stab": "res://assets/audio/sfx/combat/stab.wav",
	"bash_hit": "res://assets/audio/sfx/combat/bash_hit.wav",
	"fire_spell": "res://assets/audio/sfx/combat/fire_spell.wav",
	"ice_spell": "res://assets/audio/sfx/combat/ice_spell.wav",
	"lightning_spell": "res://assets/audio/sfx/combat/lightning_spell.wav",
	"dark_spell": "res://assets/audio/sfx/combat/dark_spell.wav",
	"poison_spell": "res://assets/audio/sfx/combat/poison_spell.wav",
	"heal_spell": "res://assets/audio/sfx/combat/heal_spell.wav",
	"buff_applied": "res://assets/audio/sfx/combat/buff_applied.wav",
	"explosion": "res://assets/audio/sfx/combat/explosion.wav",
	"critical_hit": "res://assets/audio/sfx/combat/critical_hit.wav",
	"miss_dodge": "res://assets/audio/sfx/combat/miss_dodge.wav",
	"death_ko": "res://assets/audio/sfx/combat/death_ko.wav",
	"defend_stance": "res://assets/audio/sfx/combat/defend_stance.wav",
	"projectile_launch": "res://assets/audio/sfx/combat/projectile_launch.wav",
	"projectile_impact": "res://assets/audio/sfx/combat/projectile_impact.wav",
	"flee_success": "res://assets/audio/sfx/combat/flee_success.wav",
	"flee_fail": "res://assets/audio/sfx/combat/flee_fail.wav",
	# UI
	"button_click": "res://assets/audio/sfx/ui/button_click.wav",
	"menu_open": "res://assets/audio/sfx/ui/menu_open.wav",
	"menu_close": "res://assets/audio/sfx/ui/menu_close.wav",
	"item_pickup": "res://assets/audio/sfx/ui/item_pickup.wav",
	"item_place": "res://assets/audio/sfx/ui/item_place.wav",
	"item_rotate": "res://assets/audio/sfx/ui/item_rotate.wav",
	"error_invalid": "res://assets/audio/sfx/ui/error_invalid.wav",
	"purchase_gold": "res://assets/audio/sfx/ui/purchase_gold.wav",
	"gold_earned": "res://assets/audio/sfx/ui/gold_earned.wav",
	"level_up": "res://assets/audio/sfx/ui/level_up.wav",
	# Overworld
	"chest_open": "res://assets/audio/sfx/overworld/chest_open.wav",
	"npc_interaction": "res://assets/audio/sfx/overworld/npc_interaction.wav",
	"enemy_encounter": "res://assets/audio/sfx/overworld/enemy_encounter.wav",
	"zone_transition": "res://assets/audio/sfx/overworld/zone_transition.wav",
	"quest_complete": "res://assets/audio/sfx/overworld/quest_complete.wav",
}

# --- Ambient paths ---
const AMBIENT := {
	"forest": "res://assets/audio/ambient/forest_ambient.mp3",
	"town": "res://assets/audio/ambient/town_ambient.mp3",
	"dungeon": "res://assets/audio/ambient/dungeon_ambient.mp3",
	"night": "res://assets/audio/ambient/night_ambient.mp3",
}

# --- SkillVFX to SFX mapping ---
const VFX_SFX_MAP := {
	1: "slash",         # SLASH
	2: "heavy_slash",   # POWER_SLASH
	3: "stab",          # STAB
	4: "bash_hit",      # BASH
	5: "fire_spell",    # FIRE
	6: "ice_spell",     # ICE
	7: "lightning_spell", # LIGHTNING
	8: "dark_spell",    # DARK
	9: "poison_spell",  # POISON
	10: "heal_spell",   # HEAL
	11: "buff_applied", # BUFF
	12: "explosion",    # EXPLOSION
}

const CROSSFADE_DURATION := 1.0  ## Seconds to crossfade between music tracks
const SFX_POOL_SIZE := 8  ## Max concurrent SFX players

# --- Audio bus indices (set in _ready) ---
var _bus_music: int = -1
var _bus_sfx: int = -1
var _bus_ambient: int = -1

# --- Players ---
var _music_a: AudioStreamPlayer  ## Currently playing music
var _music_b: AudioStreamPlayer  ## Crossfade target
var _ambient_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0  ## Round-robin index

# --- State ---
var _current_music_key: String = ""
var _current_ambient_key: String = ""
var _music_before_battle: String = ""  ## Track to resume after battle
var _ambient_before_battle: String = ""
var _sfx_cache: Dictionary = {}  ## path -> AudioStream (loaded)
var _sfx_volume_db: Dictionary = {}  ## sfx_key -> float (per-SFX volume offset in dB)

# --- Volume (linear, 0.0–1.0) ---
var music_volume: float = 0.8:
	set(v):
		music_volume = clampf(v, 0.0, 1.0)
		if _bus_music >= 0:
			AudioServer.set_bus_volume_db(_bus_music, linear_to_db(music_volume))

var sfx_volume: float = 1.0:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		if _bus_sfx >= 0:
			AudioServer.set_bus_volume_db(_bus_sfx, linear_to_db(sfx_volume))

var ambient_volume: float = 0.5:
	set(v):
		ambient_volume = clampf(v, 0.0, 1.0)
		if _bus_ambient >= 0:
			AudioServer.set_bus_volume_db(_bus_ambient, linear_to_db(ambient_volume))


func _ready() -> void:
	_setup_audio_buses()
	_create_players()
	_connect_signals()
	# Listen for button clicks globally
	get_tree().node_added.connect(_on_node_added)
	DebugLogger.log_info("AudioManager ready", "Audio")


func _setup_audio_buses() -> void:
	# Create audio buses: Music, SFX, Ambient — all routed to Master
	_bus_music = AudioServer.bus_count
	AudioServer.add_bus(_bus_music)
	AudioServer.set_bus_name(_bus_music, "Music")
	AudioServer.set_bus_send(_bus_music, "Master")
	AudioServer.set_bus_volume_db(_bus_music, linear_to_db(music_volume))

	_bus_sfx = AudioServer.bus_count
	AudioServer.add_bus(_bus_sfx)
	AudioServer.set_bus_name(_bus_sfx, "SFX")
	AudioServer.set_bus_send(_bus_sfx, "Master")
	AudioServer.set_bus_volume_db(_bus_sfx, linear_to_db(sfx_volume))

	_bus_ambient = AudioServer.bus_count
	AudioServer.add_bus(_bus_ambient)
	AudioServer.set_bus_name(_bus_ambient, "Ambient")
	AudioServer.set_bus_send(_bus_ambient, "Master")
	AudioServer.set_bus_volume_db(_bus_ambient, linear_to_db(ambient_volume))


func _create_players() -> void:
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	add_child(_music_a)

	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	_music_b.volume_db = -80.0
	add_child(_music_b)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Ambient"
	add_child(_ambient_player)

	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)


func _connect_signals() -> void:
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.passive_unlocked.connect(_on_passive_unlocked)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.item_placed.connect(_on_item_placed)
	EventBus.item_removed.connect(_on_item_removed)
	EventBus.item_rotated.connect(_on_item_rotated)


# ========== Public API ==========

func play_music(key: String, force_restart: bool = false) -> void:
	## Crossfade to a music track by key. No-op if already playing the same track.
	if key == _current_music_key and not force_restart:
		return
	if not MUSIC.has(key):
		DebugLogger.log_warn("Unknown music key: %s" % key, "Audio")
		return

	var stream: AudioStream = load(MUSIC[key])
	if not stream:
		DebugLogger.log_warn("Failed to load music: %s" % MUSIC[key], "Audio")
		return

	_current_music_key = key
	_crossfade_music(stream)
	DebugLogger.log_info("Playing music: %s" % key, "Audio")


func stop_music(fade_out: float = 0.5) -> void:
	## Fade out current music.
	_current_music_key = ""
	if not _music_a.playing:
		return
	var tween := create_tween()
	tween.tween_property(_music_a, "volume_db", -80.0, fade_out)
	tween.tween_callback(_music_a.stop)


func play_sfx(key: String) -> void:
	## Play a sound effect by key. Uses round-robin pool.
	if not SFX.has(key):
		DebugLogger.log_warn("Unknown SFX key: %s" % key, "Audio")
		return
	var stream: AudioStream = _get_sfx_stream(key)
	if not stream:
		return
	var player: AudioStreamPlayer = _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.volume_db = _sfx_volume_db.get(key, 0.0)
	player.play()


func get_sfx_volume_db(key: String) -> float:
	## Get per-SFX volume offset in dB.
	return _sfx_volume_db.get(key, 0.0)


func set_sfx_volume_db(key: String, db: float) -> void:
	## Set per-SFX volume offset in dB.
	_sfx_volume_db[key] = db


func play_sfx_for_vfx(vfx_type: int) -> void:
	## Play the SFX associated with a SkillVFX enum value.
	var sfx_key: String = VFX_SFX_MAP.get(vfx_type, "")
	if not sfx_key.is_empty():
		play_sfx(sfx_key)


func play_ambient(key: String) -> void:
	## Start an ambient loop. Crossfades if already playing a different one.
	if key == _current_ambient_key:
		return
	if not AMBIENT.has(key):
		DebugLogger.log_warn("Unknown ambient key: %s" % key, "Audio")
		return
	var stream: AudioStream = load(AMBIENT[key])
	if not stream:
		return
	_current_ambient_key = key
	if _ambient_player.playing:
		var tween := create_tween()
		tween.tween_property(_ambient_player, "volume_db", -80.0, 0.5)
		tween.tween_callback(func() -> void:
			_ambient_player.stream = stream
			_ambient_player.volume_db = 0.0
			_ambient_player.play()
		)
	else:
		_ambient_player.stream = stream
		_ambient_player.volume_db = 0.0
		_ambient_player.play()


func stop_ambient(fade_out: float = 0.5) -> void:
	_current_ambient_key = ""
	if not _ambient_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_ambient_player, "volume_db", -80.0, fade_out)
	tween.tween_callback(_ambient_player.stop)


# ========== Music for scenes ==========

func play_music_for_scene(scene_name: String) -> void:
	## Auto-select and play music based on scene name.
	match scene_name:
		"MainMenu":
			play_music("main_menu")
		"Overworld":
			play_music("overworld")
		"Battle":
			pass  # Handled by combat_started signal
		"ShopUI":
			play_music("town_shop")
		"PassiveTree", "CraftingUI":
			play_music("menu")
		"CharacterHub", "Squad", "CharacterStats", "CharacterSkills", "BackpackEditor":
			play_music("menu")
		"Loot":
			pass  # Keep current music (victory or battle)
		_:
			pass  # Keep current music


# ========== Internal ==========

func _crossfade_music(new_stream: AudioStream) -> void:
	# Swap A and B so B becomes the new track
	var old: AudioStreamPlayer = _music_a
	var fresh: AudioStreamPlayer = _music_b
	_music_a = fresh
	_music_b = old

	fresh.stream = new_stream
	fresh.volume_db = -80.0
	fresh.play()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fresh, "volume_db", 0.0, CROSSFADE_DURATION)
	tween.tween_property(old, "volume_db", -80.0, CROSSFADE_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(old.stop)


func _get_sfx_stream(key: String) -> AudioStream:
	if _sfx_cache.has(key):
		return _sfx_cache[key]
	var path: String = SFX[key]
	var stream: AudioStream = load(path)
	if stream:
		_sfx_cache[key] = stream
	else:
		DebugLogger.log_warn("Failed to load SFX: %s" % path, "Audio")
	return stream


# ========== Signal handlers ==========

func _on_combat_started(_encounter: Resource) -> void:
	_music_before_battle = _current_music_key
	_ambient_before_battle = _current_ambient_key
	play_sfx("enemy_encounter")
	stop_ambient(0.3)
	# Small delay so encounter SFX plays before music switch
	await get_tree().create_timer(0.3).timeout
	play_music("battle")


func _on_combat_ended(victory: bool, _defeated: Array) -> void:
	if victory:
		play_music("victory")
		# After victory fanfare, resume previous music
		await get_tree().create_timer(8.0).timeout
		if _current_music_key == "victory":
			# Only resume if we haven't already changed music
			if not _music_before_battle.is_empty():
				play_music(_music_before_battle)
			if not _ambient_before_battle.is_empty():
				play_ambient(_ambient_before_battle)
	else:
		play_music("defeat")


var _last_gold: int = -1

func _on_gold_changed(new_amount: int) -> void:
	if _last_gold < 0:
		_last_gold = new_amount
		return
	if new_amount > _last_gold:
		play_sfx("gold_earned")
	else:
		play_sfx("purchase_gold")
	_last_gold = new_amount


func _on_quest_completed(_quest_id: String) -> void:
	play_sfx("quest_complete")


func _on_passive_unlocked(_character_id: String, _node_id: String) -> void:
	play_sfx("level_up")


func _on_dialogue_started(_npc_id: String) -> void:
	play_sfx("npc_interaction")
	# Duck music during dialogue — lower the active music player's volume
	if _music_a and _music_a.playing:
		var tween := create_tween()
		tween.tween_property(_music_a, "volume_db", linear_to_db(0.4), 0.3)


func _on_dialogue_ended(_npc_id: String) -> void:
	# Restore music volume
	if _music_a and _music_a.playing:
		var tween := create_tween()
		tween.tween_property(_music_a, "volume_db", 0.0, 0.5)


func _on_item_placed(_character_id: String, _item: Resource, _grid_pos: Vector2i) -> void:
	play_sfx("item_place")


func _on_item_removed(_character_id: String, _item: Resource, _grid_pos: Vector2i) -> void:
	play_sfx("item_pickup")


func _on_item_rotated(_character_id: String, _item: Resource) -> void:
	play_sfx("item_rotate")


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		if not node.pressed.is_connected(_on_button_pressed):
			node.pressed.connect(_on_button_pressed, CONNECT_DEFERRED)


func _on_button_pressed() -> void:
	play_sfx("button_click")
