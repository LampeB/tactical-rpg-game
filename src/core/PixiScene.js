// src/core/PixiScene.js - Enhanced version with comprehensive responsive layout support
export class PixiScene {
  constructor() {
    console.log("🔧 DEBUG: PixiScene constructor called");

    this.engine = null;
    this.sprites = [];
    this.graphics = [];
    this.isActive = false;

    // Viewport and responsive properties
    this.viewportWidth = 0;
    this.viewportHeight = 0;
    this.aspectRatio = 1;
    this.baseWidth = 1200; // Reference width for scaling calculations
    this.baseHeight = 800; // Reference height for scaling calculations
    this.scaleFactor = 1;
    this.isMobile = false;
    this.isLandscape = true;

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

    // Responsive positioning cache
    this.responsiveElements = new Map();
    
    // Resize handlers
    this.resizeHandlers = [];
  }

  setEngine(engine) {
    console.log("🔧 DEBUG: setEngine called", !!engine);
    this.engine = engine;
    
    // Initialize viewport properties
    if (engine) {
      this.updateViewportProperties();
    }
  }

  onEnter() {
    console.log("🔧 DEBUG: PixiScene onEnter called");

    this.isActive = true;

    // Update viewport properties when entering
    this.updateViewportProperties();

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

    // Update hit areas and responsive elements
    this.updateHitAreas();
    this.updateResponsiveElements();

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

    // Clear responsive elements cache
    this.responsiveElements.clear();

    // Clear resize handlers
    this.resizeHandlers = [];

    console.log(`🔧 DEBUG: Scene exited: ${this.constructor.name}`);
  }

  // ============= RESPONSIVE LAYOUT SYSTEM =============

  /**
   * Handle viewport resize - called by engine when window resizes
   * Override this in subclasses for custom resize behavior
   */
  onResize(newWidth, newHeight) {
    console.log(`🔧 DEBUG: onResize called: ${newWidth}x${newHeight}`);
    
    // Update viewport properties
    this.updateViewportProperties(newWidth, newHeight);
    
    // Update hit areas
    this.updateHitAreas();
    
    // Update responsive elements
    this.updateResponsiveElements();
    
    // Trigger resize handlers
    this.triggerResizeHandlers(newWidth, newHeight);
    
    console.log(`🔧 DEBUG: Scene resize complete for ${this.constructor.name}`);
  }

  /**
   * Update viewport properties based on engine or provided dimensions
   */
  updateViewportProperties(width = null, height = null) {
    if (this.engine) {
      this.viewportWidth = width || this.engine.width;
      this.viewportHeight = height || this.engine.height;
      this.isMobile = this.engine.isMobile ? this.engine.isMobile() : false;
      this.isLandscape = this.engine.isLandscape ? this.engine.isLandscape() : true;
    } else {
      this.viewportWidth = width || window.innerWidth;
      this.viewportHeight = height || window.innerHeight;
      this.isMobile = window.innerWidth <= 768;
      this.isLandscape = window.innerWidth > window.innerHeight;
    }

    this.aspectRatio = this.viewportWidth / this.viewportHeight;
    this.scaleFactor = Math.min(
      this.viewportWidth / this.baseWidth,
      this.viewportHeight / this.baseHeight
    );

    console.log("🔧 DEBUG: Viewport properties updated", {
      width: this.viewportWidth,
      height: this.viewportHeight,
      aspectRatio: this.aspectRatio.toFixed(2),
      scaleFactor: this.scaleFactor.toFixed(2),
      isMobile: this.isMobile,
      isLandscape: this.isLandscape,
    });
  }

  /**
   * Update hit areas for all interactive containers
   */
  updateHitAreas() {
    if (!this.engine || !this.engine.app) return;

    // Update main container hit area
    this.container.hitArea = new PIXI.Rectangle(0, 0, this.viewportWidth, this.viewportHeight);

    // Update layer hit areas
    Object.values(this.layers).forEach(layer => {
      if (layer.interactive) {
        layer.hitArea = new PIXI.Rectangle(0, 0, this.viewportWidth, this.viewportHeight);
      }
    });

    console.log("🔧 DEBUG: Hit areas updated", {
      containerHitArea: !!this.container.hitArea,
      dimensions: `${this.viewportWidth}x${this.viewportHeight}`,
    });
  }

