import { HybridInventoryScene } from "../core/HybridInventoryScene.js";
import { ShapeHelper } from "../utils/ShapeHelper.js";

export class PixiLootScene extends HybridInventoryScene {
  constructor() {
    super();
    
    // Loot-specific properties
    this.lootData = null;
    this.returnScene = "world";
    this.title = "💎 TREASURE FOUND!";
    this.subtitle = "Drag items to character inventory or storage";
    this.context = null;
    this.showStats = false;
    this.stats = null;
    
    // Loot interface state
    this.draggedLootItem = null;
    this.lootPreview = null;
    
    // Responsive layout properties
    this.layout = {
      isPortrait: false,
      isMobile: false,
      scale: 1,
      padding: 20,
    };

    // Layout breakpoints
    this.breakpoints = {
      mobile: 768,
      tablet: 1024,
      desktop: 1200,
    };

    // Original mini grid size for scaling
    this.baseMiniGridSize = 20;
  }

  setLootData(lootData, options = {}) {
    this.lootData = lootData;
    this.returnScene = options.returnScene || "world";
    this.title = options.title || "💎 TREASURE FOUND!";
    this.subtitle = options.subtitle || "Drag items to character inventory or storage";
    this.showStats = options.showStats || false;
    this.stats = options.stats || null;
    this.context = options.context;

    console.log("🎁 Loot scene configured:", {
      itemCount: this.lootData?.length || 0,
      returnScene: this.returnScene,
      showStats: this.showStats
    });
  }

  onEnter() {
    super.onEnter();
    
    // Calculate responsive layout
    this.calculateLayout();
    
    // Create responsive loot interface
    this.createLootInterface();
    
    // Update game mode display
    const gameModeBtn = document.getElementById("gameMode");
    if (gameModeBtn) {
      gameModeBtn.textContent = "💎 LOOT";
    }

    // Handle window resize
    window.addEventListener("resize", () => this.handleResize());

    console.log("💎 Responsive loot scene entered");
  }

  onExit() {
    // Clean up resize handler
    window.removeEventListener("resize", this.handleResize);
    
    super.onExit();
  }

  calculateLayout() {
    const width = this.engine.width;
    const height = this.engine.height;
    
    // Determine device type and orientation
    this.layout.isPortrait = height > width;
    this.layout.isMobile = width < this.breakpoints.mobile;
    this.layout.isTablet = width >= this.breakpoints.mobile && width < this.breakpoints.desktop;
    this.layout.isDesktop = width >= this.breakpoints.desktop;
    
    // Calculate scaling factor
    this.layout.scale = Math.min(width / 1200, height / 800);
    this.layout.scale = Math.max(0.6, Math.min(1.2, this.layout.scale));
    
    // Adjust padding based on screen size
    this.layout.padding = this.layout.isMobile ? 15 : 25;
    
    // Calculate responsive panel dimensions
    const maxPanelWidth = width - (this.layout.padding * 2);
    const maxPanelHeight = height - (this.layout.padding * 2);
    
    this.layout.dimensions = {
      // Main panel
      panel: {
        width: Math.min(this.layout.isMobile ? maxPanelWidth : 900, maxPanelWidth),
        height: Math.min(
          this.showStats ? (this.layout.isMobile ? maxPanelHeight : 650) : 
          (this.layout.isMobile ? maxPanelHeight : 600), 
          maxPanelHeight
        ),
      },
      
      // Preview areas
      characterGrid: {
        cols: this.layout.isMobile ? 8 : 10,
        rows: this.layout.isMobile ? 6 : 8,
        cellSize: Math.max(15, this.baseMiniGridSize * this.layout.scale),
        x: this.layout.isMobile ? 20 : 30,
        y: this.layout.isMobile ? 80 : 100,
      },
      
      storageList: {
        width: this.layout.isMobile ? 180 : 200,
        height: this.layout.isMobile ? 120 : 160,
        x: this.layout.isMobile ? 220 : 300,
        y: this.layout.isMobile ? 80 : 100,
      },
      
      // Loot items area
      lootArea: {
        x: this.layout.isMobile ? 20 : 450,
        y: this.layout.isMobile ? 220 : 100,
        itemSize: Math.max(60, 80 * this.layout.scale),
        spacing: this.layout.isMobile ? 10 : 15,
        itemsPerRow: this.layout.isMobile ? 3 : 4,
      },
      
      // Buttons
      closeButton: {
        width: Math.max(80, 100 * this.layout.scale),
        height: Math.max(30, 35 * this.layout.scale),
      },
    };
    
    // Update mini grid size for consistent scaling
    this.miniGridSize = this.layout.dimensions.characterGrid.cellSize;
    
    // Font scaling
    this.layout.fonts = {
      title: Math.max(18, Math.min(28, 24 * this.layout.scale)),
      subtitle: Math.max(12, Math.min(16, 14 * this.layout.scale)),
      body: Math.max(10, Math.min(14, 12 * this.layout.scale)),
      small: Math.max(8, Math.min(11, 10 * this.layout.scale)),
      button: Math.max(10, Math.min(14, 12 * this.layout.scale)),
    };

    // Update preview areas based on calculated dimensions
    this.previewAreas = {
      characterGrid: {
        x: this.layout.dimensions.characterGrid.x,
        y: this.layout.dimensions.characterGrid.y,
        cols: this.layout.dimensions.characterGrid.cols,
        rows: this.layout.dimensions.characterGrid.rows,
      },
      storageList: {
        x: this.layout.dimensions.storageList.x,
        y: this.layout.dimensions.storageList.y,
        width: this.layout.dimensions.storageList.width,
        height: this.layout.dimensions.storageList.height,
      },
    };

    console.log("Loot scene layout calculated:", this.layout);
  }

