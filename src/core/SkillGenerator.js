// src/core/SkillGenerator.js - Complete inventory-based skill system
export class SkillGenerator {
  static generateSkillsFromInventory(inventoryScene) {
    console.log("🎯 Generating skills from PixiJS inventory");

    if (!inventoryScene || !inventoryScene.items) {
      console.log("No inventory scene or items found, using default skills");
      return this.getDefaultSkills();
    }

    const skills = [];
    const processedItems = new Set();

    // Get only items that are placed in the CHARACTER INVENTORY (not storage)
    const characterInventoryItems = inventoryScene.items.filter((item) => {
      return (
        item.gridX >= 0 &&
        item.gridY >= 0 &&
        this.isItemInCharacterInventory(item, inventoryScene)
      );
    });

    console.log(
      `Found ${characterInventoryItems.length} items in character inventory`
    );

    // Process each item for base skills and enhancements
    for (const item of characterInventoryItems) {
      if (processedItems.has(item)) continue;

      // Get base skills from item
      const baseSkills = this.getItemBaseSkills(item);

      if (baseSkills && baseSkills.length > 0) {
        for (const baseSkillData of baseSkills) {
          const skill = {
            name: baseSkillData.name,
            description: baseSkillData.description,
            damage: baseSkillData.damage,
            cost: baseSkillData.cost,
            type: baseSkillData.type,
            sourceItems: [item.name],
          };

          // Apply enhancements from adjacent items
          const adjacentItems = this.getAdjacentItemsInInventory(
            item,
            inventoryScene
          );
          let enhancedSkillData = { ...baseSkillData };

          for (const adjItem of adjacentItems) {
            const enhancements = this.getItemEnhancements(adjItem);
            if (enhancements) {
              for (const enhancement of enhancements) {
                if (this.canEnhance(enhancement, baseSkillData)) {
                  enhancedSkillData = this.applyEnhancement(
                    enhancedSkillData,
                    enhancement
                  );
                  skill.sourceItems.push(adjItem.name);
                }
              }
            }
          }

          // Update skill with final enhanced values
          skill.name = enhancedSkillData.name;
          skill.description = enhancedSkillData.description;
          skill.damage = enhancedSkillData.damage;
          skill.cost = enhancedSkillData.cost;

          skills.push(skill);
          console.log(`Generated skill: ${skill.name} from ${item.name}`);
        }
      }

      processedItems.add(item);
    }

    // If no weapon skills found, add default punch
    const hasWeaponSkill = skills.some(
      (skill) =>
        skill.type === "physical" &&
        skill.sourceItems.some(
          (source) =>
            source.toLowerCase().includes("sword") ||
            source.toLowerCase().includes("weapon") ||
            source.toLowerCase().includes("staff") ||
            source.toLowerCase().includes("bow") ||
            source.toLowerCase().includes("axe") ||
            source.toLowerCase().includes("dagger")
        )
    );

    if (!hasWeaponSkill) {
      skills.unshift(this.getDefaultPunchSkill());
      console.log("No weapon found, added default Punch skill");
    }

    console.log(`Total skills generated: ${skills.length}`);
    return skills.length > 0 ? skills : this.getDefaultSkills();
  }

  static isItemInCharacterInventory(item, inventoryScene) {
    // Check if item is positioned within the character inventory grid bounds
    const invGrid = inventoryScene.inventoryGrid;
    const itemScreenX = item.x;
    const itemScreenY = item.y;

    return (
      itemScreenX >= invGrid.x &&
      itemScreenX < invGrid.x + invGrid.cols * inventoryScene.gridCellSize &&
      itemScreenY >= invGrid.y &&
      itemScreenY < invGrid.y + invGrid.rows * inventoryScene.gridCellSize
    );
  }

  static getItemBaseSkills(item) {
    // Check multiple sources for base skills
    if (item.originalData && item.originalData.baseSkills) {
      return item.originalData.baseSkills;
    }

    if (item.baseSkills) {
      return item.baseSkills;
    }

    // Generate default skills based on item type and name
    return this.generateDefaultSkillsForItem(item);
  }

