// src/scenes/PixiLootScene.js - Refactored to use base class
import { InventoryBaseScene } from "../core/InventoryBaseScene.js";

export class PixiLootScene extends InventoryBaseScene {
  constructor() {
    super();

    // Loot-specific properties
    this.lootData = [];
    this.returnScene = "world";
    this.title = "💎 TREASURE FOUND!";
    this.subtitle =
      "Drag items from the right to your inventory or storage on the left";
    this.showStats = false;
    this.stats = null;

    // UI references
    this.overlay = null;
    this.panel = null;

    // Smaller grids for loot interface
    this.inventoryGrid = { x: 30, y: 100, cols: 8, rows: 6, cellSize: 25 };
    this.storageGrid = { x: 250, y: 100, cols: 6, rows: 5, cellSize: 25 };
  }

  setLootData(lootData, options = {}) {
    this.lootData = lootData || [];
    this.returnScene = options.returnScene || "world";
    this.title = options.title || "💎 TREASURE FOUND!";
    this.subtitle =
      options.subtitle ||
      "Drag items from the right to your inventory or storage on the left";
    this.showStats = options.showStats || false;
    this.stats = options.stats || null;
    this.context = options.context;

    // Adjust grid positioning based on context
    if (options.context === "battle") {
      this.inventoryGrid.y = 180;
      this.storageGrid.y = 180;
      this.inventoryGrid.rows = 5;
      this.storageGrid.rows = 4;
    } else {
      this.inventoryGrid.y = 100;
      this.storageGrid.y = 100;
      this.inventoryGrid.rows = 6;
      this.storageGrid.rows = 5;
    }
  }

  onEnter() {
    super.onEnter();
    this.createLootInterface();
  }

  // =================== LOOT INTERFACE ===================

  createInstructions(panel, panelWidth) {
    const instructions = new PIXI.Text(this.subtitle, {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xecf0f1,
      align: "center",
    });
    instructions.anchor.set(0.5);
    instructions.x = panelWidth / 2;
    instructions.y = this.showStats ? 120 : 70;
    panel.addChild(instructions);
  }