  handleResize() {
    if (!this.isActive) return;
    
    // Recalculate layout
    this.calculateLayout();
    
    // Clear and recreate interface
    this.clearLootInterface();
    this.createLootInterface();
    
    console.log("Loot scene resized and updated");
  }

  clearLootInterface() {
    // Remove all UI elements
    this.layers.effects.removeChildren();
    this.overlay = null;
    this.panel = null;
    this.currentLootInterface = null;
    this.lootPreview = null;
    this.draggedLootItem = null;
  }

  createLootInterface() {
    console.log("🎨 Creating responsive loot interface");
    
    // Create overlay
    const overlay = new PIXI.Graphics();
    overlay.beginFill(0x000000, 0.8);
    overlay.drawRect(0, 0, this.engine.width, this.engine.height);
    overlay.endFill();
    overlay.interactive = true;

    // Create main panel
    const panelDims = this.layout.dimensions.panel;
    const panel = new PIXI.Graphics();

    const panelColor = this.title.includes("VICTORY") ? 0x2e7d32 : 0x2c3e50;
    const borderColor = this.title.includes("VICTORY") ? 0x4caf50 : 0xf39c12;

    panel.beginFill(panelColor);
    panel.drawRoundedRect(0, 0, panelDims.width, panelDims.height, 15);
    panel.endFill();
    panel.lineStyle(3, borderColor);
    panel.drawRoundedRect(0, 0, panelDims.width, panelDims.height, 15);

    // Center the panel
    panel.x = (this.engine.width - panelDims.width) / 2;
    panel.y = (this.engine.height - panelDims.height) / 2;

    this.overlay = overlay;
    this.panel = panel;

    // Build interface components
    this.createTitle(panel, panelDims.width);
    if (this.showStats) this.createStats(panel, panelDims.width);
    this.createInstructions(panel, panelDims.width);
    this.createInventoryPreviews(panel);
    this.createLootItems(panel);
    this.createCloseButton(panel, panelDims.width, panelDims.height);

    overlay.addChild(panel);
    this.addSprite(overlay, "effects");
    
    console.log("✅ Responsive loot interface created");
  }

  createTitle(panel, panelWidth) {
    const title = new PIXI.Text(this.title, {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.title,
      fill: 0xffd700,
      fontWeight: "bold",
      align: "center",
    });
    title.anchor.set(0.5);
    title.x = panelWidth / 2;
    title.y = 30;
    panel.addChild(title);
  }

