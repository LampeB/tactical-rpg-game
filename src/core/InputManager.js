export class InputManager {
    constructor(canvas) {
        this.canvas = canvas;
        this.mouse = {
            x: 0,
            y: 0,
            clicked: false,
            pressed: false,
            lastPressed: false
        };
        
        this.keys = {};
        this.keyCallbacks = new Map();
        
        this.setupEventListeners();
    }
    
    setupEventListeners() {
        // Mouse events
        this.canvas.addEventListener('mousemove', (e) => {
            const rect = this.canvas.getBoundingClientRect();
            this.mouse.x = e.clientX - rect.left;
            this.mouse.y = e.clientY - rect.top;
            document.getElementById('mousePos').textContent = 
                `${Math.floor(this.mouse.x)}, ${Math.floor(this.mouse.y)}`;
        });
        
        this.canvas.addEventListener('mousedown', (e) => {
            this.mouse.lastPressed = this.mouse.pressed;
            this.mouse.pressed = true;
            this.mouse.clicked = true;
        });
        
        this.canvas.addEventListener('mouseup', (e) => {
            this.mouse.pressed = false;
        });
        
        // Keyboard events
        document.addEventListener('keydown', (e) => {
            if (!this.keys[e.code]) {
                this.keys[e.code] = true;
                this.triggerKeyCallback(e.code);
            }
        });
        
        document.addEventListener('keyup', (e) => {
            this.keys[e.code] = false;
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
        // Reset click state
        this.mouse.clicked = false;
    }
    
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
}