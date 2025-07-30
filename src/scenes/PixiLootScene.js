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
      fontSize: 24,
      fill: 0xffd700,
      fontWeight: "bold",
      align: "center",
    });
    title.anchor.set(0.5);
    title.x = panelWidth / 2;
    title.y = 40;
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
        fontSize: 14,
        fill: 0xffffff,
        align: "center",
        lineHeight: 18,
      }
    );
    statsText.anchor.set(0.5);
    statsText.x = panelWidth / 2;
    statsText.y = 80;
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

  createLootItems(panel) {
    const baseY = this.showStats ? 40 : 0;

    // Title
    const lootLabel = new PIXI.Text(
      this.title.includes("VICTORY") ? "⚔️ Battle Spoils" : "🎁 Found Items",
      {
        fontFamily: "Arial",
        fontSize: 16,
        fill: 0xffd700,
        fontWeight: "bold",
      }
    );
    lootLabel.x = 500;
    lootLabel.y = this.inventoryGrid.y - 20 + baseY;
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

    // Item background
    const bg = new PIXI.Graphics();
    bg.beginFill(itemData.color);
    bg.drawRect(0, 0, itemData.width * 30, itemData.height * 30);
    bg.endFill();
    bg.lineStyle(2, 0x2c3e50);
    bg.drawRect(0, 0, itemData.width * 30, itemData.height * 30);

    // Item name
    const nameText = new PIXI.Text(itemData.name, {
      fontFamily: "Arial",
      fontSize: 10,
      fill: 0xffffff,
      align: "center",
      wordWrap: true,
      wordWrapWidth: itemData.width * 30,
    });
    nameText.anchor.set(0.5);
    nameText.x = (itemData.width * 30) / 2;
    nameText.y = (itemData.height * 30) / 2;

    itemContainer.addChild(bg);
    itemContainer.addChild(nameText);

    // Add glow for special items
    if (itemData.type === "gem" || itemData.name.includes("Medal")) {
      const glow = new PIXI.Graphics();
      glow.lineStyle(2, 0xffd700, 0.6);
      glow.drawRect(-2, -2, itemData.width * 30 + 4, itemData.height * 30 + 4);
      itemContainer.addChildAt(glow, 0);

      // Animate glow
      let time = 0;
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

    itemContainer.on("pointerdown", (event) => {
      this.startDraggingLootItem(itemContainer, event);
    });

    return itemContainer;
  }

  createCloseButton(panel, panelWidth, panelHeight) {
    const closeBtn = new PIXI.Graphics();
    closeBtn.beginFill(0xe74c3c);
    closeBtn.drawRoundedRect(0, 0, 100, 35, 5);
    closeBtn.endFill();
    closeBtn.x = panelWidth / 2 - 50;
    closeBtn.y = panelHeight - 50;
    closeBtn.interactive = true;
    closeBtn.cursor = "pointer";

    const closeText = new PIXI.Text("Close", {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    closeText.anchor.set(0.5);
    closeText.x = 50;
    closeText.y = 17;
    closeBtn.addChild(closeText);

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
}