  createStats(panel, panelWidth) {
    if (!this.showStats || !this.stats) return;

    const statsText = new PIXI.Text(
      `Battle completed in ${this.stats.turnCount} turns\n` +
      `Damage dealt: ${this.stats.damageDealt}\n` +
      `Skills used: ${this.stats.skillsUsed}`,
      {
        fontFamily: "Arial",
        fontSize: this.layout.fonts.body,
        fill: 0xffffff,
        align: "center",
        lineHeight: Math.max(16, 18 * this.layout.scale),
      }
    );
    statsText.anchor.set(0.5);
    statsText.x = panelWidth / 2;
    statsText.y = 70;
    panel.addChild(statsText);
  }

  createInstructions(panel, panelWidth) {
    const instructions = new PIXI.Text(this.subtitle, {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.subtitle,
      fill: 0xecf0f1,
      align: "center",
      wordWrap: true,
      wordWrapWidth: panelWidth - 40,
    });
    instructions.anchor.set(0.5);
    instructions.x = panelWidth / 2;
    instructions.y = this.showStats ? 110 : 60;
    panel.addChild(instructions);
  }

  createInventoryPreviews(panel) {
    const baseY = this.showStats ? 30 : 0;
    
    // Character inventory preview
    this.createCharacterGridPreview(panel, baseY);
    
    // Storage preview
    this.createStorageListPreview(panel, baseY);
  }

  createCharacterGridPreview(panel, baseY) {
    const preview = this.layout.dimensions.characterGrid;
    
    // Label
    const label = new PIXI.Text("🎒 Character Inventory", {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.body,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    label.x = preview.x;
    label.y = preview.y - 20 + baseY;
    panel.addChild(label);

    // Grid background
    const gridBg = new PIXI.Graphics();
    const gridWidth = preview.cols * preview.cellSize;
    const gridHeight = preview.rows * preview.cellSize;
    
    gridBg.beginFill(0x2ecc71, 0.2);
    gridBg.drawRect(0, 0, gridWidth, gridHeight);
    gridBg.endFill();
    
    // Grid lines
    gridBg.lineStyle(1, 0x2ecc71, 0.5);
    for (let col = 0; col <= preview.cols; col++) {
      const x = col * preview.cellSize;
      gridBg.moveTo(x, 0);
      gridBg.lineTo(x, gridHeight);
    }
    for (let row = 0; row <= preview.rows; row++) {
      const y = row * preview.cellSize;
      gridBg.moveTo(0, y);
      gridBg.lineTo(gridWidth, y);
    }
    
    gridBg.x = preview.x;
    gridBg.y = preview.y + baseY;
    panel.addChild(gridBg);

    // Show existing items in character inventory
    this.showCharacterInventoryItems(panel, preview, baseY);
  }

  createStorageListPreview(panel, baseY) {
    const preview = this.layout.dimensions.storageList;
    
    // Label
    const label = new PIXI.Text("📦 Storage", {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.body,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    label.x = preview.x;
    label.y = preview.y - 20 + baseY;
    panel.addChild(label);

    // Storage background
    const storageBg = new PIXI.Graphics();
    storageBg.beginFill(0x8e44ad, 0.2);
    storageBg.drawRect(0, 0, preview.width, preview.height);
    storageBg.endFill();
    storageBg.lineStyle(1, 0x9b59b6);
    storageBg.drawRect(0, 0, preview.width, preview.height);
    
    storageBg.x = preview.x;
    storageBg.y = preview.y + baseY;
    panel.addChild(storageBg);

    // Show storage item count
    this.showStorageInfo(panel, preview, baseY);
  }

  showCharacterInventoryItems(panel, preview, baseY) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene || !inventoryScene.characterItems) return;

    inventoryScene.characterItems.forEach(item => {
      if (item.gridX >= 0 && item.gridY >= 0) {
        // Create mini version of the item shape
        const miniItem = new PIXI.Graphics();
        const shapePattern = item.shapePattern || [[0, 0]];
        
        shapePattern.forEach(([cellX, cellY]) => {
          const cellDrawX = (item.gridX + cellX) * preview.cellSize;
          const cellDrawY = (item.gridY + cellY) * preview.cellSize;
          
          // Only draw if within preview bounds
          if (cellDrawX < preview.cols * preview.cellSize && 
              cellDrawY < preview.rows * preview.cellSize) {
            miniItem.beginFill(item.color || 0x3498db);
            miniItem.drawRect(
              cellDrawX + 1,
              cellDrawY + 1,
              preview.cellSize - 2,
              preview.cellSize - 2
            );
            miniItem.endFill();
          }
        });
        
        miniItem.x = preview.x;
        miniItem.y = preview.y + baseY;
        panel.addChild(miniItem);
      }
    });
  }

  showStorageInfo(panel, preview, baseY) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene || !inventoryScene.storageItems) return;

    const itemCount = inventoryScene.storageItems.length;
    const totalQuantity = inventoryScene.storageItems.reduce(
      (sum, item) => sum + (item.quantity || 1), 0
    );

    const infoText = new PIXI.Text(
      `${itemCount} types\n${totalQuantity} items\n\n(Drag here for\nstorage)`,
      {
        fontFamily: "Arial",
        fontSize: this.layout.fonts.small,
        fill: 0xecf0f1,
        align: "center",
        lineHeight: Math.max(12, 14 * this.layout.scale),
      }
    );
    infoText.anchor.set(0.5);
    infoText.x = preview.x + preview.width / 2;
    infoText.y = preview.y + preview.height / 2 + baseY;
    panel.addChild(infoText);
  }

