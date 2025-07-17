import { PixiEngine } from "./core/PixiEngine.js";
import { PixiInputManager } from "./core/PixiInputManager.js";
import { PixiMenuScene } from "./scenes/PixiMenuScene.js";
import { PixiInventoryScene } from "./scenes/PixiInventoryScene.js";
import { PixiBattleScene } from "./scenes/PixiBattleScene.js";
import { PixiWorldScene } from "./scenes/PixiWorldScene.js";
import { PixiLootScene } from "./scenes/PixiLootScene.js";

class TacticalRPG {
  constructor() {
    console.log("🚀 Starting Tactical RPG with PixiJS (Viewport Sized)...");

    // Create PixiJS engine with viewport sizing (no hardcoded dimensions)
    this.engine = new PixiEngine();

    // Create input manager
    this.inputManager = new PixiInputManager();
    this.engine.setInputManager(this.inputManager);

    this.setupScenes();
    this.setupGlobalControls();
    this.setupUIHandlers();
    this.setupErrorHandling();
    this.setupViewportHandling();
  }

  setupScenes() {
    // Create and register scenes
    this.menuScene = new PixiMenuScene();
    this.inventoryScene = new PixiInventoryScene();
    this.battleScene = new PixiBattleScene();
    this.worldScene = new PixiWorldScene();
    this.lootScene = new PixiLootScene();

    this.engine.addScene("menu", this.menuScene);
    this.engine.addScene("inventory", this.inventoryScene);
    this.engine.addScene("battle", this.battleScene);
    this.engine.addScene("world", this.worldScene);
    this.engine.addScene("loot", this.lootScene);

    // Make updateNavButtons available to engine
    this.engine.updateNavButtons = (sceneName) =>
      this.updateNavButtons(sceneName);

    console.log("✅ PixiJS scenes registered with viewport support");
  }

  setupGlobalControls() {
    // Global key handlers
    this.inputManager.onKeyPress("Escape", () => {
      this.engine.switchScene("menu");
    });

    this.inputManager.onKeyPress("KeyI", () => {
      this.engine.switchScene("inventory");
    });

    this.inputManager.onKeyPress("KeyB", () => {
      this.engine.switchScene("battle");
    });

    this.inputManager.onKeyPress("KeyW", () => {
      this.engine.switchScene("world");
    });

    // Debug controls
    this.inputManager.onKeyPress("F1", () => this.toggleDebugInfo());
    this.inputManager.onKeyPress("F2", () => this.logGameState());
    this.inputManager.onKeyPress("F3", () => this.showViewportInfo());
    this.inputManager.onKeyPress("F4", () => this.showPerformanceInfo());

    // Fullscreen is handled by engine directly via F11
    // But we can add an alternative key
    this.inputManager.onKeyPress("KeyF", () => {
      if (this.inputManager.isKeyPressed("AltLeft") || this.inputManager.isKeyPressed("AltRight")) {
        this.engine.toggleFullscreen();
      }
    });

    console.log("⌨️ Global controls setup with viewport support");
  }

  setupViewportHandling() {
    // Additional viewport-specific handling
    window.addEventListener("orientationchange", () => {
      this.showNotification("Orientation changed - adjusting layout...");
      setTimeout(() => {
        this.updateViewportInfo();
      }, 200);
    });

    // Show viewport info on load
    this.updateViewportInfo();

    console.log("📱 Viewport handling setup");
  }

  updateViewportInfo() {
    const viewportInfo = this.engine.getViewportInfo();
    console.log("📱 Viewport Info:", viewportInfo);

    // Update debug info if visible
    const debugInfo = document.getElementById("debugInfo");
    if (debugInfo && debugInfo.style.display !== "none") {
      const viewportText = debugInfo.querySelector("#viewportInfo") || 
        (() => {
          const div = document.createElement("div");
          div.id = "viewportInfo";
          debugInfo.appendChild(div);
          return div;
        })();
      
      viewportText.innerHTML = `
        <div>Viewport: ${viewportInfo.width}×${viewportInfo.height}</div>
        <div>Aspect: ${viewportInfo.aspectRatio.toFixed(2)}</div>
        <div>DPR: ${viewportInfo.devicePixelRatio}</div>
        <div>Mobile: ${this.engine.isMobile() ? "Yes" : "No"}</div>
        <div>Orientation: ${this.engine.isLandscape() ? "Landscape" : "Portrait"}</div>
        <div>Fullscreen: ${viewportInfo.isFullscreen ? "Yes" : "No"}</div>
      `;
    }
  }

