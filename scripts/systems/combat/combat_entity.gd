class_name CombatEntity
extends RefCounted
## Runtime state for a single entity (character or enemy) during combat.

var entity_name: String = ""
var is_player: bool = false

# Base data references
var character_data: CharacterData  ## Set for player entities
var enemy_data: EnemyData          ## Set for enemy entities
var grid_inventory: GridInventory  ## Equipment bonuses (player only)
var tool_modifier_states: Dictionary = {}  ## PlacedItem -> ToolModifierState (cached)

# Passive skill tree bonuses (player only)
var passive_stat_modifiers: Array = []  ## of StatModifier
var passive_special_effects: Array = [] ## of String (effect IDs)

# Runtime combat state
var current_hp: int = 0
var max_hp: int = 0
var current_mp: int = 0
var max_mp: int = 0
var shield_hp: int = 0  ## Absorbs damage before HP (from start_shield)
var is_defending: bool = false
var is_dead: bool = false

# Status effects: Array of {data: StatusEffectData, remaining_turns: int, stacks: int}
var status_effects: Array = []

# Gem-based status effects: Array of StatusEffect (Burn, Poisoned, Chilled, Shocked)
var active_gem_status_effects: Array = []  ## of StatusEffect

# Skill cooldowns: skill_id -> turns remaining
var cooldowns: Dictionary = {}

# Turn timing (ATB-style): lower = acts sooner. Decreases by (100 / speed) per tick
var time_until_turn: float = 0.0


static func from_character(
	char_data: CharacterData,
	inv: GridInventory,
	passive_bonuses: Dictionary = {},
	starting_hp: int = -1,  ## -1 means use max_hp
	starting_mp: int = -1   ## -1 means use max_mp
) -> CombatEntity:
	var entity: CombatEntity = CombatEntity.new()
	entity.entity_name = char_data.display_name
	entity.is_player = true
	entity.character_data = char_data
	entity.grid_inventory = inv

	# Store passive bonuses
	entity.passive_stat_modifiers = passive_bonuses.get("stat_modifiers", [])
	entity.passive_special_effects = passive_bonuses.get("special_effects", [])

	# Get equipment stats and tool modifier states
	var computed: Dictionary = inv.get_computed_stats() if inv else {"stats": {}, "tool_states": {}}
	var equip_stats: Dictionary = computed.get("stats", {})
	entity.tool_modifier_states = computed.get("tool_states", {})

	# Compute max HP/MP: base + equipment + passive flat + passive percent
	var hp_flat: float = float(char_data.max_hp) + equip_stats.get(Enums.Stat.MAX_HP, 0.0)
	var mp_flat: float = float(char_data.max_mp) + equip_stats.get(Enums.Stat.MAX_MP, 0.0)
	var hp_pct: float = 0.0
	var mp_pct: float = 0.0

	for i in range(entity.passive_stat_modifiers.size()):
		var mod: StatModifier = entity.passive_stat_modifiers[i]
		if mod.stat == Enums.Stat.MAX_HP:
			if mod.modifier_type == Enums.ModifierType.FLAT:
				hp_flat += mod.value
			else:
				hp_pct += mod.value
		elif mod.stat == Enums.Stat.MAX_MP:
			if mod.modifier_type == Enums.ModifierType.FLAT:
				mp_flat += mod.value
			else:
				mp_pct += mod.value

	entity.max_hp = int(hp_flat * (1.0 + hp_pct / 100.0))
	entity.max_mp = int(mp_flat * (1.0 + mp_pct / 100.0))

	# Set current HP/MP: use provided values if >= 0, else default to max
	entity.current_hp = starting_hp if starting_hp >= 0 else entity.max_hp
	entity.current_mp = starting_mp if starting_mp >= 0 else entity.max_mp

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
		var computed: Dictionary = grid_inventory.get_computed_stats()
		var equip_stats: Dictionary = computed.get("stats", {})
		base += equip_stats.get(stat, 0.0)

	# Passive skill tree bonuses (player only) — flat first, then percent
	if is_player:
		var pct_bonus: float = 0.0
		for i in range(passive_stat_modifiers.size()):
			var mod: StatModifier = passive_stat_modifiers[i]
			if mod.stat == stat:
				if mod.modifier_type == Enums.ModifierType.FLAT:
					base += mod.value
				elif mod.modifier_type == Enums.ModifierType.PERCENT:
					pct_bonus += mod.value
		if pct_bonus != 0.0:
			base *= (1.0 + pct_bonus / 100.0)

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

	# Gem-based status effect modifiers (Chilled reduces speed)
	for i in range(active_gem_status_effects.size()):
		var gem_effect: StatusEffect = active_gem_status_effects[i]
		if gem_effect.stat_modifier and gem_effect.stat_modifier.stat == stat:
			if gem_effect.stat_modifier.modifier_type == Enums.ModifierType.FLAT:
				base += gem_effect.stat_modifier.value
			elif gem_effect.stat_modifier.modifier_type == Enums.ModifierType.PERCENT:
				base *= (1.0 + gem_effect.stat_modifier.value / 100.0)

	return maxf(base, 0.0)