  static getItemEnhancements(item) {
    // Check multiple sources for enhancements
    if (item.originalData && item.originalData.enhancements) {
      return item.originalData.enhancements;
    }

    if (item.enhancements) {
      return item.enhancements;
    }

    // Generate default enhancements based on item type
    return this.generateDefaultEnhancementsForItem(item);
  }

  static generateDefaultSkillsForItem(item) {
    const name = item.name.toLowerCase();
    const type = item.type ? item.type.toLowerCase() : "";

    // Weapons
    if (name.includes("sword") || name.includes("blade")) {
      return [
        {
          name: "Sword Strike",
          description: "Basic sword attack",
          damage: 25,
          cost: 0,
          type: "physical",
        },
      ];
    }

    if (name.includes("staff") || (type === "weapon" && name.includes("t-"))) {
      return [
        {
          name: "Fireball",
          description: "Launch a magical fireball",
          damage: 30,
          cost: 5,
          type: "magic",
        },
      ];
    }

    if (name.includes("bow") || name.includes("u-")) {
      return [
        {
          name: "Arrow Shot",
          description: "Ranged bow attack",
          damage: 20,
          cost: 1,
          type: "ranged",
        },
      ];
    }

    if (name.includes("dagger")) {
      return [
        {
          name: "Quick Strike",
          description: "Fast dagger attack",
          damage: 18,
          cost: 1,
          type: "physical",
        },
      ];
    }

    if (name.includes("axe")) {
      return [
        {
          name: "Cleave",
          description: "Powerful axe swing",
          damage: 35,
          cost: 2,
          type: "physical",
        },
      ];
    }

    // Armor and shields
    if (name.includes("shield") || type === "armor") {
      return [
        {
          name: "Block",
          description: "Defensive stance",
          damage: 0,
          cost: 2,
          type: "defensive",
        },
      ];
    }

    // Consumables
    if (name.includes("potion") || type === "consumable") {
      return [
        {
          name: "Heal",
          description: "Restore health",
          damage: -25, // Negative damage = healing
          cost: 0,
          type: "healing",
        },
      ];
    }

    // Default: no skills for items that aren't weapons/usables
    return [];
  }

  static generateDefaultEnhancementsForItem(item) {
    const name = item.name.toLowerCase();
    const type = item.type ? item.type.toLowerCase() : "";

    // Gems provide enhancements
    if (type === "gem" || name.includes("gem")) {
      if (name.includes("fire")) {
        return [
          {
            targetTypes: ["physical", "magic"],
            nameModifier: (name) =>
              name
                .replace("Strike", "Flaming Strike")
                .replace("Fireball", "Fire Blast"),
            descriptionModifier: (desc) => desc + " (enhanced with fire)",
            damageMultiplier: 1.5,
            costModifier: 1,
          },
        ];
      }

      if (name.includes("ice")) {
        return [
          {
            targetTypes: ["physical", "magic"],
            nameModifier: (name) =>
              name
                .replace("Strike", "Frost Strike")
                .replace("Fireball", "Ice Bolt"),
            descriptionModifier: (desc) => desc + " (enhanced with ice)",
            damageMultiplier: 1.3,
            costModifier: 1,
          },
        ];
      }

      // Generic gem enhancement
      return [
        {
          targetTypes: ["physical", "magic"],
          nameModifier: (name) => `Enhanced ${name}`,
          descriptionModifier: (desc) => desc + " (magically enhanced)",
          damageMultiplier: 1.2,
          costModifier: 0,
        },
      ];
    }

    // Shields enhance defensive skills
    if (name.includes("shield")) {
      return [
        {
          targetTypes: ["physical"],
          nameModifier: (name) => `Defensive ${name}`,
          descriptionModifier: (desc) => desc + " with shield protection",
          damageBonus: 5,
        },
      ];
    }

    return [];
  }

