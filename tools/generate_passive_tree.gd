@tool
extends EditorScript
## Generates the full passive skill tree with ~120 nodes across 3 paths + bridges.
## Run from Godot: File > Run (or Ctrl+Shift+X) with this script open.
##
## Tree structure per path:
##   Root (Minor) → 2-3 Minor → Notable → 2-3 Minor → Notable → 2-3 Minor → Keystone
##   With branches that fork and reconverge.
##
## After running, open the in-game Tree Editor to fine-tune positions visually.

const TREE_PATH := "res://data/passive_trees/tree_unified.tres"

# Preload scripts for resource creation
const PassiveNodeScript := preload("res://scripts/resources/passive_node_data.gd")
const PassiveTreeScript := preload("res://scripts/resources/passive_tree_data.gd")
const StatModScript := preload("res://scripts/resources/stat_modifier.gd")


func _run() -> void:
	var tree: Resource = PassiveTreeScript.new()
	tree.display_name = "Skill Tree"
	tree.nodes = []

	# Build all three paths
	_build_warrior_path(tree)
	_build_mage_path(tree)
	_build_rogue_path(tree)
	_build_bridges(tree)

	# Save
	var err := ResourceSaver.save(tree, TREE_PATH)
	if err == OK:
		print("[PassiveTreeGen] Saved %d nodes to %s" % [tree.nodes.size(), TREE_PATH])
	else:
		printerr("[PassiveTreeGen] Failed to save: %d" % err)


# ============================================================
#  WARRIOR PATH — Top-left region (x: 0-800, y: 0-600)
# ============================================================

