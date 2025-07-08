import { PixiScene } from '../core/PixiScene.js';
import { GameData } from '../data/GameData.js';

export class PixiInventoryScene extends PixiScene {
    constructor() {
        super();
        this.inventoryGrid = null;
        this.storageGrid = null;
        this.draggedItem = null;
        
        this.setupGrids();
        this.setupItems();
    }
    
    setupGrids() {
        // Create visual grids using PixiJS
        this.inventoryGrid = this.createGrid(50, 100, 10, 8);
        this.storageGrid = this.createGrid(650, 100, 8, 6);
    }
    
    createGrid(x, y, cols, rows) {
        const grid = new PIXI.Graphics();
        const cellSize = 40;
        
        // Draw grid lines
        grid.lineStyle(1, 0xcccccc);
        for (let col = 0; col <= cols; col++) {
            grid.moveTo(col * cellSize, 0);
            grid.lineTo(col * cellSize, rows * cellSize);
        }
        for (let row = 0; row <= rows; row++) {
            grid.moveTo(0, row * cellSize);
            grid.lineTo(cols * cellSize, row * cellSize);
        }
        
        grid.x = x;
        grid.y = y;
        this.container.addChild(grid);
        
        return {
            x, y, cols, rows, cellSize,
            items: [],
            graphics: grid
        };
    }
    
    setupItems() {
        const items = GameData.createSampleItems();
        // Place items in storage grid with PixiJS positioning
        items.forEach((item, index) => {
            const col = index % this.storageGrid.cols;
            const row = Math.floor(index / this.storageGrid.cols);
            this.placeItemInGrid(item, this.storageGrid, col, row);
        });
    }
    
    placeItemInGrid(item, grid, col, row) {
        item.sprite.x = grid.x + col * grid.cellSize;
        item.sprite.y = grid.y + row * grid.cellSize;
        grid.items.push(item);
        this.container.addChild(item.sprite);
        
        // Add drag functionality
        this.setupItemDragging(item);
    }
    
    setupItemDragging(item) {
        item.sprite.on('pointerdown', (event) => {
            this.startDragging(item, event);
        });
    }
    
    startDragging(item, event) {
        this.draggedItem = item;
        item.dragging = true;
        
        // Move to top layer
        this.container.removeChild(item.sprite);
        this.container.addChild(item.sprite);
        
        // Follow mouse
        const onMove = (event) => {
            if (item.dragging) {
                item.sprite.x = event.global.x - item.width * 20;
                item.sprite.y = event.global.y - item.height * 20;
            }
        };
        
        const onEnd = () => {
            this.stopDragging(item);
            this.engine.app.stage.off('pointermove', onMove);
            this.engine.app.stage.off('pointerup', onEnd);
        };
        
        this.engine.app.stage.on('pointermove', onMove);
        this.engine.app.stage.on('pointerup', onEnd);
    }
    
    stopDragging(item) {
        item.dragging = false;
        
        // Snap to grid logic here
        // (You can reuse your existing grid snapping logic)
        
        this.draggedItem = null;
    }
    
    update(deltaTime) {
        // Update animations, effects, etc.
    }
}