  static getAdjacentItemsInInventory(item, inventoryScene) {
    if (!item.gridX >= 0 || !item.gridY >= 0) return [];

    const adjacent = [];
    const directions = [
      { dx: -1, dy: 0 },
      { dx: 1, dy: 0 }, // left, right
      { dx: 0, dy: -1 },
      { dx: 0, dy: 1 }, // up, down
      { dx: -1, dy: -1 },
      { dx: 1, dy: -1 }, // diagonals
      { dx: -1, dy: 1 },
      { dx: 1, dy: 1 },
    ];

    // Get item's shape pattern for checking all occupied cells
    const itemPattern = item.shapePattern || [[0, 0]];

    // Check all cells occupied by the item
    for (const [cellX, cellY] of itemPattern) {
      const itemCellX = item.gridX + cellX;
      const itemCellY = item.gridY + cellY;

      // Check all directions from this cell
      for (const dir of directions) {
        const checkX = itemCellX + dir.dx;
        const checkY = itemCellY + dir.dy;

        if (
          this.isValidGridPosition(inventoryScene.inventoryGrid, checkX, checkY)
        ) {
          const adjacentItem = this.getItemAtGridPosition(
            inventoryScene,
            checkX,
            checkY
          );
          if (
            adjacentItem &&
            adjacentItem !== item &&
            !adjacent.includes(adjacentItem)
          ) {
            adjacent.push(adjacentItem);
          }
        }
      }
    }

    console.log(`Found ${adjacent.length} adjacent items to ${item.name}`);
    return adjacent;
  }

  static isValidGridPosition(grid, x, y) {
    return x >= 0 && x < grid.cols && y >= 0 && y < grid.rows;
  }

  static getItemAtGridPosition(inventoryScene, gridX, gridY) {
    // Find item that occupies this grid position in character inventory
    for (const item of inventoryScene.items) {
      if (!this.isItemInCharacterInventory(item, inventoryScene)) continue;
      if (item.gridX < 0 || item.gridY < 0) continue;

      // Check if this grid position is within the item's shape
      const itemPattern = item.shapePattern || [[0, 0]];
      for (const [cellX, cellY] of itemPattern) {
        if (item.gridX + cellX === gridX && item.gridY + cellY === gridY) {
          return item;
        }
      }
    }
    return null;
  }

  static getDefaultSkills() {
    return [this.getDefaultPunchSkill()];
  }

  static getDefaultPunchSkill() {
    return {
      name: "Punch",
      description: "Basic unarmed attack",
      damage: 12,
      cost: 0,
      type: "physical",
      sourceItems: ["Bare Hands"],
    };
  }

  static canEnhance(enhancement, baseSkill) {
    // Check if enhancement targets this skill type
    if (
      enhancement.targetTypes &&
      !enhancement.targetTypes.includes(baseSkill.type)
    ) {
      return false;
    }

    // Check if enhancement targets this specific skill name
    if (
      enhancement.targetNames &&
      !enhancement.targetNames.includes(baseSkill.name)
    ) {
      return false;
    }

    return true;
  }

  static applyEnhancement(skillData, enhancement) {
    const enhanced = { ...skillData };

    // Apply name modification
    if (enhancement.nameModifier) {
      enhanced.name = enhancement.nameModifier(enhanced.name);
    }

    // Apply damage modifications
    if (enhancement.damageMultiplier) {
      enhanced.damage = Math.floor(
        enhanced.damage * enhancement.damageMultiplier
      );
    }
    if (enhancement.damageBonus) {
      enhanced.damage += enhancement.damageBonus;
    }

    // Apply cost modification
    if (enhancement.costModifier) {
      enhanced.cost = Math.max(0, enhanced.cost + enhancement.costModifier);
    }

    // Apply description modification
    if (enhancement.descriptionModifier) {
      enhanced.description = enhancement.descriptionModifier(
        enhanced.description
      );
    }

    return enhanced;
  }

  static getSkillTypeColor(type) {
    const colors = {
      physical: 0xe74c3c,
      magic: 0x9b59b6,
      ranged: 0x16a085,
      defensive: 0x34495e,
      healing: 0x27ae60,
    };
    return colors[type] || 0x7f8c8d;
  }
}
