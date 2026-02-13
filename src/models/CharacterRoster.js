import { Character } from './Character.js';
import { Grid } from './Grid.js';
import { GameData } from '../data/GameData.js';

export class CharacterRoster {
    constructor() {
        // All available characters
        this.availableCharacters = [];
        
        // Currently selected squad (max 3 characters)
        this.activeSquad = [];
        this.maxSquadSize = 3;
        
        // Character creation templates
        this.characterTemplates = this.initializeCharacterTemplates();
        
        // Roster metadata
        this.nextCharacterId = 1;
        this.createdCount = 0;
        
        console.log("🎭 Character Roster initialized");
    }

    // ============= CHARACTER TEMPLATES =============
    
    initializeCharacterTemplates() {
        return {
            warrior: {
                name: "Warrior",
                description: "Strong melee fighter with high HP and defense",
                baseStats: {
                    maxHp: 120,
                    maxMp: 30,
                    baseAttack: 25,
                    baseDefense: 15,
                    baseSpeed: 8
                },
                startingItems: [
                    {
                        name: "Iron Sword",
                        color: 0xe74c3c,
                        width: 1,
                        height: 3,
                        type: "weapon",
                        baseSkills: [{
                            name: "Slash",
                            description: "Powerful sword attack",
                            damage: 30,
                            cost: 0,
                            type: "physical"
                        }]
                    },
                    {
                        name: "Shield",
                        color: 0x34495e,
                        width: 2,
                        height: 2,
                        type: "armor",
                        baseSkills: [{
                            name: "Block",
                            description: "Defensive stance",
                            damage: 0,
                            cost: 2,
                            type: "defensive"
                        }]
                    }
                ],
                portrait: "🛡️",
                primaryColor: 0xe74c3c
            },

            mage: {
                name: "Mage",
                description: "Powerful spellcaster with high MP and magic damage",
                baseStats: {
                    maxHp: 80,
                    maxMp: 80,
                    baseAttack: 12,
                    baseDefense: 6,
                    baseSpeed: 12
                },
                startingItems: [
                    {
                        name: "Magic Staff",
                        color: 0x9b59b6,
                        shape: "T",
                        stemLength: 3,
                        topWidth: 3,
                        orientation: "up",
                        type: "weapon",
                        baseSkills: [{
                            name: "Fireball",
                            description: "Magical fire attack",
                            damage: 35,
                            cost: 8,
                            type: "magic"
                        }]
                    },
                    {
                        name: "Mana Crystal",
                        color: 0x3498db,
                        width: 1,
                        height: 1,
                        type: "gem",
                        enhancements: [{
                            targetTypes: ["magic"],
                            nameModifier: (name) => `Enhanced ${name}`,
                            damageMultiplier: 1.3,
                            costModifier: -1
                        }]
                    }
                ],
                portrait: "🧙",
                primaryColor: 0x9b59b6
            },

            ranger: {
                name: "Ranger",
                description: "Agile archer with balanced stats and ranged attacks",
                baseStats: {
                    maxHp: 100,
                    maxMp: 50,
                    baseAttack: 20,
                    baseDefense: 10,
                    baseSpeed: 15
                },
                startingItems: [
                    {
                        name: "Elven Bow",
                        color: 0x16a085,
                        shape: "U",
                        width: 3,
                        height: 3,
                        orientation: "up",
                        type: "weapon",
                        baseSkills: [{
                            name: "Arrow Shot",
                            description: "Precise ranged attack",
                            damage: 25,
                            cost: 2,
                            type: "ranged"
                        }]
                    },
                    {
                        name: "Quiver",
                        color: 0x8b4513,
                        width: 1,
                        height: 2,
                        type: "accessory",
                        enhancements: [{
                            targetTypes: ["ranged"],
                            nameModifier: (name) => `Rapid ${name}`,
                            damageBonus: 5,
                            costModifier: -1
                        }]
                    }
                ],
                portrait: "🏹",
                primaryColor: 0x16a085
            },

            rogue: {
                name: "Rogue",
                description: "Fast assassin with critical strikes and stealth",
                baseStats: {
                    maxHp: 90,
                    maxMp: 40,
                    baseAttack: 22,
                    baseDefense: 8,
                    baseSpeed: 18
                },
                startingItems: [
                    {
                        name: "Twin Daggers",
                        color: 0x8c8c8c,
                        shape: "L",
                        armLength: 2,
                        orientation: "br",
                        type: "weapon",
                        baseSkills: [{
                            name: "Backstab",
                            description: "Critical stealth attack",
                            damage: 28,
                            cost: 3,
                            type: "physical"
                        }]
                    },
                    {
                        name: "Poison Vial",
                        color: 0x9acd32,
                        width: 1,
                        height: 1,
                        type: "consumable",
                        enhancements: [{
                            targetTypes: ["physical"],
                            nameModifier: (name) => `Poisoned ${name}`,
                            damageBonus: 8,
                            costModifier: 1
                        }]
                    }
                ],
                portrait: "🗡️",
                primaryColor: 0x8c8c8c
            },

            cleric: {
                name: "Cleric",
                description: "Holy healer with support spells and light magic",
                baseStats: {
                    maxHp: 95,
                    maxMp: 70,
                    baseAttack: 15,
                    baseDefense: 12,
                    baseSpeed: 10
                },
                startingItems: [
                    {
                        name: "Holy Symbol",
                        color: 0xffd700,
                        shape: "plus",
                        armLength: 1,
                        type: "weapon",
                        baseSkills: [{
                            name: "Heal",
                            description: "Restore ally health",
                            damage: -25,
                            cost: 6,
                            type: "healing"
                        }]
                    },
                    {
                        name: "Prayer Beads",
                        color: 0xf0e68c,
                        width: 2,
                        height: 1,
                        type: "accessory",
                        enhancements: [{
                            targetTypes: ["healing"],
                            nameModifier: (name) => `Greater ${name}`,
                            damageMultiplier: 1.4,
                            costModifier: -2
                        }]
                    }
                ],
                portrait: "⛪",
                primaryColor: 0xffd700
            },

            paladin: {
                name: "Paladin",
                description: "Holy warrior combining combat prowess with divine magic",
                baseStats: {
                    maxHp: 110,
                    maxMp: 50,
                    baseAttack: 23,
                    baseDefense: 14,
                    baseSpeed: 9
                },
                startingItems: [
                    {
                        name: "Blessed Sword",
                        color: 0xffd700,
                        width: 1,
                        height: 3,
                        type: "weapon",
                        baseSkills: [{
                            name: "Divine Strike",
                            description: "Holy-powered sword attack",
                            damage: 32,
                            cost: 4,
                            type: "physical"
                        }]
                    },
                    {
                        name: "Sacred Armor",
                        color: 0xc0c0c0,
                        width: 2,
                        height: 3,
                        type: "armor",
                        baseSkills: [{
                            name: "Guardian",
                            description: "Protect allies from harm",
                            damage: 0,
                            cost: 5,
                            type: "defensive"
                        }]
                    }
                ],
                portrait: "⚔️",
                primaryColor: 0xdaa520
            }
        };
    }