func _build_warrior_path(tree: Resource) -> void:
	var nodes: Array = []
	# Spacing constants
	var ox: float = 400.0  # origin x
	var oy: float = 300.0  # origin y
	var sx: float = 90.0   # horizontal spacing
	var sy: float = 80.0   # vertical spacing

	# === ROOT ===
	nodes.append(_node("w_root", "Vigor", _sm(0, 0, 8.0), "", ox, oy,
		"Increases maximum health."))

	# === LAYER 1 — Two minor branches ===
	nodes.append(_node("w_tough_1", "Tough", _sm(5, 0, 2.0), "", ox - sx, oy - sy,
		"Hardens the body against blows.", ["w_root"]))
	nodes.append(_node("w_might_1", "Might", _sm(4, 0, 2.0), "", ox + sx, oy - sy,
		"Raw physical power.", ["w_root"]))

	# === LAYER 2 — More minors ===
	nodes.append(_node("w_vitality_1", "Vitality", _sm(0, 0, 5.0), "", ox - sx * 2, oy - sy * 2,
		"More health.", ["w_tough_1"]))
	nodes.append(_node("w_endure_1", "Endurance", _sm(5, 1, 3.0), "", ox - sx, oy - sy * 2,
		"Percentage defense boost.", ["w_tough_1"]))
	nodes.append(_node("w_ferocity_1", "Ferocity", _sm(4, 0, 2.0), "", ox + sx, oy - sy * 2,
		"More attack power.", ["w_might_1"]))
	nodes.append(_node("w_brutality_1", "Brutality", _sm(9, 0, 5.0), "", ox + sx * 2, oy - sy * 2,
		"Harder critical hits.", ["w_might_1"]))

	# === LAYER 3 — NOTABLES (first tier) ===
	# Tank notable
	nodes.append(_notable("w_shield_wall", "Shield Wall", "start_shield",
		ox - sx * 1.5, oy - sy * 3,
		"Start battle with a protective shield.",
		["w_vitality_1", "w_endure_1"], 1, []))
	# DPS notable
	nodes.append(_notable("w_crushing_blow", "Crushing Blow", "crushing_blow",
		ox + sx * 1.5, oy - sy * 3,
		"Physical attacks can shred enemy defense.",
		["w_ferocity_1", "w_brutality_1"], 1, []))

	# === LAYER 4 — More minors after notables ===
	nodes.append(_node("w_tough_2", "Tough", _sm(5, 0, 3.0), "", ox - sx * 2.5, oy - sy * 4,
		"Hardens the body further.", ["w_shield_wall"]))
	nodes.append(_node("w_vitality_2", "Vitality", _sm(0, 0, 8.0), "", ox - sx * 1, oy - sy * 4,
		"More health.", ["w_shield_wall"]))
	nodes.append(_node("w_might_2", "Might", _sm(4, 0, 3.0), "", ox + sx * 1, oy - sy * 4,
		"More power.", ["w_crushing_blow"]))
	nodes.append(_node("w_ferocity_2", "Ferocity", _sm(4, 1, 3.0), "", ox + sx * 2.5, oy - sy * 4,
		"Percentage attack boost.", ["w_crushing_blow"]))

	# === LAYER 5 — NOTABLES (second tier) ===
	nodes.append(_notable("w_bulwark_stance", "Bulwark Stance", "bulwark_stance",
		ox - sx * 1.5, oy - sy * 5,
		"While defending, adjacent allies take 15% less damage.",
		["w_tough_2", "w_vitality_2"], 1, []))
	nodes.append(_notable("w_retaliation", "Retaliation", "counter_attack",
		ox, oy - sy * 5,
		"15% chance to counter-attack when hit.",
		["w_vitality_2", "w_might_2"], 1, []))
	nodes.append(_notable("w_bloodthirst", "Bloodthirst", "bloodthirst",
		ox + sx * 1.5, oy - sy * 5,
		"Heal 8% of physical damage dealt.",
		["w_might_2", "w_ferocity_2"], 1, []))

	# === LAYER 6 — Pre-keystone minors ===
	nodes.append(_node("w_endure_2", "Endurance", _sm(5, 1, 5.0), "", ox - sx, oy - sy * 6,
		"Even tougher.", ["w_bulwark_stance"]))
	nodes.append(_node("w_vitality_3", "Vitality", _sm(0, 1, 5.0), "", ox, oy - sy * 6,
		"Percentage health boost.", ["w_retaliation"]))
	nodes.append(_node("w_brutality_2", "Brutality", _sm(9, 0, 8.0), "", ox + sx, oy - sy * 6,
		"Devastating crits.", ["w_bloodthirst"]))

	# === LAYER 7 — NOTABLES (third tier) ===
	nodes.append(_notable("w_unbreaking", "Unbreaking", "unbreaking",
		ox - sx * 0.5, oy - sy * 7,
		"+30% status resist when above 50% HP.",
		["w_endure_2", "w_vitality_3"], 1, []))
	nodes.append(_notable("w_second_wind", "Second Wind", "second_wind",
		ox + sx * 0.5, oy - sy * 7,
		"Items heal 20% more HP.",
		["w_vitality_3", "w_brutality_2"], 1, []))

	# === LAYER 8 — Pre-keystone ===
	nodes.append(_node("w_tough_3", "Tough", _sm(5, 0, 4.0), "", ox - sx * 0.5, oy - sy * 8,
		"Final defense.", ["w_unbreaking"]))
	nodes.append(_node("w_might_3", "Might", _sm(4, 0, 4.0), "", ox + sx * 0.5, oy - sy * 8,
		"Final power.", ["w_second_wind"]))

	# === KEYSTONES ===
	nodes.append(_keystone("w_ks_fortress", "Immortal Fortress", "ks_immortal_fortress",
		ox - sx, oy - sy * 9,
		"Survive a lethal blow once per battle (30% HP). -20% Phys Atk.",
		["w_tough_3"]))
	nodes.append(_keystone("w_ks_berserker", "Berserker's Rage", "ks_berserker_rage",
		ox + sx, oy - sy * 9,
		"+40% Phys Atk, +15% Crit Dmg. Cannot defend. Cannot be healed by allies.",
		["w_might_3"]))

	for n in nodes:
		tree.nodes.append(n)


# ============================================================
#  MAGE PATH — Bottom-left region (x: -400 to 400, y: 600-1300)
# ============================================================