func has_passive_effect(effect_id: String) -> bool:
	return PassiveEffects.has_effect(passive_special_effects, effect_id)


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
		# Conditional skills from tool modifier states
		var tool_states_keys: Array = tool_modifier_states.keys()
		for i in range(tool_states_keys.size()):
			var tool_state: ToolModifierState = tool_modifier_states[tool_states_keys[i]]
			for j in range(tool_state.conditional_skills.size()):
				var skill: SkillData = tool_state.conditional_skills[j]
				if skill is SkillData and skill not in skills:
					skills.append(skill)
	elif not is_player and enemy_data:
		for skill in enemy_data.skills:
			if skill is SkillData:
				skills.append(skill)
	return skills


func has_force_aoe() -> bool:
	## Returns true if any equipped tool has force_aoe from gem modifiers.
	for key in tool_modifier_states:
		var state: ToolModifierState = tool_modifier_states[key]
		if state.force_aoe:
			return true
	return false


func get_primary_tool_modifier_state() -> ToolModifierState:
	## Returns the ToolModifierState for the primary weapon (first ACTIVE_TOOL).
	if not is_player or not grid_inventory:
		return null

	for i in range(grid_inventory.get_all_placed_items().size()):
		var placed: GridInventory.PlacedItem = grid_inventory.get_all_placed_items()[i]
		if placed.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
			return tool_modifier_states.get(placed, null)

	return null


func get_total_weapon_physical_power() -> int:
	## Sums base_power from ALL equipped active tools.
	if not is_player or not grid_inventory:
		return 0
	var total: int = 0
	for i in range(grid_inventory.get_all_placed_items().size()):
		var placed: GridInventory.PlacedItem = grid_inventory.get_all_placed_items()[i]
		if placed.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
			total += placed.item_data.base_power
	return total


func get_total_weapon_magical_power() -> int:
	## Sums magical_power from ALL equipped active tools.
	if not is_player or not grid_inventory:
		return 0
	var total: int = 0
	for i in range(grid_inventory.get_all_placed_items().size()):
		var placed: GridInventory.PlacedItem = grid_inventory.get_all_placed_items()[i]
		if placed.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
			total += placed.item_data.magical_power
	return total


func can_use_skill(skill: SkillData) -> bool:
	if skill.use_all_mp:
		if current_mp <= 0:
			return false
	elif current_mp < skill.mp_cost:
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
	# Shield absorbs damage first
	if shield_hp > 0:
		if amount <= shield_hp:
			shield_hp -= amount
			return 0
		else:
			amount -= shield_hp
			shield_hp = 0
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


func restore_mp(amount: int) -> int:
	var actual: int = mini(amount, max_mp - current_mp)
	current_mp += actual
	return actual


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


## Gem-based status effect system (Burn, Poisoned, Chilled, Shocked)

func apply_gem_status_effect(effect_template: StatusEffect, stacks: int) -> bool:
	## Applies a gem-based status effect by adding the given number of stacks.
	## Stacks accumulate on existing effects (each stack = 1 remaining turn).

	# Check if already has this effect type — ADD stacks, don't refresh to max
	for i in range(active_gem_status_effects.size()):
		var existing: StatusEffect = active_gem_status_effects[i]
		if existing.effect_type == effect_template.effect_type:
			existing.duration_turns += stacks
			return true

	# Apply new effect with given stacks as initial duration
	var new_effect: StatusEffect = effect_template.create_instance()
	new_effect.duration_turns = stacks
	active_gem_status_effects.append(new_effect)
	return true


func process_gem_status_effects() -> void:
	## Processes all active gem-based status effects, dealing damage and decrementing duration.
	## Should be called at the start of each turn.
	var expired_indices: Array = []

	for i in range(active_gem_status_effects.size()):
		var effect: StatusEffect = active_gem_status_effects[i]

		# Apply effect based on type
		match effect.effect_type:
			Enums.StatusEffectType.BURN, Enums.StatusEffectType.POISONED:
				# Damage scales with remaining stacks, capped at max_tick_damage
				if effect.tick_damage > 0:
					var raw: int = effect.duration_turns * effect.tick_damage
					var dmg: int = raw if effect.max_tick_damage == 0 else mini(raw, effect.max_tick_damage)
					take_damage(dmg)

			Enums.StatusEffectType.CHILLED:
				# Speed reduction is handled in get_effective_stat()
				pass

			Enums.StatusEffectType.SHOCKED:
				# Skip turn chance is checked in battle logic
				pass

		# Decrement duration
		effect.duration_turns -= 1
		if effect.duration_turns <= 0:
			expired_indices.append(i)

	# Remove expired effects (reverse order to maintain indices)
	for i in range(expired_indices.size() - 1, -1, -1):
		var idx: int = expired_indices[i]
		active_gem_status_effects.remove_at(idx)


func has_gem_status_effect(effect_type: Enums.StatusEffectType) -> bool:
	## Returns true if the entity has the specified gem status effect active.
	for i in range(active_gem_status_effects.size()):
		var effect: StatusEffect = active_gem_status_effects[i]
		if effect.effect_type == effect_type:
			return true
	return false


func get_gem_status_effect(effect_type: Enums.StatusEffectType) -> StatusEffect:
	## Returns the gem status effect of the specified type, or null if not found.
	for i in range(active_gem_status_effects.size()):
		var effect: StatusEffect = active_gem_status_effects[i]
		if effect.effect_type == effect_type:
			return effect
	return null
