import { Item } from '../models/Item.js';
import { COLORS } from '../utils/Constants.js';
import { SKILLS, ITEMS, ENEMIES, CHARACTER } from '../utils/GameConfig.js';

export class GameData {
  static getDefaultItems() {
    return [
      new Item({
        id: 1,
        name: "Sword",
        type: "weapon",
        width: 1,
        height: 3,
        color: COLORS.HEX.RED, // Use color constants instead of hardcoded '#e74c3c'
        baseSkills: [
          {
            name: "Slash",
            description: "Basic sword attack",
            damage: SKILLS.BASE_SKILLS.slash.damage, // Use skill constants
            cost: SKILLS.BASE_SKILLS.slash.cost,
            type: SKILLS.BASE_SKILLS.slash.type,
          },
        ],
        enhancements: [
          {
            targetTypes: ["physical"],
            nameModifier: (name) => `Sharp ${name}`,
            descriptionModifier: (desc) => desc.replace("Basic", "Enhanced"),
            damageMultiplier: SKILLS.ENHANCEMENTS.DAMAGE_MULTIPLIER_RANGE[1] * 0.8, // Use enhancement ranges
            costModifier: 0,
          },
        ],
      }),

      new Item({
        id: 2,
        name: "Staff",
        type: "weapon",
        width: 1,
        height: 3,
        color: COLORS.HEX.PURPLE, // Use color constants
        baseSkills: [
          {
            name: "Fireball",
            description: "Launch a fireball",
            damage: SKILLS.BASE_SKILLS.fireball.damage, // Use skill constants
            cost: SKILLS.BASE_SKILLS.fireball.cost,
            type: SKILLS.BASE_SKILLS.fireball.type,
          },
        ],
        enhancements: [
          {
            targetTypes: ["magic"],
            nameModifier: (name) => name.replace("Fireball", "Greater Fireball"),
            descriptionModifier: (desc) => desc.replace("Launch", "Conjure and launch"),
            damageMultiplier: SKILLS.ENHANCEMENTS.DAMAGE_MULTIPLIER_RANGE[1] * 0.9, // 1.35x damage
            costModifier: SKILLS.ENHANCEMENTS.COST_INCREASE_MAX, // +2 cost
          },
        ],
      }),

      new Item({
        id: 3,
        name: "Shield",
        type: "armor",
        width: 2,
        height: 2,
        color: COLORS.HEX.DARK_BLUE, // Use color constants
        baseSkills: [
          {
            name: "Block",
            description: "Defensive stance",
            damage: SKILLS.BASE_SKILLS.block.damage, // 0 damage
            cost: SKILLS.BASE_SKILLS.block.cost,
            type: SKILLS.BASE_SKILLS.block.type,
          },
        ],
        enhancements: [
          {
            targetTypes: ["defensive"],
            nameModifier: (name) => `Iron ${name}`,
            descriptionModifier: (desc) => desc + " with increased effectiveness",
            damageMultiplier: 1.0, // No damage change for defensive
            costModifier: -1, // Reduce cost by 1
          },
        ],
      }),

      new Item({
        id: 4,
        name: "Crossbow",
        type: "weapon",
        width: 2,
        height: 1,
        color: COLORS.HEX.ORANGE, // Use color constants
        baseSkills: [
          {
            name: "Bolt Shot",
            description: "Ranged crossbow attack",
            damage: 22, // Could be moved to SKILLS.BASE_SKILLS if used elsewhere
            cost: 3,
            type: "ranged",
          },
        ],
        enhancements: [
          {
            targetTypes: ["ranged"],
            nameModifier: (name) => name.replace("Bolt", "Piercing Bolt"),
            descriptionModifier: (desc) => desc.replace("Ranged", "Armor-piercing ranged"),
            damageMultiplier: SKILLS.ENHANCEMENTS.DAMAGE_MULTIPLIER_RANGE[1] * 0.87, // 1.3x damage
            costModifier: 1,
          },
        ],
      }),

      new Item({
        id: 5,
        name: "Dual Blades",
        type: "weapon",
        width: 2,
        height: 3,
        color: COLORS.HEX.YELLOW, // Use color constants
        baseSkills: [
          {
            name: "Twin Strike",
            description: "Attack with both blades",
            damage: 16, // Lower base damage but enhanced version is powerful
            cost: 2,
            type: "physical",
          },
        ],
        enhancements: [
          {
            targetTypes: ["physical"],
            nameModifier: (name) => name.replace("Twin Strike", "Whirlwind Assault"),
            descriptionModifier: (desc) => desc.replace("both blades", "a spinning blade dance"),
            damageMultiplier: 2.2, // Very high multiplier for this special enhancement
            costModifier: SKILLS.ENHANCEMENTS.COST_INCREASE_MAX,
          },
          // Multiple enhancements for rare items
          {
            targetTypes: ["ranged"],
            nameModifier: (name) => name.replace("Arrow Shot", "Double Shot"),
            descriptionModifier: (desc) => desc.replace("Ranged attack", "Fire two arrows simultaneously"),
            damageMultiplier: SKILLS.ENHANCEMENTS.DAMAGE_MULTIPLIER_RANGE[1] * 1.27, // 1.9x
            costModifier: SKILLS.ENHANCEMENTS.COST_INCREASE_MAX,
          },
          {
            targetTypes: ["defensive"],
            nameModifier: (name) => `Enhanced ${name}`,
            descriptionModifier: (desc) => desc + " with doubled effectiveness",
            damageMultiplier: 2.0,
            costModifier: 1,
          },
          {
            targetTypes: ["healing"],
            nameModifier: (name) => name.replace("Heal", "Greater Heal"),
            descriptionModifier: (desc) => desc.replace("Restore health", "Powerful dual-layer healing"),
            damageMultiplier: SKILLS.ENHANCEMENTS.DAMAGE_MULTIPLIER_RANGE[1] * 1.2, // 1.8x
            costModifier: SKILLS.ENHANCEMENTS.COST_INCREASE_MAX,
          },
        ],
      }),

      new Item({
        id: 6,
        name: "Potion",
        type: "consumable",
        width: 1,
        height: 1,
        color: COLORS.HEX.GREEN, // Use color constants
        baseSkills: [
          {
            name: "Heal",
            description: "Restore health",
            damage: SKILLS.BASE_SKILLS.heal.damage, // Use healing skill constants
            cost: SKILLS.BASE_SKILLS.heal.cost,
            type: SKILLS.BASE_SKILLS.heal.type,
          },
        ],
      }),

      new Item({
        id: 7,
        name: "Bow",
        type: "weapon",
        width: 1,
        height: 2,
        color: COLORS.HEX.TEAL, // Use color constants
        baseSkills: [
          {
            name: "Arrow Shot",
            description: "Ranged attack",
            damage: SKILLS.BASE_SKILLS.arrowShot.damage, // Use skill constants
            cost: SKILLS.BASE_SKILLS.arrowShot.cost,
            type: SKILLS.BASE_SKILLS.arrowShot.type,
          },
        ],
      }),

      new Item({
        id: 8,
        name: "Armor",
        type: "armor",
        width: 2,
        height: 3,
        color: COLORS.HEX.GRAY, // Use color constants
        baseSkills: [
          {
            name: "Fortify",
            description: "Increase defense",
            damage: 0, // Could be moved to SKILLS.BASE_SKILLS
            cost: 3,
            type: "defensive",
          },
        ],
        enhancements: [
          {
            targetTypes: ["defensive"],
            nameModifier: (name) => `Reinforced ${name}`,
            descriptionModifier: (desc) => desc.replace("Increase", "Greatly increase"),
            damageMultiplier: 1.0, // No damage for defensive skills
            costModifier: -1,
          },
        ],
      }),

      new Item({
        id: 9,
        name: "Ice Shard",
        type: "weapon",
        width: 1,
        height: 1,
        color: "#64b5f6", // Light blue - could be added to constants
        baseSkills: [
          {
            name: "Ice Spike",
            description: "Sharp ice projectile",
            damage: SKILLS.BASE_SKILLS.iceSpike.damage, // Use skill constants
            cost: SKILLS.BASE_SKILLS.iceSpike.cost,
            type: SKILLS.BASE_SKILLS.iceSpike.type,
          },
        ],
        enhancements: [
          {
            targetTypes: ["magic"],
            nameModifier: (name) => name.replace("Ice Spike", "Frost Spear"),
            descriptionModifier: (desc) => desc.replace("Sharp ice", "Massive frozen"),
            damageMultiplier: SKILLS.ENHANCEMENTS.DAMAGE_MULTIPLIER_RANGE[1] * 0.73, // 1.1x
            costModifier: 0,
          },
          {
            targetTypes: ["healing"],
            nameModifier: (name) => name.replace("Heal", "Frost Mend"),
            descriptionModifier: (desc) => desc.replace("Restore health", "Cooling ice healing that numbs pain"),
            damageMultiplier: SKILLS.ENHANCEMENTS.DAMAGE_MULTIPLIER_RANGE[1] * 0.73, // 1.1x
            costModifier: 0,
          },
        ],
      }),

      new Item({
        id: 10,
        name: "Lightning Rod",
        type: "weapon",
        width: 1,
        height: 2,
        color: COLORS.HEX.YELLOW, // Use color constants
        baseSkills: [
          {
            name: "Lightning Bolt",
            description: "Electric shock attack",
            damage: SKILLS.BASE_SKILLS.lightningBolt.damage, // Use skill constants
            cost: SKILLS.BASE_SKILLS.lightningBolt.cost,
            type: SKILLS.BASE_SKILLS.lightningBolt.type,
          },
        ],
      }),
    ];
  }