  showViewportInfo() {
    const viewportInfo = this.engine.getViewportInfo();
    
    console.group("📱 Viewport Information");
    console.log("Dimensions:", `${viewportInfo.width} × ${viewportInfo.height}`);
    console.log("Aspect Ratio:", viewportInfo.aspectRatio.toFixed(2));
    console.log("Device Pixel Ratio:", viewportInfo.devicePixelRatio);
    console.log("Is Mobile:", this.engine.isMobile());
    console.log("Is Landscape:", this.engine.isLandscape());
    console.log("Is Fullscreen:", viewportInfo.isFullscreen);
    console.log("Canvas Size:", `${this.engine.app.view.width} × ${this.engine.app.view.height}`);
    console.log("Screen Size:", `${this.engine.app.screen.width} × ${this.engine.app.screen.height}`);
    console.groupEnd();

    this.showNotification(
      `Viewport: ${viewportInfo.width}×${viewportInfo.height} | ` +
      `${this.engine.isMobile() ? "Mobile" : "Desktop"} | ` +
      `${this.engine.isLandscape() ? "Landscape" : "Portrait"}${viewportInfo.isFullscreen ? " | Fullscreen" : ""}`
    );
  }

  showPerformanceInfo() {
    const performanceInfo = {
      fps: this.engine.fps,
      renderer: this.engine.app.renderer.type === PIXI.RENDERER_TYPE.WEBGL ? "WebGL" : "Canvas",
      drawCalls: this.engine.app.renderer.gl ? this.engine.app.renderer.gl.getParameter(this.engine.app.renderer.gl.getExtension("WEBGL_debug_renderer_info").UNMASKED_RENDERER_WEBGL) : "N/A",
      memory: performance.memory ? `${Math.round(performance.memory.usedJSHeapSize / 1024 / 1024)}MB` : "N/A",
    };

    console.group("🎮 Performance Information");
    console.log("FPS:", performanceInfo.fps);
    console.log("Renderer:", performanceInfo.renderer);
    console.log("GPU:", performanceInfo.drawCalls);
    console.log("Memory Usage:", performanceInfo.memory);
    console.log("Scene Objects:", this.engine.currentScene?.sprites?.length || 0);
    console.groupEnd();

    this.showNotification(
      `${performanceInfo.fps} FPS | ${performanceInfo.renderer} | ${performanceInfo.memory}`
    );
  }

