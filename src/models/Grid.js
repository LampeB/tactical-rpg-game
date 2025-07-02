import { Skill } from './Skill.js';

export class Grid {
    constructor(x, y, cols, rows, cellSize) {
        this.x = x;
        this.y = y;
        this.cols = cols;
        this.rows = rows;
        this.cellSize = cellSize;
        this.width = cols * cellSize;
        this.height = rows * cellSize;
        
        // 2D array to track what's in each cell
        this.cells = Array(rows).fill().map(() => Array(cols).fill(null));
        
        // Array of items in this grid
        this.items = [];
    }
    
    // Item Management
    addItem(item) {
        if (!this.items.includes(item)) {
            this.items.push(item);
        }
    }
    
    removeItem(item) {
        this.clearItemFromCells(item);
        this.items = this.items.filter(i => i !== item);
        item.gridX = -1;
        item.gridY = -1;
    }
    
    clearItemFromCells(item) {
        for (let row = 0; row < this.rows; row++) {
            for (let col = 0; col < this.cols; col++) {
                if (this.cells[row][col] === item) {
                    this.cells[row][col] = null;
                }
            }
        }
    }
    
    placeItem(item, gridX, gridY) {
        if (!item.canPlaceAt(this, gridX, gridY)) {
            return false;
        }
        
        // Clear item from previous position
        this.clearItemFromCells(item);
        
        // Place item in new position
        for (let dy = 0; dy < item.height; dy++) {
            for (let dx = 0; dx < item.width; dx++) {
                this.cells[gridY + dy][gridX + dx] = item;
            }
        }
        
        item.gridX = gridX;
        item.gridY = gridY;
        this.addItem(item);
        return true;
    }
    
    // Position Utilities
    getGridPosition(mouseX, mouseY) {
        if (mouseX < this.x || mouseY < this.y || 
            mouseX >= this.x + this.width || mouseY >= this.y + this.height) {
            return null;
        }
        
        return {
            x: Math.floor((mouseX - this.x) / this.cellSize),
            y: Math.floor((mouseY - this.y) / this.cellSize)
        };
    }
    
    getItemAt(mouseX, mouseY) {
        const gridPos = this.getGridPosition(mouseX, mouseY);
        if (!gridPos || gridPos.y >= this.rows || gridPos.x >= this.cols) {
            return null;
        }
        return this.cells[gridPos.y][gridPos.x];
    }
    
    isPositionValid(x, y) {
        return x >= 0 && x < this.cols && y >= 0 && y < this.rows;
    }
    
