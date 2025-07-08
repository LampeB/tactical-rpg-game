export class PixiScene {
    constructor() {
        this.engine = null;
        this.container = new PIXI.Container();
        this.sprites = [];
        this.graphics = [];
        this.isActive = false;
        
        // Layer management
        this.layers = {
            background: new PIXI.Container(),
            world: new PIXI.Container(),
            ui: new PIXI.Container(),
            effects: new PIXI.Container()
        };
        
        // Add layers to main container
        this.container.addChild(this.layers.background);
        this.container.addChild(this.layers.world);
        this.container.addChild(this.layers.ui);
        this.container.addChild(this.layers.effects);
        
        // Input handling
        this.keys = {};
        this.mousePosition = { x: 0, y: 0 };
        this.mouseClicked = false;
    }
    
    setEngine(engine) {
        this.engine = engine;
    }
    
    onEnter() {
        this.isActive = true;
        
        // Add this scene's container to the stage
        if (this.engine && this.engine.app) {
            this.engine.app.stage.addChild(this.container);
        }
        
        // Setup input handlers
        this.setupInputHandlers();
        
        console.log(`Scene entered: ${this.constructor.name}`);
    }
    
    onExit() {
        this.isActive = false;
        
        // Remove from stage
        if (this.engine && this.engine.app && this.container.parent) {
            this.engine.app.stage.removeChild(this.container);
        }
        
        // Clean up input handlers
        this.cleanupInputHandlers();
        
        console.log(`Scene exited: ${this.constructor.name}`);
    }
    
    update(deltaTime) {
        if (!this.isActive) return;
        
        // Update all sprites
        this.sprites.forEach(sprite => {
            if (sprite.update && typeof sprite.update === 'function') {
                sprite.update(deltaTime);
            }
        });
        
        // Override in subclasses for scene-specific logic
    }
    
    setupInputHandlers() {
        if (!this.engine || !this.engine.app) return;
        
        // Mouse/touch events
        this.container.on('pointerdown', (event) => this.onPointerDown(event));
        this.container.on('pointerup', (event) => this.onPointerUp(event));
        this.container.on('pointermove', (event) => this.onPointerMove(event));
        
        // Keyboard events
        document.addEventListener('keydown', this.onKeyDown.bind(this));
        document.addEventListener('keyup', this.onKeyUp.bind(this));
        
        // Make container interactive
        this.container.interactive = true;
        this.container.hitArea = this.engine.app.screen;
    }
    
    cleanupInputHandlers() {
        if (this.container) {
            this.container.off('pointerdown');
            this.container.off('pointerup');
            this.container.off('pointermove');
            this.container.interactive = false;
        }
        
        document.removeEventListener('keydown', this.onKeyDown.bind(this));
        document.removeEventListener('keyup', this.onKeyUp.bind(this));
    }
    
    // Input event handlers
    onPointerDown(event) {
        this.mousePosition.x = event.global.x;
        this.mousePosition.y = event.global.y;
        this.mouseClicked = true;
        
        // Override in subclasses
        this.handleMouseDown(event);
    }
    
    onPointerUp(event) {
        this.mousePosition.x = event.global.x;
        this.mousePosition.y = event.global.y;
        
        // Override in subclasses
        this.handleMouseUp(event);
    }
    
    onPointerMove(event) {
        this.mousePosition.x = event.global.x;
        this.mousePosition.y = event.global.y;
        
        // Update UI mouse position display
        const mousePosElement = document.getElementById('mousePos');
        if (mousePosElement) {
            mousePosElement.textContent = `${Math.floor(this.mousePosition.x)}, ${Math.floor(this.mousePosition.y)}`;
        }
        
        // Override in subclasses
        this.handleMouseMove(event);
    }
    
    onKeyDown(event) {
        this.keys[event.code] = true;
        
        // Override in subclasses
        this.handleKeyDown(event);
    }
    
    onKeyUp(event) {
        this.keys[event.code] = false;
        
        // Override in subclasses
        this.handleKeyUp(event);
    }
    
    // Override these in subclasses
    handleMouseDown(event) {}
    handleMouseUp(event) {}
    handleMouseMove(event) {}
    handleKeyDown(event) {}
    handleKeyUp(event) {}
    
    // Sprite management
    addSprite(sprite, layer = 'world') {
        this.sprites.push(sprite);
        
        if (this.layers[layer]) {
            this.layers[layer].addChild(sprite);
        } else {
            this.container.addChild(sprite);
        }
        
        return sprite;
    }
    
    removeSprite(sprite) {
        const index = this.sprites.indexOf(sprite);
        if (index > -1) {
            this.sprites.splice(index, 1);
        }
        
        if (sprite.parent) {
            sprite.parent.removeChild(sprite);
        }
    }
    
    // Graphics management
    addGraphics(graphics, layer = 'world') {
        this.graphics.push(graphics);
        
        if (this.layers[layer]) {
            this.layers[layer].addChild(graphics);
        } else {
            this.container.addChild(graphics);
        }
        
        return graphics;
    }
    
    removeGraphics(graphics) {
        const index = this.graphics.indexOf(graphics);
        if (index > -1) {
            this.graphics.splice(index, 1);
        }
        
        if (graphics.parent) {
            graphics.parent.removeChild(graphics);
        }
    }
    
    // Utility methods
    createSimpleButton(text, x, y, onClick) {
        const button = new PIXI.Graphics();
        button.beginFill(0x3498db);
        button.drawRoundedRect(0, 0, 120, 40, 5);
        button.endFill();
        
        const buttonText = new PIXI.Text(text, {
            fontFamily: 'Arial',
            fontSize: 14,
            fill: 0xffffff,
            align: 'center'
        });
        
        buttonText.anchor.set(0.5);
        buttonText.x = 60;
        buttonText.y = 20;
        
        button.addChild(buttonText);
        button.x = x;
        button.y = y;
        button.interactive = true;
        button.cursor = 'pointer';
        
        button.on('pointerdown', onClick);
        
        return button;
    }
    
    // Camera/view management
    setCameraPosition(x, y) {
        this.layers.world.x = -x;
        this.layers.world.y = -y;
    }
    
    getCameraPosition() {
        return {
            x: -this.layers.world.x,
            y: -this.layers.world.y
        };
    }
    
    // Cleanup
    destroy() {
        this.onExit();
        
        // Clean up sprites
        this.sprites.forEach(sprite => {
            if (sprite.destroy) {
                sprite.destroy();
            }
        });
        this.sprites = [];
        
        // Clean up graphics
        this.graphics.forEach(graphics => {
            if (graphics.destroy) {
                graphics.destroy();
            }
        });
        this.graphics = [];
        
        // Clean up container
        if (this.container) {
            this.container.destroy({ children: true });
        }
        
        console.log(`Scene destroyed: ${this.constructor.name}`);
    }
}