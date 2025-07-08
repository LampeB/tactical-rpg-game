import { PixiScene } from '../core/PixiScene.js';

export class PixiInventoryScene extends PixiScene {
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
        
        // ADD THIS - Update navigation buttons
        if (this.engine && this.engine.updateNavButtons) {
            this.engine.updateNavButtons('inventory');
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
        // Sample items data with skills and enhancements
        const itemsData = [
            { 
                name: 'Sword', 
                color: 0xe74c3c, 
                width: 1, 
                height: 3, 
                x: 0, 
                y: 0,
                type: 'weapon',
                baseSkills: [{
                    name: 'Slash',
                    description: 'Basic sword strike',
                    damage: 25,
                    cost: 0,
                    type: 'physical'
                }]
            },
            { 
                name: 'Shield', 
                color: 0x34495e, 
                width: 2, 
                height: 2, 
                x: 2, 
                y: 0,
                type: 'armor',
                baseSkills: [{
                    name: 'Block',
                    description: 'Defensive stance',
                    damage: 0,
                    cost: 2,
                    type: 'defensive'
                }],
                enhancements: [{
                    targetTypes: ['physical'],
                    nameModifier: (name) => `Defensive ${name}`,
                    descriptionModifier: (desc) => desc + ' with shield protection',
                    damageBonus: 8
                }]
            },
            { 
                name: 'Fire Gem', 
                color: 0xe67e22, 
                width: 1, 
                height: 1, 
                x: 0, 
                y: 3,
                type: 'gem',
                enhancements: [{
                    targetTypes: ['physical'],
                    nameModifier: (name) => name.replace('Slash', 'Flaming Strike'),
                    descriptionModifier: (desc) => desc.replace('Basic sword strike', 'Blazing sword attack with fire damage'),
                    damageMultiplier: 1.6,
                    costModifier: 2
                }, {
                    targetTypes: ['magic'],
                    nameModifier: (name) => name.replace('Fireball', 'Fire Blast'),
                    descriptionModifier: (desc) => desc + ' (enhanced by fire gem)',
                    damageMultiplier: 1.5
                }]
            },
            { 
                name: 'Potion', 
                color: 0x27ae60, 
                width: 1, 
                height: 1, 
                x: 1, 
                y: 3,
                type: 'consumable',
                baseSkills: [{
                    name: 'Heal',
                    description: 'Restore health',
                    damage: -25,
                    cost: 0,
                    type: 'healing'
                }]
            },
            { 
                name: 'Staff', 
                color: 0x9b59b6, 
                width: 1, 
                height: 2, 
                x: 4, 
                y: 0,
                type: 'weapon',
                baseSkills: [{
                    name: 'Fireball',
                    description: 'Launch a fireball',
                    damage: 30,
                    cost: 8,
                    type: 'magic'
                }]
            }
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
        
        // Simple highlight effect for gems
        if (data.name.includes('Gem')) {
            const highlight = new PIXI.Graphics();
            highlight.lineStyle(2, 0xffd700, 0.8);
            highlight.drawRect(0, 0, data.width * this.gridCellSize - 4, data.height * this.gridCellSize - 4);
            item.addChild(highlight);
            
            let time = 0;
            const animate = () => {
                time += 0.05;
                highlight.alpha = 0.3 + Math.sin(time) * 0.3;
                requestAnimationFrame(animate);
            };
            animate();
        }
        
        // Store item data with proper structure
        item.itemData = data;
        item.gridX = -1;
        item.gridY = -1;
        
        // Add inventory item properties
        item.name = data.name;
        item.type = data.type;
        item.width = data.width;
        item.height = data.height;
        item.color = data.color;
        item.baseSkills = data.baseSkills || [];
        item.enhancements = data.enhancements || [];
        
        // Add methods for skill generation
        item.isPlaced = function() {
            return this.gridX >= 0 && this.gridY >= 0;
        };
        
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