    // Spatial Relationship Analysis
    getAdjacentItems(item) {
        if (!item.isPlaced()) return [];
        
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
                    
                    if (this.isPositionValid(checkX, checkY)) {
                        const adjacentItem = this.cells[checkY][checkX];
                        if (adjacentItem && adjacentItem !== item && !adjacent.includes(adjacentItem)) {
                            adjacent.push(adjacentItem);
                        }
                    }
                }
            }
        }
        
        return adjacent;
    }
    
    // Skill Generation System
    generateSkills() {
        const skills = [];
        const processedItems = new Set();
        
        // Process each item for base skills and enhancements
        for (const item of this.items) {
            if (processedItems.has(item)) continue;
            
            // Generate skills from this item's base skills
            for (const baseSkillData of item.baseSkills) {
                const skill = new Skill(
                    baseSkillData.name,
                    baseSkillData.description,
                    baseSkillData.damage,
                    baseSkillData.cost,
                    baseSkillData.type
                );
                
                skill.addSourceItem(item);
                
                // Apply enhancements from adjacent items
                const adjacentItems = this.getAdjacentItems(item);
                let enhancedSkillData = { ...baseSkillData };
                
                for (const adjItem of adjacentItems) {
                    for (const enhancement of adjItem.enhancements) {
                        if (this.canEnhance(enhancement, baseSkillData)) {
                            enhancedSkillData = this.applyEnhancement(enhancedSkillData, enhancement);
                            skill.addSourceItem(adjItem);
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
            
            processedItems.add(item);
        }
        
        return skills;
    }
    
    canEnhance(enhancement, baseSkill) {
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
    
    applyEnhancement(skillData, enhancement) {
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
            enhanced.cost = Math.max(1, enhanced.cost + enhancement.costModifier);
        }
        
        // Apply description modification
        if (enhancement.descriptionModifier) {
            enhanced.description = enhancement.descriptionModifier(enhanced.description);
        }
        
        return enhanced;
    }
    
    // Rendering
    render(ctx) {
        this.renderBackground(ctx);
        this.renderGridLines(ctx);
        this.renderItems(ctx);
    }
    
    renderBackground(ctx) {
        ctx.fillStyle = '#ecf0f1';
        ctx.fillRect(this.x, this.y, this.width, this.height);
    }
    
    renderGridLines(ctx) {
        ctx.strokeStyle = '#bdc3c7';
        ctx.lineWidth = 1;
        
        // Horizontal lines
        for (let row = 0; row <= this.rows; row++) {
            const y = this.y + row * this.cellSize;
            ctx.beginPath();
            ctx.moveTo(this.x, y);
            ctx.lineTo(this.x + this.width, y);
            ctx.stroke();
        }
        
        // Vertical lines
        for (let col = 0; col <= this.cols; col++) {
            const x = this.x + col * this.cellSize;
            ctx.beginPath();
            ctx.moveTo(x, this.y);
            ctx.lineTo(x, this.y + this.height);
            ctx.stroke();
        }
    }
    
    renderItems(ctx) {
        this.items.forEach(item => {
            if (item.isPlaced() && !item.dragging) {
                this.renderItem(ctx, item);
            }
        });
    }
    
    renderItem(ctx, item) {
        const x = this.x + item.gridX * this.cellSize;
        const y = this.y + item.gridY * this.cellSize;
        const w = item.width * this.cellSize;
        const h = item.height * this.cellSize;
        
        // Item background (highlight if needed)
        ctx.fillStyle = item.isHighlighted ? this.brightenColor(item.color) : item.color;
        ctx.fillRect(x + 2, y + 2, w - 4, h - 4);
        
        // Item border (thicker if highlighted)
        ctx.strokeStyle = item.isHighlighted ? '#f39c12' : '#2c3e50';
        ctx.lineWidth = item.isHighlighted ? 3 : 2;
        ctx.strokeRect(x + 2, y + 2, w - 4, h - 4);
        
        // Item name
        ctx.fillStyle = '#ffffff';
        ctx.font = '12px Arial';
        ctx.textAlign = 'center';
        ctx.fillText(item.name, x + w / 2, y + h / 2 + 4);
        
        // Enhancement indicator
        if (item.enhancements.length > 0) {
            ctx.fillStyle = '#f39c12';
            ctx.font = '10px Arial';
            ctx.fillText('✦', x + w - 8, y + 12);
        }
    }
    
    brightenColor(color) {
        const colorMap = {
            '#e74c3c': '#ff6b5a', '#9b59b6': '#b574d3', '#34495e': '#4a6377',
            '#e67e22': '#ff9639', '#f39c12': '#ffb32e', '#27ae60': '#2ecc71',
            '#16a085': '#1abc9c', '#7f8c8d': '#95a5a6'
        };
        return colorMap[color] || color;
    }
    
    // Utility Methods
    clear() {
        this.items.forEach(item => this.removeItem(item));
    }
    
    getItemCount() {
        return this.items.length;
    }
    
    hasSpace(item) {
        // Check if there's any space for this item
        for (let y = 0; y <= this.rows - item.height; y++) {
            for (let x = 0; x <= this.cols - item.width; x++) {
                if (item.canPlaceAt(this, x, y)) {
                    return true;
                }
            }
        }
        return false;
    }
}