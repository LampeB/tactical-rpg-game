import { PixiScene } from "../core/PixiScene.js";

// Try to import ShapeHelper synchronously
let ShapeHelper = null;
try {
  // Use dynamic import but handle it properly
  import("../utils/ShapeHelper.js")
    .then((module) => {
      ShapeHelper = module.ShapeHelper;
      console.log("✅ ShapeHelper loaded successfully");
    })
    .catch((error) => {
      console.warn("⚠️ ShapeHelper not found, will use basic shapes");
    });
} catch (error) {
  console.warn("⚠️ ShapeHelper import failed, using basic shapes");
}

export class PixiInventoryScene extends PixiScene {
  constructor() {
    super();

    // CONFIGURABLE GRID SETTINGS
    this.gridCellSize = 60;
    this.inventoryGrid = { x: 50, y: 100, cols: 10, rows: 8 };
    this.storageGrid = { x: 700, y: 100, cols: 8, rows: 6 };

    // Item management
    this.draggedItem = null;
    this.items = [];
    this.highlightedItems = [];
    this.showShapeOutlines = true;
    this.showDimensionInfo = false;
    this.dropPreviews = [];
    this.currentTooltip = null;

    console.log("📦 PixiInventoryScene constructor completed");
  }

  onEnter() {
    super.onEnter();

    console.log("🎨 INVENTORY SCENE LOADING...");
    console.log("Current ShapeHelper status:", !!ShapeHelper);

    // Create background
    this.createBackground();

    // Create grids
    this.createGrids();

    // Create sample items - always start with basic items to ensure something shows
    this.createBasicItems();

    // Update game mode display
    const gameModeBtn = document.getElementById("gameMode");
    if (gameModeBtn) {
      gameModeBtn.textContent = "📦 INVENTORY";
    }

    // Update navigation buttons
    if (this.engine && this.engine.updateNavButtons) {
      this.engine.updateNavButtons("inventory");
    }

    console.log(`📦 Inventory scene loaded with ${this.items.length} items`);
  }

