import { Scene } from '../core/Scene.js';
import { Grid } from '../models/Grid.js';
import { GameData } from '../data/GameData.js';

export class InventoryScene extends Scene {
    constructor() {
        super();
        this.inventoryGrid = new Grid(50, 100, 10, 8, 40);
        this.storageGrid = new Grid(650, 100, 8, 6, 40);
        this.draggedItem = null;
        this.dragStartGrid = null;
        this.setupItems();
    }
    
    setupItems() {
        const items = GameData.createSampleItems();
        
        // Place items in storage with better organization
        const placements = [
            { item: 0, x: 0, y: 0 }, // Sword
            { item: 1, x: 2, y: 0 }, // Staff
            { item: 2, x: 4, y: 0 }, // Shield
            { item: 3, x: 0, y: 3 }, // Fire Gem
            { item: 4, x: 1, y: 3 }, // Dual Cast
            { item: 5, x: 2, y: 3 }, // Potion
            { item: 6, x: 6, y: 0 }, // Bow
            { item: 7, x: 0, y: 4 }, // Armor
            { item: 8, x: 3, y: 3 }, // Ice Gem
            { item: 9, x: 4, y: 3 }  // Lightning Rod
        ];
        
        placements.forEach(placement => {
            if (items[placement.item]) {
                this.storageGrid.placeItem(items[placement.item], placement.x, placement.y);
            }
        });
    }
    
    onEnter() {
        super.onEnter();
        
        // Set up input handlers
        this.engine.inputManager.onKeyPress('KeyR', () => this.resetItems());
        this.engine.inputManager.onKeyPress('KeyM', () => this.engine.switchScene('menu'));
        this.engine.inputManager.onKeyPress('KeyB', () => this.engine.switchScene('battle'));
        this.engine.inputManager.onKeyPress('Escape', () => this.engine.switchScene('menu'));
        this.engine.inputManager.onKeyPress('KeyC', () => this.clearInventory());
        this.engine.inputManager.onKeyPress('KeyS', () => this.saveInventoryState());
    }
    
    resetItems() {
        this.inventoryGrid.clear();
        this.storageGrid.clear();
        this.setupItems();
    }
    
    clearInventory() {
        // Move all items from inventory back to storage
        const inventoryItems = [...this.inventoryGrid.items];
        inventoryItems.forEach(item => {
            this.inventoryGrid.removeItem(item);
            // Try to place back in storage
            this.autoPlaceInStorage(item);
        });
    }
    
    autoPlaceInStorage(item) {
        // Find first available spot in storage
        for (let y = 0; y <= this.storageGrid.rows - item.height; y++) {
            for (let x = 0; x <= this.storageGrid.cols - item.width; x++) {
                if (item.canPlaceAt(this.storageGrid, x, y)) {
                    this.storageGrid.placeItem(item, x, y);
                    return true;
                }
            }
        }
        return false;
    }
    
    saveInventoryState() {
        // TODO: Implement save system
        console.log('Inventory state saved!');
    }
    
    update(deltaTime) {
        const input = this.engine.inputManager;
        const mouse = input.getMousePosition();
        
        // Handle mouse interactions
        this.updateItemHighlights(mouse);
        
        if (input.isMouseClicked()) {
            this.handleMouseDown(mouse);
        }
        
        if (!input.isMousePressed() && this.draggedItem) {
            this.handleMouseUp(mouse);
        }
    }
    
    updateItemHighlights(mouse) {
        // Clear all highlights
        [...this.inventoryGrid.items, ...this.storageGrid.items].forEach(item => {
            item.isHighlighted = false;
        });
        
        // Find hovered item
        let hoveredItem = this.inventoryGrid.getItemAt(mouse.x, mouse.y) || 
                         this.storageGrid.getItemAt(mouse.x, mouse.y);
        
        if (hoveredItem && !hoveredItem.dragging) {
            hoveredItem.isHighlighted = true;
            
            // Highlight adjacent items
            const grid = this.inventoryGrid.items.includes(hoveredItem) ? 
                        this.inventoryGrid : this.storageGrid;
            grid.getAdjacentItems(hoveredItem).forEach(item => {
                item.isHighlighted = true;
            });
        }
    }
    
    handleMouseDown(mouse) {
        // Check inventory first
        let clickedItem = this.inventoryGrid.getItemAt(mouse.x, mouse.y);
        let sourceGrid = this.inventoryGrid;
        
        // Then check storage
        if (!clickedItem) {
            clickedItem = this.storageGrid.getItemAt(mouse.x, mouse.y);
            sourceGrid = this.storageGrid;
        }
        
        if (clickedItem) {
            this.startDragging(clickedItem, sourceGrid, mouse);
        }
    }
    