  /**
   * Update positions of responsive elements
   */
  updateResponsiveElements() {
    this.responsiveElements.forEach((config, element) => {
      this.applyResponsivePosition(element, config);
    });

    console.log(`🔧 DEBUG: Updated ${this.responsiveElements.size} responsive elements`);
  }

  /**
   * Apply responsive positioning to an element
   */
  applyResponsivePosition(element, config) {
    const { anchor, offset, scale, minScale, maxScale } = config;

    // Calculate position based on anchor
    let x = 0, y = 0;

    switch (anchor.x) {
      case 'left': x = 0; break;
      case 'center': x = this.viewportWidth / 2; break;
      case 'right': x = this.viewportWidth; break;
      default: x = this.viewportWidth * anchor.x; break;
    }

    switch (anchor.y) {
      case 'top': y = 0; break;
      case 'center': y = this.viewportHeight / 2; break;
      case 'bottom': y = this.viewportHeight; break;
      default: y = this.viewportHeight * anchor.y; break;
    }

    // Apply offset
    x += offset.x * this.scaleFactor;
    y += offset.y * this.scaleFactor;

    // Update element position
    element.x = x;
    element.y = y;

    // Apply scaling if enabled
    if (scale) {
      let elementScale = this.scaleFactor;
      if (minScale !== undefined) elementScale = Math.max(elementScale, minScale);
      if (maxScale !== undefined) elementScale = Math.min(elementScale, maxScale);
      
      element.scale.set(elementScale);
    }
  }

  /**
   * Trigger all registered resize handlers
   */
  triggerResizeHandlers(newWidth, newHeight) {
    this.resizeHandlers.forEach(handler => {
      try {
        handler(newWidth, newHeight);
      } catch (error) {
        console.error("🔧 ERROR: Resize handler failed:", error);
      }
    });
  }

  // ============= RESPONSIVE POSITIONING HELPERS =============

  /**
   * Register an element for responsive positioning
   */
  makeResponsive(element, config = {}) {
    const defaultConfig = {
      anchor: { x: 'left', y: 'top' },
      offset: { x: 0, y: 0 },
      scale: false,
      minScale: 0.5,
      maxScale: 2.0,
    };

    const finalConfig = { ...defaultConfig, ...config };
    this.responsiveElements.set(element, finalConfig);
    
    // Apply initial positioning
    this.applyResponsivePosition(element, finalConfig);

    console.log("🔧 DEBUG: Element made responsive", {
      elementName: element.name || "unnamed",
      anchor: finalConfig.anchor,
      offset: finalConfig.offset,
    });

    return element;
  }

  /**
   * Remove responsive positioning from an element
   */
  removeResponsive(element) {
    return this.responsiveElements.delete(element);
  }

  /**
   * Add a resize handler function
   */
  addResizeHandler(handler) {
    this.resizeHandlers.push(handler);
  }

  /**
   * Remove a resize handler function
   */
  removeResizeHandler(handler) {
    const index = this.resizeHandlers.indexOf(handler);
    if (index > -1) {
      this.resizeHandlers.splice(index, 1);
    }
  }

  // ============= VIEWPORT UTILITIES =============

  /**
   * Get viewport-relative coordinates
   */
  getViewportCoordinates(x, y) {
    return {
      x: x / this.viewportWidth,
      y: y / this.viewportHeight,
    };
  }

  /**
   * Get absolute coordinates from viewport-relative coordinates
   */
  getAbsoluteCoordinates(relativeX, relativeY) {
    return {
      x: relativeX * this.viewportWidth,
      y: relativeY * this.viewportHeight,
    };
  }

  /**
   * Get scaled size based on current scale factor
   */
  getScaledSize(baseSize) {
    return baseSize * this.scaleFactor;
  }

  /**
   * Get responsive font size
   */
  getResponsiveFontSize(baseSize) {
    let size = baseSize * this.scaleFactor;
    
    // Clamp font size for readability
    if (this.isMobile) {
      size = Math.max(size, 10); // Minimum 10px on mobile
      size = Math.min(size, 24); // Maximum 24px on mobile
    } else {
      size = Math.max(size, 12); // Minimum 12px on desktop
      size = Math.min(size, 32); // Maximum 32px on desktop
    }
    
    return Math.round(size);
  }

  /**
   * Get responsive padding/margin
   */
  getResponsivePadding(basePadding) {
    let padding = basePadding * this.scaleFactor;
    
    // Adjust for mobile
    if (this.isMobile) {
      padding = Math.max(padding, 8); // Minimum padding on mobile
    }
    
    return Math.round(padding);
  }

