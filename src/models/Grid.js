import { Skill } from './Skill.js';
import { COLORS, FONTS, LAYOUT } from '../utils/Constants.js';

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
        const pos = this.getGridPosition(mouseX, mouseY);
        if (!pos) return null;
        
        return this.cells[pos.y][pos.x];
    }
    
    // Skill Enhancement Methods
    static applyEnhancement(skillData, enhancement) {
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
        ctx.fillStyle = COLORS.HEX.LIGHT_GRAY;
        ctx.fillRect(this.x, this.y, this.width, this.height);
    }
    
    renderGridLines(ctx) {
        ctx.strokeStyle = COLORS.HEX.MEDIUM_GRAY;
        ctx.lineWidth = LAYOUT.THIN_BORDER;
        
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
        ctx.fillRect(
            x + LAYOUT.SMALL_SPACING / 2, 
            y + LAYOUT.SMALL_SPACING / 2, 
            w - LAYOUT.SMALL_SPACING, 
            h - LAYOUT.SMALL_SPACING
        );
        
        // Item border (thicker if highlighted)
        ctx.strokeStyle = item.isHighlighted ? COLORS.HEX.YELLOW : COLORS.HEX.DARK_GRAY;
        ctx.lineWidth = item.isHighlighted ? LAYOUT.HIGHLIGHT_BORDER : LAYOUT.MEDIUM_BORDER;
        ctx.strokeRect(
            x + LAYOUT.SMALL_SPACING / 2, 
            y + LAYOUT.SMALL_SPACING / 2, 
            w - LAYOUT.SMALL_SPACING, 
            h - LAYOUT.SMALL_SPACING
        );
        
        // Item name
        ctx.fillStyle = COLORS.HEX.WHITE;
        ctx.font = `${FONTS.SIZE.BODY}px ${FONTS.FAMILY.PRIMARY}`;
        ctx.textAlign = FONTS.ALIGN.CENTER;
        ctx.fillText(item.name, x + w / 2, y + h / 2 + LAYOUT.SMALL_SPACING);
        
        // Enhancement indicator
        if (item.enhancements.length > 0) {
            ctx.fillStyle = COLORS.HEX.YELLOW;
            ctx.font = `${FONTS.SIZE.SMALL}px ${FONTS.FAMILY.PRIMARY}`;
            ctx.fillText('✦', x + w - LAYOUT.MEDIUM_SPACING, y + FONTS.SIZE.BODY);
        }
    }
    
    brightenColor(color) {
        // Use the brightened color mappings from constants
        const colorMap = {
            [COLORS.HEX.RED]: COLORS.HEX.BRIGHT_RED,
            [COLORS.HEX.PURPLE]: COLORS.HEX.BRIGHT_PURPLE,
            [COLORS.HEX.DARK_BLUE]: COLORS.HEX.BRIGHT_DARK_BLUE,
            [COLORS.HEX.ORANGE]: COLORS.HEX.BRIGHT_ORANGE,
            [COLORS.HEX.YELLOW]: COLORS.HEX.BRIGHT_YELLOW,
            [COLORS.HEX.GREEN]: COLORS.HEX.BRIGHT_GREEN,
            [COLORS.HEX.TEAL]: COLORS.HEX.BRIGHT_TEAL,
            [COLORS.HEX.GRAY]: COLORS.HEX.BRIGHT_GRAY,
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