    // ============= CHARACTER CREATION =============

    createCharacter(templateKey, customName = null) {
        const template = this.characterTemplates[templateKey];
        if (!template) {
            console.error(`❌ Unknown character template: ${templateKey}`);
            return null;
        }

        console.log(`🎭 Creating ${template.name} character`);

        // Generate character name
        const characterName = customName || this.generateCharacterName(template.name);

        // Create character with template stats
        const character = new Character(
            characterName,
            template.baseStats.maxHp,
            template.baseStats.maxMp
        );

        // Set base stats
        character.baseAttack = template.baseStats.baseAttack;
        character.baseDefense = template.baseStats.baseDefense;
        character.baseSpeed = template.baseStats.baseSpeed;

        // Set character metadata
        character.id = this.nextCharacterId++;
        character.class = template.name;
        character.description = template.description;
        character.portrait = template.portrait;
        character.primaryColor = template.primaryColor;
        character.level = 1;
        character.experience = 0;
        character.experienceToNext = 100;

        // Create character inventory (10x8 grid)
        character.inventory = new Grid(0, 0, 10, 8, 40);

        // Add starting items to inventory
        this.addStartingItems(character, template.startingItems);

        // Add to roster
        this.availableCharacters.push(character);
        this.createdCount++;

        console.log(`✅ Created ${characterName} (${template.name})`);
        return character;
    }

