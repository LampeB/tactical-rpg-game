import { PixiEngine } from './core/PixiEngine.js';
import { PixiInputManager } from './core/PixiInputManager.js';
import { PixiScene } from './core/PixiScene.js';

// Temporary scenes until we convert the real ones
class PixiMenuScene extends PixiScene {
    constructor() {
        super();
        this.buttons = [];
        this.hoveredButton = -1;
    }
    
    onEnter() {
        super.onEnter();
        
        // Create background
        this.createBackground();
        
        // Create menu buttons
        this.createMenuButtons();
        
        // Update game mode display
        const gameModeBtn = document.getElementById('gameMode');
        if (gameModeBtn) {
            gameModeBtn.textContent = '📋 MENU';
        }
        
        console.log('Menu scene loaded with PixiJS');
    }
    
    createBackground() {
        // Gradient background
        const bg = new PIXI.Graphics();
        bg.beginFill(0x3498db);
        bg.drawRect(0, 0, this.engine.width, this.engine.height);
        bg.endFill();
        this.addGraphics(bg, 'background');
        
        // Title
        const title = new PIXI.Text('TACTICAL RPG', {
            fontFamily: 'Arial',
            fontSize: 48,
            fill: 0xffffff,
            align: 'center',
            fontWeight: 'bold'
        });
        title.anchor.set(0.5);
        title.x = this.engine.width / 2;
        title.y = 150;
        this.addSprite(title, 'ui');
        
        // Subtitle - REMOVED GLOW FILTER (this was causing the error)
        const subtitle = new PIXI.Text('Enhanced with PixiJS', {
            fontFamily: 'Arial',
            fontSize: 24,
            fill: 0x64b5f6, // Changed to blue color instead of glow
            align: 'center'
        });
        subtitle.anchor.set(0.5);
        subtitle.x = this.engine.width / 2;
        subtitle.y = 200;
        
        this.addSprite(subtitle, 'ui');
    }
    
    createMenuButtons() {
        const buttonData = [
            { text: '🎒 Inventory Management', action: () => this.engine.switchScene('inventory') },
            { text: '⚔️ Battle Mode', action: () => this.engine.switchScene('battle') },
            { text: '🎮 World Exploration', action: () => this.engine.switchScene('world') },
            { text: '⚙️ Settings', action: () => this.showSettings() }
        ];
        
        buttonData.forEach((data, index) => {
            const button = this.createMenuButton(data.text, data.action, index);
            this.buttons.push(button);
        });
    }
    
    createMenuButton(text, action, index) {
        const buttonContainer = new PIXI.Container();
        
        // Button background
        const bg = new PIXI.Graphics();
        bg.beginFill(0x34495e);
        bg.drawRoundedRect(0, 0, 350, 50, 10);
        bg.endFill();
        
        // Button border
        bg.lineStyle(2, 0xecf0f1);
        bg.drawRoundedRect(0, 0, 350, 50, 10);
        
        // Button text
        const buttonText = new PIXI.Text(text, {
            fontFamily: 'Arial',
            fontSize: 18,
            fill: 0xffffff,
            align: 'center'
        });
        buttonText.anchor.set(0.5);
        buttonText.x = 175;
        buttonText.y = 25;
        
        buttonContainer.addChild(bg);
        buttonContainer.addChild(buttonText);
        
        // Position
        buttonContainer.x = this.engine.width / 2 - 175;
        buttonContainer.y = 300 + index * 70;
        
        // Make interactive
        buttonContainer.interactive = true;
        buttonContainer.cursor = 'pointer';
        
        // Hover effects
        buttonContainer.on('pointerover', () => {
            bg.clear();
            bg.beginFill(0xf39c12);
            bg.drawRoundedRect(0, 0, 350, 50, 10);
            bg.endFill();
            bg.lineStyle(2, 0xffffff);
            bg.drawRoundedRect(0, 0, 350, 50, 10);
            buttonText.style.fill = 0x2c3e50;
        });
        
        buttonContainer.on('pointerout', () => {
            bg.clear();
            bg.beginFill(0x34495e);
            bg.drawRoundedRect(0, 0, 350, 50, 10);
            bg.endFill();
            bg.lineStyle(2, 0xecf0f1);
            bg.drawRoundedRect(0, 0, 350, 50, 10);
            buttonText.style.fill = 0xffffff;
        });
        
        buttonContainer.on('pointerdown', action);
        
        this.addSprite(buttonContainer, 'ui');
        return buttonContainer;
    }
    
