import { ShapeHelper } from "../utils/ShapeHelper.js";
import { PixiScene } from "../core/PixiScene.js";

export class PixiInventoryScene extends PixiScene {
  constructor() {
    super();

    this.gridCellSize = 60;
    this.inventoryGrid = { x: 50, y: 100, cols: 10, rows: 8 };
    this.storageGrid = { x: 700, y: 100, cols: 8, rows: 6 };
    this.items = [];

    // Drag and drop state
    this.draggedItem = null;
    this.dragStartGrid = null;
    this.dragOffset = { x: 0, y: 0 };
    this.placementPreview = null;
    this.currentTooltip = null;

    // Visual settings
    this.showShapeOutlines = false;
    this.showDimensionInfo = false;
  }

  onEnter() {
    super.onEnter();

    this.createBackground();
    this.createGrids();

    if (!this.isInitialized) {
      // First time - start with empty inventory
      this.items = [];
      this.createStarterItems();
      this.isInitialized = true;
    } else {
      // Subsequent times - restore any items that were added
      this.items.forEach((item) => {
        if (!item.parent) {
          this.addSprite(item, "world");
        }
      });
    }
  }

  initializePersistentData() {
    if (!this.items) {
      this.items = [];
    }
  }

  canPlaceItemAt(grid, item, gridX, gridY) {
    console.log(
      `🔍 Checking placement for ${item.name} at (${gridX}, ${gridY}) in ${
        grid === this.inventoryGrid ? "inventory" : "storage"
      }`
    );

    const itemGridWidth = item.gridWidth || item.originalData?.width || 1;
    const itemGridHeight = item.gridHeight || item.originalData?.height || 1;

    // Check bounds using bounding box
    if (
      gridX < 0 ||
      gridY < 0 ||
      gridX + itemGridWidth > grid.cols ||
      gridY + itemGridHeight > grid.rows
    ) {
      console.log(
        `   ❌ Out of bounds: (${gridX}, ${gridY}) + (${itemGridWidth}, ${itemGridHeight}) vs (${grid.cols}, ${grid.rows})`
      );
      return false;
    }

    // Get the actual shape pattern of the item being placed
    const itemShapePattern = item.shapePattern || [[0, 0]]; // Default to single cell

    // Check for overlapping with other items using ACTUAL SHAPES
    for (const otherItem of this.items) {
      // Skip the item being dragged and items not placed
      if (otherItem === item || otherItem.gridX < 0 || otherItem.gridY < 0) {
        continue;
      }

      // Check if this item is in the same grid
      const otherItemGrid = this.findItemGrid(otherItem);
      if (otherItemGrid !== grid) {
        continue;
      }

      // Get the other item's shape pattern
      const otherShapePattern = otherItem.shapePattern || [[0, 0]];

      // Check if any cells of the new item overlap with any cells of the existing item
      const hasOverlap = this.checkShapeOverlap(
        itemShapePattern,
        gridX,
        gridY,
        otherShapePattern,
        otherItem.gridX,
        otherItem.gridY
      );

      if (hasOverlap) {
        console.log(
          `   ❌ Shape overlap with ${otherItem.name} at (${otherItem.gridX}, ${otherItem.gridY})`
        );
        return false;
      }
    }

    console.log(`   ✅ Placement valid - no shape conflicts`);
    return true;
  }

  checkShapeOverlap(pattern1, x1, y1, pattern2, x2, y2) {
    // Convert both patterns to absolute grid coordinates
    const cells1 = pattern1.map(([cellX, cellY]) => [x1 + cellX, y1 + cellY]);
    const cells2 = pattern2.map(([cellX, cellY]) => [x2 + cellX, y2 + cellY]);

    // Check if any cell from pattern1 overlaps with any cell from pattern2
    for (const [cell1X, cell1Y] of cells1) {
      for (const [cell2X, cell2Y] of cells2) {
        if (cell1X === cell2X && cell1Y === cell2Y) {
          console.log(`     Overlap at grid cell (${cell1X}, ${cell1Y})`);
          return true;
        }
      }
    }

    return false;
  }

  createBackground() {
    const bg = new PIXI.Graphics();
    bg.beginFill(0x27ae60);
    bg.drawRect(0, 0, this.engine.width, this.engine.height);
    bg.endFill();
    bg.name = "background";

    this.addSprite(bg, "background");

    // Add title
    const title = new PIXI.Text("📦 INVENTORY DEBUG", {
      fontFamily: "Arial",
      fontSize: 28,
      fill: 0xffffff,
      align: "center",
      fontWeight: "bold",
    });
    title.anchor.set(0.5);
    title.x = this.engine.width / 2;
    title.y = 40;
    title.name = "title";

    this.addSprite(title, "ui");
  }