  /**
   * Check if point is within viewport bounds
   */
  isPointInViewport(x, y) {
    return x >= 0 && x <= this.viewportWidth && y >= 0 && y <= this.viewportHeight;
  }

  /**
   * Clamp position to viewport bounds
   */
  clampToViewport(x, y, elementWidth = 0, elementHeight = 0) {
    return {
      x: Math.max(0, Math.min(this.viewportWidth - elementWidth, x)),
      y: Math.max(0, Math.min(this.viewportHeight - elementHeight, y)),
    };
  }

  /**
   * Get safe area coordinates (avoiding notches, navigation bars, etc.)
   */
  getSafeAreaBounds() {
    // Default safe area - can be enhanced with device-specific detection
    const safeMargin = this.isMobile ? 20 : 0;
    
    return {
      left: safeMargin,
      top: safeMargin,
      right: this.viewportWidth - safeMargin,
      bottom: this.viewportHeight - safeMargin,
      width: this.viewportWidth - (safeMargin * 2),
      height: this.viewportHeight - (safeMargin * 2),
    };
  }

  // ============= ENHANCED INPUT HANDLING =============

  setupInputHandlers() {
    if (!this.engine || !this.engine.app) {
      console.log("🔧 DEBUG: Cannot setup input handlers - no engine/app");
      return;
    }

    console.log("🔧 DEBUG: Setting up responsive input handlers");

    // Mouse/touch events with coordinate normalization
    this.container.on("pointerdown", (event) => this.onPointerDown(event));
    this.container.on("pointerup", (event) => this.onPointerUp(event));
    this.container.on("pointermove", (event) => this.onPointerMove(event));

    // Keyboard events
    document.addEventListener("keydown", this.onKeyDown.bind(this));
    document.addEventListener("keyup", this.onKeyUp.bind(this));

    // Make container interactive
    this.container.interactive = true;
    this.updateHitAreas();

    console.log("🔧 DEBUG: Responsive input handlers setup complete");
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

  // Input event handlers with responsive coordinate handling
  onPointerDown(event) {
    const normalizedCoords = this.normalizeCoordinates(event.global);
    this.mousePosition.x = normalizedCoords.x;
    this.mousePosition.y = normalizedCoords.y;
    this.mouseClicked = true;
    
    // Create enhanced event object
    const enhancedEvent = {
      ...event,
      normalizedGlobal: normalizedCoords,
      viewportRelative: this.getViewportCoordinates(normalizedCoords.x, normalizedCoords.y),
      scaleFactor: this.scaleFactor,
      isMobile: this.isMobile,
    };
    
    this.handleMouseDown(enhancedEvent);
  }

  onPointerUp(event) {
    const normalizedCoords = this.normalizeCoordinates(event.global);
    this.mousePosition.x = normalizedCoords.x;
    this.mousePosition.y = normalizedCoords.y;
    
    const enhancedEvent = {
      ...event,
      normalizedGlobal: normalizedCoords,
      viewportRelative: this.getViewportCoordinates(normalizedCoords.x, normalizedCoords.y),
      scaleFactor: this.scaleFactor,
      isMobile: this.isMobile,
    };
    
    this.handleMouseUp(enhancedEvent);
  }

  onPointerMove(event) {
    const normalizedCoords = this.normalizeCoordinates(event.global);
    this.mousePosition.x = normalizedCoords.x;
    this.mousePosition.y = normalizedCoords.y;

    // Update UI mouse position display
    const mousePosElement = document.getElementById("mousePos");
    if (mousePosElement) {
      mousePosElement.textContent = `${Math.floor(normalizedCoords.x)}, ${Math.floor(normalizedCoords.y)}`;
    }

    const enhancedEvent = {
      ...event,
      normalizedGlobal: normalizedCoords,
      viewportRelative: this.getViewportCoordinates(normalizedCoords.x, normalizedCoords.y),
      scaleFactor: this.scaleFactor,
      isMobile: this.isMobile,
    };

    this.handleMouseMove(enhancedEvent);
  }

  onKeyDown(event) {
    this.keys[event.code] = true;
    
    const enhancedEvent = {
      ...event,
      scaleFactor: this.scaleFactor,
      isMobile: this.isMobile,
      viewportWidth: this.viewportWidth,
      viewportHeight: this.viewportHeight,
    };
    
    this.handleKeyDown(enhancedEvent);
  }

  onKeyUp(event) {
    this.keys[event.code] = false;
    
    const enhancedEvent = {
      ...event,
      scaleFactor: this.scaleFactor,
      isMobile: this.isMobile,
      viewportWidth: this.viewportWidth,
      viewportHeight: this.viewportHeight,
    };
    
    this.handleKeyUp(enhancedEvent);
  }

  /**
   * Normalize coordinates for different screen sizes and DPI
   */
  normalizeCoordinates(globalCoords) {
    // Account for device pixel ratio and canvas scaling
    const rect = this.engine.app.view.getBoundingClientRect();
    const scaleX = this.engine.app.view.width / rect.width;
    const scaleY = this.engine.app.view.height / rect.height;

    return {
      x: globalCoords.x * scaleX,
      y: globalCoords.y * scaleY,
    };
  }

  // Override these in subclasses for custom input handling
  handleMouseDown(event) {}
  handleMouseUp(event) {}
  handleMouseMove(event) {}
  handleKeyDown(event) {}
  handleKeyUp(event) {}

  // ============= SPRITE MANAGEMENT WITH RESPONSIVE SUPPORT =============

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

    // Remove from responsive elements if present
    this.removeResponsive(sprite);

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

    // Remove from responsive elements if present
    this.removeResponsive(graphics);

    if (graphics.parent) {
      graphics.parent.removeChild(graphics);
    }
  }

