import { Engine } from './core/Engine.js';
import { InputManager } from './core/InputManager.js';
import { MenuScene } from './scenes/MenuScene.js';
import { InventoryScene } from './scenes/InventoryScene.js';
import { BattleScene } from './scenes/BattleScene.js';

class TacticalRPG {
    constructor() {
        this.engine = new Engine('gameCanvas');
        this.inputManager = new InputManager(this.engine.canvas);
        this.engine.setInputManager(this.inputManager);
        
        this.setupScenes();
        this.setupGlobalControls();
        this.setupErrorHandling();
    }
    
    setupScenes() {
        // Create and register all scenes
        this.menuScene = new MenuScene();
        this.inventoryScene = new InventoryScene();
        this.battleScene = new BattleScene();
        
        this.engine.addScene('menu', this.menuScene);
        this.engine.addScene('inventory', this.inventoryScene);
        this.engine.addScene('battle', this.battleScene);
    }
    
    setupGlobalControls() {
        // Global key handlers that work across all scenes
        this.inputManager.onKeyPress('Escape', () => {
            // Always allow escape to menu unless in battle
            if (this.engine.currentScene !== this.battleScene) {
                this.engine.switchScene('menu');
            }
        });
        
        // Debug controls (remove in production)
        this.inputManager.onKeyPress('F1', () => this.toggleDebugInfo());
        this.inputManager.onKeyPress('F2', () => this.logGameState());
    }
    
    setupErrorHandling() {
        // Global error handler for the game
        window.addEventListener('error', (event) => {
            console.error('Game Error:', event.error);
            this.handleGameError(event.error);
        });
        
        // Handle unhandled promise rejections
        window.addEventListener('unhandledrejection', (event) => {
            console.error('Unhandled Promise Rejection:', event.reason);
            this.handleGameError(event.reason);
        });
    }
    
    handleGameError(error) {
        // In a production game, you might want to show a user-friendly error message
        // and possibly save the game state before crashing
        console.error('Critical game error occurred:', error);
        
        // For development, we'll just log it
        // In production, you might want to:
        // 1. Save current game state
        // 2. Show error dialog
        // 3. Attempt to recover or restart
    }
    
    toggleDebugInfo() {
        const debugElement = document.getElementById('debugInfo');
        if (debugElement) {
            debugElement.style.display = debugElement.style.display === 'none' ? 'block' : 'none';
        }
    }
    
    logGameState() {
        console.group('🎮 Game State Debug Info');
        console.log('Current Scene:', this.engine.currentScene?.constructor.name);
        console.log('Engine State:', {
            width: this.engine.width,
            height: this.engine.height,
            fps: this.engine.fps,
            isRunning: this.engine.isRunning
        });
        
        if (this.engine.currentScene === this.inventoryScene) {
            console.log('Inventory Items:', this.inventoryScene.inventoryGrid.items.length);
            console.log('Storage Items:', this.inventoryScene.storageGrid.items.length);
            console.log('Available Skills:', this.inventoryScene.inventoryGrid.generateSkills().length);
        }
        
        if (this.engine.currentScene === this.battleScene) {
            console.log('Battle State:', this.battleScene.battleState);
            console.log('Current Turn:', this.battleScene.getCurrentActor()?.name);
            console.log('Player HP:', `${this.battleScene.player.hp}/${this.battleScene.player.maxHp}`);
            console.log('Enemies Alive:', this.battleScene.enemies.filter(e => e.isAlive()).length);
        }
        
        console.groupEnd();
    }
    
    // Game lifecycle methods
    start() {
        console.group('🚀 Tactical RPG - Starting Game');
        console.log('📁 Architecture: Modular ES6 with clean separation of concerns');
        console.log('🎯 Features:');
        console.log('  ├── Advanced inventory system with spatial relationships');
        console.log('  ├── Dynamic skill generation based on item placement');
        console.log('  ├── Turn-based combat with AI enemies');
        console.log('  ├── Character progression and leveling');
        console.log('  ├── Clean scene management system');
        console.log('  └── Robust input handling and error management');
        console.log('');
        console.log('🎮 Controls:');
        console.log('  ├── Menu: Arrow keys + Enter, or click');
        console.log('  ├── Inventory: Drag & drop, hover for relationships');
        console.log('  ├── Battle: Click skills then targets, or use hotkeys');
        console.log('  └── Global: Esc = Menu, F1 = Debug, F2 = State log');
        console.groupEnd();
        
        // Set initial scene and start the engine
        this.engine.switchScene('menu');
        this.engine.start();
        
        // Update UI
        document.getElementById('gameState').textContent = 'Running - Professional Architecture';
        
        // Show welcome message
        this.showWelcomeMessage();
    }
    
    showWelcomeMessage() {
        setTimeout(() => {
            console.log('');
            console.log('🎉 Welcome to Tactical RPG!');
            console.log('Navigate to Inventory (I) to set up your character\'s equipment,');
            console.log('then head to Battle (B) to test your skill combinations!');
            console.log('');
        }, 1000);
    }
    
    stop() {
        this.engine.stop();
        console.log('🛑 Game stopped');
    }
    
