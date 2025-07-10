export class PixiEngine {
  constructor(width = 1280, height = 720) {
    this.width = width;
    this.height = height;
    this.isRunning = false;

    // Create PixiJS application
    this.app = new PIXI.Application({
      width: width,
      height: height,
      backgroundColor: 0x2c3e50,
      antialias: true,
      resolution: window.devicePixelRatio || 1,
      autoDensity: true,
    });

    // Scene management
    this.scenes = new Map();
    this.currentScene = null;
    this.inputManager = null;

    // Performance tracking
    this.fps = 60;
    this.frameCount = 0;
    this.lastTime = performance.now();

    this.setupApplication();
  }

  setupApplication() {
    // Add canvas to DOM
    const gameContainer = document.getElementById("gameContainer");
    if (gameContainer) {
      gameContainer.appendChild(this.app.view);
    }

    // Setup global interaction
    this.app.stage.interactive = true;
    this.app.stage.hitArea = this.app.screen;

    // Window resize handling
    window.addEventListener("resize", () => this.handleResize());

    // Performance monitoring
    this.app.ticker.add(() => this.updatePerformance());

    console.log("PixiJS Engine initialized:", {
      width: this.width,
      height: this.height,
      renderer:
        this.app.renderer.type === PIXI.RENDERER_TYPE.WEBGL
          ? "WebGL"
          : "Canvas",
    });
  }

  setInputManager(inputManager) {
    this.inputManager = inputManager;
    if (inputManager) {
      inputManager.setPixiApp(this.app);
    }
  }

  addScene(name, scene) {
    this.scenes.set(name, scene);
    scene.setEngine(this);
    console.log(`Scene '${name}' added to engine`);
  }

  switchScene(name) {
    const newScene = this.scenes.get(name);
    if (!newScene) {
      console.error(`Scene '${name}' not found`);
      return false;
    }

    // Don't reload the same scene
    if (this.currentScene === newScene) {
      console.log(`Already in scene '${name}', skipping reload`);
      return false;
    }

    // Exit current scene
    if (this.currentScene) {
      this.currentScene.onExit();
    }

    // Clear stage
    this.app.stage.removeChildren();

    // Enter new scene
    this.currentScene = newScene;
    this.currentScene.onEnter();

    // Update UI
    this.updateGameStateUI(name);

    // UPDATE NAVIGATION BUTTONS AUTOMATICALLY - Add this
    if (this.updateNavButtons) {
      this.updateNavButtons(name);
    }

    console.log(`Switched to scene: ${name}`);
    return true;
  }

  start() {
    if (this.isRunning) return;

    this.isRunning = true;

    // Start main game loop
    this.app.ticker.add((deltaTime) => {
      this.gameLoop(deltaTime);
    });

    // Hide loading screen
    this.hideLoadingScreen();

    console.log("PixiJS Engine started");
  }

  stop() {
    this.isRunning = false;
    this.app.ticker.stop();
    console.log("PixiJS Engine stopped");
  }

  gameLoop(deltaTime) {
    if (!this.isRunning) return;

    // Update input manager
    if (this.inputManager) {
      this.inputManager.update();
    }

    // Update current scene
    if (this.currentScene) {
      this.currentScene.update(deltaTime);
    }

    // Late update for input cleanup
    if (this.inputManager && this.inputManager.lateUpdate) {
      this.inputManager.lateUpdate();
    }
  }

  updatePerformance() {
    this.frameCount++;

    if (this.frameCount % 60 === 0) {
      const currentTime = performance.now();
      this.fps = Math.round(60000 / (currentTime - this.lastTime));
      this.lastTime = currentTime;

      // Update FPS display
      const fpsElement = document.getElementById("fps");
      if (fpsElement) {
        fpsElement.textContent = this.fps;
      }
    }
  }

  handleResize() {
    // Simple resize handling - could be enhanced
    const container = document.getElementById("gameContainer");
    if (container) {
      this.app.renderer.resize(window.innerWidth, window.innerHeight);
    }
  }

  hideLoadingScreen() {
    const loadingScreen = document.getElementById("loadingScreen");
    if (loadingScreen) {
      loadingScreen.style.opacity = "0";
      setTimeout(() => {
        loadingScreen.style.display = "none";
      }, 500);
    }
  }

  updateGameStateUI(sceneName) {
    // Update various UI elements
    const gameStateElement = document.getElementById("gameState");
    if (gameStateElement) {
      gameStateElement.textContent = sceneName;
    }

    const engineStateElement = document.getElementById("engineState");
    if (engineStateElement) {
      engineStateElement.textContent = "PixiJS Running";
    }
  }

  // Utility methods for scenes
  createContainer() {
    return new PIXI.Container();
  }

  createGraphics() {
    return new PIXI.Graphics();
  }

  createSprite(texture) {
    return new PIXI.Sprite(texture);
  }

  createText(text, style) {
    return new PIXI.Text(text, style);
  }

  // Resource management
  loadTexture(url) {
    return PIXI.Texture.from(url);
  }

  // Cleanup
  destroy() {
    this.stop();

    if (this.currentScene) {
      this.currentScene.onExit();
    }

    this.scenes.clear();
    this.app.destroy(true, {
      children: true,
      texture: true,
      baseTexture: true,
    });

    console.log("PixiJS Engine destroyed");
  }
}
