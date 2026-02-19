class_name CombatEntity
extends RefCounted
## Runtime state for a single entity (character or enemy) during combat.

var entity_name: String = ""
var is_player: bool = false

# Base data references
var character_data: CharacterData  ## Set for player entities
var enemy_data: EnemyData          ## Set for enemy entities
var grid_inventory: GridInventory  ## Equipment bonuses (player only)

# Runtime combat state
var current_hp: int = 0
var max_hp: int = 0
var current_mp: int = 0
var max_mp: int = 0
var is_defending: bool = false
var is_dead: bool = false

# Status effects: Array of {data: StatusEffectData, remaining_turns: int, stacks: int}
var status_effects: Array = []

# Skill cooldowns: skill_id -> turns remaining
var cooldowns: Dictionary = {}


static func from_character(char_data: CharacterData, inv: GridInventory) -> CombatEntity:
	var entity: CombatEntity = CombatEntity.new()
	entity.entity_name = char_data.display_name
	entity.is_player = true
	entity.character_data = char_data
	entity.grid_inventory = inv

	var equip_stats: Dictionary = inv.get_computed_stats() if inv else {}
	entity.max_hp = char_data.max_hp + int(equip_stats.get(Enums.Stat.MAX_HP, 0.0))
	entity.max_mp = char_data.max_mp + int(equip_stats.get(Enums.Stat.MAX_MP, 0.0))
	entity.current_hp = entity.max_hp
	entity.current_mp = entity.max_mp
	return entity


static func from_enemy(e_data: EnemyData) -> CombatEntity:
	var entity: CombatEntity = CombatEntity.new()
	entity.entity_name = e_data.display_name
	entity.is_player = false
	entity.enemy_data = e_data
	entity.max_hp = e_data.max_hp
	entity.max_mp = 0
	entity.current_hp = entity.max_hp
	entity.current_mp = 0
	return entity


func get_effective_stat(stat: Enums.Stat) -> float:
	var base: float = 0.0
	if is_player and character_data:
		base = float(character_data.get_base_stat(stat))
	elif not is_player and enemy_data:
		base = float(enemy_data.get_base_stat(stat))

	# Equipment bonuses (player only)
	if is_player and grid_inventory:
		var equip_stats: Dictionary = grid_inventory.get_computed_stats()
		base += equip_stats.get(stat, 0.0)

	# Status effect modifiers
	for effect in status_effects:
		var data: StatusEffectData = effect.data
		for mod in data.stat_modifiers:
			if mod is StatModifier and mod.stat == stat:
				if mod.modifier_type == Enums.ModifierType.FLAT:
					base += mod.value * effect.stacks
				elif mod.modifier_type == Enums.ModifierType.PERCENT:
					base *= (1.0 + mod.value / 100.0 * effect.stacks)

	# Speed multiplier from status effects
	if stat == Enums.Stat.SPEED:
		for effect in status_effects:
			var data: StatusEffectData = effect.data
			if data.speed_multiplier != 1.0:
				base *= data.speed_multiplier

	return maxf(base, 0.0)


func get_available_skills() -> Array:
	var skills: Array = []
	if is_player and character_data:
		for skill in character_data.innate_skills:
			if skill is SkillData:
				skills.append(skill)
		# Skills granted by equipped items
		if grid_inventory:
			for i in range(grid_inventory.get_all_placed_items().size()):
				var placed: GridInventory.PlacedItem = grid_inventory.get_all_placed_items()[i]
				for skill in placed.item_data.granted_skills:
					if skill is SkillData and skill not in skills:
						skills.append(skill)
	elif not is_player and enemy_data:
		for skill in enemy_data.skills:
			if skill is SkillData:
				skills.append(skill)
	return skills


func can_use_skill(skill: SkillData) -> bool:
	if current_mp < skill.mp_cost:
		return false
	if cooldowns.get(skill.id, 0) > 0:
		return false
	# Check action restrictions from status effects
	for effect in status_effects:
		var data: StatusEffectData = effect.data
		if data.prevents_skills:
			return false
	return true


func can_act() -> bool:
	for effect in status_effects:
		var data: StatusEffectData = effect.data
		if data.prevents_action:
			return false
	return true


func get_damage_taken_multiplier() -> float:
	var mult: float = 1.0
	for effect in status_effects:
		var data: StatusEffectData = effect.data
		if data.damage_taken_multiplier != 1.0:
			mult *= data.damage_taken_multiplier
	return mult


func take_damage(amount: int) -> int:
	var actual: int = mini(amount, current_hp)
	current_hp -= actual
	if current_hp <= 0:
		current_hp = 0
		is_dead = true
	return actual


func heal(amount: int) -> int:
	var actual: int = mini(amount, max_hp - current_hp)
	current_hp += actual
	return actual


func spend_mp(amount: int) -> void:
	current_mp = maxi(current_mp - amount, 0)


func apply_status(status_data: StatusEffectData) -> bool:
	# Check if already has this status
	for effect in status_effects:
		if effect.data.id == status_data.id:
			if status_data.stackable and effect.stacks < status_data.max_stacks:
				effect.stacks += 1
				effect.remaining_turns = status_data.duration
				return true
			else:
				# Refresh duration
				effect.remaining_turns = status_data.duration
				return true
	# New status
	status_effects.append({
		"data": status_data,
		"remaining_turns": status_data.duration,
		"stacks": 1,
	})
	return true


func tick_cooldowns() -> void:
	var to_remove: Array = []
	var keys: Array = cooldowns.keys()
	for i in range(keys.size()):
		var skill_id: String = keys[i]
		cooldowns[skill_id] -= 1
		if cooldowns[skill_id] <= 0:
			to_remove.append(skill_id)
	for i in range(to_remove.size()):
		cooldowns.erase(to_remove[i])