  createGrid(gridData, color, name) {
    const grid = new PIXI.Graphics();

    // Draw background FIRST - no stroke
    grid.beginFill(color, 0.3);
    grid.drawRect(
      0,
      0,
      gridData.cols * this.gridCellSize,
      gridData.rows * this.gridCellSize
    );
    grid.endFill();

    // Draw internal grid lines with proper alignment
    grid.lineStyle({
      width: 1,
      color: 0xffffff,
      alpha: 0.5,
      alignment: 0.5, // Center the line exactly
    });

    // Vertical lines
    for (let col = 1; col < gridData.cols; col++) {
      const x = col * this.gridCellSize;
      grid.moveTo(x, 0);
      grid.lineTo(x, gridData.rows * this.gridCellSize);
    }

    // Horizontal lines
    for (let row = 1; row < gridData.rows; row++) {
      const y = row * this.gridCellSize;
      grid.moveTo(0, y);
      grid.lineTo(gridData.cols * this.gridCellSize, y);
    }

    // Draw outer border with inside alignment
    grid.lineStyle({
      width: 2,
      color: 0xffffff,
      alpha: 0.8,
      alignment: 0, // Draw border INSIDE
    });

    grid.drawRect(
      0,
      0,
      gridData.cols * this.gridCellSize,
      gridData.rows * this.gridCellSize
    );

    grid.x = gridData.x;
    grid.y = gridData.y;
    grid.name = name + "Graphics";
    grid.visible = true;

    this.addGraphics(grid, "world");
    return grid;
  }

  createGrids() {
    // Create grids with stroke fix
    this.inventoryGrid.graphics = this.createGrid(
      this.inventoryGrid,
      0x2ecc71,
      "Character Inventory"
    );
    this.storageGrid.graphics = this.createGrid(
      this.storageGrid,
      0x9b59b6,
      "Item Storage"
    );
  }