    showSettings() {
        console.log('Settings clicked - PixiJS version!');
        // Create a simple settings popup
        this.createSettingsPopup();
    }
    
    createSettingsPopup() {
        // Semi-transparent overlay
        const overlay = new PIXI.Graphics();
        overlay.beginFill(0x000000, 0.7);
        overlay.drawRect(0, 0, this.engine.width, this.engine.height);
        overlay.endFill();
        overlay.interactive = true;
        
        // Settings panel
        const panel = new PIXI.Graphics();
        panel.beginFill(0x34495e);
        panel.drawRoundedRect(0, 0, 400, 300, 15);
        panel.endFill();
        panel.lineStyle(3, 0xf39c12);
        panel.drawRoundedRect(0, 0, 400, 300, 15);
        
        panel.x = this.engine.width / 2 - 200;
        panel.y = this.engine.height / 2 - 150;
        
        // Title
        const title = new PIXI.Text('Settings', {
            fontFamily: 'Arial',
            fontSize: 24,
            fill: 0xffffff,
            align: 'center'
        });
        title.anchor.set(0.5);
        title.x = 200;
        title.y = 40;
        panel.addChild(title);
        
        // Settings text
        const settingsText = new PIXI.Text('PixiJS Engine Settings\n\n✨ Hardware Acceleration: ON\n🎨 Anti-aliasing: ON\n📊 Performance Monitor: ON\n🖱️ Interactive UI: ON', {
            fontFamily: 'Arial',
            fontSize: 14,
            fill: 0xecf0f1,
            align: 'center',
            lineHeight: 20
        });
        settingsText.anchor.set(0.5);
        settingsText.x = 200;
        settingsText.y = 150;
        panel.addChild(settingsText);
        
        // Close button
        const closeBtn = this.createSimpleButton('Close', 150, 230, () => {
            this.removeSprite(overlay);
        });
        panel.addChild(closeBtn);
        
        overlay.addChild(panel);
        this.addSprite(overlay, 'ui');
    }
    
    handleKeyDown(event) {
        if (event.code === 'Escape') {
            console.log('Escape pressed in menu');
        }
    }
}

class PixiInventoryScene extends PixiScene {
    constructor() {
        super();
        this.gridCellSize = 40;
        this.inventoryGrid = { x: 50, y: 100, cols: 10, rows: 8 };
        this.storageGrid = { x: 650, y: 100, cols: 8, rows: 6 };
        this.draggedItem = null;
        this.items = [];
    }
    
    onEnter() {
        super.onEnter();
        
        // Create background
        this.createBackground();
        
        // Create grids
        this.createGrids();
        
        // Create sample items
        this.createSampleItems();
        
        // Update game mode display
        const gameModeBtn = document.getElementById('gameMode');
        if (gameModeBtn) {
            gameModeBtn.textContent = '🎒 INVENTORY';
        }
        
        console.log('Inventory scene loaded with PixiJS');
    }
    
