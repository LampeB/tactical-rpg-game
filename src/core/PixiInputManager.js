export class PixiInputManager {
    constructor() {
        this.keys = {};
        this.mouse = {
            x: 0,
            y: 0,
            clicked: false,
            pressed: false,
            button: 0
        };
        
        this.keyCallbacks = new Map();
        this.pixiApp = null;
        
        this.setupEventListeners();
    }
    
    setPixiApp(app) {
        this.pixiApp = app;
        console.log('Input manager connected to PixiJS app');
    }
    
    setupEventListeners() {
        // Global keyboard events
        document.addEventListener('keydown', (e) => {
            if (!this.keys[e.code]) {
                this.keys[e.code] = true;
                this.triggerKeyCallback(e.code);
            }
        });
        
        document.addEventListener('keyup', (e) => {
            this.keys[e.code] = false;
        });
        
        // Prevent default for game keys
        document.addEventListener('keydown', (e) => {
            if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) {
                e.preventDefault();
            }
        });
    }
    
    onKeyPress(keyCode, callback) {
        if (!this.keyCallbacks.has(keyCode)) {
            this.keyCallbacks.set(keyCode, []);
        }
        this.keyCallbacks.get(keyCode).push(callback);
    }
    
    clearCallbacks() {
        this.keyCallbacks.clear();
    }
    
    triggerKeyCallback(keyCode) {
        if (this.keyCallbacks.has(keyCode)) {
            this.keyCallbacks.get(keyCode).forEach(callback => callback());
        }
    }
    
    update() {
        // Mouse position updates are handled by PixiScene
        // This method can be used for other input updates
    }
    
    lateUpdate() {
        // Reset click state after frame
        this.mouse.clicked = false;
    }
    
    // Utility methods
    isKeyPressed(keyCode) {
        return this.keys[keyCode] || false;
    }
    
    getMousePosition() {
        return { x: this.mouse.x, y: this.mouse.y };
    }
    
    isMouseClicked() {
        return this.mouse.clicked;
    }
    
    isMousePressed() {
        return this.mouse.pressed;
    }
    
    // Movement helper
    getMovementVector() {
        const movement = { x: 0, y: 0 };
        
        if (this.isKeyPressed('KeyW') || this.isKeyPressed('ArrowUp')) {
            movement.y -= 1;
        }
        if (this.isKeyPressed('KeyS') || this.isKeyPressed('ArrowDown')) {
            movement.y += 1;
        }
        if (this.isKeyPressed('KeyA') || this.isKeyPressed('ArrowLeft')) {
            movement.x -= 1;
        }
        if (this.isKeyPressed('KeyD') || this.isKeyPressed('ArrowRight')) {
            movement.x += 1;
        }
        
        // Normalize diagonal movement
        if (movement.x !== 0 && movement.y !== 0) {
            const length = Math.sqrt(movement.x * movement.x + movement.y * movement.y);
            movement.x /= length;
            movement.y /= length;
        }
        
        return movement;
    }
    
    // Cleanup
    destroy() {
        this.clearCallbacks();
        
        document.removeEventListener('keydown', this.onKeyDown);
        document.removeEventListener('keyup', this.onKeyUp);
        
        console.log('Input manager destroyed');
    }
}