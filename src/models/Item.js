export class Item {
    constructor(config) {
        // Keep your existing properties
        this.id = config.id;
        this.name = config.name;
        this.type = config.type;
        this.width = config.width;
        this.height = config.height;
        this.color = config.color || '#3498db';
        this.baseSkills = config.baseSkills || [];
        this.enhancements = config.enhancements || [];
        
        // PixiJS specific properties
        this.sprite = null;
        this.gridX = -1;
        this.gridY = -1;
        this.dragging = false;
        
        this.createSprite();
    }
    
    createSprite() {
        // Create PixiJS sprite (placeholder for now)
        this.sprite = new PIXI.Graphics();
        this.sprite.beginFill(parseInt(this.color.replace('#', '0x')));
        this.sprite.drawRect(0, 0, this.width * 40, this.height * 40);
        this.sprite.endFill();
        
        // Add glow effect for gems
        if (this.type === 'gem') {
            const glow = new PIXI.filters.GlowFilter({
                color: parseInt(this.color.replace('#', '0x')),
                distance: 10,
                outerStrength: 0.5
            });
            this.sprite.filters = [glow];
        }
        
        // Make interactive
        this.sprite.interactive = true;
        this.sprite.cursor = 'pointer';
    }
    
    setEngine(engine) {
        this.engine = engine;
    }
    
    onEnter() {
        this.engine.app.stage.addChild(this.container);
    }
    
    onExit() {
        this.engine.app.stage.removeChild(this.container);
    }
    
    update(deltaTime) {
        // Override in subclasses
    }
    
    addSprite(sprite) {
        this.sprites.push(sprite);
        this.container.addChild(sprite);
    }
    
    removeSprite(sprite) {
        const index = this.sprites.indexOf(sprite);
        if (index > -1) {
            this.sprites.splice(index, 1);
            this.container.removeChild(sprite);
        }
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