    createBackground() {
        const bg = new PIXI.Graphics();
        bg.beginFill(0x27ae60);
        bg.drawRect(0, 0, this.engine.width, this.engine.height);
        bg.endFill();
        this.addGraphics(bg, 'background');
        
        // Title
        const title = new PIXI.Text('INVENTORY MANAGEMENT', {
            fontFamily: 'Arial',
            fontSize: 24,
            fill: 0xffffff,
            align: 'center',
            fontWeight: 'bold'
        });
        title.anchor.set(0.5);
        title.x = this.engine.width / 2;
        title.y = 40;
        this.addSprite(title, 'ui');
        
        // Grid labels
        const inventoryLabel = new PIXI.Text('Character Inventory', {
            fontFamily: 'Arial',
            fontSize: 16,
            fill: 0xffffff
        });
        inventoryLabel.x = this.inventoryGrid.x;
        inventoryLabel.y = this.inventoryGrid.y - 25;
        this.addSprite(inventoryLabel, 'ui');
        
        const storageLabel = new PIXI.Text('Item Storage', {
            fontFamily: 'Arial',
            fontSize: 16,
            fill: 0xffffff
        });
        storageLabel.x = this.storageGrid.x;
        storageLabel.y = this.storageGrid.y - 25;
        this.addSprite(storageLabel, 'ui');
    }
    
    createGrids() {
        // Create inventory grid
        this.createGrid(this.inventoryGrid, 0x34495e);
        
        // Create storage grid
        this.createGrid(this.storageGrid, 0x8e44ad);
    }
    
    createGrid(gridData, color) {
        const grid = new PIXI.Graphics();
        
        // Grid background
        grid.beginFill(color, 0.3);
        grid.drawRect(0, 0, gridData.cols * this.gridCellSize, gridData.rows * this.gridCellSize);
        grid.endFill();
        
        // Grid lines
        grid.lineStyle(1, 0xbdc3c7);
        
        // Vertical lines
        for (let col = 0; col <= gridData.cols; col++) {
            const x = col * this.gridCellSize;
            grid.moveTo(x, 0);
            grid.lineTo(x, gridData.rows * this.gridCellSize);
        }
        
        // Horizontal lines
        for (let row = 0; row <= gridData.rows; row++) {
            const y = row * this.gridCellSize;
            grid.moveTo(0, y);
            grid.lineTo(gridData.cols * this.gridCellSize, y);
        }
        
        grid.x = gridData.x;
        grid.y = gridData.y;
        
        this.addGraphics(grid, 'world');
    }
    
    createSampleItems() {
        // Sample items data
        const itemsData = [
            { name: 'Sword', color: 0xe74c3c, width: 1, height: 3, x: 0, y: 0 },
            { name: 'Shield', color: 0x34495e, width: 2, height: 2, x: 2, y: 0 },
            { name: 'Fire Gem', color: 0xe67e22, width: 1, height: 1, x: 0, y: 3 },
            { name: 'Potion', color: 0x27ae60, width: 1, height: 1, x: 1, y: 3 },
            { name: 'Staff', color: 0x9b59b6, width: 1, height: 2, x: 4, y: 0 }
        ];
        
        itemsData.forEach(data => {
            const item = this.createItem(data);
            this.placeItemInGrid(item, this.storageGrid, data.x, data.y);
        });
    }
    
    createItem(data) {
        const item = new PIXI.Container();
        
        // Item background
        const bg = new PIXI.Graphics();
        bg.beginFill(data.color);
        bg.drawRect(0, 0, data.width * this.gridCellSize - 4, data.height * this.gridCellSize - 4);
        bg.endFill();
        
        // Item border
        bg.lineStyle(2, 0x2c3e50);
        bg.drawRect(0, 0, data.width * this.gridCellSize - 4, data.height * this.gridCellSize - 4);
        
        // Item name
        const text = new PIXI.Text(data.name, {
            fontFamily: 'Arial',
            fontSize: 12,
            fill: 0xffffff,
            align: 'center'
        });
        text.anchor.set(0.5);
        text.x = (data.width * this.gridCellSize) / 2 - 2;
        text.y = (data.height * this.gridCellSize) / 2 - 2;
        
        item.addChild(bg);
        item.addChild(text);
        
        // Simple highlight effect for gems (instead of glow filter)
        if (data.name.includes('Gem')) {
            // Add a subtle border animation
            const highlight = new PIXI.Graphics();
            highlight.lineStyle(2, 0xffd700, 0.8);
            highlight.drawRect(0, 0, data.width * this.gridCellSize - 4, data.height * this.gridCellSize - 4);
            item.addChild(highlight);
            
            // Simple pulsing animation
            let time = 0;
            const animate = () => {
                time += 0.05;
                highlight.alpha = 0.3 + Math.sin(time) * 0.3;
                requestAnimationFrame(animate);
            };
            animate();
        }
        
        // Store item data
        item.itemData = data;
        item.gridX = -1;
        item.gridY = -1;
        
        // Make interactive
        item.interactive = true;
        item.cursor = 'pointer';
        
        // Drag functionality
        item.on('pointerdown', (event) => this.startDragging(item, event));
        
        this.items.push(item);
        return item;
    }
    
