/**
 * GameConfig.js - Game-specific configuration and balance settings
 * 
 * This file contains all gameplay-related constants, character stats,
 * damage values, and game balance configurations.
 */

// ============= CHARACTER CONFIGURATION =============

export const CHARACTER = {
    // Base character stats
    BASE_STATS: {
      HP: 100,
      MP: 50,
      ATTACK: 15,
      DEFENSE: 5,
      SPEED: 10,
      LEVEL: 1,
    },
    
    // Level progression
    LEVEL: {
      MAX_LEVEL: 99,
      BASE_EXPERIENCE: 100,
      EXPERIENCE_MULTIPLIER: 1.5,
      STAT_GROWTH_PER_LEVEL: {
        HP: 8,
        MP: 4,
        ATTACK: 2,
        DEFENSE: 1,
        SPEED: 1,
      },
    },
    
    // Class-specific multipliers
    CLASS_MULTIPLIERS: {
      warrior: {
        hp: 1.2,
        mp: 0.8,
        attack: 1.1,
        defense: 1.3,
        speed: 0.9,
      },
      mage: {
        hp: 0.8,
        mp: 1.5,
        attack: 0.9,
        defense: 0.7,
        speed: 1.1,
      },
      rogue: {
        hp: 0.9,
        mp: 1.0,
        attack: 1.2,
        defense: 0.8,
        speed: 1.4,
      },
      archer: {
        hp: 0.95,
        mp: 1.1,
        attack: 1.15,
        defense: 0.85,
        speed: 1.2,
      },
    },
  };
  
  // ============= ENEMY CONFIGURATION =============
  
  export const ENEMIES = {
    // Enemy templates with base stats
    TEMPLATES: {
      goblin: {
        name: "Goblin",
        maxHp: 60,
        maxMp: 20,
        baseAttack: 12,
        baseDefense: 3,
        baseSpeed: 8,
        experienceReward: 25,
        goldReward: 15,
      },
      orc: {
        name: "Orc Warrior",
        maxHp: 100,
        maxMp: 15,
        baseAttack: 18,
        baseDefense: 8,
        baseSpeed: 5,
        experienceReward: 50,
        goldReward: 30,
      },
      wizard: {
        name: "Dark Wizard",
        maxHp: 70,
        maxMp: 60,
        baseAttack: 8,
        baseDefense: 4,
        baseSpeed: 12,
        experienceReward: 75,
        goldReward: 45,
      },
      dragon: {
        name: "Ancient Dragon",
        maxHp: 500,
        maxMp: 200,
        baseAttack: 45,
        baseDefense: 25,
        baseSpeed: 15,
        experienceReward: 1000,
        goldReward: 500,
      },
    },
    
    // Enemy scaling by area/level
    SCALING: {
      HP_PER_LEVEL: 10,
      ATTACK_PER_LEVEL: 2,
      DEFENSE_PER_LEVEL: 1,
      EXPERIENCE_MULTIPLIER: 1.1,
      GOLD_MULTIPLIER: 1.05,
    },
  };
  
  // ============= SKILL CONFIGURATION =============
  
  export const SKILLS = {
    // Skill types and their base properties
    TYPES: {
      physical: {
        color: 0xe74c3c,
        colorHex: '#e74c3c',
        baseDamage: 20,
        baseCost: 2,
        critChance: 0.15,
        critMultiplier: 2.0,
      },
      magic: {
        color: 0x9b59b6,
        colorHex: '#9b59b6',
        baseDamage: 25,
        baseCost: 5,
        critChance: 0.10,
        critMultiplier: 2.5,
      },
      ranged: {
        color: 0x16a085,
        colorHex: '#16a085',
        baseDamage: 18,
        baseCost: 3,
        critChance: 0.20,
        critMultiplier: 1.8,
      },
      defensive: {
        color: 0x34495e,
        colorHex: '#34495e',
        baseDamage: 0,
        baseCost: 4,
        critChance: 0.05,
        critMultiplier: 1.5,
      },
      healing: {
        color: 0x27ae60,
        colorHex: '#27ae60',
        baseDamage: -20, // Negative damage = healing
        baseCost: 6,
        critChance: 0.08,
        critMultiplier: 2.0,
      },
    },
    
    // Skill enhancement system
    ENHANCEMENTS: {
      // Damage modifiers
      DAMAGE_MULTIPLIER_RANGE: [0.8, 1.5],
      DAMAGE_BONUS_RANGE: [0, 10],
      
      // Cost modifiers
      COST_REDUCTION_MAX: 3,
      COST_INCREASE_MAX: 2,
      MIN_SKILL_COST: 0,
      
      // Enhancement rarity weights
      RARITY_WEIGHTS: {
        common: 0.6,
        uncommon: 0.25,
        rare: 0.12,
        epic: 0.03,
      },
    },
    
    // Base skill templates
    BASE_SKILLS: {
      // Physical skills
      slash: { name: "Slash", damage: 15, cost: 0, type: "physical" },
      heavyStrike: { name: "Heavy Strike", damage: 25, cost: 2, type: "physical" },
      whirlwind: { name: "Whirlwind", damage: 20, cost: 4, type: "physical" },
      
      // Magic skills
      fireball: { name: "Fireball", damage: 22, cost: 4, type: "magic" },
      iceSpike: { name: "Ice Spike", damage: 18, cost: 3, type: "magic" },
      lightningBolt: { name: "Lightning Bolt", damage: 28, cost: 6, type: "magic" },
      
      // Ranged skills
      arrowShot: { name: "Arrow Shot", damage: 16, cost: 1, type: "ranged" },
      throwKnife: { name: "Throw Knife", damage: 12, cost: 2, type: "ranged" },
      
      // Healing skills
      heal: { name: "Heal", damage: -15, cost: 8, type: "healing" },
      frostMend: { name: "Frost Mend", damage: -18, cost: 10, type: "healing" },
      
      // Defensive skills
      block: { name: "Block", damage: 0, cost: 2, type: "defensive" },
      battleRoar: { name: "Battle Roar", damage: 0, cost: 5, type: "defensive" },
    },
  };
  
  // ============= ITEM CONFIGURATION =============
  
  export const ITEMS = {
    // Item rarity system
    RARITY: {
      common: {
        weight: 0.5,
        color: '#95a5a6',
        enhancementChance: 0.1,
        maxEnhancements: 1,
      },
      uncommon: {
        weight: 0.3,
        color: '#27ae60',
        enhancementChance: 0.3,
        maxEnhancements: 2,
      },
      rare: {
        weight: 0.15,
        color: '#3498db',
        enhancementChance: 0.6,
        maxEnhancements: 3,
      },
      epic: {
        weight: 0.04,
        color: '#9b59b6',
        enhancementChance: 0.8,
        maxEnhancements: 4,
      },
      legendary: {
        weight: 0.01,
        color: '#f39c12',
        enhancementChance: 1.0,
        maxEnhancements: 5,
      },
    },
    
    // Item type configurations
    TYPES: {
      weapon: {
        statBonuses: ['attack', 'critChance'],
        skillTypes: ['physical', 'magic', 'ranged'],
        maxWidth: 3,
        maxHeight: 4,
      },
      armor: {
        statBonuses: ['defense', 'hp'],
        skillTypes: ['defensive'],
        maxWidth: 2,
        maxHeight: 3,
      },
      accessory: {
        statBonuses: ['speed', 'mp', 'critChance'],
        skillTypes: ['magic', 'healing'],
        maxWidth: 2,
        maxHeight: 2,
      },
      consumable: {
        statBonuses: [],
        skillTypes: ['healing'],
        maxWidth: 1,
        maxHeight: 2,
      },
    },
    
    // Drop rates by source
    DROP_RATES: {
      combat: {
        common: 0.6,
        uncommon: 0.25,
        rare: 0.12,
        epic: 0.025,
        legendary: 0.005,
      },
      chest: {
        common: 0.4,
        uncommon: 0.35,
        rare: 0.2,
        epic: 0.045,
        legendary: 0.005,
      },
      boss: {
        common: 0.1,
        uncommon: 0.3,
        rare: 0.4,
        epic: 0.18,
        legendary: 0.02,
      },
    },
  };
  
  // ============= BATTLE CONFIGURATION =============
  
  export const BATTLE = {
    // Turn order and timing
    TURN_ORDER: {
      SPEED_RANDOMIZATION: 0.2, // ±20% speed variance
      INITIATIVE_BONUS: 5,
      SURPRISE_ROUND_CHANCE: 0.1,
    },
    
    // Damage calculation
    DAMAGE: {
      // Base damage formula: (Attack - Defense) * Random(0.8, 1.2)
      VARIANCE_MIN: 0.8,
      VARIANCE_MAX: 1.2,
      MIN_DAMAGE: 1,
      DEFENSE_REDUCTION_CAP: 0.9, // Defense can reduce damage by max 90%
      
      // Critical hit system
      BASE_CRIT_CHANCE: 0.05,
      CRIT_DAMAGE_MULTIPLIER: 2.0,
      
      // Elemental damage modifiers
      ELEMENTAL_WEAKNESS: 1.5,
      ELEMENTAL_RESISTANCE: 0.5,
      ELEMENTAL_IMMUNITY: 0.0,
    },
    
    // Status effects
    STATUS_EFFECTS: {
      poison: {
        damagePerTurn: 5,
        maxDuration: 5,
        stackable: true,
      },
      burn: {
        damagePerTurn: 8,
        maxDuration: 3,
        stackable: false,
      },
      freeze: {
        damagePerTurn: 0,
        maxDuration: 2,
        skipsTurn: true,
      },
      stun: {
        damagePerTurn: 0,
        maxDuration: 1,
        skipsTurn: true,
      },
    },
    
    // Auto-battle settings
    AUTO_BATTLE: {
      ACTION_DELAY: 1500,
      SKILL_PRIORITY: ['healing', 'magic', 'physical', 'ranged', 'defensive'],
      HP_THRESHOLD_FOR_HEALING: 0.3, // Use healing when below 30% HP
      MP_CONSERVATION_THRESHOLD: 0.2, // Save MP when below 20%
    },
    
    // Escape system
    ESCAPE: {
      BASE_SUCCESS_CHANCE: 0.8,
      SPEED_MODIFIER: 0.1, // +10% per speed difference
      LEVEL_MODIFIER: 0.05, // +5% per level difference
      ATTEMPT_PENALTY: 0.2, // -20% for each failed attempt
    },
  };
  
  // ============= WORLD CONFIGURATION =============
  
  export const WORLD = {
    // Map generation
    MAP: {
      DEFAULT_SIZE: 50,
      CHUNK_SIZE: 10,
      TILE_SIZE: 32,
      
      // Terrain types and movement costs
      TERRAIN: {
        grass: { moveCost: 1, color: '#27ae60' },
        forest: { moveCost: 2, color: '#1e8449' },
        mountain: { moveCost: 3, color: '#7d6608' },
        water: { moveCost: 999, color: '#2980b9' }, // Impassable
        road: { moveCost: 0.5, color: '#95a5a6' },
      },
      
      // POI generation rates
      POINTS_OF_INTEREST: {
        town: 0.02,
        dungeon: 0.05,
        chest: 0.08,
        merchant: 0.03,
        shrine: 0.01,
      },
    },
    
    // Movement system
    MOVEMENT: {
      BASE_MOVE_SPEED: 100, // pixels per second
      DIAGONAL_PENALTY: Math.sqrt(2),
      STAMINA_COST_PER_TILE: 1,
      STAMINA_REGEN_RATE: 2, // per second when not moving
      MAX_STAMINA: 100,
    },
    
    // Random encounters
    ENCOUNTERS: {
      BASE_ENCOUNTER_RATE: 0.1, // 10% per tile moved
      TERRAIN_MODIFIERS: {
        grass: 1.0,
        forest: 1.5,
        mountain: 2.0,
        road: 0.5,
      },
      PARTY_LEVEL_SCALING: 0.1, // +10% rate per party level above area level
    },
  };
  
  // ============= INPUT CONFIGURATION =============
  
  export const INPUT = {
    // Movement sensitivity
    MOVEMENT: {
      BASE_SENSITIVITY: 1.0,
      MIN_SENSITIVITY: 0.1,
      MAX_SENSITIVITY: 3.0,
      SENSITIVITY_STEP: 0.1,
      
      // Acceleration settings
      ACCELERATION_TIME: 200, // ms to reach full speed
      DECELERATION_TIME: 100, // ms to stop
    },
    
    // Touch and mouse settings
    TOUCH: {
      TAP_MAX_DURATION: 200, // ms
      LONG_PRESS_DURATION: 500, // ms
      SWIPE_MIN_DISTANCE: 50, // pixels
      PINCH_THRESHOLD: 10, // pixels
    },
    
    // Keyboard shortcuts
    KEYS: {
      // Scene switching
      MENU: ['Escape'],
      INVENTORY: ['KeyI', 'KeyB'], // I or B
      BATTLE: ['KeyB'],
      WORLD: ['KeyW'],
      
      // Debug keys
      TOGGLE_DEBUG: ['F1'],
      LOG_STATE: ['F2'],
      SHOW_VIEWPORT: ['F3'],
      SHOW_PERFORMANCE: ['F4'],
      
      // Inventory shortcuts
      TOGGLE_SHAPE_OUTLINES: ['KeyS'],
      TOGGLE_DIMENSIONS: ['KeyD'],
      RESET_ITEMS: ['KeyR'],
      TEST_SHAPES: ['KeyT'],
      CLEAR_INVENTORY: ['KeyC'],
      
      // Fullscreen
      FULLSCREEN: ['F11', 'AltLeft+KeyF'],
    },
  };
  
  // ============= PERFORMANCE CONFIGURATION =============
  
  export const PERFORMANCE = {
    // Rendering settings
    RENDERING: {
      TARGET_FPS: 60,
      MAX_SPRITES_PER_LAYER: 1000,
      CULLING_MARGIN: 100, // pixels outside viewport to still render
      
      // Particle limits
      MAX_PARTICLES: 500,
      PARTICLE_CLEANUP_INTERVAL: 5000, // ms
    },
    
    // Memory management
    MEMORY: {
      TEXTURE_CACHE_SIZE: 100,
      SOUND_CACHE_SIZE: 50,
      GARBAGE_COLLECTION_INTERVAL: 30000, // ms
    },
    
    // Quality scaling based on performance
    QUALITY_SCALING: {
      EXCELLENT: { particles: 1.0, shadows: true, effects: true },
      GOOD: { particles: 0.7, shadows: true, effects: true },
      MEDIUM: { particles: 0.5, shadows: false, effects: true },
      LOW: { particles: 0.2, shadows: false, effects: false },
    },
  };
  
  // ============= SAVE SYSTEM CONFIGURATION =============
  
  export const SAVE_SYSTEM = {
    // Auto-save settings
    AUTO_SAVE: {
      ENABLED: true,
      INTERVAL: 30000, // ms (30 seconds)
      MAX_AUTO_SAVES: 5,
    },
    
    // Save file management
    FILES: {
      MAX_SAVE_SLOTS: 10,
      BACKUP_COUNT: 3,
      COMPRESSION_ENABLED: true,
    },
    
    // Data validation
    VALIDATION: {
      VERSION_CHECK: true,
      CHECKSUM_VALIDATION: true,
      MIGRATION_ENABLED: true,
    },
  };