  createLootItems(panel) {
    const lootDims = this.layout.dimensions.lootArea;
    const baseY = this.showStats ? 30 : 0;

    // Loot area label
    const lootLabel = new PIXI.Text(
      this.title.includes("VICTORY") ? "⚔️ Battle Spoils" : "🎁 Found Items",
      {
        fontFamily: "Arial",
        fontSize: this.layout.fonts.body,
        fill: 0xffd700,
        fontWeight: "bold",
      }
    );
    lootLabel.x = lootDims.x;
    lootLabel.y = lootDims.y - 20 + baseY;
    panel.addChild(lootLabel);

    // Create loot items
    if (this.lootData && this.lootData.length > 0) {
      this.lootData.forEach((itemData, index) => {
        const lootItem = this.createDraggableLootItem(itemData, index);
        
        // Calculate position based on responsive layout
        const col = index % lootDims.itemsPerRow;
        const row = Math.floor(index / lootDims.itemsPerRow);
        
        lootItem.x = lootDims.x + col * (lootDims.itemSize + lootDims.spacing);
        lootItem.y = lootDims.y + baseY + row * (lootDims.itemSize + lootDims.spacing);
        
        panel.addChild(lootItem);
      });
    } else {
      // No loot message
      const noLootText = new PIXI.Text("No items found", {
        fontFamily: "Arial",
        fontSize: this.layout.fonts.body,
        fill: 0x95a5a6,
        align: "center",
      });
      noLootText.anchor.set(0.5);
      noLootText.x = lootDims.x + 100;
      noLootText.y = lootDims.y + 50 + baseY;
      panel.addChild(noLootText);
    }
  }