    placeItemInGrid(item, grid, gridX, gridY) {
        item.x = grid.x + gridX * this.gridCellSize + 2;
        item.y = grid.y + gridY * this.gridCellSize + 2;
        item.gridX = gridX;
        item.gridY = gridY;
        
        this.addSprite(item, 'world');
    }
    
    startDragging(item, event) {
        this.draggedItem = item;
        
        // Store original position
        item.originalX = item.x;
        item.originalY = item.y;
        item.originalGridX = item.gridX;
        item.originalGridY = item.gridY;
        
        // Move to top layer
        this.removeSprite(item);
        this.addSprite(item, 'effects');
        
        // Make semi-transparent
        item.alpha = 0.8;
        
        // Follow mouse
        const onMove = (event) => {
            if (this.draggedItem === item) {
                item.x = event.global.x - (item.itemData.width * this.gridCellSize) / 2;
                item.y = event.global.y - (item.itemData.height * this.gridCellSize) / 2;
            }
        };
        
        const onEnd = (event) => {
            this.stopDragging(item, event);
            this.engine.app.stage.off('pointermove', onMove);
            this.engine.app.stage.off('pointerup', onEnd);
        };
        
        this.engine.app.stage.on('pointermove', onMove);
        this.engine.app.stage.on('pointerup', onEnd);
    }
    
    stopDragging(item, event) {
        if (this.draggedItem !== item) return;
        
        // Find which grid we're over
        const mousePos = event.global;
        let targetGrid = null;
        let gridX = -1;
        let gridY = -1;
        
        // Check inventory grid
        if (mousePos.x >= this.inventoryGrid.x && 
            mousePos.x < this.inventoryGrid.x + this.inventoryGrid.cols * this.gridCellSize &&
            mousePos.y >= this.inventoryGrid.y && 
            mousePos.y < this.inventoryGrid.y + this.inventoryGrid.rows * this.gridCellSize) {
            
            targetGrid = this.inventoryGrid;
            gridX = Math.floor((mousePos.x - this.inventoryGrid.x) / this.gridCellSize);
            gridY = Math.floor((mousePos.y - this.inventoryGrid.y) / this.gridCellSize);
        }
        
        // Check storage grid
        if (mousePos.x >= this.storageGrid.x && 
            mousePos.x < this.storageGrid.x + this.storageGrid.cols * this.gridCellSize &&
            mousePos.y >= this.storageGrid.y && 
            mousePos.y < this.storageGrid.y + this.storageGrid.rows * this.gridCellSize) {
            
            targetGrid = this.storageGrid;
            gridX = Math.floor((mousePos.x - this.storageGrid.x) / this.gridCellSize);
            gridY = Math.floor((mousePos.y - this.storageGrid.y) / this.gridCellSize);
        }
        
        // Place item or return to original position
        if (targetGrid && this.canPlaceItem(item, targetGrid, gridX, gridY)) {
            this.placeItemInGrid(item, targetGrid, gridX, gridY);
        } else {
            // Return to original position
            item.x = item.originalX;
            item.y = item.originalY;
            item.gridX = item.originalGridX;
            item.gridY = item.originalGridY;
        }
        
        // Restore appearance
        item.alpha = 1;
        
        // Move back to world layer
        this.removeSprite(item);
        this.addSprite(item, 'world');
        
        this.draggedItem = null;
    }
    
