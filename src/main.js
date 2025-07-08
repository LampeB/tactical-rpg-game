import { PixiEngine } from "./core/PixiEngine.js";
import { PixiInputManager } from "./core/PixiInputManager.js";
import { PixiMenuScene } from "./scenes/PixiMenuScene.js";
import { PixiInventoryScene } from "./scenes/PixiInventoryScene.js";
import { PixiBattleScene } from "./scenes/PixiBattleScene.js";
import { PixiWorldScene } from "./scenes/PixiWorldScene.js";

class TacticalRPG {
  constructor() {
    console.log("🚀 Starting Tactical RPG with PixiJS...");

    // Create PixiJS engine
    this.engine = new PixiEngine(1200, 800);

    // Create input manager
    this.inputManager = new PixiInputManager();
    this.engine.setInputManager(this.inputManager);

    this.setupScenes();
    this.setupGlobalControls();
    this.setupUIHandlers();
    this.setupErrorHandling();
  }

  setupScenes() {
    // Create and register scenes (now imported from separate files)
    this.menuScene = new PixiMenuScene();
    this.inventoryScene = new PixiInventoryScene();
    this.battleScene = new PixiBattleScene();
    this.worldScene = new PixiWorldScene();

    this.engine.addScene("menu", this.menuScene);
    this.engine.addScene("inventory", this.inventoryScene);
    this.engine.addScene("battle", this.battleScene);
    this.engine.addScene("world", this.worldScene);

    // ADD THIS - Make updateNavButtons available to engine
    this.engine.updateNavButtons = (sceneName) =>
      this.updateNavButtons(sceneName);

    console.log("✅ PixiJS scenes registered from separate files");
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

    // Remove KeyW global handler since it conflicts with world movement
    // Users can use the World button instead

    // Debug controls
    this.inputManager.onKeyPress("F1", () => this.toggleDebugInfo());
    this.inputManager.onKeyPress("F2", () => this.logGameState());

    console.log("⌨️ Global controls setup");
  }

  setupUIHandlers() {
    // Navigation buttons with enhanced event handling
    const menuBtn = document.getElementById("menuBtn");
    const inventoryBtn = document.getElementById("inventoryBtn");
    const worldBtn = document.getElementById("worldBtn");
    const battleBtn = document.getElementById("battleBtn");

    // Add event listeners with higher priority and debugging
    if (menuBtn) {
      menuBtn.addEventListener(
        "click",
        (e) => {
          e.stopPropagation();
          console.log("📋 Menu button clicked");
          this.switchToScene("menu");
        },
        true
      ); // Use capture phase for higher priority
    }

    if (inventoryBtn) {
      inventoryBtn.addEventListener(
        "click",
        (e) => {
          e.stopPropagation();
          console.log("🎒 Inventory button clicked");
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

    console.log("🖱️ UI handlers setup with enhanced event handling");
  }

  switchToScene(sceneName) {
    this.engine.switchScene(sceneName);
    this.updateNavButtons(sceneName);
  }

  updateNavButtons(activeScene) {
    // Update navigation button states
    const buttons = {
      menu: document.getElementById("menuBtn"),
      inventory: document.getElementById("inventoryBtn"),
      world: document.getElementById("worldBtn"), // <-- This was missing!
      battle: document.getElementById("battleBtn"),
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

    // Show error in UI
    const gameStateElement = document.getElementById("gameState");
    if (gameStateElement) {
      gameStateElement.textContent = "Error occurred";
      gameStateElement.style.color = "#e74c3c";
    }
  }

  toggleDebugInfo() {
    const debugElement = document.getElementById("debugInfo");
    if (debugElement) {
      debugElement.style.display =
        debugElement.style.display === "none" ? "block" : "none";
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
      renderer:
        this.engine.app.renderer.type === PIXI.RENDERER_TYPE.WEBGL
          ? "WebGL"
          : "Canvas",
    });
    console.log("Total Scenes:", this.engine.scenes.size);
    console.log("PixiJS Version:", PIXI.VERSION);
    console.log("Scene Files Structure:");
    console.log("  ├── scenes/PixiMenuScene.js");
    console.log("  ├── scenes/PixiInventoryScene.js");
    console.log("  ├── scenes/PixiBattleScene.js");
    console.log("  └── scenes/PixiWorldScene.js");
    console.groupEnd();
  }

  start() {
    console.group("🚀 Tactical RPG - Modular PixiJS Architecture");
    console.log("🎨 Graphics Engine: PixiJS WebGL");
    console.log("📁 Architecture: Modular scene files");
    console.log("✨ Features:");
    console.log("  ├── Hardware-accelerated 2D rendering");
    console.log("  ├── Modular scene management");
    console.log("  ├── Interactive drag & drop system");
    console.log("  ├── World exploration with camera");
    console.log("  ├── Layer-based rendering system");
    console.log("  └── Optimized performance monitoring");
    console.log("");
    console.log("🎮 Controls:");
    console.log("  ├── ESC = Menu");
    console.log("  ├── I = Inventory");
    console.log("  ├── B = Battle");
    console.log("  ├── W = World");
    console.log("  ├── F1 = Toggle Debug");
    console.log("  └── F2 = Log State");
    console.groupEnd();

    // Start with menu scene
    this.engine.switchScene("menu");
    this.updateNavButtons("menu");

    // Start the engine
    this.engine.start();

    console.log(
      "🎯 Game started successfully with modular PixiJS architecture!"
    );
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
  window.PIXI = PIXI; // For console debugging

  console.log("🎮 Game instance available as window.game");
  console.log("🎨 PixiJS available as window.PIXI");
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