    generateCharacterName(className) {
        const nameGenerators = {
            Warrior: ["Gareth", "Thane", "Bronn", "Ser Duncan", "Roderick", "Marcus", "Valerian"],
            Mage: ["Gandalf", "Merlin", "Alaric", "Elias", "Morgana", "Celestine", "Zephyr"],
            Ranger: ["Legolas", "Strider", "Talon", "Sylvan", "Artemis", "Kaelyn", "Orion"],
            Rogue: ["Shadow", "Whisper", "Vex", "Nyx", "Raven", "Sable", "Dagger"],
            Cleric: ["Benedict", "Seraphine", "Gabriel", "Luna", "Faith", "Grace", "Devine"],
            Paladin: ["Arthur", "Roland", "Galahad", "Percival", "Lancelot", "Tristan", "Gareth"]
        };

        const names = nameGenerators[className] || ["Hero", "Champion", "Adventurer"];
        const baseName = names[Math.floor(Math.random() * names.length)];
        
        // Add number if name already exists
        let finalName = baseName;
        let counter = 1;
        while (this.availableCharacters.some(char => char.name === finalName)) {
            finalName = `${baseName} ${counter}`;
            counter++;
        }

        return finalName;
    }

    addStartingItems(character, startingItems) {
        console.log(`🎒 Adding starting items for ${character.name}`);

        startingItems.forEach((itemData, index) => {
            // Create item using GameData format
            const item = this.createInventoryItem(itemData);
            
            // Try to place in inventory
            const placed = this.tryPlaceItemInInventory(character.inventory, item);
            if (!placed) {
                console.warn(`⚠️ Could not place ${item.name} in ${character.name}'s inventory`);
            }
        });
    }

    createInventoryItem(itemData) {
        // This creates an item compatible with the existing inventory system
        const item = {
            id: Math.random().toString(36).substr(2, 9),
            name: itemData.name,
            type: itemData.type,
            width: itemData.width || 1,
            height: itemData.height || 1,
            color: itemData.color || '#3498db',
            shape: itemData.shape || 'rectangle',
            baseSkills: itemData.baseSkills || [],
            enhancements: itemData.enhancements || [],
            gridX: -1,
            gridY: -1,
            dragging: false,
            isHighlighted: false,
            
            // Add any custom shape properties
            stemLength: itemData.stemLength,
            topWidth: itemData.topWidth,
            armLength: itemData.armLength,
            orientation: itemData.orientation,

            // Standard methods
            isPlaced: function() {
                return this.gridX >= 0 && this.gridY >= 0;
            },

            canPlaceAt: function(grid, x, y) {
                // Check bounds
                if (x < 0 || y < 0 || x + this.width > grid.cols || y + this.height > grid.rows) {
                    return false;
                }

                // Check for overlapping items
                for (let dy = 0; dy < this.height; dy++) {
                    for (let dx = 0; dx < this.width; dx++) {
                        const cell = grid.cells[y + dy][x + dx];
                        if (cell !== null && cell !== this) {
                            return false;
                        }
                    }
                }

                return true;
            },

            clone: function() {
                return { ...this };
            }
        };

        return item;
    }

    tryPlaceItemInInventory(inventory, item) {
        // Try to find a spot for the item
        for (let y = 0; y <= inventory.rows - item.height; y++) {
            for (let x = 0; x <= inventory.cols - item.width; x++) {
                if (item.canPlaceAt(inventory, x, y)) {
                    inventory.placeItem(item, x, y);
                    return true;
                }
            }
        }
        return false;
    }

    // ============= ROSTER MANAGEMENT =============

    getAvailableCharacters() {
        return [...this.availableCharacters];
    }

    getCharacterById(id) {
        return this.availableCharacters.find(char => char.id === id);
    }

    getCharacterByName(name) {
        return this.availableCharacters.find(char => char.name === name);
    }