    canPlaceItem(item, grid, gridX, gridY) {
        // Check bounds
        if (gridX < 0 || gridY < 0 || 
            gridX + item.itemData.width > grid.cols || 
            gridY + item.itemData.height > grid.rows) {
            return false;
        }
        
        // Check for overlapping items (simplified)
        return true;
    }
    
    handleKeyDown(event) {
        if (event.code === 'KeyI') {
            this.engine.switchScene('menu');
        }
    }
}

class PixiBattleScene extends PixiScene {
    constructor() {
        super();
    }
    
    onEnter() {
        super.onEnter();
        
        // Create placeholder battle scene
        this.createBattleBackground();
        
        // Update game mode display
        const gameModeBtn = document.getElementById('gameMode');
        if (gameModeBtn) {
            gameModeBtn.textContent = '⚔️ BATTLE';
        }
        
        console.log('Battle scene loaded with PixiJS');
    }
    
    createBattleBackground() {
        const bg = new PIXI.Graphics();
        bg.beginFill(0x8e44ad);
        bg.drawRect(0, 0, this.engine.width, this.engine.height);
        bg.endFill();
        this.addGraphics(bg, 'background');
        
        const title = new PIXI.Text('BATTLE SYSTEM\n\n(Ready for your existing battle logic!)', {
            fontFamily: 'Arial',
            fontSize: 32,
            fill: 0xffffff,
            align: 'center'
        });
        title.anchor.set(0.5);
        title.x = this.engine.width / 2;
        title.y = this.engine.height / 2;
        this.addSprite(title, 'ui');
    }
}

class TacticalRPG {
    constructor() {
        console.log('🚀 Starting Tactical RPG with PixiJS...');
        
        // Create PixiJS engine
        this.engine = new PixiEngine(1200, 800);
        
        // Create input manager
        this.inputManager = new PixiInputManager();
        this.engine.setInputManager(this.inputManager);
        
        this.setupScenes();
        this.setupGlobalControls();
        this.setupUIHandlers();
        this.setupErrorHandling();
    }
    
    setupScenes() {
        // Create and register scenes
        this.menuScene = new PixiMenuScene();
        this.inventoryScene = new PixiInventoryScene();
        this.battleScene = new PixiBattleScene();
        
        this.engine.addScene('menu', this.menuScene);
        this.engine.addScene('inventory', this.inventoryScene);
        this.engine.addScene('battle', this.battleScene);
        
        console.log('✅ PixiJS scenes registered');
    }
    
    setupGlobalControls() {
        // Global key handlers
        this.inputManager.onKeyPress('Escape', () => {
            this.engine.switchScene('menu');
        });
        
        this.inputManager.onKeyPress('KeyI', () => {
            this.engine.switchScene('inventory');
        });
        
        this.inputManager.onKeyPress('KeyB', () => {
            this.engine.switchScene('battle');
        });
        
        // Debug controls
        this.inputManager.onKeyPress('F1', () => this.toggleDebugInfo());
        this.inputManager.onKeyPress('F2', () => this.logGameState());
        
        console.log('⌨️ Global controls setup');
    }
    
    setupUIHandlers() {
        // Navigation buttons
        const menuBtn = document.getElementById('menuBtn');
        const inventoryBtn = document.getElementById('inventoryBtn');
        const battleBtn = document.getElementById('battleBtn');
        
        if (menuBtn) menuBtn.addEventListener('click', () => this.switchToScene('menu'));
        if (inventoryBtn) inventoryBtn.addEventListener('click', () => this.switchToScene('inventory'));
        if (battleBtn) battleBtn.addEventListener('click', () => this.switchToScene('battle'));
        
        console.log('🖱️ UI handlers setup');
    }
    
    switchToScene(sceneName) {
        this.engine.switchScene(sceneName);
        this.updateNavButtons(sceneName);
    }
    