  createBackground() {
    const bg = new PIXI.Graphics();
    bg.beginFill(0x27ae60);
    bg.drawRect(0, 0, this.engine.width, this.engine.height);
    bg.endFill();
    this.addGraphics(bg, "background");

    // Title
    const title = new PIXI.Text("📦 INVENTORY SYSTEM", {
      fontFamily: "Arial",
      fontSize: 28,
      fill: 0xffffff,
      align: "center",
      fontWeight: "bold",
    });
    title.anchor.set(0.5);
    title.x = this.engine.width / 2;
    title.y = 40;
    this.addSprite(title, "ui");

    // Grid labels
    const inventoryLabel = new PIXI.Text("Character Inventory", {
      fontFamily: "Arial",
      fontSize: 18,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    inventoryLabel.x = this.inventoryGrid.x;
    inventoryLabel.y = this.inventoryGrid.y - 30;
    this.addSprite(inventoryLabel, "ui");

    const storageLabel = new PIXI.Text("Item Storage", {
      fontFamily: "Arial",
      fontSize: 18,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    storageLabel.x = this.storageGrid.x;
    storageLabel.y = this.storageGrid.y - 30;
    this.addSprite(storageLabel, "ui");

    // Instructions
    const instructions = new PIXI.Text(
      "Drag items to move them between grids | R = Reset Items | Working!",
      {
        fontFamily: "Arial",
        fontSize: 12,
        fill: 0xecf0f1,
        align: "center",
      }
    );
    instructions.anchor.set(0.5);
    instructions.x = this.engine.width / 2;
    instructions.y = this.engine.height - 50;
    this.addSprite(instructions, "ui");

    console.log("✅ Background created");
  }

  createGrids() {
    // Create inventory grid
    this.createGrid(this.inventoryGrid, 0x34495e, "Character Inventory");

    // Create storage grid
    this.createGrid(this.storageGrid, 0x8e44ad, "Item Storage");

    console.log("✅ Grids created");
  }

  createGrid(gridData, color, name) {
    const grid = new PIXI.Graphics();

    // Grid background
    grid.beginFill(color, 0.4);
    grid.drawRect(
      0,
      0,
      gridData.cols * this.gridCellSize,
      gridData.rows * this.gridCellSize
    );
    grid.endFill();

    // Grid border
    grid.lineStyle(3, 0xecf0f1);
    grid.drawRect(
      0,
      0,
      gridData.cols * this.gridCellSize,
      gridData.rows * this.gridCellSize
    );

    // Grid lines
    grid.lineStyle(1, 0xbdc3c7, 0.8);

    // Vertical lines
    for (let col = 0; col <= gridData.cols; col++) {
      const x = col * this.gridCellSize;
      grid.moveTo(x, 0);
      grid.lineTo(x, gridData.rows * this.gridCellSize);
    }

    // Horizontal lines
    for (let row = 0; row <= gridData.rows; row++) {
      const y = row * this.gridCellSize;
      grid.moveTo(0, y);
      grid.lineTo(gridData.cols * this.gridCellSize, y);
    }

    grid.x = gridData.x;
    grid.y = gridData.y;

    this.addGraphics(grid, "world");
    console.log(
      `✅ Created ${name} grid: ${gridData.cols}×${gridData.rows} cells`
    );
  }

  createBasicItems() {
    console.log("📦 Creating basic items...");

    const itemsData = [
      {
        name: "Sword",
        color: 0xe74c3c,
        width: 1,
        height: 3,
        x: 0,
        y: 0,
        type: "weapon",
        description: "A sharp blade for combat",
      },
      {
        name: "Shield",
        color: 0x34495e,
        width: 2,
        height: 2,
        x: 2,
        y: 0,
        type: "armor",
        description: "A sturdy shield for defense",
      },
      {
        name: "Potion",
        color: 0x27ae60,
        width: 1,
        height: 1,
        x: 4,
        y: 0,
        type: "consumable",
        description: "A healing potion",
      },
      {
        name: "Staff",
        color: 0x9b59b6,
        width: 1,
        height: 2,
        x: 0,
        y: 3,
        type: "weapon",
        description: "A magical staff",
      },
      {
        name: "Gem",
        color: 0xf39c12,
        width: 1,
        height: 1,
        x: 2,
        y: 3,
        type: "gem",
        description: "A magical enhancement gem",
      },
      {
        name: "Bow",
        color: 0x16a085,
        width: 1,
        height: 2,
        x: 3,
        y: 3,
        type: "weapon",
        description: "A ranged weapon",
      },
      {
        name: "Armor",
        color: 0x7f8c8d,
        width: 2,
        height: 3,
        x: 5,
        y: 0,
        type: "armor",
        description: "Heavy plate armor",
      },
      {
        name: "Ring",
        color: 0xe67e22,
        width: 1,
        height: 1,
        x: 4,
        y: 3,
        type: "accessory",
        description: "A magical ring",
      },
    ];

    let itemsCreated = 0;

    // Create and place items
    itemsData.forEach((data, index) => {
      try {
        console.log(`Creating item ${index + 1}: ${data.name}`);
        const item = this.createRectangleItem(data);
        this.placeItemInGrid(item, this.storageGrid, data.x, data.y);
        itemsCreated++;
        console.log(`✅ Created ${data.name} successfully`);
      } catch (error) {
        console.error(`❌ Failed to create ${data.name}:`, error);
      }
    });

    console.log(`📦 Created ${itemsCreated} items total`);
  }

  createRectangleItem(data) {
    const item = new PIXI.Container();

    const pixelWidth = data.width * this.gridCellSize - 4;
    const pixelHeight = data.height * this.gridCellSize - 4;

    // Item background
    const bg = new PIXI.Graphics();
    bg.beginFill(data.color);
    bg.drawRoundedRect(0, 0, pixelWidth, pixelHeight, 4);
    bg.endFill();

    // Item border
    bg.lineStyle(3, 0x2c3e50);
    bg.drawRoundedRect(0, 0, pixelWidth, pixelHeight, 4);

    item.addChild(bg);

    // Item name
    const fontSize = Math.min(pixelWidth / 8, pixelHeight / 4, 16);
    const text = new PIXI.Text(data.name, {
      fontFamily: "Arial",
      fontSize: fontSize,
      fill: 0xffffff,
      align: "center",
      fontWeight: "bold",
      stroke: 0x000000,
      strokeThickness: 2,
    });
    text.anchor.set(0.5);
    text.x = pixelWidth / 2;
    text.y = pixelHeight / 2;

    item.addChild(text);

    // Add type indicator dot
    const typeIndicator = new PIXI.Graphics();
    const indicatorColor = this.getTypeColor(data.type);
    typeIndicator.beginFill(indicatorColor);
    typeIndicator.drawCircle(pixelWidth - 8, 8, 5);
    typeIndicator.endFill();
    item.addChild(typeIndicator);

    // Store properties
    item.name = data.name;
    item.type = data.type;
    item.color = data.color;
    item.description = data.description || "";
    item.width = data.width;
    item.height = data.height;
    item.gridX = -1;
    item.gridY = -1;

    // Add methods
    item.isPlaced = function () {
      return this.gridX >= 0 && this.gridY >= 0;
    };

    // Make interactive
    item.interactive = true;
    item.cursor = "pointer";

    // Hover effects
    item.on("pointerover", () => {
      if (!this.draggedItem) {
        item.scale.set(1.05);
        this.showTooltip(item);
      }
    });

    item.on("pointerout", () => {
      if (!this.draggedItem) {
        item.scale.set(1);
        this.hideTooltip();
      }
    });

    // Drag functionality
    item.on("pointerdown", (event) => this.startDragging(item, event));

    // Add glow effect for gems
    if (data.type === "gem") {
      const glow = new PIXI.Graphics();
      glow.lineStyle(2, 0xffd700, 0.8);
      glow.drawRoundedRect(-2, -2, pixelWidth + 4, pixelHeight + 4, 6);
      item.addChildAt(glow, 0);

      // Animate glow
      let glowTime = Math.random() * Math.PI * 2;
      const animateGlow = () => {
        glowTime += 0.05;
        glow.alpha = 0.3 + Math.sin(glowTime) * 0.3;
        if (item.parent) {
          requestAnimationFrame(animateGlow);
        }
      };
      animateGlow();
    }

    this.items.push(item);
    return item;
  }

  getTypeColor(type) {
    const colors = {
      weapon: 0xe74c3c,
      armor: 0x34495e,
      gem: 0xf39c12,
      consumable: 0x27ae60,
      accessory: 0x9b59b6,
      material: 0x95a5a6,
    };
    return colors[type] || 0x95a5a6;
  }

  showTooltip(item) {
    const tooltip = new PIXI.Container();

    const bg = new PIXI.Graphics();
    bg.beginFill(0x2c3e50, 0.95);
    bg.drawRoundedRect(0, 0, 200, 80, 8);
    bg.endFill();
    bg.lineStyle(2, 0x3498db);
    bg.drawRoundedRect(0, 0, 200, 80, 8);

    const title = new PIXI.Text(item.name, {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    title.x = 10;
    title.y = 10;

    const info = new PIXI.Text(
      [
        `Type: ${item.type}`,
        `Size: ${item.width}×${item.height}`,
        item.description,
      ].join("\n"),
      {
        fontFamily: "Arial",
        fontSize: 10,
        fill: 0xecf0f1,
        lineHeight: 12,
      }
    );
    info.x = 10;
    info.y = 30;

    tooltip.addChild(bg);
    tooltip.addChild(title);
    tooltip.addChild(info);

    // Position tooltip
    tooltip.x = item.x + item.width * this.gridCellSize + 10;
    tooltip.y = item.y;

    // Keep in bounds
    if (tooltip.x + 200 > this.engine.width) {
      tooltip.x = item.x - 210;
    }

    this.addSprite(tooltip, "ui");
    this.currentTooltip = tooltip;
  }

  hideTooltip() {
    if (this.currentTooltip) {
      this.removeSprite(this.currentTooltip);
      this.currentTooltip = null;
    }
  }

  placeItemInGrid(item, grid, gridX, gridY) {
    item.x = grid.x + gridX * this.gridCellSize + 2;
    item.y = grid.y + gridY * this.gridCellSize + 2;
    item.gridX = gridX;
    item.gridY = gridY;

    this.addSprite(item, "world");

    console.log(`🎯 Placed ${item.name} at grid position (${gridX}, ${gridY})`);
  }

  startDragging(item, event) {
    if (this.draggedItem) return;

    this.draggedItem = item;
    this.hideTooltip();

    // Store original position
    item.originalX = item.x;
    item.originalY = item.y;
    item.originalGridX = item.gridX;
    item.originalGridY = item.gridY;

    // Visual feedback
    item.scale.set(1.1);
    item.alpha = 0.9;

    // Move to top layer
    this.removeSprite(item);
    this.addSprite(item, "effects");

    console.log(`🎯 Started dragging ${item.name}`);

    // Follow mouse
    const onMove = (event) => {
      if (this.draggedItem === item) {
        item.x = event.global.x - (item.width * this.gridCellSize) / 2;
        item.y = event.global.y - (item.height * this.gridCellSize) / 2;
      }
    };

    const onEnd = (event) => {
      this.stopDragging(item, event);
      this.engine.app.stage.off("pointermove", onMove);
      this.engine.app.stage.off("pointerup", onEnd);
    };

    this.engine.app.stage.on("pointermove", onMove);
    this.engine.app.stage.on("pointerup", onEnd);
  }

  stopDragging(item, event) {
    if (this.draggedItem !== item) return;

    const mousePos = event.global;
    let placed = false;

    // Try both grids
    [this.inventoryGrid, this.storageGrid].forEach((grid) => {
      if (placed) return;

      const gridPos = this.getGridPosition(mousePos, grid);
      if (gridPos && this.canPlaceItem(item, grid, gridPos.x, gridPos.y)) {
        this.placeItemInGrid(item, grid, gridPos.x, gridPos.y);
        placed = true;
        const gridName = grid === this.inventoryGrid ? "inventory" : "storage";
        console.log(
          `✅ Placed ${item.name} in ${gridName} at (${gridPos.x}, ${gridPos.y})`
        );
      }
    });

    if (!placed) {
      // Return to original position
      item.x = item.originalX;
      item.y = item.originalY;
      item.gridX = item.originalGridX;
      item.gridY = item.originalGridY;
      console.log(`❌ Returned ${item.name} to original position`);
    }

    // Restore appearance
    item.scale.set(1);
    item.alpha = 1;

    // Move back to world layer
    this.removeSprite(item);
    this.addSprite(item, "world");

    this.draggedItem = null;
  }

  getGridPosition(mousePos, grid) {
    if (
      mousePos.x < grid.x ||
      mousePos.y < grid.y ||
      mousePos.x >= grid.x + grid.cols * this.gridCellSize ||
      mousePos.y >= grid.y + grid.rows * this.gridCellSize
    ) {
      return null;
    }

    return {
      x: Math.floor((mousePos.x - grid.x) / this.gridCellSize),
      y: Math.floor((mousePos.y - grid.y) / this.gridCellSize),
    };
  }

  canPlaceItem(item, grid, gridX, gridY) {
    // Check bounds
    if (
      gridX < 0 ||
      gridY < 0 ||
      gridX + item.width > grid.cols ||
      gridY + item.height > grid.rows
    ) {
      return false;
    }

    // Check for overlaps
    for (const otherItem of this.items) {
      if (otherItem === item || !otherItem.isPlaced()) continue;

      const overlaps = !(
        gridX + item.width <= otherItem.gridX ||
        otherItem.gridX + otherItem.width <= gridX ||
        gridY + item.height <= otherItem.gridY ||
        otherItem.gridY + otherItem.height <= gridY
      );

      if (overlaps) return false;
    }

    return true;
  }

  handleKeyDown(event) {
    if (event.code === "KeyR") {
      this.resetItems();
    }
  }

  resetItems() {
    console.log("🔄 Resetting items...");

    // Clear current items
    this.items.forEach((item) => this.removeSprite(item));
    this.items = [];

    // Recreate items
    this.createBasicItems();

    console.log(`✅ Items reset - ${this.items.length} items created`);
  }
}