    startDragging(item, sourceGrid, mouse) {
        this.draggedItem = item;
        this.dragStartGrid = sourceGrid;
        
        // Store original position
        item.originalGridX = item.gridX;
        item.originalGridY = item.gridY;
        
        // Calculate drag offset
        const itemScreenX = sourceGrid.x + item.gridX * sourceGrid.cellSize;
        const itemScreenY = sourceGrid.y + item.gridY * sourceGrid.cellSize;
        
        item.dragOffsetX = mouse.x - itemScreenX;
        item.dragOffsetY = mouse.y - itemScreenY;
        item.dragging = true;
        
        // Remove from grid temporarily
        sourceGrid.clearItemFromCells(item);
    }
    
    handleMouseUp(mouse) {
        if (!this.draggedItem) return;
        
        let placed = false;
        let targetGrid = null;
        
        // Try inventory first
        const invPos = this.inventoryGrid.getGridPosition(mouse.x, mouse.y);
        if (invPos && this.draggedItem.canPlaceAt(this.inventoryGrid, invPos.x, invPos.y)) {
            this.inventoryGrid.placeItem(this.draggedItem, invPos.x, invPos.y);
            targetGrid = this.inventoryGrid;
            placed = true;
        }
        
        // Try storage if inventory failed
        if (!placed) {
            const storPos = this.storageGrid.getGridPosition(mouse.x, mouse.y);
            if (storPos && this.draggedItem.canPlaceAt(this.storageGrid, storPos.x, storPos.y)) {
                this.storageGrid.placeItem(this.draggedItem, storPos.x, storPos.y);
                targetGrid = this.storageGrid;
                placed = true;
            }
        }
        
        if (placed) {
            // Successfully placed - remove from original grid if different
            if (targetGrid !== this.dragStartGrid) {
                const itemIndex = this.dragStartGrid.items.indexOf(this.draggedItem);
                if (itemIndex > -1) {
                    this.dragStartGrid.items.splice(itemIndex, 1);
                }
            }
        } else {
            // Return to original position
            this.dragStartGrid.placeItem(
                this.draggedItem, 
                this.draggedItem.originalGridX, 
                this.draggedItem.originalGridY
            );
        }
        
        // End dragging
        this.draggedItem.dragging = false;
        this.draggedItem = null;
        this.dragStartGrid = null;
    }
    
    render(ctx) {
        // Background
        ctx.fillStyle = '#27ae60';
        ctx.fillRect(0, 0, this.engine.width, this.engine.height);
        
        // Title
        ctx.fillStyle = '#ffffff';
        ctx.font = '24px Arial';
        ctx.textAlign = 'center';
        ctx.fillText('INVENTORY MANAGEMENT', this.engine.width / 2, 40);
        
        // Grid labels
        ctx.font = '16px Arial';
        ctx.textAlign = 'left';
        ctx.fillText('Character Inventory', this.inventoryGrid.x, this.inventoryGrid.y - 10);
        ctx.fillText('Item Storage', this.storageGrid.x, this.storageGrid.y - 10);
        
        // Instructions
        ctx.font = '14px Arial';
        ctx.fillText('Drag items | Hover for relationships | R: reset | C: clear inventory | M: menu | B: battle', 
                    50, this.engine.height - 30);
        
        // Render grids
        this.inventoryGrid.render(ctx);
        this.storageGrid.render(ctx);
        
        // Skills panel
        this.renderSkillsPanel(ctx);
        
        // Dragged item and preview
        if (this.draggedItem && this.draggedItem.dragging) {
            this.renderPlacementPreview(ctx);
            this.renderDraggedItem(ctx);
        }
        
        // Grid statistics
        this.renderGridStats(ctx);
    }
    