  showNotification(message, duration = 3000) {
    // Remove existing notification
    const existing = document.querySelector(".game-notification");
    if (existing) {
      existing.remove();
    }

    // Create new notification
    const notification = document.createElement("div");
    notification.className = "game-notification";
    notification.textContent = message;
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      background: rgba(52, 152, 219, 0.95);
      color: white;
      padding: 12px 20px;
      border-radius: 8px;
      font-family: 'Courier New', monospace;
      font-size: 12px;
      font-weight: bold;
      z-index: 1000;
      max-width: 300px;
      word-wrap: break-word;
      border: 2px solid rgba(255, 255, 255, 0.3);
      backdrop-filter: blur(5px);
      transform: translateX(100%);
      transition: transform 0.3s ease-out;
    `;

    document.body.appendChild(notification);

    // Animate in
    requestAnimationFrame(() => {
      notification.style.transform = "translateX(0)";
    });

    // Animate out and remove
    setTimeout(() => {
      notification.style.transform = "translateX(100%)";
      setTimeout(() => {
        if (document.body.contains(notification)) {
          document.body.removeChild(notification);
        }
      }, 300);
    }, duration);
  }

  setupUIHandlers() {
    // Navigation buttons with enhanced event handling
    const menuBtn = document.getElementById("menuBtn");
    const inventoryBtn = document.getElementById("inventoryBtn");
    const worldBtn = document.getElementById("worldBtn");
    const battleBtn = document.getElementById("battleBtn");

    if (menuBtn) {
      menuBtn.addEventListener(
        "click",
        (e) => {
          e.stopPropagation();
          console.log("📋 Menu button clicked");
          this.switchToScene("menu");
        },
        true
      );
    }

    if (inventoryBtn) {
      inventoryBtn.addEventListener(
        "click",
        (e) => {
          e.stopPropagation();
          console.log("🎨 Shaped Inventory button clicked");
          this.switchToScene("inventory");
        },
        true
      );
    }

    if (worldBtn) {
      worldBtn.addEventListener(
        "click",
        (e) => {
          e.stopPropagation();
          console.log("🌍 World button clicked");
          this.switchToScene("world");
        },
        true
      );
    }

    if (battleBtn) {
      battleBtn.addEventListener(
        "click",
        (e) => {
          e.stopPropagation();
          console.log("⚔️ Battle button clicked");
          this.switchToScene("battle");
        },
        true
      );
    }

    // Add viewport-specific UI handling
    this.setupResponsiveUI();

    console.log("🖱️ UI handlers setup with viewport responsiveness");
  }

  setupResponsiveUI() {
    // Adjust UI based on viewport size
    const updateUILayout = () => {
      const viewportInfo = this.engine.getViewportInfo();
      const isMobile = this.engine.isMobile();
      const isPortrait = !this.engine.isLandscape();

      // Adjust HUD positioning and size for mobile
      const hud = document.getElementById("hud");
      if (hud) {
        if (isMobile) {
          hud.style.fontSize = "12px";
          hud.style.padding = "10px";
          if (isPortrait) {
            hud.style.top = "10px";
            hud.style.left = "10px";
            hud.style.right = "10px";
            hud.style.width = "auto";
          }
        } else {
          hud.style.fontSize = "14px";
          hud.style.padding = "15px";
          hud.style.top = "20px";
          hud.style.left = "20px";
          hud.style.right = "auto";
          hud.style.width = "200px";
        }
      }

      // Adjust controls for mobile
      const controls = document.getElementById("controls");
      if (controls) {
        if (isMobile && isPortrait) {
          controls.style.display = "none"; // Hide on mobile portrait
        } else {
          controls.style.display = "block";
          controls.style.fontSize = isMobile ? "10px" : "12px";
        }
      }

      // Adjust navigation buttons
      const navButtons = document.querySelector(".nav-buttons");
      if (navButtons) {
        if (isMobile) {
          navButtons.style.flexDirection = "row";
          navButtons.style.bottom = "10px";
          navButtons.style.right = "10px";
          navButtons.style.left = "10px";
          navButtons.style.justifyContent = "space-around";
        } else {
          navButtons.style.flexDirection = "row";
          navButtons.style.bottom = "20px";
          navButtons.style.right = "20px";
          navButtons.style.left = "auto";
          navButtons.style.justifyContent = "flex-end";
        }
      }

      console.log(`📱 UI layout updated for ${isMobile ? "mobile" : "desktop"} ${isPortrait ? "portrait" : "landscape"}`);
    };

    // Update on resize
    window.addEventListener("resize", () => {
      setTimeout(updateUILayout, 100);
    });

    // Initial update
    updateUILayout();
  }

  switchToScene(sceneName) {
    this.engine.switchScene(sceneName);
    this.updateNavButtons(sceneName);
  }

  updateNavButtons(activeScene) {
    const buttons = {
      menu: document.getElementById("menuBtn"),
      inventory: document.getElementById("inventoryBtn"),
      battle: document.getElementById("battleBtn"),
      world: document.getElementById("worldBtn"),
    };

    Object.keys(buttons).forEach((scene) => {
      const btn = buttons[scene];
      if (btn) {
        if (scene === activeScene) {
          btn.classList.add("active");
        } else {
          btn.classList.remove("active");
        }
      }
    });
  }

  setupErrorHandling() {
    window.addEventListener("error", (event) => {
      console.error("Game Error:", event.error);
      this.handleGameError(event.error);
    });

    window.addEventListener("unhandledrejection", (event) => {
      console.error("Unhandled Promise Rejection:", event.reason);
      this.handleGameError(event.reason);
    });
  }

  handleGameError(error) {
    console.error("Critical game error occurred:", error);

    const gameStateElement = document.getElementById("gameState");
    if (gameStateElement) {
      gameStateElement.textContent = "Error occurred";
      gameStateElement.style.color = "#e74c3c";
    }

    this.showNotification("⚠️ Game error occurred - check console", 5000);
  }

  toggleDebugInfo() {
    const debugElement = document.getElementById("debugInfo");
    if (debugElement) {
      const isVisible = debugElement.style.display !== "none";
      debugElement.style.display = isVisible ? "none" : "block";
      
      if (!isVisible) {
        this.updateViewportInfo();
      }
    }
  }

  logGameState() {
    console.group("🎮 PixiJS Game State Debug Info");
    console.log("Current Scene:", this.engine.currentScene?.constructor.name);
    console.log("Engine State:", {
      width: this.engine.width,
      height: this.engine.height,
      fps: this.engine.fps,
      isRunning: this.engine.isRunning,
      isFullscreen: this.engine.isFullscreen,
      renderer:
        this.engine.app.renderer.type === PIXI.RENDERER_TYPE.WEBGL
          ? "WebGL"
          : "Canvas",
    });
    console.log("Viewport:", this.engine.getViewportInfo());
    console.log("Total Scenes:", this.engine.scenes.size);
    console.log("PixiJS Version:", PIXI.VERSION);
    console.log("Custom Shape System:", "ACTIVE");
    console.log("Device Info:", {
      userAgent: navigator.userAgent,
      platform: navigator.platform,
      language: navigator.language,
      cookieEnabled: navigator.cookieEnabled,
    });
    console.groupEnd();
  }

  start() {
    console.group("🚀 Tactical RPG - Viewport-Aware PixiJS with Custom Shapes");
    console.log("🎨 Graphics Engine: PixiJS WebGL (Viewport Sized)");
    console.log("📱 Viewport Support: Full responsive design");
    console.log("📁 Architecture: Modular scene files");
    console.log("🎯 Shape System: Custom item shapes supported");
    console.log("✨ Features:");
    console.log("  ├── Full viewport sizing (100% width/height)");
    console.log("  ├── Automatic window resize handling");
    console.log("  ├── F11 fullscreen toggle support");
    console.log("  ├── Mobile-responsive UI layout");
    console.log("  ├── Orientation change detection");
    console.log("  ├── Hardware-accelerated 2D rendering");
    console.log("  ├── Custom shaped inventory items");
    console.log("  ├── L, T, U, Diamond, Z shapes");
    console.log("  ├── Tetris piece shapes");
    console.log("  ├── Pattern-based shape creation");
    console.log("  ├── Shape transformations & validation");
    console.log("  ├── Visual drag & drop feedback");
    console.log("  ├── ASCII shape visualization");
    console.log("  └── 25+ pre-defined shapes");
    console.log("");
    console.log("🎮 Controls:");
    console.log("  ├── ESC = Menu");
    console.log("  ├── I = Inventory");
    console.log("  ├── B = Battle");
    console.log("  ├── W = World");
    console.log("  ├── F11 = Fullscreen");
    console.log("  ├── Alt+F = Fullscreen (alternative)");
    console.log("  ├── F1 = Toggle Debug Info");
    console.log("  ├── F2 = Log Game State");
    console.log("  ├── F3 = Show Viewport Info");
    console.log("  └── F4 = Show Performance Info");
    console.log("");
    console.log("🎨 Inventory Shape Controls:");
    console.log("  ├── S = Toggle shape outlines");
    console.log("  ├── D = Toggle dimension info");
    console.log("  ├── R = Reset items");
    console.log("  ├── T = Test shape creation");
    console.log("  └── C = Clear inventory");
    console.log("");
    console.log("📱 Viewport Info:");
    const viewportInfo = this.engine.getViewportInfo();
    console.log(`  ├── Dimensions: ${viewportInfo.width} × ${viewportInfo.height}`);
    console.log(`  ├── Aspect Ratio: ${viewportInfo.aspectRatio.toFixed(2)}`);
    console.log(`  ├── Device: ${this.engine.isMobile() ? "Mobile" : "Desktop"}`);
    console.log(`  ├── Orientation: ${this.engine.isLandscape() ? "Landscape" : "Portrait"}`);
    console.log(`  └── DPR: ${viewportInfo.devicePixelRatio}`);
    console.groupEnd();

    // Start with menu scene
    this.engine.switchScene("menu");
    this.updateNavButtons("menu");

    // Start the engine
    this.engine.start();

    // Show welcome notification
    setTimeout(() => {
      this.showNotification(
        `🎮 Game loaded! ${this.engine.width}×${this.engine.height} | Press F11 for fullscreen`
      );
    }, 1000);

    console.log(
      "🎯 Game started successfully with viewport-aware custom shape inventory system!"
    );
    console.log("🎨 Ready to create L-shaped, T-shaped, and custom items!");
    console.log("📱 Fully responsive - try resizing your window or going fullscreen!");
  }

  stop() {
    this.engine.stop();
    console.log("🛑 Game stopped");
  }

  destroy() {
    this.engine.destroy();
    this.inputManager.destroy();
    console.log("🧹 Game destroyed and cleaned up");
  }
}

// Initialize game when page loads
window.addEventListener("load", () => {
  const game = new TacticalRPG();
  game.start();

  // Make game globally available for debugging
  window.game = game;
  window.PIXI = PIXI;

  console.log("🎮 Game instance available as window.game");
  console.log("🎨 PixiJS available as window.PIXI");
  console.log("🎯 Custom shape system ready!");
  console.log("📱 Viewport-aware engine active!");
});

// Handle page visibility changes
document.addEventListener("visibilitychange", () => {
  if (window.game) {
    if (document.hidden) {
      window.game.stop();
      console.log("⏸️ Game paused (tab hidden)");
    } else {
      window.game.engine.start();
      console.log("▶️ Game resumed (tab visible)");
    }
  }
});

// Handle page unload
window.addEventListener("beforeunload", () => {
  if (window.game) {
    window.game.destroy();
    console.log("🧹 Game cleaned up before page unload");
  }
});

// Export for potential module usage
export { TacticalRPG };