func _build_mage_path(tree: Resource) -> void:
	var nodes: Array = []
	var ox: float = 0.0
	var oy: float = 900.0
	var sx: float = 90.0
	var sy: float = 80.0

	# === ROOT ===
	nodes.append(_node("m_root", "Focus", _sm(1, 0, 8.0), "", ox, oy,
		"Expand your mana reserves."))

	# === LAYER 1 ===
	nodes.append(_node("m_ward_1", "Ward", _sm(7, 0, 2.0), "", ox - sx, oy + sy,
		"Magical protection.", ["m_root"]))
	nodes.append(_node("m_sorcery_1", "Sorcery", _sm(6, 0, 2.0), "", ox + sx, oy + sy,
		"Sharpen magical attack.", ["m_root"]))

	# === LAYER 2 ===
	nodes.append(_node("m_arcana_1", "Arcana", _sm(1, 0, 5.0), "", ox - sx * 2, oy + sy * 2,
		"More mana.", ["m_ward_1"]))
	nodes.append(_node("m_warding_1", "Warding", _sm(7, 1, 3.0), "", ox - sx, oy + sy * 2,
		"Percentage magic defense.", ["m_ward_1"]))
	nodes.append(_node("m_sorcery_2", "Sorcery", _sm(6, 0, 2.0), "", ox + sx, oy + sy * 2,
		"More magic attack.", ["m_sorcery_1"]))
	nodes.append(_node("m_precision_1", "Precision", _sm(8, 0, 3.0), "", ox + sx * 2, oy + sy * 2,
		"Better crit rate.", ["m_sorcery_1"]))

	# === LAYER 3 — NOTABLES ===
	nodes.append(_notable("m_arcane_shield", "Arcane Shield", "arcane_shield",
		ox - sx * 1.5, oy + sy * 3,
		"+1 Mag Def per 10 unspent MP at turn start.",
		["m_arcana_1", "m_warding_1"], 1, []))
	nodes.append(_notable("m_elemental_mastery", "Elemental Mastery", "elemental_mastery",
		ox + sx * 1.5, oy + sy * 3,
		"+15% damage vs element-weak enemies.",
		["m_sorcery_2", "m_precision_1"], 1, []))

	# === LAYER 4 ===
	nodes.append(_node("m_arcana_2", "Arcana", _sm(1, 0, 5.0), "", ox - sx * 2.5, oy + sy * 4,
		"More mana.", ["m_arcane_shield"]))
	nodes.append(_node("m_ward_2", "Ward", _sm(7, 0, 3.0), "", ox - sx * 1, oy + sy * 4,
		"Magic defense.", ["m_arcane_shield"]))
	nodes.append(_node("m_sorcery_3", "Sorcery", _sm(6, 0, 3.0), "", ox + sx * 1, oy + sy * 4,
		"Magic power.", ["m_elemental_mastery"]))
	nodes.append(_node("m_precision_2", "Precision", _sm(8, 0, 3.0), "", ox + sx * 2.5, oy + sy * 4,
		"Crit rate.", ["m_elemental_mastery"]))

	# === LAYER 5 — NOTABLES ===
	nodes.append(_notable("m_mana_surge", "Mana Surge", "mana_regen",
		ox - sx * 1.5, oy + sy * 5,
		"Restore 3 MP at the start of each turn.",
		["m_arcana_2", "m_ward_2"], 1, []))
	nodes.append(_notable("m_spell_echo", "Spell Echo", "spell_echo",
		ox, oy + sy * 5,
		"10% chance for spells to trigger twice at 50% damage.",
		["m_ward_2", "m_sorcery_3"], 1, []))
	nodes.append(_notable("m_resonance", "Resonance", "resonance",
		ox + sx * 1.5, oy + sy * 5,
		"Same-element consecutive spells deal +20% damage.",
		["m_sorcery_3", "m_precision_2"], 1, []))

	# === LAYER 6 ===
	nodes.append(_node("m_arcana_3", "Arcana", _sm(1, 1, 5.0), "", ox - sx, oy + sy * 6,
		"Percentage mana boost.", ["m_mana_surge"]))
	nodes.append(_node("m_sorcery_4", "Sorcery", _sm(6, 1, 5.0), "", ox, oy + sy * 6,
		"Percentage magic attack.", ["m_spell_echo"]))
	nodes.append(_node("m_brutality_m1", "Brutality", _sm(9, 0, 8.0), "", ox + sx, oy + sy * 6,
		"Critical damage.", ["m_resonance"]))

	# === LAYER 7 — NOTABLES ===
	nodes.append(_notable("m_focused_mind", "Focused Mind", "focused_mind_cond",
		ox - sx * 0.5, oy + sy * 7,
		"+15% Mag Atk when MP above 50%.",
		["m_arcana_3", "m_sorcery_4"], 1, []))
	nodes.append(_notable("m_chain_reaction", "Chain Reaction", "chain_reaction",
		ox + sx * 0.5, oy + sy * 7,
		"Status effects 20% chance to spread.",
		["m_sorcery_4", "m_brutality_m1"], 1, []))

	# === LAYER 8 ===
	nodes.append(_node("m_ward_3", "Ward", _sm(7, 0, 4.0), "", ox - sx * 0.5, oy + sy * 8,
		"Final magic defense.", ["m_focused_mind"]))
	nodes.append(_node("m_sorcery_5", "Sorcery", _sm(6, 0, 4.0), "", ox + sx * 0.5, oy + sy * 8,
		"Final magic power.", ["m_chain_reaction"]))

	# === KEYSTONES ===
	nodes.append(_keystone("m_ks_archmage", "Archmage", "ks_archmage",
		ox - sx, oy + sy * 9,
		"First spell each battle costs 0 MP. -30% Max HP.",
		["m_ward_3"]))
	nodes.append(_keystone("m_ks_overload", "Elemental Overload", "ks_elemental_overload",
		ox + sx, oy + sy * 9,
		"+30% elemental damage. Non-elemental -50%.",
		["m_sorcery_5"]))

	for n in nodes:
		tree.nodes.append(n)