  createItem(data) {
    console.log(
      `🔨 Creating item: ${data.name} (${data.shape || "rectangle"})`
    );

    const item = new PIXI.Container();
    const cellSize = this.gridCellSize;
    const padding = 4;

    // Get shape pattern - default to rectangle if no shape specified
    let shapePattern = [];

    if (!data.shape || data.shape === "rectangle") {
      // Default rectangle
      shapePattern = ShapeHelper.createRectangle(data.width, data.height);
    } else {
      // Use ShapeHelper for all other shapes
      switch (data.shape) {
        case "T":
          shapePattern = ShapeHelper.createTShape(
            data.stemLength || 3,
            data.topWidth || 3,
            data.orientation || "up"
          );
          break;
        case "U":
          shapePattern = ShapeHelper.createUShape(
            data.height || 3,
            data.width || 3,
            data.orientation || "up"
          );
          break;
        case "L":
          shapePattern = ShapeHelper.createLShape(
            data.armLength || 3,
            data.orientation || "tl"
          );
          break;
        case "Plus":
          shapePattern = ShapeHelper.createPlusShape(data.armLength || 1);
          break;
        case "Diamond":
          shapePattern = ShapeHelper.createDiamond(data.size || 3);
          break;
        case "Z":
          shapePattern = ShapeHelper.createZShape(
            data.width || 3,
            data.height || 3,
            data.mirrored || false
          );
          break;
        case "Frame":
          shapePattern = ShapeHelper.createFrame(
            data.width,
            data.height,
            data.thickness || 1
          );
          break;
        case "Pattern":
          shapePattern = ShapeHelper.createFromPattern(data.pattern);
          break;
        default:
          // Try predefined shapes
          const predefined = ShapeHelper.getPreDefinedShapes();
          shapePattern =
            predefined[data.shape] ||
            ShapeHelper.createRectangle(data.width, data.height);
      }

      // Apply transformations if specified
      if (data.rotations) {
        for (let i = 0; i < data.rotations; i++) {
          shapePattern = ShapeHelper.rotateClockwise(shapePattern);
        }
      }

      if (data.mirrorH) {
        shapePattern = ShapeHelper.mirrorHorizontal(shapePattern);
      }

      if (data.mirrorV) {
        shapePattern = ShapeHelper.mirrorVertical(shapePattern);
      }

      // Normalize the pattern
      shapePattern = ShapeHelper.normalize(shapePattern);
    }

    // Validate the shape
    const validation = ShapeHelper.validateShape(shapePattern);
    if (!validation.valid) {
      console.warn(`⚠️ Invalid shape for ${data.name}: ${validation.error}`);
      shapePattern = ShapeHelper.createRectangle(
        data.width || 1,
        data.height || 1
      );
    }

    // Get actual bounds of the shape
    const bounds = ShapeHelper.getBounds(shapePattern);

    // Draw the shape using individual cells
    shapePattern.forEach(([cellX, cellY]) => {
      const cellGraphic = new PIXI.Graphics();

      // Cell background
      cellGraphic.beginFill(data.color);
      cellGraphic.drawRoundedRect(
        padding / 2,
        padding / 2,
        cellSize - padding,
        cellSize - padding,
        4
      );
      cellGraphic.endFill();

      // Cell border
      cellGraphic.lineStyle(2, 0x2c3e50);
      cellGraphic.drawRoundedRect(
        padding / 2,
        padding / 2,
        cellSize - padding,
        cellSize - padding,
        4
      );

      // Position the cell
      cellGraphic.x = cellX * cellSize;
      cellGraphic.y = cellY * cellSize;

      item.addChild(cellGraphic);
    });

    // Add item name text
    const fontSize = Math.min(
      (bounds.width * cellSize - padding) / 8,
      (bounds.height * cellSize - padding) / 4,
      14
    );
    const text = new PIXI.Text(data.name, {
      fontFamily: "Arial",
      fontSize: fontSize,
      fill: 0xffffff,
      align: "center",
      fontWeight: "bold",
      stroke: 0x000000,
      strokeThickness: 1,
    });
    text.anchor.set(0.5);
    text.x = (bounds.width * cellSize) / 2;
    text.y = (bounds.height * cellSize) / 2;
    item.addChild(text);

    // Add type indicator
    const typeIndicator = new PIXI.Graphics();
    const indicatorColor = this.getTypeColor(data.type);
    typeIndicator.beginFill(indicatorColor);
    typeIndicator.drawCircle(bounds.width * cellSize - 8, 8, 4);
    typeIndicator.endFill();
    item.addChild(typeIndicator);

    // Store properties using actual bounds
    item.name = data.name;
    item.type = data.type;
    item.color = data.color;
    item.description = data.description || "";
    item.gridWidth = bounds.width;
    item.gridHeight = bounds.height;
    item.originalData = data;
    item.shape = data.shape || "rectangle";
    item.shapePattern = shapePattern;
    item.gridX = -1;
    item.gridY = -1;
    item.visible = true;

    // Make interactive
    this.makeItemInteractive(item);

    // Add special effects for gems
    if (data.type === "gem") {
      this.addGemGlowEffect(
        item,
        bounds.width * cellSize,
        bounds.height * cellSize
      );
    }

    this.items.push(item);

    console.log(
      `✅ Item created: ${data.name} (${bounds.width}x${bounds.height})`
    );
    if (data.shape && data.shape !== "rectangle") {
      console.log(`   ASCII preview:\n${ShapeHelper.toAscii(shapePattern)}`);
    }

    return item;
  }

  createStarterItems() {
    console.log("🎯 Creating starter items");

    const starterItems = [
      {
        name: "Sword",
        color: 0xe74c3c,
        width: 1,
        height: 3,
        type: "weapon",
        description: "A sharp blade",
      },
      {
        name: "Shield",
        color: 0x34495e,
        width: 2,
        height: 2,
        type: "armor",
        description: "A protective shield",
      },
      {
        name: "Potion",
        color: 0x27ae60,
        width: 1,
        height: 1,
        type: "consumable",
        description: "A healing potion",
      },
      {
        name: "T-Staff",
        color: 0x9b59b6,
        shape: "T",
        stemLength: 3,
        topWidth: 3,
        orientation: "up",
        type: "weapon",
        description: "A T-shaped magical staff",
      },
      {
        name: "U-Bow",
        color: 0x16a085,
        shape: "U",
        width: 3,
        height: 3,
        orientation: "up",
        type: "weapon",
        description: "A U-shaped bow",
      },
    ];

    // Compact placement ensuring everything fits in storage grid (8x6)
    const placements = [
      { x: 0, y: 0 }, // Sword (1x3) - left column
      { x: 2, y: 0 }, // Shield (2x2) - top middle
      { x: 1, y: 0 }, // Potion (1x1) - between sword and shield
      { x: 5, y: 0 }, // T-Staff (3x3) - right side
      { x: 2, y: 3 }, // U-Bow (3x3) - bottom middle
    ];

    // Create and place items
    starterItems.forEach((itemData, index) => {
      if (index < placements.length) {
        const item = this.createItem(itemData);
        const placement = placements[index];

        if (
          this.canPlaceItemAt(this.storageGrid, item, placement.x, placement.y)
        ) {
          this.placeItemInGrid(
            item,
            this.storageGrid,
            placement.x,
            placement.y
          );
          console.log(
            `✅ Placed ${itemData.name} at (${placement.x}, ${placement.y})`
          );
        } else {
          console.log(`⚠️ Trying fallback placement for ${itemData.name}`);
          this.findAndPlaceItem(item);
        }
      }
    });

    console.log("✅ All starter items placed successfully");
  }