    removeCharacter(characterId) {
        const index = this.availableCharacters.findIndex(char => char.id === characterId);
        if (index > -1) {
            const character = this.availableCharacters[index];
            
            // Remove from active squad if present
            this.removeFromSquad(characterId);
            
            // Remove from roster
            this.availableCharacters.splice(index, 1);
            
            console.log(`🗑️ Removed ${character.name} from roster`);
            return true;
        }
        return false;
    }

    // ============= SQUAD MANAGEMENT =============

    addToSquad(characterId) {
        if (this.activeSquad.length >= this.maxSquadSize) {
            console.warn(`⚠️ Squad is full (${this.maxSquadSize} characters maximum)`);
            return false;
        }

        const character = this.getCharacterById(characterId);
        if (!character) {
            console.error(`❌ Character with ID ${characterId} not found`);
            return false;
        }

        if (this.activeSquad.includes(character)) {
            console.warn(`⚠️ ${character.name} is already in the squad`);
            return false;
        }

        this.activeSquad.push(character);
        console.log(`✅ Added ${character.name} to squad (${this.activeSquad.length}/${this.maxSquadSize})`);
        return true;
    }

    removeFromSquad(characterId) {
        const index = this.activeSquad.findIndex(char => char.id === characterId);
        if (index > -1) {
            const character = this.activeSquad[index];
            this.activeSquad.splice(index, 1);
            console.log(`➖ Removed ${character.name} from squad`);
            return true;
        }
        return false;
    }

    clearSquad() {
        this.activeSquad = [];
        console.log("🧹 Cleared active squad");
    }

    getActiveSquad() {
        return [...this.activeSquad];
    }

    getSquadLeader() {
        return this.activeSquad.length > 0 ? this.activeSquad[0] : null;
    }

    isInSquad(characterId) {
        return this.activeSquad.some(char => char.id === characterId);
    }

    getSquadSize() {
        return this.activeSquad.length;
    }

    hasRoom() {
        return this.activeSquad.length < this.maxSquadSize;
    }

    // ============= CHARACTER PROGRESSION =============

    giveExperience(characterId, amount) {
        const character = this.getCharacterById(characterId);
        if (!character) return false;

        character.experience += amount;
        console.log(`📈 ${character.name} gained ${amount} XP (${character.experience})`);

        // Check for level up
        while (character.experience >= character.experienceToNext) {
            this.levelUpCharacter(character);
        }

        return true;
    }

    levelUpCharacter(character) {
        character.experience -= character.experienceToNext;
        character.level++;
        
        // Increase stats
        const statGains = this.getStatGainsForClass(character.class);
        character.maxHp += statGains.hp;
        character.maxMp += statGains.mp;
        character.baseAttack += statGains.attack;
        character.baseDefense += statGains.defense;
        character.baseSpeed += statGains.speed;

        // Heal to full on level up
        character.hp = character.maxHp;
        character.mp = character.maxMp;

        // Calculate next level requirement
        character.experienceToNext = Math.floor(100 * Math.pow(1.2, character.level - 1));

        console.log(`🆙 ${character.name} reached level ${character.level}!`);
        console.log(`📊 Stats: HP+${statGains.hp}, MP+${statGains.mp}, ATK+${statGains.attack}, DEF+${statGains.defense}, SPD+${statGains.speed}`);

        return {
            newLevel: character.level,
            statGains: statGains,
            message: `${character.name} reached level ${character.level}!`
        };
    }

    getStatGainsForClass(className) {
        const classGains = {
            Warrior: { hp: 8, mp: 2, attack: 3, defense: 2, speed: 1 },
            Mage: { hp: 4, mp: 6, attack: 1, defense: 1, speed: 2 },
            Ranger: { hp: 6, mp: 3, attack: 2, defense: 1, speed: 3 },
            Rogue: { hp: 5, mp: 2, attack: 2, defense: 1, speed: 4 },
            Cleric: { hp: 6, mp: 5, attack: 1, defense: 2, speed: 1 },
            Paladin: { hp: 7, mp: 3, attack: 2, defense: 3, speed: 1 }
        };

        return classGains[className] || { hp: 5, mp: 3, attack: 2, defense: 1, speed: 2 };
    }