  createDraggableLootItem(itemData, index) {
    const itemContainer = new PIXI.Container();
    const itemSize = this.layout.dimensions.lootArea.itemSize;

    // Item background
    const bg = new PIXI.Graphics();
    bg.beginFill(itemData.color || 0x95a5a6);
    bg.drawRoundedRect(0, 0, itemSize, itemSize, 8);
    bg.endFill();
    bg.lineStyle(2, 0x2c3e50);
    bg.drawRoundedRect(0, 0, itemSize, itemSize, 8);
    itemContainer.addChild(bg);

    // Item name
    const nameText = new PIXI.Text(itemData.name, {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.small,
      fill: 0xffffff,
      align: "center",
      fontWeight: "bold",
      wordWrap: true,
      wordWrapWidth: itemSize - 10,
    });
    nameText.anchor.set(0.5);
    nameText.x = itemSize / 2;
    nameText.y = itemSize / 2 - 8;
    itemContainer.addChild(nameText);

    // Item type
    const typeText = new PIXI.Text(itemData.type, {
      fontFamily: "Arial",
      fontSize: Math.max(8, this.layout.fonts.small - 2),
      fill: 0xbdc3c7,
      align: "center",
    });
    typeText.anchor.set(0.5);
    typeText.x = itemSize / 2;
    typeText.y = itemSize / 2 + 8;
    itemContainer.addChild(typeText);

    // Quantity if > 1
    if (itemData.quantity && itemData.quantity > 1) {
      const quantitySize = Math.max(8, 10 * this.layout.scale);
      const quantityBg = new PIXI.Graphics();
      quantityBg.beginFill(0xf39c12);
      quantityBg.drawCircle(0, 0, quantitySize);
      quantityBg.endFill();
      quantityBg.x = itemSize - quantitySize - 2;
      quantityBg.y = quantitySize + 2;
      itemContainer.addChild(quantityBg);

      const quantityText = new PIXI.Text(itemData.quantity.toString(), {
        fontFamily: "Arial",
        fontSize: Math.max(8, this.layout.fonts.small - 2),
        fill: 0xffffff,
        fontWeight: "bold",
        align: "center",
      });
      quantityText.anchor.set(0.5);
      quantityText.x = itemSize - quantitySize - 2;
      quantityText.y = quantitySize + 2;
      itemContainer.addChild(quantityText);
    }

    // Add special effects for valuable items
    if (itemData.type === "gem" || 
        itemData.name.includes("Medal") || 
        itemData.name.includes("Epic") ||
        itemData.name.includes("Legendary")) {
      
      const glowSize = Math.max(3, 3 * this.layout.scale);
      const glow = new PIXI.Graphics();
      glow.lineStyle(glowSize, 0xffd700, 0.6);
      glow.drawRoundedRect(-glowSize, -glowSize, itemSize + glowSize * 2, itemSize + glowSize * 2, 11);
      itemContainer.addChildAt(glow, 0);

      // Animate glow
      let time = Math.random() * Math.PI * 2;
      const animate = () => {
        time += 0.08;
        glow.alpha = 0.4 + Math.sin(time) * 0.4;
        if (this.isActive) {
          requestAnimationFrame(animate);
        }
      };
      animate();
    }

    // Store item data and make interactive
    itemContainer.itemData = itemData;
    itemContainer.originalX = itemContainer.x;
    itemContainer.originalY = itemContainer.y;
    itemContainer.interactive = true;
    itemContainer.cursor = "pointer";

    // Enhanced touch/mouse handling
    itemContainer.on("pointerdown", (event) => {
      this.startLootDragging(itemContainer, event);
    });

    // Touch-friendly hover effects
    itemContainer.on("pointerover", () => {
      if (!this.draggedLootItem) {
        itemContainer.scale.set(1.05);
      }
    });

    itemContainer.on("pointerout", () => {
      if (!this.draggedLootItem) {
        itemContainer.scale.set(1);
      }
    });

    return itemContainer;
  }

