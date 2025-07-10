// src/core/PixiScene.js - Fixed version with comprehensive debugging
export class PixiScene {
  constructor() {
    console.log("🔧 DEBUG: PixiScene constructor called");

    this.engine = null;
    this.sprites = [];
    this.graphics = [];
    this.isActive = false;

    // Create main container
    this.container = new PIXI.Container();
    this.container.name = "sceneContainer";

    console.log("🔧 DEBUG: Container created", {
      container: !!this.container,
      visible: this.container.visible,
    });

    // Layer management - Create layers as containers
    this.layers = {
      background: new PIXI.Container(),
      world: new PIXI.Container(),
      ui: new PIXI.Container(),
      effects: new PIXI.Container(),
    };

    // Name the layers for debugging
    this.layers.background.name = "backgroundLayer";
    this.layers.world.name = "worldLayer";
    this.layers.ui.name = "uiLayer";
    this.layers.effects.name = "effectsLayer";

    // Add layers to main container in the correct order
    this.container.addChild(this.layers.background);
    this.container.addChild(this.layers.world);
    this.container.addChild(this.layers.ui);
    this.container.addChild(this.layers.effects);

    console.log("🔧 DEBUG: Layers created and added to container", {
      containerChildren: this.container.children.length,
      layerNames: this.container.children.map((child) => child.name),
    });

    // Input handling
    this.keys = {};
    this.mousePosition = { x: 0, y: 0 };
    this.mouseClicked = false;
  }

  setEngine(engine) {
    console.log("🔧 DEBUG: setEngine called", !!engine);
    this.engine = engine;
  }

  onEnter() {
    console.log("🔧 DEBUG: PixiScene onEnter called");

    this.isActive = true;

    // Ensure container is visible
    this.container.visible = true;

    // Ensure all layers are visible
    Object.values(this.layers).forEach((layer) => {
      layer.visible = true;
    });

    console.log("🔧 DEBUG: Before adding to stage", {
      hasEngine: !!this.engine,
      hasApp: !!(this.engine && this.engine.app),
      hasStage: !!(this.engine && this.engine.app && this.engine.app.stage),
      containerVisible: this.container.visible,
      containerChildren: this.container.children.length,
    });

    // Add this scene's container to the stage
    if (this.engine && this.engine.app && this.engine.app.stage) {
      this.engine.app.stage.addChild(this.container);
      console.log("🔧 DEBUG: Container added to stage", {
        containerParent: !!this.container.parent,
        stageChildren: this.engine.app.stage.children.length,
      });
    } else {
      console.error(
        "🔧 ERROR: Cannot add container to stage - missing engine/app/stage"
      );
    }

    // Setup input handlers
    this.setupInputHandlers();

    console.log(`🔧 DEBUG: Scene entered: ${this.constructor.name}`);
  }

  onExit() {
    console.log("🔧 DEBUG: PixiScene onExit called");

    this.isActive = false;

    // Remove from stage
    if (this.engine && this.engine.app && this.container.parent) {
      this.engine.app.stage.removeChild(this.container);
      console.log("🔧 DEBUG: Container removed from stage");
    }

    // Clean up input handlers
    this.cleanupInputHandlers();

    console.log(`🔧 DEBUG: Scene exited: ${this.constructor.name}`);
  }

  update(deltaTime) {
    if (!this.isActive) return;

    // Update all sprites
    this.sprites.forEach((sprite) => {
      if (sprite.update && typeof sprite.update === "function") {
        sprite.update(deltaTime);
      }
    });
  }

  setupInputHandlers() {
    if (!this.engine || !this.engine.app) {
      console.log("🔧 DEBUG: Cannot setup input handlers - no engine/app");
      return;
    }

    console.log("🔧 DEBUG: Setting up input handlers");

    // Mouse/touch events
    this.container.on("pointerdown", (event) => this.onPointerDown(event));
    this.container.on("pointerup", (event) => this.onPointerUp(event));
    this.container.on("pointermove", (event) => this.onPointerMove(event));

    // Keyboard events
    document.addEventListener("keydown", this.onKeyDown.bind(this));
    document.addEventListener("keyup", this.onKeyUp.bind(this));

    // Make container interactive
    this.container.interactive = true;
    this.container.hitArea = this.engine.app.screen;

    console.log("🔧 DEBUG: Input handlers setup complete");
  }

  cleanupInputHandlers() {
    console.log("🔧 DEBUG: Cleaning up input handlers");

    if (this.container) {
      this.container.off("pointerdown");
      this.container.off("pointerup");
      this.container.off("pointermove");
      this.container.interactive = false;
    }

    document.removeEventListener("keydown", this.onKeyDown.bind(this));
    document.removeEventListener("keyup", this.onKeyUp.bind(this));
  }

  // Input event handlers
  onPointerDown(event) {
    this.mousePosition.x = event.global.x;
    this.mousePosition.y = event.global.y;
    this.mouseClicked = true;
    this.handleMouseDown(event);
  }

  onPointerUp(event) {
    this.mousePosition.x = event.global.x;
    this.mousePosition.y = event.global.y;
    this.handleMouseUp(event);
  }