  findItemGrid(item) {
    // Use the stored original position during drag, or current position
    const itemX = item.isDragging ? item.originalX : item.x;
    const itemY = item.isDragging ? item.originalY : item.y;

    // Check inventory grid
    if (
      itemX >= this.inventoryGrid.x &&
      itemX <
        this.inventoryGrid.x + this.inventoryGrid.cols * this.gridCellSize &&
      itemY >= this.inventoryGrid.y &&
      itemY < this.inventoryGrid.y + this.inventoryGrid.rows * this.gridCellSize
    ) {
      return this.inventoryGrid;
    }

    // Default to storage grid
    return this.storageGrid;
  }

  findItemUnderMouse(mouseX, mouseY) {
    console.log(`🔍 Looking for item under mouse at (${mouseX}, ${mouseY})`);

    // Check items in reverse order (top to bottom)
    for (let i = this.items.length - 1; i >= 0; i--) {
      const item = this.items[i];

      if (!item.visible || item.gridX < 0 || item.gridY < 0) {
        continue;
      }

      // Convert mouse position to grid coordinates
      let mouseGridX = -1;
      let mouseGridY = -1;

      // Check which grid the mouse is over
      if (
        mouseX >= this.inventoryGrid.x &&
        mouseX <
          this.inventoryGrid.x + this.inventoryGrid.cols * this.gridCellSize &&
        mouseY >= this.inventoryGrid.y &&
        mouseY <
          this.inventoryGrid.y + this.inventoryGrid.rows * this.gridCellSize
      ) {
        mouseGridX = Math.floor(
          (mouseX - this.inventoryGrid.x) / this.gridCellSize
        );
        mouseGridY = Math.floor(
          (mouseY - this.inventoryGrid.y) / this.gridCellSize
        );
      } else if (
        mouseX >= this.storageGrid.x &&
        mouseX <
          this.storageGrid.x + this.storageGrid.cols * this.gridCellSize &&
        mouseY >= this.storageGrid.y &&
        mouseY < this.storageGrid.y + this.storageGrid.rows * this.gridCellSize
      ) {
        mouseGridX = Math.floor(
          (mouseX - this.storageGrid.x) / this.gridCellSize
        );
        mouseGridY = Math.floor(
          (mouseY - this.storageGrid.y) / this.gridCellSize
        );
      }

      if (mouseGridX >= 0 && mouseGridY >= 0) {
        // Check if the mouse is over any cell of this item's actual shape
        const shapePattern = item.shapePattern || [[0, 0]];
        for (const [cellX, cellY] of shapePattern) {
          const absoluteCellX = item.gridX + cellX;
          const absoluteCellY = item.gridY + cellY;

          if (mouseGridX === absoluteCellX && mouseGridY === absoluteCellY) {
            console.log(
              `   Found ${item.name} - mouse over shape cell (${cellX}, ${cellY})`
            );
            return item;
          }
        }
      }
    }

    console.log(`   No item found under mouse`);
    return null;
  }

