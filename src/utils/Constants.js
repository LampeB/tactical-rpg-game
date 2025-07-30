/**
 * Constants.js - Centralized configuration constants
 * 
 * This file contains all magic numbers and configuration values
 * used throughout the application for consistency and maintainability.
 */

// ============= GRID & LAYOUT CONSTANTS =============

export const GRID = {
    // Default grid settings
    DEFAULT_CELL_SIZE: 40,
    MIN_CELL_SIZE: 15,
    BASE_MINI_GRID_SIZE: 20,
    
    // Standard grid dimensions
    INVENTORY_COLS: 10,
    INVENTORY_ROWS: 8,
    MOBILE_INVENTORY_COLS: 8,
    MOBILE_INVENTORY_ROWS: 6,
    
    // Loot scene grid dimensions
    LOOT_GRID_COLS: 10,
    LOOT_GRID_ROWS: 8,
    LOOT_MOBILE_COLS: 8,
    LOOT_MOBILE_ROWS: 6,
  };
  
  export const LAYOUT = {
    // Spacing and padding
    PADDING: 20,
    MOBILE_PADDING: 15,
    SMALL_SPACING: 5,
    MEDIUM_SPACING: 10,
    LARGE_SPACING: 15,
    EXTRA_LARGE_SPACING: 20,
    
    // Border and line widths
    THIN_BORDER: 1,
    MEDIUM_BORDER: 2,
    THICK_BORDER: 3,
    HIGHLIGHT_BORDER: 3,
    
    // Corner radius values
    SMALL_RADIUS: 5,
    MEDIUM_RADIUS: 8,
    LARGE_RADIUS: 10,
    EXTRA_LARGE_RADIUS: 15,
  };
  
  export const RESPONSIVE = {
    // Mobile breakpoints
    MOBILE_MAX_WIDTH: 768,
    TABLET_MAX_WIDTH: 1024,
    
    // Scale factors
    MIN_SCALE: 0.6,
    MAX_SCALE: 1.4,
    BASE_SCALE: 1.0,
    
    // Mobile scale adjustments
    MOBILE_SCALE_FACTOR: 0.8,
    MOBILE_MIN_SCALE: 0.8,
    MOBILE_MAX_SCALE: 1.0,
  };
  
  // ============= COLOR CONSTANTS =============
  
  export const COLORS = {
    // Primary colors (hex format)
    HEX: {
      RED: '#e74c3c',
      PURPLE: '#9b59b6',
      DARK_BLUE: '#34495e',
      ORANGE: '#e67e22',
      YELLOW: '#f39c12',
      GREEN: '#27ae60',
      TEAL: '#16a085',
      GRAY: '#7f8c8d',
      WHITE: '#ffffff',
      BLACK: '#000000',
      
      // UI specific colors
      LIGHT_GRAY: '#ecf0f1',
      MEDIUM_GRAY: '#bdc3c7',
      DARK_GRAY: '#2c3e50',
      GOLD: '#ffd700',
      
      // Brightened versions for highlighting
      BRIGHT_RED: '#ff6b5a',
      BRIGHT_PURPLE: '#b574d3',
      BRIGHT_DARK_BLUE: '#4a6377',
      BRIGHT_ORANGE: '#ff9639',
      BRIGHT_YELLOW: '#ffb32e',
      BRIGHT_GREEN: '#2ecc71',
      BRIGHT_TEAL: '#1abc9c',
      BRIGHT_GRAY: '#95a5a6',
    },
    
    // PIXI color format (numeric)
    PIXI: {
      RED: 0xe74c3c,
      PURPLE: 0x9b59b6,
      DARK_BLUE: 0x34495e,
      ORANGE: 0xe67e22,
      YELLOW: 0xf39c12,
      GREEN: 0x27ae60,
      TEAL: 0x16a085,
      GRAY: 0x7f8c8d,
      WHITE: 0xffffff,
      BLACK: 0x000000,
      
      // UI Panel colors
      LIGHT_GRAY: 0xecf0f1,
      MEDIUM_GRAY: 0xbdc3c7,
      DARK_GRAY: 0x2c3e50,
      GOLD: 0xffd700,
      
      // Battle UI colors
      PLAYER_PANEL: 0x2e7d32,
      PLAYER_BORDER: 0x4caf50,
      ENEMY_PANEL: 0xad1457,
      ENEMY_BORDER: 0xe91e63,
      SKILLS_PANEL: 0x1976d2,
      SKILLS_BORDER: 0x2196f3,
      LOG_PANEL: 0x455a64,
      LOG_BORDER: 0x607d8b,
      TURN_INDICATOR: 0x34495e,
      ACTION_BUTTON: 0x795548,
      AUTO_BATTLE_ACTIVE: 0xe74c3c,
      
      // Menu colors
      MENU_INVENTORY: 0x27ae60,
      MENU_BATTLE: 0xe74c3c,
      MENU_WORLD: 0x3498db,
      MENU_SETTINGS: 0x95a5a6,
      
      // Overlay colors
      OVERLAY_DARK: 0x000000,
      VICTORY_PANEL: 0x2e7d32,
      DEFEAT_PANEL: 0xad1457,
    },
    
    // Alpha/transparency values
    ALPHA: {
      INVISIBLE: 0.0,
      VERY_LOW: 0.1,
      LOW: 0.3,
      MEDIUM_LOW: 0.5,
      MEDIUM: 0.7,
      MEDIUM_HIGH: 0.8,
      HIGH: 0.9,
      OPAQUE: 1.0,
    },
  };
  
  // ============= FONT CONSTANTS =============
  
  export const FONTS = {
    // Font families
    FAMILY: {
      PRIMARY: 'Arial',
      MONOSPACE: 'monospace',
    },
    
    // Base font sizes
    SIZE: {
      TINY: 8,
      SMALL: 10,
      BODY: 12,
      SUBTITLE: 14,
      TITLE: 18,
      LARGE_TITLE: 24,
      HUGE_TITLE: 28,
      
      // Mobile font sizes
      MOBILE_TINY: 8,
      MOBILE_SMALL: 10,
      MOBILE_BODY: 12,
      MOBILE_SUBTITLE: 14,
      MOBILE_TITLE: 16,
      MOBILE_LARGE_TITLE: 20,
    },
    
    // Font weight options
    WEIGHT: {
      NORMAL: 'normal',
      BOLD: 'bold',
    },
    
    // Text alignment
    ALIGN: {
      LEFT: 'left',
      CENTER: 'center',
      RIGHT: 'right',
    },
  };
  
  // ============= UI ELEMENT DIMENSIONS =============
  
  export const UI = {
    // Button dimensions
    BUTTON: {
      // Standard buttons
      SMALL_WIDTH: 80,
      SMALL_HEIGHT: 30,
      MEDIUM_WIDTH: 100,
      MEDIUM_HEIGHT: 35,
      LARGE_WIDTH: 350,
      LARGE_HEIGHT: 60,
      
      // Mobile buttons
      MOBILE_SMALL_WIDTH: 70,
      MOBILE_SMALL_HEIGHT: 25,
      MOBILE_MEDIUM_WIDTH: 90,
      MOBILE_MEDIUM_HEIGHT: 30,
      MOBILE_LARGE_WIDTH: 280,
      MOBILE_LARGE_HEIGHT: 50,
      
      // Battle skill buttons
      SKILL_HEIGHT_DESKTOP: 40,
      SKILL_HEIGHT_MOBILE: 50,
      SKILL_SPACING_DESKTOP: 5,
      SKILL_SPACING_MOBILE: 8,
    },
    
    // Panel dimensions
    PANEL: {
      // Loot scene panels
      LOOT_MAX_WIDTH: 900,
      LOOT_MAX_HEIGHT_WITH_STATS: 650,
      LOOT_MAX_HEIGHT_NO_STATS: 600,
      
      // Battle scene panels
      BATTLE_PLAYER_WIDTH: 300,
      BATTLE_PLAYER_HEIGHT: 120,
      BATTLE_ENEMY_WIDTH: 200,
      BATTLE_ENEMY_HEIGHT: 100,
      BATTLE_SKILLS_WIDTH: 250,
      BATTLE_SKILLS_MIN_HEIGHT: 200,
      BATTLE_LOG_WIDTH: 300,
      BATTLE_LOG_HEIGHT: 150,
      TURN_INDICATOR_WIDTH: 200,
      TURN_INDICATOR_HEIGHT: 50,
    },
    
    // Menu configuration
    MENU: {
      TITLE_OFFSET_Y: -200,
      SUBTITLE_OFFSET_Y: -140,
      VERSION_OFFSET_Y: -100,
      BUTTON_START_OFFSET_Y: -20,
      BUTTON_SPACING: 80,
      
      // Mobile menu adjustments
      MOBILE_SPACING: 60,
      MOBILE_TITLE_OFFSET_PERCENT: 0.3,
      MOBILE_SUBTITLE_OFFSET_PERCENT: 0.22,
      MOBILE_VERSION_OFFSET_PERCENT: 0.18,
    },
    
    // Item and loot dimensions
    LOOT: {
      ITEM_SIZE_BASE: 80,
      ITEM_SIZE_MIN: 60,
      SPACING_DESKTOP: 15,
      SPACING_MOBILE: 10,
      ITEMS_PER_ROW_DESKTOP: 4,
      ITEMS_PER_ROW_MOBILE: 3,
      
      // Storage list dimensions
      STORAGE_WIDTH_DESKTOP: 200,
      STORAGE_WIDTH_MOBILE: 180,
      STORAGE_HEIGHT_DESKTOP: 160,
      STORAGE_HEIGHT_MOBILE: 120,
    },
    
    // Health/MP bar dimensions
    BAR: {
      WIDTH: 120,
      HEIGHT: 8,
      BORDER_WIDTH: 1,
    },
  };
  
  // ============= GAME TIMING CONSTANTS =============
  
  export const TIMING = {
    // Animation durations (in milliseconds)
    FAST_ANIMATION: 150,
    MEDIUM_ANIMATION: 300,
    SLOW_ANIMATION: 500,
    VERY_SLOW_ANIMATION: 1000,
    
    // Battle timing
    BATTLE_ACTION_DELAY: 500,
    DAMAGE_DISPLAY_DURATION: 1000,
    AUTO_BATTLE_DELAY: 1500,
    
    // Input timing
    DOUBLE_CLICK_TIME: 300,
    LONG_PRESS_TIME: 500,
  };
  
  // ============= DEBUGGING CONSTANTS =============
  
  export const DEBUG = {
    // Console colors for debugging
    LOG_COLORS: {
      INFO: '#3498db',
      SUCCESS: '#27ae60',
      WARNING: '#f39c12',
      ERROR: '#e74c3c',
      DEBUG: '#9b59b6',
    },
    
    // Debug flags (can be overridden by environment)
    SHOW_GRID_LINES: false,
    SHOW_COLLISION_BOXES: false,
    SHOW_FPS: false,
    VERBOSE_LOGGING: false,
  };
  
  // ============= MATH CONSTANTS =============
  
  export const MATH = {
    // Common mathematical constants
    SQRT_2: Math.sqrt(2),
    HALF_PI: Math.PI / 2,
    TWO_PI: Math.PI * 2,
    
    // Normalization factors
    DIAGONAL_MOVEMENT_FACTOR: 1 / Math.sqrt(2),
    
    // Precision values
    FLOAT_PRECISION: 0.001,
    PERCENTAGE_PRECISION: 0.01,
  };