    // ============= UTILITY METHODS =============

    createStarterRoster() {
        console.log("🎭 Creating starter roster");
        
        // Create one character of each class for testing
        const starterClasses = ['warrior', 'mage', 'ranger'];
        
        starterClasses.forEach(classKey => {
            this.createCharacter(classKey);
        });

        // Add first three to squad
        if (this.availableCharacters.length >= 1) {
            this.addToSquad(this.availableCharacters[0].id);
        }

        console.log(`✅ Created starter roster with ${this.availableCharacters.length} characters`);
    }

    getCharacterTemplates() {
        return Object.keys(this.characterTemplates).map(key => ({
            key: key,
            ...this.characterTemplates[key]
        }));
    }

    getRosterStats() {
        return {
            totalCharacters: this.availableCharacters.length,
            squadSize: this.activeSquad.length,
            maxSquadSize: this.maxSquadSize,
            averageLevel: this.availableCharacters.length > 0 
                ? Math.round(this.availableCharacters.reduce((sum, char) => sum + char.level, 0) / this.availableCharacters.length)
                : 0,
            charactersCreated: this.createdCount
        };
    }

    // ============= SAVE/LOAD SYSTEM =============

    exportRosterData() {
        return {
            availableCharacters: this.availableCharacters.map(char => this.serializeCharacter(char)),
            activeSquadIds: this.activeSquad.map(char => char.id),
            nextCharacterId: this.nextCharacterId,
            createdCount: this.createdCount
        };
    }

    importRosterData(data) {
        try {
            // Restore characters
            this.availableCharacters = data.availableCharacters.map(charData => 
                this.deserializeCharacter(charData)
            );

            // Restore squad
            this.activeSquad = [];
            if (data.activeSquadIds) {
                data.activeSquadIds.forEach(id => {
                    const character = this.getCharacterById(id);
                    if (character) {
                        this.activeSquad.push(character);
                    }
                });
            }

            // Restore metadata
            this.nextCharacterId = data.nextCharacterId || this.availableCharacters.length + 1;
            this.createdCount = data.createdCount || this.availableCharacters.length;

            console.log(`📥 Imported roster: ${this.availableCharacters.length} characters, ${this.activeSquad.length} in squad`);
            return true;
        } catch (error) {
            console.error("❌ Failed to import roster data:", error);
            return false;
        }
    }

    serializeCharacter(character) {
        return {
            id: character.id,
            name: character.name,
            class: character.class,
            description: character.description,
            portrait: character.portrait,
            primaryColor: character.primaryColor,
            level: character.level,
            experience: character.experience,
            experienceToNext: character.experienceToNext,
            hp: character.hp,
            mp: character.mp,
            maxHp: character.maxHp,
            maxMp: character.maxMp,
            baseAttack: character.baseAttack,
            baseDefense: character.baseDefense,
            baseSpeed: character.baseSpeed,
            inventoryItems: character.inventory ? character.inventory.items : []
        };
    }

    deserializeCharacter(data) {
        const character = new Character(data.name, data.maxHp, data.maxMp);
        
        // Restore all properties
        Object.assign(character, data);
        
        // Recreate inventory
        character.inventory = new Grid(0, 0, 10, 8, 40);
        if (data.inventoryItems) {
            data.inventoryItems.forEach(itemData => {
                const item = this.createInventoryItem(itemData);
                character.inventory.addItem(item);
            });
        }

        return character;
    }

    // ============= DEBUG METHODS =============

    debugRosterState() {
        console.group("🎭 Character Roster Debug");
        console.log("Available Characters:", this.availableCharacters.length);
        this.availableCharacters.forEach(char => {
            console.log(`  - ${char.name} (${char.class}) Lv.${char.level} | HP:${char.hp}/${char.maxHp} MP:${char.mp}/${char.maxMp}`);
        });
        console.log("Active Squad:", this.activeSquad.length);
        this.activeSquad.forEach((char, index) => {
            console.log(`  ${index + 1}. ${char.name} (${char.class}) Lv.${char.level}`);
        });
        console.log("Stats:", this.getRosterStats());
        console.groupEnd();
    }
}