  // ============= UTILITY METHODS =============

  update(deltaTime) {
    if (!this.isActive) return;

    // Update all sprites
    this.sprites.forEach((sprite) => {
      if (sprite.update && typeof sprite.update === "function") {
        sprite.update(deltaTime);
      }
    });
  }

  createSimpleButton(text, x, y, onClick, responsive = false) {
    const button = new PIXI.Graphics();
    const buttonWidth = this.getScaledSize(120);
    const buttonHeight = this.getScaledSize(40);
    
    button.beginFill(0x3498db);
    button.drawRoundedRect(0, 0, buttonWidth, buttonHeight, 5);
    button.endFill();

    const buttonText = new PIXI.Text(text, {
      fontFamily: "Arial",
      fontSize: this.getResponsiveFontSize(14),
      fill: 0xffffff,
      align: "center",
    });

    buttonText.anchor.set(0.5);
    buttonText.x = buttonWidth / 2;
    buttonText.y = buttonHeight / 2;

    button.addChild(buttonText);
    button.interactive = true;
    button.cursor = "pointer";

    button.on("pointerdown", onClick);

    if (responsive) {
      this.makeResponsive(button, {
        anchor: { x: 'left', y: 'top' },
        offset: { x, y },
        scale: true,
      });
    } else {
      button.x = x;
      button.y = y;
    }

    return button;
  }

  // Camera/view management with responsive support
  setCameraPosition(x, y) {
    // Scale camera movement based on viewport
    const scaledX = x * this.scaleFactor;
    const scaledY = y * this.scaleFactor;
    
    this.layers.world.x = -scaledX;
    this.layers.world.y = -scaledY;
    this.layers.background.x = -scaledX * 0.5; // Parallax effect
    this.layers.background.y = -scaledY * 0.5;
  }

  getCameraPosition() {
    return {
      x: -this.layers.world.x / this.scaleFactor,
      y: -this.layers.world.y / this.scaleFactor,
    };
  }

  // ============= DEBUG METHODS =============

  debugFullState() {
    console.group("🔧 FULL PIXISCENE DEBUG STATE");
    console.log("Scene State:", {
      isActive: this.isActive,
      hasEngine: !!this.engine,
      containerVisible: this.container?.visible,
      containerChildren: this.container?.children?.length,
      containerParent: !!this.container?.parent,
    });

    console.log("Viewport State:", {
      width: this.viewportWidth,
      height: this.viewportHeight,
      aspectRatio: this.aspectRatio.toFixed(2),
      scaleFactor: this.scaleFactor.toFixed(2),
      isMobile: this.isMobile,
      isLandscape: this.isLandscape,
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

    console.log("Responsive Elements:", this.responsiveElements.size);
    console.log("Resize Handlers:", this.resizeHandlers.length);
    console.log("Sprites:", this.sprites.length);
    console.log("Graphics:", this.graphics.length);
    console.groupEnd();
  }

  // ============= CLEANUP =============

  destroy() {
    console.log("🔧 DEBUG: PixiScene destroy called");

    this.onExit();

    // Clean up responsive elements
    this.responsiveElements.clear();
    this.resizeHandlers = [];

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