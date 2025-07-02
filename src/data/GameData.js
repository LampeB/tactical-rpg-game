import { Item } from "../models/Item.js";

export class GameData {
  static createSampleItems() {
    return [
      new Item({
        id: 1,
        name: "Sword",
        type: "weapon",
        width: 1,
        height: 3,
        color: "#e74c3c",
        baseSkills: [
          {
            name: "Attack",
            description: "Basic sword strike",
            damage: 25,
            cost: 0,
            type: "physical",
          },
        ],
      }),

      new Item({
        id: 2,
        name: "Staff",
        type: "weapon",
        width: 1,
        height: 2,
        color: "#9b59b6",
        baseSkills: [
          {
            name: "Fireball",
            description: "Launch a fireball",
            damage: 30,
            cost: 5,
            type: "magic",
          },
        ],
      }),

      new Item({
        id: 3,
        name: "Shield",
        type: "armor",
        width: 2,
        height: 2,
        color: "#34495e",
        baseSkills: [
          {
            name: "Block",
            description: "Defensive stance",
            damage: 0,
            cost: 2,
            type: "defensive",
          },
        ],
        enhancements: [
          {
            targetTypes: ["physical"],
            nameModifier: (name) => `Defensive ${name}`,
            descriptionModifier: (desc) => desc + " with shield protection",
            damageBonus: 5,
          },
        ],
      }),
      new Item({
        id: 4,
        name: "Fire Gem",
        type: "gem",
        width: 1,
        height: 1,
        color: "#e67e22",
        enhancements: [
          {
            targetTypes: ["magic"],
            nameModifier: (name) => name.replace("Fireball", "Fire Blast"),
            descriptionModifier: (desc) => desc + " (enhanced by fire gem)",
            damageMultiplier: 1.5,
          },
          {
            targetTypes: ["physical"],
            nameModifier: (name) => name.replace("Attack", "Flaming Strike"),
            descriptionModifier: (desc) =>
              desc.replace(
                "Basic sword strike",
                "Blazing sword attack with fire damage"
              ),
            damageMultiplier: 1.6,
            costModifier: 2,
          },
          {
            targetTypes: ["ranged"],
            nameModifier: (name) => name.replace("Arrow Shot", "Fire Arrow"),
            descriptionModifier: (desc) =>
              desc.replace(
                "Ranged attack",
                "Burning arrow that ignites targets"
              ),
            damageMultiplier: 1.4,
            costModifier: 1,
          },
          {
            targetTypes: ["defensive"],
            nameModifier: (name) => `Burning ${name}`,
            descriptionModifier: (desc) =>
              desc + " with fire retaliation damage",
            damageBonus: 8,
          },
          {
            targetTypes: ["healing"],
            nameModifier: (name) => name.replace("Heal", "Cauterize"),
            descriptionModifier: (desc) =>
              desc.replace(
                "Restore health",
                "Painful but effective fire healing"
              ),
            damageMultiplier: 0.8,
            costModifier: 1,
          },
        ],
      }),

      new Item({
        id: 5,
        name: "Dual Cast",
        type: "gem",
        width: 1,
        height: 1,
        color: "#f39c12",
        enhancements: [
          {
            targetTypes: ["magic"],
            nameModifier: (name) => `Double ${name}`,
            descriptionModifier: (desc) => desc + " (cast twice)",
            damageMultiplier: 1.8,
            costModifier: 3,
          },
          {
            targetTypes: ["physical"],
            nameModifier: (name) => name.replace("Attack", "Combo Strike"),
            descriptionModifier: (desc) =>
              desc.replace("Basic sword strike", "Rapid dual weapon attack"),
            damageMultiplier: 1.7,
            costModifier: 2,
          },
          {
            targetTypes: ["ranged"],
            nameModifier: (name) => name.replace("Arrow Shot", "Double Shot"),
            descriptionModifier: (desc) =>
              desc.replace("Ranged attack", "Fire two arrows simultaneously"),
            damageMultiplier: 1.9,
            costModifier: 2,
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
            descriptionModifier: (desc) =>
              desc.replace("Restore health", "Powerful dual-layer healing"),
            damageMultiplier: 1.8,
            costModifier: 2,
          },
        ],
      }),
      new Item({
        id: 6,
        name: "Potion",
        type: "consumable",
        width: 1,
        height: 1,
        color: "#27ae60",
        baseSkills: [
          {
            name: "Heal",
            description: "Restore health",
            damage: -20, // Negative damage = healing
            cost: 0,
            type: "healing",
          },
        ],
      }),

      new Item({
        id: 7,
        name: "Bow",
        type: "weapon",
        width: 1,
        height: 2,
        color: "#16a085",
        baseSkills: [
          {
            name: "Arrow Shot",
            description: "Ranged attack",
            damage: 20,
            cost: 1,
            type: "ranged",
          },
        ],
      }),

      new Item({
        id: 8,
        name: "Armor",
        type: "armor",
        width: 2,
        height: 3,
        color: "#7f8c8d",
        baseSkills: [
          {
            name: "Fortify",
            description: "Increase defense",
            damage: 0,
            cost: 3,
            type: "defensive",
          },
        ],
        enhancements: [
          {
            targetTypes: ["defensive"],
            nameModifier: (name) => `Heavy ${name}`,
            descriptionModifier: (desc) => desc + " (armored)",
            damageBonus: 10,
          },
        ],
      }),

      new Item({
        id: 9,
        name: "Ice Gem",
        type: "gem",
        width: 1,
        height: 1,
        color: "#3498db",
        enhancements: [
          {
            targetTypes: ["magic"],
            nameModifier: (name) =>
              name
                .replace("Fireball", "Frost Bolt")
                .replace("Lightning Bolt", "Ice Shard"),
            descriptionModifier: (desc) => desc + " (frozen with ice)",
            damageMultiplier: 1.3,
            costModifier: 1,
          },
          {
            targetTypes: ["physical"],
            nameModifier: (name) => name.replace("Attack", "Frost Strike"),
            descriptionModifier: (desc) =>
              desc.replace(
                "Basic sword strike",
                "Chilling blade attack that slows enemies"
              ),
            damageMultiplier: 1.2,
            costModifier: 1,
          },
          {
            targetTypes: ["ranged"],
            nameModifier: (name) => name.replace("Arrow Shot", "Ice Arrow"),
            descriptionModifier: (desc) =>
              desc.replace(
                "Ranged attack",
                "Freezing arrow that slows targets"
              ),
            damageMultiplier: 1.1,
            costModifier: 1,
          },
          {
            targetTypes: ["defensive"],
            nameModifier: (name) => `Frozen ${name}`,
            descriptionModifier: (desc) => desc + " with ice armor protection",
            damageBonus: 5,
            costModifier: 1,
          },
          {
            targetTypes: ["healing"],
            nameModifier: (name) => name.replace("Heal", "Frost Mend"),
            descriptionModifier: (desc) =>
              desc.replace(
                "Restore health",
                "Cooling ice healing that numbs pain"
              ),
            damageMultiplier: 1.1,
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
        color: "#f1c40f",
        baseSkills: [
          {
            name: "Lightning Bolt",
            description: "Electric shock attack",
            damage: 28,
            cost: 4,
            type: "magic",
          },
        ],
      }),
    ];
  }

  static getSkillTypeColor(type) {
    const colors = {
      physical: "#e74c3c",
      magic: "#9b59b6",
      ranged: "#16a085",
      defensive: "#34495e",
      healing: "#27ae60",
    };
    return colors[type] || "#7f8c8d";
  }

  static createEnemyTemplates() {
    return {
      goblin: {
        name: "Goblin",
        maxHp: 60,
        maxMp: 20,
        baseAttack: 12,
        baseDefense: 3,
        baseSpeed: 8,
        skills: [
          { name: "Scratch", damage: 15, cost: 0, type: "physical" },
          { name: "Throw Rock", damage: 12, cost: 2, type: "ranged" },
        ],
      },

      orc: {
        name: "Orc Warrior",
        maxHp: 100,
        maxMp: 15,
        baseAttack: 18,
        baseDefense: 8,
        baseSpeed: 5,
        skills: [
          { name: "Heavy Strike", damage: 25, cost: 0, type: "physical" },
          { name: "Battle Roar", damage: 0, cost: 5, type: "defensive" },
        ],
      },

      wizard: {
        name: "Dark Wizard",
        maxHp: 70,
        maxMp: 60,
        baseAttack: 8,
        baseDefense: 4,
        baseSpeed: 12,
        skills: [
          { name: "Dark Bolt", damage: 22, cost: 6, type: "magic" },
          { name: "Heal", damage: -15, cost: 8, type: "healing" },
        ],
      },
    };
  }
}
