import { PixiEngine } from "./core/PixiEngine.js";
import { PixiInputManager } from "./core/PixiInputManager.js";
import { CharacterRoster } from "./models/CharacterRoster.js";
import { PixiMenuScene } from "./scenes/PixiMenuScene.js";
import { PixiInventoryScene } from "./scenes/PixiInventoryScene.js";
import { PixiSquadScene } from "./scenes/PixiSquadScene.js";
import { PixiBattleScene } from "./scenes/PixiBattleScene.js";
import { PixiWorldScene } from "./scenes/PixiWorldScene.js";
import { PixiLootScene } from "./scenes/PixiLootScene.js";

class TacticalRPG {
    constructor() {
        console.log("🚀 Starting Tactical RPG with PixiJS...");
      
        // Create PixiJS engine
        this.engine = new PixiEngine(1200, 800);
      
        // Create input manager
        this.inputManager = new PixiInputManager();
        this.engine.setInputManager(this.inputManager);
      
        // Create and initialize character roster
        this.characterRoster = new CharacterRoster();
        this.characterRoster.createStarterRoster();
        this.engine.characterRoster = this.characterRoster;
      
        this.setupScenes();
        this.setupGlobalControls();
        this.setupUIHandlers();
        this.setupErrorHandling();
      }

      setupScenes() {
        // Create and register scenes
        this.menuScene = new PixiMenuScene();
        this.inventoryScene = new PixiInventoryScene();
        this.squadScene = new PixiSquadScene();
        this.battleScene = new PixiBattleScene();
        this.worldScene = new PixiWorldScene();
        this.lootScene = new PixiLootScene();
      
        this.engine.addScene("menu", this.menuScene);
        this.engine.addScene("inventory", this.inventoryScene);
        this.engine.addScene("squad", this.squadScene);
        this.engine.addScene("battle", this.battleScene);
        this.engine.addScene("world", this.worldScene);
        this.engine.addScene("loot", this.lootScene);
      
        // Make updateNavButtons available to engine
        this.engine.updateNavButtons = (sceneName) =>
          this.updateNavButtons(sceneName);
      
        console.log("✅ PixiJS scenes registered with custom shape support");
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
    
    this.inputManager.onKeyPress("KeyU", () => {
        this.engine.switchScene("squad");
    });

    // Debug controls
    this.inputManager.onKeyPress("F1", () => this.toggleDebugInfo());
    this.inputManager.onKeyPress("F2", () => this.logGameState());
    this.inputManager.onKeyPress("F3", () => this.showShapeInfo());

    console.log("⌨️ Global controls setup");
  }

  showShapeInfo() {
    console.group("🎨 Custom Shape System Info");
    console.log("Enhanced Inventory System with Custom Shapes");
    console.log("Controls in Inventory Scene:");
    console.log("  S = Toggle shape outlines");
    console.log("  D = Toggle dimension info");
    console.log("  R = Reset items");
    console.log("  T = Test shape creation");
    console.log("  C = Clear inventory");
    console.log("");
    console.log("Available Shape Types:");
    console.log("  • Rectangle (traditional)");
    console.log("  • L-shapes (4 orientations)");
    console.log("  • T-shapes (staffs, hammers)");
    console.log("  • U-shapes (bows, horseshoes)");
    console.log("  • Plus/Cross shapes");
    console.log("  • Diamond shapes");
    console.log("  • Z-shapes");
    console.log("  • Tetris pieces");
    console.log("  • Custom patterns");
    console.log("  • Frames and hollow shapes");
    console.groupEnd();

    this.showNotification("Shape Info logged to console");
  }

  showNotification(message) {
    // Simple notification system
    const notification = document.createElement("div");
    notification.textContent = message;
    notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: rgba(52, 152, 219, 0.9);
            color: white;
            padding: 15px 20px;
            border-radius: 8px;
            font-family: 'Courier New', monospace;
            font-weight: bold;
            z-index: 1000;
            animation: slideIn 0.3s ease-out;
        `;

    document.body.appendChild(notification);

    setTimeout(() => {
      notification.style.opacity = "0";
      notification.style.transform = "translateX(100%)";
      setTimeout(() => {
        if (document.body.contains(notification)) {
          document.body.removeChild(notification);
        }
      }, 300);
    }, 2000);
  }

  setupUIHandlers() {
    // Navigation buttons with enhanced event handling
    const menuBtn = document.getElementById("menuBtn");
    const inventoryBtn = document.getElementById("inventoryBtn");
    const squadBtn = document.getElementById("squadBtn");
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
    
    if (squadBtn) {
      squadBtn.addEventListener(
        "click",
        (e) => {
          e.stopPropagation();
          console.log("🎭 Squad button clicked");
          this.switchToScene("squad");
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
  }

  switchToScene(sceneName) {
    this.engine.switchScene(sceneName);
    this.updateNavButtons(sceneName);
  }

  updateNavButtons(activeScene) {
    const buttons = {
      menu: document.getElementById("menuBtn"),
      inventory: document.getElementById("inventoryBtn"),
      squad: document.getElementById("squadBtn"),
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
    console.log("Custom Shape System:", "ACTIVE");
    console.groupEnd();
  }

  start() {
    console.group("🚀 Tactical RPG - Enhanced PixiJS with Custom Shapes");
    console.log("🎨 Graphics Engine: PixiJS WebGL");
    console.log("📁 Architecture: Modular scene files");
    console.log("🎯 Shape System: Custom item shapes supported");
    console.log("✨ Features:");
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
    console.log("  ├── U = Squad");
    console.log("  ├── B = Battle");
    console.log("  ├── W = World");
    console.log("");
    console.log("🎨 Inventory Shape Controls:");
    console.log("  ├── S = Toggle shape outlines");
    console.log("  ├── D = Toggle dimension info");
    console.log("  ├── R = Reset items");
    console.log("  ├── T = Test shape creation");
    console.log("  └── C = Clear inventory");
    console.groupEnd();

    // Start with menu scene
    this.engine.switchScene("menu");
    this.updateNavButtons("menu");

    // Start the engine
    this.engine.start();

    console.log(
      "🎯 Game started successfully with custom shape inventory system!"
    );
    console.log("🎨 Ready to create L-shaped, T-shaped, and custom items!");
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
