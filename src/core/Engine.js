export class Engine {
    constructor(canvasId) {
        this.canvas = document.getElementById(canvasId);
        this.ctx = this.canvas.getContext('2d');
        this.width = this.canvas.width;
        this.height = this.canvas.height;
        
        this.lastTime = 0;
        this.deltaTime = 0;
        this.fps = 0;
        this.frameCount = 0;
        this.isRunning = false;
        
        this.scenes = new Map();
        this.currentScene = null;
        this.inputManager = null; // Will be injected
    }
    
    setInputManager(inputManager) {
        this.inputManager = inputManager;
    }
    
    addScene(name, scene) {
        this.scenes.set(name, scene);
        scene.setEngine(this);
    }
    
    switchScene(name) {
        if (this.currentScene) {
            this.currentScene.onExit();
        }
        
        this.currentScene = this.scenes.get(name);
        if (this.currentScene) {
            this.currentScene.onEnter();
            document.getElementById('gameState').textContent = name;
        }
    }
    
    start() {
        this.isRunning = true;
        this.gameLoop();
    }
    
    stop() {
        this.isRunning = false;
    }
    
    gameLoop() {
        if (!this.isRunning) return;
        
        const currentTime = performance.now();
        this.deltaTime = currentTime - this.lastTime;
        this.lastTime = currentTime;
        
        this.update(this.deltaTime);
        this.render();
        
        // Update FPS
        this.frameCount++;
        if (this.frameCount % 60 === 0) {
            this.fps = Math.round(1000 / this.deltaTime);
            document.getElementById('fps').textContent = this.fps;
        }
        
        requestAnimationFrame(() => this.gameLoop());
    }
    
    update(deltaTime) {
        if (this.inputManager) {
            this.inputManager.update();
        }
        
        if (this.currentScene) {
            this.currentScene.update(deltaTime);
        }
    }
    
    render() {
        // Clear canvas
        this.ctx.fillStyle = '#bdc3c7';
        this.ctx.fillRect(0, 0, this.width, this.height);
        
        if (this.currentScene) {
            this.currentScene.render(this.ctx);
        }
    }
}