  createCloseButton(panel, panelWidth, panelHeight) {
    const btnDims = this.layout.dimensions.closeButton;
    const closeBtn = new PIXI.Graphics();
    
    closeBtn.beginFill(0xe74c3c);
    closeBtn.drawRoundedRect(0, 0, btnDims.width, btnDims.height, 5);
    closeBtn.endFill();
    closeBtn.lineStyle(1, 0xc0392b);
    closeBtn.drawRoundedRect(0, 0, btnDims.width, btnDims.height, 5);
    
    closeBtn.x = (panelWidth - btnDims.width) / 2;
    closeBtn.y = panelHeight - btnDims.height - 15;
    closeBtn.interactive = true;
    closeBtn.cursor = "pointer";

    const closeText = new PIXI.Text("Close", {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.button,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    closeText.anchor.set(0.5);
    closeText.x = btnDims.width / 2;
    closeText.y = btnDims.height / 2;
    closeBtn.addChild(closeText);

    closeBtn.on("pointerover", () => {
      closeBtn.tint = 0xcccccc;
    });

    closeBtn.on("pointerout", () => {
      closeBtn.tint = 0xffffff;
    });

    closeBtn.on("pointerdown", () => {
      this.engine.switchScene(this.returnScene);
    });

    panel.addChild(closeBtn);
  }

  // ============= DRAG AND DROP FOR LOOT =============

  startLootDragging(item, event) {
    console.log(`🖱️ Starting loot drag: ${item.itemData.name}`);
    
    this.draggedLootItem = item;
    item.alpha = 0.8;
    item.scale.set(1.1);

    // Store original position
    item.originalX = item.x;
    item.originalY = item.y;

    // Move to top of panel
    this.panel.removeChild(item);
    this.panel.addChild(item);

    // Calculate drag offset
    const localPos = this.panel.toLocal(event.global);
    item.dragOffsetX = localPos.x - item.x;
    item.dragOffsetY = localPos.y - item.y;

    // Setup mouse handlers with enhanced touch support
    const onMove = (event) => {
      if (this.draggedLootItem === item) {
        const localPos = this.panel.toLocal(event.global);
        item.x = localPos.x - item.dragOffsetX;
        item.y = localPos.y - item.dragOffsetY;
        
        // Show drop preview
        this.showLootDropPreview(item, localPos);
      }
    };

    const onEnd = (event) => {
      this.stopLootDragging(item, event);
      this.engine.app.stage.off("pointermove", onMove);
      this.engine.app.stage.off("pointerup", onEnd);
      this.engine.app.stage.off("pointerupoutside", onEnd);
    };

    this.engine.app.stage.on("pointermove", onMove);
    this.engine.app.stage.on("pointerup", onEnd);
    this.engine.app.stage.on("pointerupoutside", onEnd);
  }

  showLootDropPreview(item, localPos) {
    // Clear previous preview
    if (this.lootPreview) {
      this.panel.removeChild(this.lootPreview);
      this.lootPreview = null;
    }

    const baseY = this.showStats ? 30 : 0;
    
    // Check if over character grid
    const gridArea = this.layout.dimensions.characterGrid;
    const gridWidth = gridArea.cols * gridArea.cellSize;
    const gridHeight = gridArea.rows * gridArea.cellSize;
    
    if (localPos.x >= gridArea.x && 
        localPos.x <= gridArea.x + gridWidth &&
        localPos.y >= gridArea.y + baseY && 
        localPos.y <= gridArea.y + baseY + gridHeight) {
      
      // Show grid drop preview
      const preview = new PIXI.Graphics();
      preview.beginFill(0x2ecc71, 0.5);
      preview.drawRoundedRect(0, 0, gridWidth, gridHeight, 4);
      preview.endFill();
      preview.x = gridArea.x;
      preview.y = gridArea.y + baseY;
      
      this.panel.addChild(preview);
      this.lootPreview = preview;
      return;
    }

    // Check if over storage area
    const storageArea = this.layout.dimensions.storageList;
    if (localPos.x >= storageArea.x && 
        localPos.x <= storageArea.x + storageArea.width &&
        localPos.y >= storageArea.y + baseY && 
        localPos.y <= storageArea.y + baseY + storageArea.height) {
      
      // Show storage drop preview
      const preview = new PIXI.Graphics();
      preview.beginFill(0x9b59b6, 0.5);
      preview.drawRoundedRect(0, 0, storageArea.width, storageArea.height, 4);
      preview.endFill();
      preview.x = storageArea.x;
      preview.y = storageArea.y + baseY;
      
      this.panel.addChild(preview);
      this.lootPreview = preview;
    }
  }

  stopLootDragging(item, event) {
    if (!this.draggedLootItem || this.draggedLootItem !== item) return;

    console.log(`🖱️ Stopping loot drag: ${item.itemData.name}`);

    const localPos = this.panel.toLocal(event.global);
    const baseY = this.showStats ? 30 : 0;
    let transferred = false;

    // Check if dropped on character grid
    const gridArea = this.layout.dimensions.characterGrid;
    const gridWidth = gridArea.cols * gridArea.cellSize;
    const gridHeight = gridArea.rows * gridArea.cellSize;
    
    if (localPos.x >= gridArea.x && 
        localPos.x <= gridArea.x + gridWidth &&
        localPos.y >= gridArea.y + baseY && 
        localPos.y <= gridArea.y + baseY + gridHeight) {
      
      transferred = this.transferToCharacterInventory(item.itemData);
    }
    
    // Check if dropped on storage area
    else {
      const storageArea = this.layout.dimensions.storageList;
      if (localPos.x >= storageArea.x && 
          localPos.x <= storageArea.x + storageArea.width &&
          localPos.y >= storageArea.y + baseY && 
          localPos.y <= storageArea.y + baseY + storageArea.height) {
        
        transferred = this.transferToStorage(item.itemData);
      }
    }

    if (transferred) {
      // Remove item from loot interface
      this.panel.removeChild(item);
      this.showTransferMessage(item.itemData.name, transferred);
      
      // Remove from loot data
      const index = this.lootData.indexOf(item.itemData);
      if (index > -1) {
        this.lootData.splice(index, 1);
      }
    } else {
      // Return to original position
      item.x = item.originalX;
      item.y = item.originalY;
      item.alpha = 1;
      item.scale.set(1);
    }

    // Clear preview
    if (this.lootPreview) {
      this.panel.removeChild(this.lootPreview);
      this.lootPreview = null;
    }

    this.draggedLootItem = null;
  }

  transferToCharacterInventory(itemData) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene) {
      console.error("❌ Inventory scene not found!");
      return false;
    }

    console.log(`📦 Attempting to transfer ${itemData.name} to character inventory`);

    // Create the item
    const newItem = inventoryScene.createGridItem(itemData);
    
    // Try to find a place for it in the character grid
    for (let y = 0; y <= inventoryScene.characterGrid.rows - newItem.gridHeight; y++) {
      for (let x = 0; x <= inventoryScene.characterGrid.cols - newItem.gridWidth; x++) {
        if (inventoryScene.canPlaceInGrid(newItem, x, y)) {
          inventoryScene.placeInGrid(newItem, x, y);
          
          // Add to scene if it's currently active
          if (inventoryScene.isActive) {
            inventoryScene.addSprite(newItem, "world");
          }
          
          console.log(`✅ Transferred ${itemData.name} to character grid at (${x}, ${y})`);
          return "character";
        }
      }
    }

    // No space in character inventory, try storage instead
    inventoryScene.addToStorage(itemData);
    console.log(`📚 No space in character inventory, moved ${itemData.name} to storage`);
    return "storage";
  }

