export class Item {
    constructor(config) {
        this.id = config.id;
        this.name = config.name;
        this.type = config.type; // weapon, gem, armor, consumable
        this.width = config.width; // in grid cells
        this.height = config.height; // in grid cells
        this.color = config.color || '#3498db';
        this.baseSkills = config.baseSkills || []; // Skills this item provides
        this.enhancements = config.enhancements || []; // How this item modifies other skills
        
        // Position and state
        this.gridX = -1;
        this.gridY = -1;
        this.dragging = false;
        this.dragOffsetX = 0;
        this.dragOffsetY = 0;
        this.isHighlighted = false;
        this.originalGridX = -1;
        this.originalGridY = -1;
    }
    
    canPlaceAt(grid, x, y) {
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
    }
    
    isPlaced() {
        return this.gridX >= 0 && this.gridY >= 0;
    }
    
    getGridCells() {
        const cells = [];
        for (let dy = 0; dy < this.height; dy++) {
            for (let dx = 0; dx < this.width; dx++) {
                cells.push({ x: this.gridX + dx, y: this.gridY + dy });
            }
        }
        return cells;
    }
    
    clone() {
        return new Item({
            id: this.id,
            name: this.name,
            type: this.type,
            width: this.width,
            height: this.height,
            color: this.color,
            baseSkills: [...this.baseSkills],
            enhancements: [...this.enhancements]
        });
    }
}