  calculateLayout() {
    const width = this.engine.width;
    const height = this.engine.height;

    // Determine device type and orientation
    this.layout.isPortrait = height > width;
    this.layout.isMobile = width < this.breakpoints.mobile;
    this.layout.isTablet =
      width >= this.breakpoints.mobile && width < this.breakpoints.desktop;
    this.layout.isDesktop = width >= this.breakpoints.desktop;

    // Calculate scaling factor
    this.layout.scale = Math.min(width / 1200, height / 800);
    this.layout.scale = Math.max(0.6, Math.min(1.2, this.layout.scale));

    // Adjust padding based on screen size
    this.layout.padding = this.layout.isMobile ? 15 : 25;

    // Calculate responsive panel dimensions
    const maxPanelWidth = width - this.layout.padding * 2;
    const maxPanelHeight = height - this.layout.padding * 2;

    this.layout.dimensions = {
      // Main panel
      panel: {
        width: Math.min(
          this.layout.isMobile ? maxPanelWidth : 900,
          maxPanelWidth
        ),
        height: Math.min(
          this.showStats
            ? this.layout.isMobile
              ? maxPanelHeight
              : 650
            : this.layout.isMobile
            ? maxPanelHeight
            : 600,
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
    // Create overlay
    this.overlay = new PIXI.Graphics();
    this.overlay.beginFill(0x000000, 0.8);
    this.overlay.drawRect(0, 0, this.engine.width, this.engine.height);
    this.overlay.endFill();
    this.overlay.interactive = true;

    // Create panel
    const panelWidth = 900;
    const panelHeight = this.showStats ? 650 : 600;
    this.panel = this.createMainPanel(panelWidth, panelHeight);

    // Build interface
    this.createTitle(this.panel, panelWidth);
    this.createStats(this.panel, panelWidth);
    this.createInstructions(this.panel, panelWidth);
    this.createMiniGrids(this.panel);
    this.createLootItems(this.panel);
    this.createCloseButton(this.panel, panelWidth, panelHeight);

    this.overlay.addChild(this.panel);
    this.addSprite(this.overlay, "effects");
  }

  createMainPanel(width, height) {
    const panel = new PIXI.Graphics();
    const panelColor = this.title.includes("VICTORY") ? 0x2e7d32 : 0x2c3e50;
    const borderColor = this.title.includes("VICTORY") ? 0x4caf50 : 0xf39c12;

    panel.beginFill(panelColor);
    panel.drawRoundedRect(0, 0, width, height, 15);
    panel.endFill();
    panel.lineStyle(3, borderColor);
    panel.drawRoundedRect(0, 0, width, height, 15);

    panel.x = this.engine.width / 2 - width / 2;
    panel.y = this.engine.height / 2 - height / 2;

    return panel;
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

  createMiniGrids(panel) {
    const baseY = this.showStats ? 40 : 0;

    // Create mini versions of inventory grids
    this.createMiniGrid(
      panel,
      this.inventoryGrid,
      "🎒 Character Inventory",
      0x27ae60,
      0x2ecc71,
      baseY
    );

    this.createMiniGrid(
      panel,
      this.storageGrid,
      "📦 Storage",
      0x8e44ad,
      0x9b59b6,
      baseY
    );

    this.showExistingItemsInMini(panel, baseY);
  }

  createMiniGrid(panel, gridData, label, bgColor, lineColor, baseY) {
    // Label
    const gridLabel = new PIXI.Text(label, {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    gridLabel.x = gridData.x;
    gridLabel.y = gridData.y - 20 + baseY;
    panel.addChild(gridLabel);

    // Grid
    const grid = new PIXI.Graphics();
    grid.beginFill(bgColor, 0.2);
    grid.drawRect(
      0,
      0,
      gridData.cols * gridData.cellSize,
      gridData.rows * gridData.cellSize
    );
    grid.endFill();
    grid.lineStyle(1, lineColor);

    // Draw grid lines
    for (let col = 0; col <= gridData.cols; col++) {
      const x = col * gridData.cellSize;
      grid.moveTo(x, 0);
      grid.lineTo(x, gridData.rows * gridData.cellSize);
    }
    for (let row = 0; row <= gridData.rows; row++) {
      const y = row * gridData.cellSize;
      grid.moveTo(0, y);
      grid.lineTo(gridData.cols * gridData.cellSize, y);
    }

    grid.x = gridData.x;
    grid.y = gridData.y + baseY;
    panel.addChild(grid);
  }

  showStorageInfo(panel, preview, baseY) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene || !inventoryScene.storageItems) return;

    // Title
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

    // Handle empty loot
    if (this.lootData.length === 0) {
      const emptyMessage = new PIXI.Text(
        "This container is empty.\nBetter luck next time!",
        {
          fontFamily: "Arial",
          fontSize: 14,
          fill: 0xbdc3c7,
          align: "center",
          lineHeight: 18,
        }
      );
      emptyMessage.anchor.set(0.5);
      emptyMessage.x = 600;
      emptyMessage.y = this.inventoryGrid.y + 100 + baseY;
      panel.addChild(emptyMessage);
      return;
    }

    // Create loot items
    this.lootData.forEach((itemData, index) => {
      const item = this.createDraggableLootItem(itemData, index);
      item.x = 500 + (index % 3) * 120;
      item.y = this.inventoryGrid.y + 20 + baseY + Math.floor(index / 3) * 120;
      panel.addChild(item);
    });
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
    nameText.x = (itemData.width * 30) / 2;
    nameText.y = (itemData.height * 30) / 2;

    itemContainer.addChild(bg);
    itemContainer.addChild(nameText);

    // Add glow for special items
    if (itemData.type === "gem" || itemData.name.includes("Medal")) {
      const glow = new PIXI.Graphics();
      glow.lineStyle(glowSize, 0xffd700, 0.6);
      glow.drawRoundedRect(
        -glowSize,
        -glowSize,
        itemSize + glowSize * 2,
        itemSize + glowSize * 2,
        11
      );
      itemContainer.addChildAt(glow, 0);

      // Animate glow
      let time = Math.random() * Math.PI * 2;
      const animate = () => {
        time += 0.05;
        glow.alpha = 0.4 + Math.sin(time) * 0.3;
        if (this.isActive) requestAnimationFrame(animate);
      };
      animate();
    }

    // Store data and make interactive
    itemContainer.itemData = itemData;
    itemContainer.interactive = true;
    itemContainer.cursor = "pointer";

    // Enhanced touch/mouse handling
    itemContainer.on("pointerdown", (event) => {
      this.startDraggingLootItem(itemContainer, event);
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

  // =================== DRAG AND DROP FOR LOOT ===================

  startDraggingLootItem(item, event) {
    // Simplified drag for loot items
    console.log(`Dragging loot: ${item.itemData.name}`);
    // TODO: Implement loot item drag and drop to inventory
  }

  showExistingItemsInMini(panel, baseY) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene || !inventoryScene.items) return;

    inventoryScene.items.forEach((item) => {
      if (item.gridX >= 0 && item.gridY >= 0) {
        const miniItem = new PIXI.Graphics();
        miniItem.beginFill(item.color || 0x3498db);
        miniItem.drawRect(
          0,
          0,
          (item.gridWidth || 1) * this.storageGrid.cellSize - 2,
          (item.gridHeight || 1) * this.storageGrid.cellSize - 2
        );
        miniItem.endFill();

        // Position in mini grid (simplified)
        miniItem.x =
          this.storageGrid.x + item.gridX * this.storageGrid.cellSize + 1;
        miniItem.y =
          this.storageGrid.y +
          item.gridY * this.storageGrid.cellSize +
          1 +
          baseY;

        panel.addChild(miniItem);
      }
    });
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