# ============================================================
#  ROGUE PATH — Right region (x: 600-1400, y: 400-1000)
# ============================================================

func _build_rogue_path(tree: Resource) -> void:
	var nodes: Array = []
	var ox: float = 1000.0
	var oy: float = 600.0
	var sx: float = 90.0
	var sy: float = 80.0

	# === ROOT ===
	nodes.append(_node("r_root", "Agility", _sm(2, 0, 2.0), "", ox, oy,
		"Move faster."))

	# === LAYER 1 ===
	nodes.append(_node("r_cunning_1", "Cunning", _sm(3, 0, 1.0), "", ox + sx, oy - sy,
		"Fortune favors the clever.", ["r_root"]))
	nodes.append(_node("r_keen_1", "Keen Eye", _sm(8, 0, 3.0), "", ox + sx, oy + sy,
		"Spot weaknesses.", ["r_root"]))

	# === LAYER 2 ===
	nodes.append(_node("r_alacrity_1", "Alacrity", _sm(2, 0, 2.0), "", ox + sx * 2, oy - sy * 2,
		"Speed.", ["r_cunning_1"]))
	nodes.append(_node("r_fortune_1", "Fortune", _sm(3, 0, 1.0), "", ox + sx * 2, oy - sy,
		"Luck.", ["r_cunning_1"]))
	nodes.append(_node("r_ferocity_r1", "Ferocity", _sm(4, 0, 2.0), "", ox + sx * 2, oy + sy,
		"Attack power.", ["r_keen_1"]))
	nodes.append(_node("r_precision_r1", "Precision", _sm(8, 0, 3.0), "", ox + sx * 2, oy + sy * 2,
		"Crit rate.", ["r_keen_1"]))

	# === LAYER 3 — NOTABLES ===
	nodes.append(_notable("r_ambush", "Ambush", "ambush",
		ox + sx * 3, oy - sy * 1.5,
		"First attack each battle deals +40% damage.",
		["r_alacrity_1", "r_fortune_1"], 1, []))
	nodes.append(_notable("r_exploit", "Exploit Weakness", "exploit_weakness",
		ox + sx * 3, oy + sy * 1.5,
		"+25% damage vs enemies with status effects.",
		["r_ferocity_r1", "r_precision_r1"], 1, []))

	# === LAYER 4 ===
	nodes.append(_node("r_alacrity_2", "Alacrity", _sm(2, 1, 3.0), "", ox + sx * 4, oy - sy * 2.5,
		"Percentage speed.", ["r_ambush"]))
	nodes.append(_node("r_cunning_2", "Cunning", _sm(3, 0, 1.0), "", ox + sx * 4, oy - sy * 1,
		"Luck.", ["r_ambush"]))
	nodes.append(_node("r_ferocity_r2", "Ferocity", _sm(4, 0, 3.0), "", ox + sx * 4, oy + sy * 1,
		"Attack.", ["r_exploit"]))
	nodes.append(_node("r_brutality_r1", "Brutality", _sm(9, 0, 5.0), "", ox + sx * 4, oy + sy * 2.5,
		"Crit damage.", ["r_exploit"]))

	# === LAYER 5 — NOTABLES ===
	nodes.append(_notable("r_shadowstep", "Shadowstep", "shadowstep",
		ox + sx * 5, oy - sy * 2,
		"After dodging, next attack +30% Crit Rate.",
		["r_alacrity_2", "r_cunning_2"], 1, []))
	nodes.append(_notable("r_nimble", "Nimble", "evasion",
		ox + sx * 5, oy - sy * 0.5,
		"10% chance to dodge attacks.",
		["r_cunning_2", "r_ferocity_r2"], 1, []))
	nodes.append(_notable("r_poison_mastery", "Poison Mastery", "poison_mastery",
		ox + sx * 5, oy + sy * 2,
		"Poison lasts 1 extra turn, +15% Poison damage.",
		["r_ferocity_r2", "r_brutality_r1"], 1, []))

	# === LAYER 6 ===
	nodes.append(_node("r_alacrity_3", "Alacrity", _sm(2, 0, 2.0), "", ox + sx * 6, oy - sy * 1.5,
		"Speed.", ["r_shadowstep"]))
	nodes.append(_node("r_fortune_2", "Fortune", _sm(3, 0, 2.0), "", ox + sx * 6, oy,
		"Luck.", ["r_nimble"]))
	nodes.append(_node("r_precision_r2", "Precision", _sm(8, 0, 5.0), "", ox + sx * 6, oy + sy * 1.5,
		"Crit rate.", ["r_poison_mastery"]))

	# === LAYER 7 — NOTABLES ===
	nodes.append(_notable("r_quick_hands", "Quick Hands", "quick_hands",
		ox + sx * 7, oy - sy * 1,
		"Item use doesn't cost turn (once per battle).",
		["r_alacrity_3", "r_fortune_2"], 1, []))
	nodes.append(_notable("r_lucky_strike", "Lucky Strike", "lucky_strike",
		ox + sx * 7, oy + sx * 0.5,
		"Crits have 20% chance to drop bonus gold.",
		["r_fortune_2", "r_precision_r2"], 1, []))

	# === LAYER 8 ===
	nodes.append(_node("r_alacrity_4", "Alacrity", _sm(2, 0, 3.0), "", ox + sx * 8, oy - sy * 0.5,
		"Speed.", ["r_quick_hands"]))
	nodes.append(_node("r_brutality_r2", "Brutality", _sm(9, 0, 8.0), "", ox + sx * 8, oy + sy * 0.5,
		"Crit damage.", ["r_lucky_strike"]))

	# === KEYSTONES ===
	nodes.append(_keystone("r_ks_phantom", "Phantom", "ks_phantom",
		ox + sx * 9, oy - sy * 0.5,
		"25% dodge chance. -20% Max HP.",
		["r_alacrity_4"]))
	nodes.append(_keystone("r_ks_executioner", "Executioner", "ks_executioner",
		ox + sx * 9, oy + sy * 0.5,
		"+100% damage below 25% HP. -15% above 50%.",
		["r_brutality_r2"]))

	for n in nodes:
		tree.nodes.append(n)


