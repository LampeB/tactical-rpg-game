export class PixiEngine {
    constructor(width = window.innerWidth, height = window.innerHeight) {
      console.log("🔧 DEBUG: PixiEngine constructor called", { width, height });
  
      this.width = width;
      this.height = height;
      this.isRunning = false;
      this.isFullscreen = false;
  
      // Create PixiJS application with viewport sizing
      this.app = new PIXI.Application({
        width: width,
        height: height,
        backgroundColor: 0x2c3e50,
        antialias: true,
        resolution: window.devicePixelRatio || 1,
        autoDensity: true,
        resizeTo: window, // Automatically resize to window
      });
  
      console.log("🔧 DEBUG: PIXI Application created", {
        width: this.app.screen.width,
        height: this.app.screen.height,
        renderer:
          this.app.renderer.type === PIXI.RENDERER_TYPE.WEBGL
            ? "WebGL"
            : "Canvas",
        resizeTo: "window",
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
      this.setupViewportHandling();
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
  
      // Make canvas fill viewport
      this.app.view.style.width = "100vw";
      this.app.view.style.height = "100vh";
      this.app.view.style.display = "block";
      this.app.view.style.position = "absolute";
      this.app.view.style.top = "0";
      this.app.view.style.left = "0";
  
      // Setup global interaction
      this.app.stage.interactive = true;
      this.app.stage.hitArea = this.app.screen;
  
      console.log("🔧 DEBUG: Stage setup", {
        interactive: this.app.stage.interactive,
        children: this.app.stage.children.length,
      });
  
      // Performance monitoring
      this.app.ticker.add(() => this.updatePerformance());
  
      console.log("🔧 DEBUG: PixiJS Engine initialized successfully");
    }
  
    setupViewportHandling() {
      console.log("🔧 DEBUG: Setting up viewport handling");
  
      // Handle window resize events
      window.addEventListener("resize", () => this.handleResize());
  
      // Handle orientation change on mobile
      window.addEventListener("orientationchange", () => {
        setTimeout(() => this.handleResize(), 100);
      });
  
      // Handle fullscreen events
      document.addEventListener("fullscreenchange", () => this.handleFullscreenChange());
      document.addEventListener("webkitfullscreenchange", () => this.handleFullscreenChange());
      document.addEventListener("mozfullscreenchange", () => this.handleFullscreenChange());
      document.addEventListener("MSFullscreenChange", () => this.handleFullscreenChange());
  
      // Global F11 fullscreen toggle
      document.addEventListener("keydown", (event) => {
        if (event.key === "F11") {
          event.preventDefault();
          this.toggleFullscreen();
        }
      });
  
      console.log("🔧 DEBUG: Viewport handling setup complete");
    }
  
    setInputManager(inputManager) {
      console.log("🔧 DEBUG: Setting input manager", !!inputManager);
      this.inputManager = inputManager;
      if (inputManager) {
        inputManager.setPixiApp(this.app);
        
        // Add F11 fullscreen support to input manager
        inputManager.onKeyPress("F11", () => {
          this.toggleFullscreen();
        });
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
  
      // Ensure proper initial sizing
      this.handleResize();
  
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
      console.log("🔧 DEBUG: Handling resize", {
        oldSize: { width: this.width, height: this.height },
        newSize: { width: window.innerWidth, height: window.innerHeight },
      });
  
      // Update engine dimensions
      this.width = window.innerWidth;
      this.height = window.innerHeight;
  
      // The PIXI app should auto-resize due to resizeTo: window option
      // But we'll ensure it's properly sized
      this.app.renderer.resize(this.width, this.height);
  
      // Update stage hit area
      this.app.stage.hitArea = new PIXI.Rectangle(0, 0, this.width, this.height);
  
      // Notify current scene of resize
      if (this.currentScene && this.currentScene.onResize) {
        this.currentScene.onResize(this.width, this.height);
      }
  
      // Update viewport display
      const engineState = document.getElementById("engineState");
      if (engineState) {
        engineState.textContent = `PixiJS ${this.width}×${this.height}${this.isFullscreen ? " (Fullscreen)" : ""}`;
      }
  
      console.log("🔧 DEBUG: Resize complete", {
        appSize: { width: this.app.screen.width, height: this.app.screen.height },
        canvasSize: { width: this.app.view.width, height: this.app.view.height },
        windowSize: { width: this.width, height: this.height },
      });
    }
  
    toggleFullscreen() {
      console.log("🔧 DEBUG: Toggling fullscreen");
  
      if (!this.isFullscreen) {
        this.enterFullscreen();
      } else {
        this.exitFullscreen();
      }
    }
  
    enterFullscreen() {
      const element = document.documentElement;
  
      if (element.requestFullscreen) {
        element.requestFullscreen();
      } else if (element.webkitRequestFullscreen) {
        element.webkitRequestFullscreen();
      } else if (element.mozRequestFullScreen) {
        element.mozRequestFullScreen();
      } else if (element.msRequestFullscreen) {
        element.msRequestFullscreen();
      }
  
      console.log("🔧 DEBUG: Requesting fullscreen");
    }
  
    exitFullscreen() {
      if (document.exitFullscreen) {
        document.exitFullscreen();
      } else if (document.webkitExitFullscreen) {
        document.webkitExitFullscreen();
      } else if (document.mozCancelFullScreen) {
        document.mozCancelFullScreen();
      } else if (document.msExitFullscreen) {
        document.msExitFullscreen();
      }
  
      console.log("🔧 DEBUG: Exiting fullscreen");
    }
  
    handleFullscreenChange() {
      this.isFullscreen = !!(
        document.fullscreenElement ||
        document.webkitFullscreenElement ||
        document.mozFullScreenElement ||
        document.msFullscreenElement
      );
  
      console.log("🔧 DEBUG: Fullscreen state changed", this.isFullscreen);
  
      // Trigger resize to update dimensions
      setTimeout(() => this.handleResize(), 100);
  
      // Update UI to reflect fullscreen state
      const engineState = document.getElementById("engineState");
      if (engineState) {
        engineState.textContent = `PixiJS ${this.width}×${this.height}${this.isFullscreen ? " (Fullscreen)" : ""}`;
      }
  
      // Show/hide UI elements based on fullscreen state
      const controls = document.getElementById("controls");
      const hud = document.getElementById("hud");
      const navButtons = document.querySelector(".nav-buttons");
  
      if (this.isFullscreen) {
        // Hide some UI elements in fullscreen for immersion
        if (controls) controls.style.opacity = "0.7";
        if (hud) hud.style.opacity = "0.9";
        if (navButtons) navButtons.style.opacity = "0.8";
      } else {
        // Restore UI elements
        if (controls) controls.style.opacity = "1";
        if (hud) hud.style.opacity = "1";
        if (navButtons) navButtons.style.opacity = "1";
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
        engineStateElement.textContent = `PixiJS ${this.width}×${this.height}${this.isFullscreen ? " (Fullscreen)" : ""}`;
      }
    }
  
    // Get viewport info for scenes
    getViewportInfo() {
      return {
        width: this.width,
        height: this.height,
        isFullscreen: this.isFullscreen,
        aspectRatio: this.width / this.height,
        devicePixelRatio: window.devicePixelRatio || 1,
      };
    }
  
    // Check if device is mobile
    isMobile() {
      return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
        navigator.userAgent
      ) || window.innerWidth <= 768;
    }
  
    // Check if device is in landscape orientation
    isLandscape() {
      return this.width > this.height;
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
        isFullscreen: this.isFullscreen,
        isMobile: this.isMobile(),
        isLandscape: this.isLandscape(),
      });
  
      console.log("PIXI App:", {
        width: this.app.screen.width,
        height: this.app.screen.height,
        stageChildren: this.app.stage.children.length,
        renderer:
          this.app.renderer.type === PIXI.RENDERER_TYPE.WEBGL
            ? "WebGL"
            : "Canvas",
        resolution: this.app.renderer.resolution,
      });
  
      console.log("Viewport:", {
        windowSize: { width: window.innerWidth, height: window.innerHeight },
        canvasSize: { width: this.app.view.width, height: this.app.view.height },
        devicePixelRatio: window.devicePixelRatio,
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
  
      // Clean up event listeners
      window.removeEventListener("resize", this.handleResize);
      window.removeEventListener("orientationchange", this.handleResize);
      document.removeEventListener("fullscreenchange", this.handleFullscreenChange);
      document.removeEventListener("webkitfullscreenchange", this.handleFullscreenChange);
      document.removeEventListener("mozfullscreenchange", this.handleFullscreenChange);
      document.removeEventListener("MSFullscreenChange", this.handleFullscreenChange);
  
      this.scenes.clear();
      this.app.destroy(true, {
        children: true,
        texture: true,
        baseTexture: true,
      });
  
      console.log("🔧 DEBUG: PixiJS Engine destroyed");
    }
  }