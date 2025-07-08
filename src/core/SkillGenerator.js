export class SkillGenerator {
    static generateSkillsFromInventory(inventoryGrid) {
        if (!inventoryGrid || !inventoryGrid.items) {
            return this.getDefaultSkills();
        }

        const skills = [];
        const processedItems = new Set();

        // Process each item for base skills and enhancements
        for (const item of inventoryGrid.items) {
            if (processedItems.has(item)) continue;

            // Generate skills from this item's base skills
            if (item.baseSkills) {
                for (const baseSkillData of item.baseSkills) {
                    const skill = {
                        name: baseSkillData.name,
                        description: baseSkillData.description,
                        damage: baseSkillData.damage,
                        cost: baseSkillData.cost,
                        type: baseSkillData.type,
                        sourceItems: [item.name]
                    };

                    // Apply enhancements from adjacent items
                    const adjacentItems = this.getAdjacentItems(inventoryGrid, item);
                    let enhancedSkillData = { ...baseSkillData };

                    for (const adjItem of adjacentItems) {
                        if (adjItem.enhancements) {
                            for (const enhancement of adjItem.enhancements) {
                                if (this.canEnhance(enhancement, baseSkillData)) {
                                    enhancedSkillData = this.applyEnhancement(enhancedSkillData, enhancement);
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
                }
            }

            processedItems.add(item);
        }

        // If no weapon skills found, add default punch
        const hasWeaponSkill = skills.some(skill => 
            skill.type === 'physical' && skill.sourceItems.some(source => 
                source.toLowerCase().includes('sword') || 
                source.toLowerCase().includes('weapon') ||
                source.toLowerCase().includes('staff') ||
                source.toLowerCase().includes('bow')
            )
        );

        if (!hasWeaponSkill) {
            skills.unshift({
                name: 'Punch',
                description: 'Basic unarmed attack',
                damage: 12,
                cost: 0,
                type: 'physical',
                sourceItems: ['Bare Hands']
            });
        }

        return skills.length > 0 ? skills : this.getDefaultSkills();
    }

    static getDefaultSkills() {
        return [
            {
                name: 'Punch',
                description: 'Basic unarmed attack',
                damage: 12,
                cost: 0,
                type: 'physical',
                sourceItems: ['Bare Hands']
            }
        ];
    }

    static getAdjacentItems(grid, item) {
        if (!item.isPlaced || !item.isPlaced()) return [];

        const adjacent = [];
        const directions = [
            {dx: -1, dy: 0}, {dx: 1, dy: 0}, // left, right
            {dx: 0, dy: -1}, {dx: 0, dy: 1}, // up, down
            {dx: -1, dy: -1}, {dx: 1, dy: -1}, // diagonals
            {dx: -1, dy: 1}, {dx: 1, dy: 1}
        ];

        // Check all cells occupied by the item
        for (let dy = 0; dy < item.height; dy++) {
            for (let dx = 0; dx < item.width; dx++) {
                const itemCellX = item.gridX + dx;
                const itemCellY = item.gridY + dy;

                // Check all directions from this cell
                for (const dir of directions) {
                    const checkX = itemCellX + dir.dx;
                    const checkY = itemCellY + dir.dy;

                    if (this.isPositionValid(grid, checkX, checkY)) {
                        const adjacentItem = this.getItemAtPosition(grid, checkX, checkY);
                        if (adjacentItem && adjacentItem !== item && !adjacent.includes(adjacentItem)) {
                            adjacent.push(adjacentItem);
                        }
                    }
                }
            }
        }

        return adjacent;
    }

    static isPositionValid(grid, x, y) {
        return x >= 0 && x < grid.cols && y >= 0 && y < grid.rows;
    }

    static getItemAtPosition(grid, x, y) {
        // Find item that occupies this position
        for (const item of grid.items) {
            if (item.gridX <= x && x < item.gridX + item.width &&
                item.gridY <= y && y < item.gridY + item.height) {
                return item;
            }
        }
        return null;
    }

    static canEnhance(enhancement, baseSkill) {
        // Check if enhancement targets this skill type
        if (enhancement.targetTypes && !enhancement.targetTypes.includes(baseSkill.type)) {
            return false;
        }

        // Check if enhancement targets this specific skill name
        if (enhancement.targetNames && !enhancement.targetNames.includes(baseSkill.name)) {
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
            enhanced.damage = Math.floor(enhanced.damage * enhancement.damageMultiplier);
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
            enhanced.description = enhancement.descriptionModifier(enhanced.description);
        }

        return enhanced;
    }

    static getSkillTypeColor(type) {
        const colors = {
            physical: 0xe74c3c,
            magic: 0x9b59b6,
            ranged: 0x16a085,
            defensive: 0x34495e,
            healing: 0x27ae60
        };
        return colors[type] || 0x7f8c8d;
    }
}