# ============================================================
#  BRIDGE NODES — Connect the three paths
# ============================================================

func _build_bridges(tree: Resource) -> void:
	var nodes: Array = []

	# Warrior ↔ Mage bridge (between w_shield_wall and m_arcane_shield regions)
	nodes.append(_node("bridge_wm_1", "Mystic Guard", _sm(7, 0, 3.0), "",
		200, 400, "Channel defense into magic protection.",
		["w_shield_wall"]))
	nodes.append(_notable("bridge_wm_spell_sword", "Spell Sword", "spell_sword",
		100, 550, "Phys Atk adds 15% to Mag Atk.",
		["bridge_wm_1"], 0, []))
	nodes.append(_node("bridge_mw_1", "Arcane Fortitude", _sm(0, 0, 8.0), "",
		50, 700, "Mana reinforces your body.",
		["bridge_wm_spell_sword", "m_arcane_shield"], 1))

	# Mage ↔ Rogue bridge (bottom-right)
	nodes.append(_node("bridge_mr_1", "Mental Acuity", _sm(3, 0, 1.0), "",
		400, 1050, "Keen awareness sharpens luck.",
		["m_resonance"]))
	nodes.append(_notable("bridge_mr_arcane_trick", "Arcane Trickster", "arcane_trickster",
		600, 1000, "Spell status effects last 1 extra turn.",
		["bridge_mr_1"], 0, []))
	nodes.append(_node("bridge_rm_1", "Mystic Flow", _sm(1, 0, 5.0), "",
		800, 900, "Fluid movement channels magical energy.",
		["bridge_mr_arcane_trick", "r_poison_mastery"], 1))

	# Warrior ↔ Rogue bridge (top-right)
	nodes.append(_node("bridge_wr_1", "Predator", _sm(2, 0, 2.0), "",
		700, 200, "Aggressive instincts quicken reflexes.",
		["w_bloodthirst"]))
	nodes.append(_notable("bridge_wr_shadow_knight", "Shadow Knight", "shadow_knight",
		850, 300, "Counter-attacks have +50% Crit Rate.",
		["bridge_wr_1"], 0, []))
	nodes.append(_node("bridge_rw_1", "Iron Will", _sm(5, 0, 2.0), "",
		950, 400, "Determination hardens defenses.",
		["bridge_wr_shadow_knight", "r_ambush"], 1))

	# Central notable — Battle Mage (accessible from Warrior-Mage bridge and Mage path)
	nodes.append(_notable("bridge_battle_mage", "Battle Mage", "battle_mage",
		300, 650, "Mag Atk adds 15% to Phys Atk.",
		["bridge_mw_1", "m_mana_surge"], 1, []))

	# Central keystone — Jack of All Trades
	nodes.append(_keystone("ks_jack", "Jack of All Trades", "ks_jack_of_all_trades",
		500, 600, "+10% all stats. No other Keystones.",
		["bridge_wm_spell_sword", "bridge_mr_arcane_trick", "bridge_wr_shadow_knight"], 1))

	for n in nodes:
		tree.nodes.append(n)