  static getSkillTypeColor(type) {
    // Use skill type colors from GameConfig instead of hardcoded values
    const skillType = SKILLS.TYPES[type];
    return skillType ? skillType.colorHex : COLORS.HEX.GRAY;
  }

  static createEnemyTemplates() {
    // Return enemy templates from GameConfig instead of hardcoded values
    const templates = {};
    
    Object.entries(ENEMIES.TEMPLATES).forEach(([key, template]) => {
      templates[key] = {
        name: template.name,
        maxHp: template.maxHp,
        maxMp: template.maxMp,
        baseAttack: template.baseAttack,
        baseDefense: template.baseDefense,
        baseSpeed: template.baseSpeed,
        skills: [
          { 
            name: "Scratch", 
            damage: Math.floor(template.baseAttack * 0.8), // 80% of base attack
            cost: 0, 
            type: "physical" 
          },
          { 
            name: "Special Attack", 
            damage: Math.floor(template.baseAttack * 1.2), // 120% of base attack
            cost: Math.floor(template.maxMp * 0.3), // 30% of max MP
            type: key === "wizard" ? "magic" : "physical" 
          },
        ],
      };
    });

    return templates;
  }

  // Character creation using constants
  static createPlayerCharacter() {
    return {
      name: "Hero",
      hp: CHARACTER.BASE_STATS.HP,
      maxHp: CHARACTER.BASE_STATS.HP,
      mp: CHARACTER.BASE_STATS.MP,
      maxMp: CHARACTER.BASE_STATS.MP,
      level: CHARACTER.BASE_STATS.LEVEL,
      attack: CHARACTER.BASE_STATS.ATTACK,
      defense: CHARACTER.BASE_STATS.DEFENSE,
      speed: CHARACTER.BASE_STATS.SPEED,
      skills: [
        {
          name: "Basic Attack",
          damage: CHARACTER.BASE_STATS.ATTACK,
          cost: 0,
          type: "physical",
        }
      ],
    };
  }

  // Item rarity helpers using GameConfig
  static getItemRarity(item) {
    const enhancementCount = item.enhancements?.length || 0;
    
    if (enhancementCount === 0) return 'common';
    if (enhancementCount <= 2) return 'uncommon';
    if (enhancementCount <= 3) return 'rare';
    if (enhancementCount <= 4) return 'epic';
    return 'legendary';
  }

  static getItemRarityColor(rarity) {
    const rarityData = ITEMS.RARITY[rarity];
    return rarityData ? rarityData.color : COLORS.HEX.GRAY;
  }

  static getItemDropChance(rarity, source = 'combat') {
    const dropRates = ITEMS.DROP_RATES[source];
    return dropRates ? dropRates[rarity] : 0;
  }
}