  // Add this helper method to find available spots
  findAndPlaceItem(item) {
    console.log(`🔍 Finding available spot for ${item.name}`);

    // Try storage grid first
    for (let y = 0; y <= this.storageGrid.rows - item.gridHeight; y++) {
      for (let x = 0; x <= this.storageGrid.cols - item.gridWidth; x++) {
        if (this.canPlaceItemAt(this.storageGrid, item, x, y)) {
          this.placeItemInGrid(item, this.storageGrid, x, y);
          console.log(`✅ Found spot for ${item.name} at (${x}, ${y})`);
          return true;
        }
      }
    }

    // If storage is full, try inventory
    for (let y = 0; y <= this.inventoryGrid.rows - item.gridHeight; y++) {
      for (let x = 0; x <= this.inventoryGrid.cols - item.gridWidth; x++) {
        if (this.canPlaceItemAt(this.inventoryGrid, item, x, y)) {
          this.placeItemInGrid(item, this.inventoryGrid, x, y);
          console.log(
            `✅ Found spot for ${item.name} in inventory at (${x}, ${y})`
          );
          return true;
        }
      }
    }

    console.error(`❌ No available spot found for ${item.name}`);
    return false;
  }

  makeItemInteractive(item) {
    // Add methods
    item.isPlaced = function () {
      return this.gridX >= 0 && this.gridY >= 0;
    };

    // Make interactive
    item.interactive = true;
    item.cursor = "pointer";
    item.buttonMode = true;

    // Hover effects
    item.on("pointerover", () => {
      if (!this.draggedItem && !item.isDragging) {
        item.scale.set(1.05);
        this.showTooltip(item);
      }
    });

    item.on("pointerout", () => {
      if (!this.draggedItem && !item.isDragging) {
        item.scale.set(1);
        this.hideTooltip();
      }
    });

    console.log(`🎮 Made ${item.name} interactive`);
  }