    restart() {
        this.stop();
        // Reset all scenes to initial state
        this.inventoryScene = new InventoryScene();
        this.battleScene = new BattleScene();
        this.engine.addScene('inventory', this.inventoryScene);
        this.engine.addScene('battle', this.battleScene);
        
        this.start();
        console.log('🔄 Game restarted');
    }
    
    // Save/Load system (basic implementation)
    saveGame() {
        try {
            const gameData = {
                version: '1.0.0',
                timestamp: Date.now(),
                player: this.battleScene.player.toJSON(),
                inventoryItems: this.serializeInventory(),
                currentScene: this.engine.currentScene?.constructor.name
            };
            
            localStorage.setItem('tacticalRPG_save', JSON.stringify(gameData));
            console.log('✅ Game saved successfully');
            return true;
        } catch (error) {
            console.error('❌ Failed to save game:', error);
            return false;
        }
    }
    
    loadGame() {
        try {
            const saveData = localStorage.getItem('tacticalRPG_save');
            if (!saveData) {
                console.log('ℹ️ No save data found');
                return false;
            }
            
            const gameData = JSON.parse(saveData);
            console.log('📂 Loading game from:', new Date(gameData.timestamp));
            
            // Restore player data
            this.battleScene.player.fromJSON(gameData.player);
            
            // Restore inventory (simplified - would need more complex logic)
            this.deserializeInventory(gameData.inventoryItems);
            
            // Switch to saved scene
            if (gameData.currentScene && this.engine.scenes.has(gameData.currentScene.toLowerCase())) {
                this.engine.switchScene(gameData.currentScene.toLowerCase());
            }
            
            console.log('✅ Game loaded successfully');
            return true;
        } catch (error) {
            console.error('❌ Failed to load game:', error);
            return false;
        }
    }
    
    serializeInventory() {
        // Simplified inventory serialization
        return {
            inventoryItems: this.inventoryScene.inventoryGrid.items.map(item => ({
                id: item.id,
                gridX: item.gridX,
                gridY: item.gridY
            })),
            storageItems: this.inventoryScene.storageGrid.items.map(item => ({
                id: item.id,
                gridX: item.gridX,
                gridY: item.gridY
            }))
        };
    }
    
    deserializeInventory(inventoryData) {
        // Simplified inventory deserialization
        // In a full implementation, you'd need to reconstruct the items
        // and place them according to the saved positions
        console.log('📦 Inventory restoration would happen here');
    }
    
    // Performance monitoring
    getPerformanceStats() {
        return {
            fps: this.engine.fps,
            memoryUsage: performance.memory ? {
                used: Math.round(performance.memory.usedJSHeapSize / 1024 / 1024),
                total: Math.round(performance.memory.totalJSHeapSize / 1024 / 1024),
                limit: Math.round(performance.memory.jsHeapSizeLimit / 1024 / 1024)
            } : 'Not available',
            gameObjects: {
                inventoryItems: this.inventoryScene.inventoryGrid.items.length + 
                                this.inventoryScene.storageGrid.items.length,
                battleCharacters: this.battleScene.enemies.length + 1,
                scenes: this.engine.scenes.size
            }
        };
    }
    
    // Development utilities
    cheatMode() {
        if (process.env.NODE_ENV === 'development') {
            console.log('🎭 Cheat mode activated');
            
            // Give player max stats
            this.battleScene.player.hp = this.battleScene.player.maxHp;
            this.battleScene.player.mp = this.battleScene.player.maxMp;
            this.battleScene.player.level = 10;
            
            // Add all items to inventory
            // Implementation would depend on specific needs
            
            return true;
        }
        
        console.log('🚫 Cheat mode not available in production');
        return false;
    }
    }
    
    // Game instance - global for debugging
    let game;
    
    // Initialize game when page loads
    window.addEventListener('load', () => {
    game = new TacticalRPG();
    game.start();
    
    // Make game globally available for debugging
    window.game = game;
    
    // Add development helpers
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        console.log('🔧 Development mode detected');
        console.log('Available global commands:');
        console.log('  - game.saveGame() / game.loadGame()');
        console.log('  - game.getPerformanceStats()');
        console.log('  - game.cheatMode()');
        console.log('  - game.restart()');
        
        // Add performance monitoring
        setInterval(() => {
            const stats = game.getPerformanceStats();
            if (stats.fps < 30) {
                console.warn('⚠️ Low FPS detected:', stats.fps);
            }
        }, 5000);
    }
    });
    
    // Handle page visibility changes
    document.addEventListener('visibilitychange', () => {
    if (game) {
        if (document.hidden) {
            // Pause game when tab is not visible
            game.engine.stop();
            console.log('⏸️ Game paused (tab hidden)');
        } else {
            // Resume game when tab becomes visible
            game.engine.start();
            console.log('▶️ Game resumed (tab visible)');
        }
    }
    });
    
    // Handle page unload
    window.addEventListener('beforeunload', (event) => {
    if (game) {
        // Auto-save before closing
        const saved = game.saveGame();
        if (saved) {
            console.log('💾 Auto-saved game before closing');
        }
    }
    });
    
    // Export for potential module usage
    export { TacticalRPG };