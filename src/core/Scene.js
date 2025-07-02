export class Scene {
    constructor() {
        this.engine = null;
    }
    
    setEngine(engine) {
        this.engine = engine;
    }
    
    onEnter() {
        // Clear previous input callbacks
        if (this.engine && this.engine.inputManager) {
            this.engine.inputManager.clearCallbacks();
        }
        // Override in subclasses
    }
    
    onExit() {
        // Override in subclasses
    }
    
    update(deltaTime) {
        // Override in subclasses
    }
    
    render(ctx) {
        // Override in subclasses
    }
}