    renderSkillsPanel(ctx) {
        const panelX = 50;
        const panelY = 450;
        const panelWidth = 1100;
        const panelHeight = 280;
        
        // Panel background
        ctx.fillStyle = 'rgba(52, 73, 94, 0.9)';
        ctx.fillRect(panelX, panelY, panelWidth, panelHeight);
        ctx.strokeStyle = '#ecf0f1';
        ctx.lineWidth = 2;
        ctx.strokeRect(panelX, panelY, panelWidth, panelHeight);
        
        // Title
        ctx.fillStyle = '#ecf0f1';
        ctx.font = '18px Arial';
        ctx.textAlign = 'left';
        ctx.fillText('Available Skills (from Character Inventory)', panelX + 10, panelY + 25);
        
        const skills = this.inventoryGrid.generateSkills();
        
        if (skills.length === 0) {
            ctx.fillStyle = '#bdc3c7';
            ctx.font = '16px Arial';
            ctx.fillText('No skills available - place items in character inventory to generate skills', 
                        panelX + 20, panelY + 60);
            return;
        }
        
        // Render skills in a grid layout
        const skillWidth = 250;
        const skillHeight = 70;
        const skillSpacing = 15;
        const skillsPerRow = 4;
        
        skills.forEach((skill, index) => {
            const col = index % skillsPerRow;
            const row = Math.floor(index / skillsPerRow);
            const x = panelX + 20 + col * (skillWidth + skillSpacing);
            const y = panelY + 50 + row * (skillHeight + skillSpacing);
            
            // Skill background
            ctx.fillStyle = GameData.getSkillTypeColor(skill.type);
            ctx.fillRect(x, y, skillWidth, skillHeight);
            ctx.strokeStyle = '#2c3e50';
            ctx.lineWidth = 1;
            ctx.strokeRect(x, y, skillWidth, skillHeight);
            
            // Skill details
            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 14px Arial';
            ctx.textAlign = 'left';
            ctx.fillText(skill.name, x + 8, y + 18);
            
            ctx.font = '12px Arial';
            ctx.fillText(`Damage: ${skill.damage}`, x + 8, y + 35);
            ctx.fillText(`Cost: ${skill.cost} MP`, x + 8, y + 50);
            
            // Source items
            ctx.fillStyle = '#ecf0f1';
            ctx.font = '10px Arial';
            const sourceText = skill.getSourceItemNames();
            const maxLength = 28;
            const displayText = sourceText.length > maxLength ? 
                               sourceText.substring(0, maxLength) + '...' : sourceText;
            ctx.fillText(`From: ${displayText}`, x + 8, y + 65);
        });
    }
    
    renderDraggedItem(ctx) {
        const item = this.draggedItem;
        const mouse = this.engine.inputManager.getMousePosition();
        const x = mouse.x - item.dragOffsetX;
        const y = mouse.y - item.dragOffsetY;
        const w = item.width * 40;
        const h = item.height * 40;
        
        // Semi-transparent item
        ctx.fillStyle = item.color + '80';
        ctx.fillRect(x, y, w, h);
        ctx.strokeStyle = '#2c3e50';
        ctx.lineWidth = 2;
        ctx.strokeRect(x, y, w, h);
        
        // Item name
        ctx.fillStyle = '#ffffff';
        ctx.font = '12px Arial';
        ctx.textAlign = 'center';
        ctx.fillText(item.name, x + w / 2, y + h / 2 + 4);
    }
    
    renderPlacementPreview(ctx) {
        const mouse = this.engine.inputManager.getMousePosition();
        const item = this.draggedItem;
        
        [this.inventoryGrid, this.storageGrid].forEach(grid => {
            const pos = grid.getGridPosition(mouse.x, mouse.y);
            if (pos) {
                const canPlace = item.canPlaceAt(grid, pos.x, pos.y);
                const x = grid.x + pos.x * grid.cellSize;
                const y = grid.y + pos.y * grid.cellSize;
                const w = item.width * grid.cellSize;
                const h = item.height * grid.cellSize;
                
                ctx.fillStyle = canPlace ? 'rgba(46, 204, 113, 0.3)' : 'rgba(231, 76, 60, 0.3)';
                ctx.fillRect(x, y, w, h);
                ctx.strokeStyle = canPlace ? '#2ecc71' : '#e74c3c';
                ctx.lineWidth = 2;
                ctx.strokeRect(x, y, w, h);
            }
        });
    }
    
    renderGridStats(ctx) {
        ctx.fillStyle = '#ffffff';
        ctx.font = '12px Arial';
        ctx.textAlign = 'left';
        
        // Inventory stats
        const invItems = this.inventoryGrid.getItemCount();
        const invCapacity = this.inventoryGrid.cols * this.inventoryGrid.rows;
        ctx.fillText(`Items: ${invItems}`, this.inventoryGrid.x, this.inventoryGrid.y + this.inventoryGrid.height + 15);
        
        // Storage stats
        const storItems = this.storageGrid.getItemCount();
        const storCapacity = this.storageGrid.cols * this.storageGrid.rows;
        ctx.fillText(`Items: ${storItems}`, this.storageGrid.x, this.storageGrid.y + this.storageGrid.height + 15);
    }
}