# ============================================================
#  NODE FACTORY HELPERS
# ============================================================

## Create a stat modifier: stat_idx maps to Enums.Stat, mod_type 0=FLAT 1=PERCENT
func _sm(stat_idx: int, mod_type: int, value: float) -> Array:
	return [stat_idx, mod_type, value]


func _node(id: String, display_name: String, sm: Array, effect: String,
		px: float, py: float, desc: String, prereqs: Array = [], prereq_mode: int = 0) -> Resource:
	var node: Resource = PassiveNodeScript.new()
	node.id = id
	node.display_name = display_name
	node.description = desc
	node.tier = 0  # MINOR
	node.position = Vector2(px, py)
	node.gold_cost = 50
	node.special_effect_id = effect

	if not sm.is_empty():
		var mod: Resource = StatModScript.new()
		mod.stat = sm[0]
		mod.modifier_type = sm[1]
		mod.value = sm[2]
		node.stat_modifiers = [mod]

	var prereq_arr: Array[String] = []
	for p in prereqs:
		prereq_arr.append(p)
	node.prerequisites = prereq_arr
	node.prerequisite_mode = prereq_mode
	return node


func _notable(id: String, display_name: String, effect: String,
		px: float, py: float, desc: String,
		prereqs: Array, prereq_mode: int, stat_mods: Array) -> Resource:
	var node: Resource = PassiveNodeScript.new()
	node.id = id
	node.display_name = display_name
	node.description = desc
	node.tier = 1  # NOTABLE
	node.position = Vector2(px, py)
	node.gold_cost = 150
	node.special_effect_id = effect

	var mods: Array[Resource] = []
	for sm_arr in stat_mods:
		var mod: Resource = StatModScript.new()
		mod.stat = sm_arr[0]
		mod.modifier_type = sm_arr[1]
		mod.value = sm_arr[2]
		mods.append(mod)
	node.stat_modifiers = []
	for m in mods:
		node.stat_modifiers.append(m)

	var prereq_arr: Array[String] = []
	for p in prereqs:
		prereq_arr.append(p)
	node.prerequisites = prereq_arr
	node.prerequisite_mode = prereq_mode
	return node


func _keystone(id: String, display_name: String, effect: String,
		px: float, py: float, desc: String,
		prereqs: Array, prereq_mode: int = 0) -> Resource:
	var node: Resource = PassiveNodeScript.new()
	node.id = id
	node.display_name = display_name
	node.description = desc
	node.tier = 2  # KEYSTONE
	node.position = Vector2(px, py)
	node.gold_cost = 500
	node.special_effect_id = effect

	var prereq_arr: Array[String] = []
	for p in prereqs:
		prereq_arr.append(p)
	node.prerequisites = prereq_arr
	node.prerequisite_mode = prereq_mode
	return node