  transferToStorage(itemData) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene) {
      console.error("❌ Inventory scene not found!");
      return false;
    }

    console.log(`📚 Transferring ${itemData.name} to storage`);
    inventoryScene.addToStorage(itemData);
    return "storage";
  }

  showTransferMessage(itemName, destination) {
    const message = destination === "character" 
      ? `${itemName} added to character inventory`
      : `${itemName} added to storage`;
    
    console.log(`✅ ${message}`);
    
    // Create floating message
    const messageText = new PIXI.Text(message, {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.body,
      fill: 0x2ecc71,
      fontWeight: "bold",
      align: "center",
    });
    messageText.anchor.set(0.5);
    messageText.x = this.panel.width / 2;
    messageText.y = 100;
    
    this.panel.addChild(messageText);
    
    // Animate and remove
    let alpha = 1;
    const fadeOut = () => {
      alpha -= 0.05;
      messageText.alpha = alpha;
      messageText.y -= 1;
      
      if (alpha <= 0) {
        if (this.panel && this.panel.children.includes(messageText)) {
          this.panel.removeChild(messageText);
        }
      } else {
        requestAnimationFrame(fadeOut);
      }
    };
    
    setTimeout(() => fadeOut(), 1000);
  }

  // ============= TOUCH/MOBILE OPTIMIZATIONS =============

  handleKeyDown(event) {
    // ESC key closes the loot interface
    if (event.code === "Escape") {
      this.engine.switchScene(this.returnScene);
    }
  }

  handleMouseDown(event) {
    // Handle clicks outside the panel to close (if desired)
    if (this.layout.isMobile) {
      const panelBounds = this.panel.getBounds();
      if (!panelBounds.contains(event.global.x, event.global.y)) {
        // Could add a confirmation dialog here for mobile
        console.log("Clicked outside panel on mobile");
      }
    }
  }

  // ============= RESPONSIVE HELPER METHODS =============

  getResponsiveSize(baseSize) {
    return Math.max(baseSize * 0.7, baseSize * this.layout.scale);
  }

  getResponsiveSpacing(baseSpacing) {
    return Math.max(baseSpacing * 0.5, baseSpacing * this.layout.scale);
  }

  isSmallScreen() {
    return this.layout.isMobile || this.engine.width < 600;
  }

  // ============= UPDATE METHODS =============

  update(deltaTime) {
    super.update(deltaTime);

    // Update any animations or dynamic elements
    if (this.draggedLootItem) {
      // Could add drag momentum or smoothing here
    }
  }
}