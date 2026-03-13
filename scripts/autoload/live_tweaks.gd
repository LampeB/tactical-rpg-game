extends Node
## Runtime variable overrides for live balancing and debug.
## Provides a registry of tweakable values that the TweaksEditor UI can modify.
## Game systems read values via get_float()/get_int() instead of Constants.

signal tweak_changed(key: String, value: float)

var _tweaks: Dictionary = {}  ## key -> {category, value, default_value, min_value, max_value, step}


func _ready() -> void:
	_register_defaults()


func _register_defaults() -> void:
	# Combat
	_reg("Combat", "base_critical_rate", Constants.BASE_CRITICAL_RATE, 0.0, 1.0, 0.01)
	_reg("Combat", "base_critical_damage", Constants.BASE_CRITICAL_DAMAGE, 1.0, 5.0, 0.1)
	_reg("Combat", "max_critical_rate", Constants.MAX_CRITICAL_RATE, 0.5, 1.0, 0.05)
	_reg("Combat", "luck_crit_scaling", Constants.LUCK_CRIT_SCALING, 0.0, 0.01, 0.0005)
	_reg("Combat", "defend_damage_reduction", Constants.DEFEND_DAMAGE_REDUCTION, 0.0, 1.0, 0.05)
	_reg("Combat", "turn_time_base", Constants.TURN_TIME_BASE, 10.0, 500.0, 10.0)
	_reg("Combat", "enemy_skill_chance", Constants.ENEMY_SKILL_CHANCE, 0.0, 1.0, 0.05)

	# Tier scaling
	for i in range(Constants.TIER_BASE_POWER.size()):
		_reg("Tier Scaling", "tier_%d_base_power" % i, float(Constants.TIER_BASE_POWER[i]), 1.0, 200.0, 1.0)
	for i in range(Constants.TIER_PRICE_MULTIPLIER.size()):
		_reg("Tier Scaling", "tier_%d_price_mult" % i, Constants.TIER_PRICE_MULTIPLIER[i], 0.1, 500.0, 0.5)

	# Economy
	_reg("Economy", "starting_gold", float(Constants.STARTING_GOLD), 0.0, 10000.0, 50.0)

	# Passive tree
	_reg("Passive Tree", "passive_base_cost", float(Constants.PASSIVE_BASE_COST), 0.0, 500.0, 10.0)
	_reg("Passive Tree", "passive_cost_per_unlock", float(Constants.PASSIVE_COST_PER_UNLOCK), 0.0, 100.0, 5.0)

	# World / movement
	_reg("World", "player_speed", Constants.PLAYER_SPEED, 1.0, 30.0, 0.5)
	_reg("World", "sprint_multiplier", Constants.PLAYER_SPRINT_MULTIPLIER, 1.0, 5.0, 0.1)
	_reg("World", "enemy_move_speed", Constants.ENEMY_MOVE_SPEED, 0.5, 10.0, 0.5)
	_reg("World", "enemy_patrol_distance", Constants.ENEMY_PATROL_DISTANCE, 1.0, 20.0, 0.5)
	_reg("World", "enemy_detection_radius", Constants.ENEMY_DETECTION_RADIUS, 0.5, 10.0, 0.5)
	_reg("World", "interaction_range", Constants.INTERACTION_RANGE, 0.5, 5.0, 0.25)

	# Party
	_reg("Party", "max_squad_size", float(Constants.MAX_SQUAD_SIZE), 1.0, 8.0, 1.0)
	_reg("Party", "max_roster_size", float(Constants.MAX_ROSTER_SIZE), 4.0, 30.0, 1.0)
	_reg("Party", "max_stash_slots", float(Constants.MAX_STASH_SLOTS), 10.0, 500.0, 10.0)


func _reg(category: String, key: String, default_val: float, min_val: float, max_val: float, step_val: float) -> void:
	_tweaks[key] = {
		"category": category,
		"value": default_val,
		"default_value": default_val,
		"min_value": min_val,
		"max_value": max_val,
		"step": step_val,
	}


func get_float(key: String) -> float:
	if _tweaks.has(key):
		return float(_tweaks[key]["value"])
	return 0.0


func get_int(key: String) -> int:
	if _tweaks.has(key):
		return int(_tweaks[key]["value"])
	return 0


func set_value(key: String, val: float) -> void:
	if _tweaks.has(key):
		_tweaks[key]["value"] = val
		tweak_changed.emit(key, val)


func is_modified(key: String) -> bool:
	if _tweaks.has(key):
		return not is_equal_approx(_tweaks[key]["value"], _tweaks[key]["default_value"])
	return false


func get_all_tweaks() -> Dictionary:
	return _tweaks


func get_categories() -> Array:
	var cats: Array = []
	var keys: Array = _tweaks.keys()
	for i in range(keys.size()):
		var cat: String = _tweaks[keys[i]]["category"]
		if not cats.has(cat):
			cats.append(cat)
	return cats


func get_tweaks_for_category(category: String) -> Array:
	## Returns array of keys belonging to the given category.
	var result: Array = []
	var keys: Array = _tweaks.keys()
	for i in range(keys.size()):
		if _tweaks[keys[i]]["category"] == category:
			result.append(keys[i])
	return result


func reset_all() -> void:
	var keys: Array = _tweaks.keys()
	for i in range(keys.size()):
		_tweaks[keys[i]]["value"] = _tweaks[keys[i]]["default_value"]
		tweak_changed.emit(keys[i], _tweaks[keys[i]]["value"])


func reset_key(key: String) -> void:
	if _tweaks.has(key):
		_tweaks[key]["value"] = _tweaks[key]["default_value"]
		tweak_changed.emit(key, _tweaks[key]["value"])