  addGemGlowEffect(item, pixelWidth, pixelHeight) {
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

  placeItemInGrid(item, grid, gridX, gridY) {
    // EXACT positioning
    const screenX = grid.x + gridX * this.gridCellSize;
    const screenY = grid.y + gridY * this.gridCellSize;

    item.x = screenX;
    item.y = screenY;
    item.gridX = gridX;
    item.gridY = gridY;

    // FORCE VISIBILITY
    item.visible = true;
    item.alpha = 1;
    item.scale.set(1);

    // Remove from any existing parent first
    if (item.parent) {
      item.parent.removeChild(item);
    }

    // Add to world layer directly
    this.layers.world.addChild(item);

    return true;
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

  startDragging(item, event) {
    // Prevent event bubbling to avoid conflicts
    event.stopPropagation();
    this.hideTooltip();

    this.draggedItem = item;
    this.dragStartGrid = this.findItemGrid(item);
    item.isDragging = true;

    // Store original position
    item.originalX = item.x;
    item.originalY = item.y;
    item.originalGridX = item.gridX;
    item.originalGridY = item.gridY;

    // Visual feedback during drag
    item.alpha = 0.9; // Slightly less transparent
    item.scale.set(1.05); // Slightly smaller scale

    // Move item to top of world layer for better visibility
    this.layers.world.removeChild(item);
    this.layers.world.addChild(item);

    // Calculate drag offset from mouse to item corner
    const globalPos = event.global;
    item.dragOffsetX = globalPos.x - item.x;
    item.dragOffsetY = globalPos.y - item.y;

    // Clear from current grid position temporarily
    const originalGridX = item.gridX;
    const originalGridY = item.gridY;
    item.gridX = -1;
    item.gridY = -1;
  }

  stopDragging(event) {
    if (!this.draggedItem) return;

    const item = this.draggedItem;
    const globalPos = event.global;

    // Try to find a valid placement
    let placed = false;
    let targetGrid = null;
    let gridX = -1;
    let gridY = -1;

    // Check inventory grid first
    const invPos = this.getGridPosition(
      this.inventoryGrid,
      globalPos.x,
      globalPos.y
    );
    if (invPos) {
      const canPlace = this.canPlaceItemAt(
        this.inventoryGrid,
        item,
        invPos.x,
        invPos.y
      );

      if (canPlace) {
        targetGrid = this.inventoryGrid;
        gridX = invPos.x;
        gridY = invPos.y;
        placed = true;
      }
    }

    // Check storage grid if inventory failed
    if (!placed) {
      const storPos = this.getGridPosition(
        this.storageGrid,
        globalPos.x,
        globalPos.y
      );
      if (storPos) {
        const canPlace = this.canPlaceItemAt(
          this.storageGrid,
          item,
          storPos.x,
          storPos.y
        );

        if (canPlace) {
          targetGrid = this.storageGrid;
          gridX = storPos.x;
          gridY = storPos.y;
          placed = true;
        }
      } else {
      }
    }

    if (placed) {
      // Place item in new position
      this.placeItemInGrid(item, targetGrid, gridX, gridY);
    } else {
      // Return to original position
      this.placeItemInGrid(
        item,
        this.dragStartGrid,
        item.originalGridX,
        item.originalGridY
      );
    }

    // Reset visual state
    item.alpha = 1;
    item.scale.set(1);
    item.isDragging = false;

    // Clean up
    this.hideTooltip();
    this.hidePlacementPreview();
    this.draggedItem = null;
    this.dragStartGrid = null;
  }

  getGridPosition(grid, screenX, screenY) {
    // Check if position is within grid bounds
    if (
      screenX < grid.x ||
      screenY < grid.y ||
      screenX >= grid.x + grid.cols * this.gridCellSize ||
      screenY >= grid.y + grid.rows * this.gridCellSize
    ) {
      return null;
    }

    return {
      x: Math.floor((screenX - grid.x) / this.gridCellSize),
      y: Math.floor((screenY - grid.y) / this.gridCellSize),
    };
  }

  showPlacementPreview(item, grid, gridX, gridY, canPlace) {
    this.hidePlacementPreview();

    const preview = new PIXI.Graphics();
    const color = canPlace ? 0x2ecc71 : 0xe74c3c;
    const alpha = canPlace ? 0.3 : 0.5;
    const padding = 4;

    // Use the actual shape pattern instead of bounding box
    const shapePattern = item.shapePattern || [[0, 0]];

    shapePattern.forEach(([cellX, cellY]) => {
      const cellGraphic = new PIXI.Graphics();

      cellGraphic.beginFill(color, alpha);
      cellGraphic.drawRoundedRect(
        padding / 2,
        padding / 2,
        this.gridCellSize - padding,
        this.gridCellSize - padding,
        4
      );
      cellGraphic.endFill();

      cellGraphic.lineStyle(2, color, 0.8);
      cellGraphic.drawRoundedRect(
        padding / 2,
        padding / 2,
        this.gridCellSize - padding,
        this.gridCellSize - padding,
        4
      );

      cellGraphic.x = cellX * this.gridCellSize;
      cellGraphic.y = cellY * this.gridCellSize;

      preview.addChild(cellGraphic);
    });

    preview.x = grid.x + gridX * this.gridCellSize;
    preview.y = grid.y + gridY * this.gridCellSize;

    this.addSprite(preview, "ui");
    this.placementPreview = preview;
  }

  hidePlacementPreview() {
    if (this.placementPreview) {
      this.removeSprite(this.placementPreview);
      this.placementPreview = null;
    }
  }

  handleMouseUp(event) {
    if (this.draggedItem) {
      this.stopDragging(event);
    }
  }

  handleMouseMove(event) {
    if (this.draggedItem) {
      const globalPos = event.global;
      const item = this.draggedItem;

      // Update item position
      item.x = globalPos.x - item.dragOffsetX;
      item.y = globalPos.y - item.dragOffsetY;

      // Show placement preview
      const invPos = this.getGridPosition(
        this.inventoryGrid,
        globalPos.x,
        globalPos.y
      );
      if (invPos) {
        const canPlace = this.canPlaceItemAt(
          this.inventoryGrid,
          item,
          invPos.x,
          invPos.y
        );
        this.showPlacementPreview(
          item,
          this.inventoryGrid,
          invPos.x,
          invPos.y,
          canPlace
        );
      } else {
        const storPos = this.getGridPosition(
          this.storageGrid,
          globalPos.x,
          globalPos.y
        );
        if (storPos) {
          const canPlace = this.canPlaceItemAt(
            this.storageGrid,
            item,
            storPos.x,
            storPos.y
          );
          this.showPlacementPreview(
            item,
            this.storageGrid,
            storPos.x,
            storPos.y,
            canPlace
          );
        } else {
          this.hidePlacementPreview();
        }
      }
    }
  }

  handleMouseDown(event) {
    console.log("🖱️ Global mouse down at:", event.global.x, event.global.y);

    // Find what item was clicked
    const clickedItem = this.findItemUnderMouse(event.global.x, event.global.y);

    if (clickedItem && clickedItem.interactive) {
      console.log(`🎯 Found clicked item: ${clickedItem.name}`);
      this.startDragging(clickedItem, event);
    } else {
      console.log("🎯 No item found under mouse");
    }
  }

  initializePersistentData() {
    if (!this.items) {
      this.items = [];
    }
    console.log("📋 Inventory persistent data initialized");
  }
}
