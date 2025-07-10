export class PixiEngine {
  constructor(width = 1280, height = 720) {
    console.log("🔧 DEBUG: PixiEngine constructor called", { width, height });

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

    console.log("🔧 DEBUG: PIXI Application created", {
      width: this.app.screen.width,
      height: this.app.screen.height,
      renderer:
        this.app.renderer.type === PIXI.RENDERER_TYPE.WEBGL
          ? "WebGL"
          : "Canvas",
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
    console.log("🔧 DEBUG: Setting up application");

    // Add canvas to DOM
    const gameContainer = document.getElementById("gameContainer");
    if (gameContainer) {
      gameContainer.appendChild(this.app.view);
      console.log("🔧 DEBUG: Canvas added to gameContainer");
    } else {
      console.error("🔧 ERROR: gameContainer element not found!");
      return;
    }

    // Setup global interaction
    this.app.stage.interactive = true;
    this.app.stage.hitArea = this.app.screen;

    console.log("🔧 DEBUG: Stage setup", {
      interactive: this.app.stage.interactive,
      children: this.app.stage.children.length,
    });

    // Window resize handling
    window.addEventListener("resize", () => this.handleResize());

    // Performance monitoring
    this.app.ticker.add(() => this.updatePerformance());

    console.log("🔧 DEBUG: PixiJS Engine initialized successfully");
  }

  setInputManager(inputManager) {
    console.log("🔧 DEBUG: Setting input manager", !!inputManager);
    this.inputManager = inputManager;
    if (inputManager) {
      inputManager.setPixiApp(this.app);
    }
  }

  addScene(name, scene) {
    console.log("🔧 DEBUG: Adding scene", name);
    this.scenes.set(name, scene);
    scene.setEngine(this);
    console.log(
      `🔧 DEBUG: Scene '${name}' added to engine (total: ${this.scenes.size})`
    );
  }

  switchScene(name) {
    console.log("🔧 DEBUG: switchScene called", name);

    const newScene = this.scenes.get(name);
    if (!newScene) {
      console.error(
        `🔧 ERROR: Scene '${name}' not found. Available scenes:`,
        Array.from(this.scenes.keys())
      );
      return false;
    }

    // Don't reload the same scene
    if (this.currentScene === newScene) {
      console.log(`🔧 DEBUG: Already in scene '${name}', skipping reload`);
      return false;
    }

    console.log("🔧 DEBUG: Before scene switch", {
      currentScene: this.currentScene?.constructor?.name || "none",
      newScene: newScene.constructor.name,
      stageChildren: this.app.stage.children.length,
    });

    // Exit current scene
    if (this.currentScene) {
      console.log("🔧 DEBUG: Exiting current scene");
      this.currentScene.onExit();
    }

    // Clear stage completely
    console.log("🔧 DEBUG: Clearing stage");
    this.app.stage.removeChildren();

    console.log("🔧 DEBUG: Stage cleared", {
      stageChildren: this.app.stage.children.length,
    });

    // Enter new scene
    console.log("🔧 DEBUG: Entering new scene");
    this.currentScene = newScene;
    this.currentScene.onEnter();

    console.log("🔧 DEBUG: After scene switch", {
      currentScene: this.currentScene.constructor.name,
      stageChildren: this.app.stage.children.length,
      sceneIsActive: this.currentScene.isActive,
    });

    // Update UI
    this.updateGameStateUI(name);

    // UPDATE NAVIGATION BUTTONS AUTOMATICALLY
    if (this.updateNavButtons) {
      this.updateNavButtons(name);
    }

    console.log(`🔧 DEBUG: Successfully switched to scene: ${name}`);
    return true;
  }

  start() {
    if (this.isRunning) {
      console.log("🔧 DEBUG: Engine already running");
      return;
    }

    console.log("🔧 DEBUG: Starting engine");
    this.isRunning = true;

    // Start main game loop
    this.app.ticker.add((deltaTime) => {
      this.gameLoop(deltaTime);
    });

    // Hide loading screen
    this.hideLoadingScreen();

    console.log("🔧 DEBUG: PixiJS Engine started successfully");
  }

  stop() {
    console.log("🔧 DEBUG: Stopping engine");
    this.isRunning = false;
    this.app.ticker.stop();
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
    console.log("🔧 DEBUG: Handling resize");
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
    const gameStateElement = document.getElementById("gameState");
    if (gameStateElement) {
      gameStateElement.textContent = sceneName;
    }

    const engineStateElement = document.getElementById("engineState");
    if (engineStateElement) {
      engineStateElement.textContent = "PixiJS Running";
    }
  }

  // Debug method
  debugFullState() {
    console.group("🔧 FULL ENGINE DEBUG STATE");
    console.log("Engine:", {
      isRunning: this.isRunning,
      width: this.width,
      height: this.height,
      fps: this.fps,
      totalScenes: this.scenes.size,
      sceneNames: Array.from(this.scenes.keys()),
    });

    console.log("PIXI App:", {
      width: this.app.screen.width,
      height: this.app.screen.height,
      stageChildren: this.app.stage.children.length,
      renderer:
        this.app.renderer.type === PIXI.RENDERER_TYPE.WEBGL
          ? "WebGL"
          : "Canvas",
    });

    console.log("Current Scene:", {
      name: this.currentScene?.constructor?.name || "none",
      isActive: this.currentScene?.isActive || false,
    });

    if (this.currentScene && this.currentScene.debugFullState) {
      this.currentScene.debugFullState();
    }

    console.groupEnd();
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
    console.log("🔧 DEBUG: Destroying engine");
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

    console.log("🔧 DEBUG: PixiJS Engine destroyed");
  }
}