    updateNavButtons(activeScene) {
        // Update navigation button states
        const buttons = {
            menu: document.getElementById('menuBtn'),
            inventory: document.getElementById('inventoryBtn'),
            battle: document.getElementById('battleBtn')
        };
        
        Object.keys(buttons).forEach(scene => {
            const btn = buttons[scene];
            if (btn) {
                if (scene === activeScene) {
                    btn.classList.add('active');
                } else {
                    btn.classList.remove('active');
                }
            }
        });
    }
    
    setupErrorHandling() {
        window.addEventListener('error', (event) => {
            console.error('Game Error:', event.error);
            this.handleGameError(event.error);
        });
        
        window.addEventListener('unhandledrejection', (event) => {
            console.error('Unhandled Promise Rejection:', event.reason);
            this.handleGameError(event.reason);
        });
    }
    
    handleGameError(error) {
        console.error('Critical game error occurred:', error);
        
        // Show error in UI
        const gameStateElement = document.getElementById('gameState');
        if (gameStateElement) {
            gameStateElement.textContent = 'Error occurred';
            gameStateElement.style.color = '#e74c3c';
        }
    }
    
    toggleDebugInfo() {
        const debugElement = document.getElementById('debugInfo');
        if (debugElement) {
            debugElement.style.display = debugElement.style.display === 'none' ? 'block' : 'none';
        }
    }
    
    logGameState() {
        console.group('🎮 PixiJS Game State Debug Info');
        console.log('Current Scene:', this.engine.currentScene?.constructor.name);
        console.log('Engine State:', {
            width: this.engine.width,
            height: this.engine.height,
            fps: this.engine.fps,
            isRunning: this.engine.isRunning,
            renderer: this.engine.app.renderer.type === PIXI.RENDERER_TYPE.WEBGL ? 'WebGL' : 'Canvas'
        });
        console.log('Total Scenes:', this.engine.scenes.size);
        console.log('PixiJS Version:', PIXI.VERSION);
        console.groupEnd();
    }
    
    start() {
        console.group('🚀 Tactical RPG - Starting with PixiJS');
        console.log('🎨 Graphics Engine: PixiJS WebGL');
        console.log('✨ Features:');
        console.log('  ├── Hardware-accelerated 2D rendering');
        console.log('  ├── Smooth animations and transitions');
        console.log('  ├── Interactive drag & drop system');
        console.log('  ├── Layer-based rendering system');
        console.log('  └── Optimized performance monitoring');
        console.log('');
        console.log('🎮 Controls:');
        console.log('  ├── ESC = Menu');
        console.log('  ├── I = Inventory');
        console.log('  ├── B = Battle');
        console.log('  ├── F1 = Toggle Debug');
        console.log('  └── F2 = Log State');
        console.groupEnd();
        
        // Start with menu scene
        this.engine.switchScene('menu');
        this.updateNavButtons('menu');
        
        // Start the engine
        this.engine.start();
        
        console.log('🎯 Game started successfully with PixiJS!');
    }
    
    stop() {
        this.engine.stop();
        console.log('🛑 Game stopped');
    }
    
    destroy() {
        this.engine.destroy();
        this.inputManager.destroy();
        console.log('🧹 Game destroyed and cleaned up');
    }
}

// Initialize game when page loads
window.addEventListener('load', () => {
    const game = new TacticalRPG();
    game.start();
    
    // Make game globally available for debugging
    window.game = game;
    window.PIXI = PIXI; // For console debugging
    
    console.log('🎮 Game instance available as window.game');
    console.log('🎨 PixiJS available as window.PIXI');
});

// Handle page visibility changes
document.addEventListener('visibilitychange', () => {
    if (window.game) {
        if (document.hidden) {
            window.game.stop();
            console.log('⏸️ Game paused (tab hidden)');
        } else {
            window.game.engine.start();
            console.log('▶️ Game resumed (tab visible)');
        }
    }
});

// Handle page unload
window.addEventListener('beforeunload', () => {
    if (window.game) {
        window.game.destroy();
        console.log('🧹 Game cleaned up before page unload');
    }
});

// Export for potential module usage
export { TacticalRPG };