  onPointerMove(event) {
    this.mousePosition.x = event.global.x;
    this.mousePosition.y = event.global.y;

    // Update UI mouse position display
    const mousePosElement = document.getElementById("mousePos");
    if (mousePosElement) {
      mousePosElement.textContent = `${Math.floor(
        this.mousePosition.x
      )}, ${Math.floor(this.mousePosition.y)}`;
    }

    this.handleMouseMove(event);
  }

  onKeyDown(event) {
    this.keys[event.code] = true;
    this.handleKeyDown(event);
  }

  onKeyUp(event) {
    this.keys[event.code] = false;
    this.handleKeyUp(event);
  }

  // Override these in subclasses
  handleMouseDown(event) {}
  handleMouseUp(event) {}
  handleMouseMove(event) {}
  handleKeyDown(event) {}
  handleKeyUp(event) {}

  // Sprite management with enhanced debugging
  addSprite(sprite, layer = "world") {
    console.log("🔧 DEBUG: addSprite called", {
      spriteName: sprite.name || "unnamed",
      layer: layer,
      hasLayers: !!this.layers,
      hasTargetLayer: !!(this.layers && this.layers[layer]),
      spriteVisible: sprite.visible,
    });

    if (!sprite) {
      console.error("🔧 ERROR: Cannot add null/undefined sprite");
      return null;
    }

    // Add to sprites array
    this.sprites.push(sprite);

    // Ensure sprite is visible
    sprite.visible = true;

    // Add to appropriate layer
    if (this.layers && this.layers[layer]) {
      this.layers[layer].addChild(sprite);
      console.log("🔧 DEBUG: Sprite added to layer", {
        layer: layer,
        layerChildren: this.layers[layer].children.length,
        spriteParent: !!sprite.parent,
      });
    } else {
      console.warn(
        "🔧 WARNING: Layer not found, adding to container directly",
        layer
      );
      this.container.addChild(sprite);
    }

    return sprite;
  }

  removeSprite(sprite) {
    console.log("🔧 DEBUG: removeSprite called", sprite.name || "unnamed");

    const index = this.sprites.indexOf(sprite);
    if (index > -1) {
      this.sprites.splice(index, 1);
    }

    if (sprite.parent) {
      sprite.parent.removeChild(sprite);
    }
  }

  // Graphics management
  addGraphics(graphics, layer = "world") {
    console.log("🔧 DEBUG: addGraphics called", {
      graphicsName: graphics.name || "unnamed",
      layer: layer,
    });

    this.graphics.push(graphics);

    if (this.layers && this.layers[layer]) {
      this.layers[layer].addChild(graphics);
    } else {
      this.container.addChild(graphics);
    }

    return graphics;
  }

  removeGraphics(graphics) {
    const index = this.graphics.indexOf(graphics);
    if (index > -1) {
      this.graphics.splice(index, 1);
    }

    if (graphics.parent) {
      graphics.parent.removeChild(graphics);
    }
  }

  // Utility methods
  createSimpleButton(text, x, y, onClick) {
    const button = new PIXI.Graphics();
    button.beginFill(0x3498db);
    button.drawRoundedRect(0, 0, 120, 40, 5);
    button.endFill();

    const buttonText = new PIXI.Text(text, {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      align: "center",
    });

    buttonText.anchor.set(0.5);
    buttonText.x = 60;
    buttonText.y = 20;

    button.addChild(buttonText);
    button.x = x;
    button.y = y;
    button.interactive = true;
    button.cursor = "pointer";

    button.on("pointerdown", onClick);

    return button;
  }

  // Camera/view management
  setCameraPosition(x, y) {
    this.layers.world.x = -x;
    this.layers.world.y = -y;
  }

  getCameraPosition() {
    return {
      x: -this.layers.world.x,
      y: -this.layers.world.y,
    };
  }

  // Debug methods
  debugFullState() {
    console.group("🔧 FULL PIXISCENE DEBUG STATE");
    console.log("Scene State:", {
      isActive: this.isActive,
      hasEngine: !!this.engine,
      containerVisible: this.container?.visible,
      containerChildren: this.container?.children?.length,
      containerParent: !!this.container?.parent,
    });

    console.log("Layer States:", {
      background: {
        visible: this.layers.background?.visible,
        children: this.layers.background?.children?.length,
      },
      world: {
        visible: this.layers.world?.visible,
        children: this.layers.world?.children?.length,
      },
      ui: {
        visible: this.layers.ui?.visible,
        children: this.layers.ui?.children?.length,
      },
      effects: {
        visible: this.layers.effects?.visible,
        children: this.layers.effects?.children?.length,
      },
    });

    console.log("Sprites:", this.sprites.length);
    console.log("Graphics:", this.graphics.length);
    console.groupEnd();
  }

  // Cleanup
  destroy() {
    console.log("🔧 DEBUG: PixiScene destroy called");

    this.onExit();

    // Clean up sprites
    this.sprites.forEach((sprite) => {
      if (sprite.destroy) {
        sprite.destroy();
      }
    });
    this.sprites = [];

    // Clean up graphics
    this.graphics.forEach((graphics) => {
      if (graphics.destroy) {
        graphics.destroy();
      }
    });
    this.graphics = [];

    // Clean up container
    if (this.container) {
      this.container.destroy({ children: true });
    }

    console.log(`🔧 DEBUG: Scene destroyed: ${this.constructor.name}`);
  }
}
