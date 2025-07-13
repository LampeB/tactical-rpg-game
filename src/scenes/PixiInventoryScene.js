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
    this.instructionsText = new PIXI.Text(
      "Drag items | Press R while dragging to rotate",
      {
        fontFamily: "Arial",
        fontSize: 14,
        fill: 0xffffff,
        align: "center",
      }
    );
    this.instructionsText.anchor.set(0.5);
    this.instructionsText.x = this.engine.width / 2;
    this.instructionsText.y = this.engine.height - 20;

    this.addSprite(this.instructionsText, "ui");

    // Set initial instructions
    this.updateInstructions();
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

    return this.getGridPositionFromScreenCoords(grid, screenX, screenY);
  }

  getGridPositionFromScreenCoords(grid, screenX, screenY) {
    // Check if position is within grid bounds
    if (
      screenX < grid.x ||
      screenY < grid.y ||
      screenX >= grid.x + grid.cols * this.gridCellSize ||
      screenY >= grid.y + grid.rows * this.gridCellSize
    ) {
      return null;
    }
    const epsilon = 0.001;

    return {
      x: Math.floor((screenX - grid.x + epsilon) / this.gridCellSize),
      y: Math.floor((screenY - grid.y + epsilon) / this.gridCellSize),
    };
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

  handleKeyDown(event) {
    if (event.code === "KeyR") {
      if (this.draggedItem) {
        this.rotateDraggedItem();
      }
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

      // Update item position using the drag offset
      const targetX = globalPos.x - item.dragOffsetX;
      const targetY = globalPos.y - item.dragOffsetY;

      // Optional: Add slight snapping when near grid cells for better visual feedback
      let snapX = targetX;
      let snapY = targetY;

      // Check if we're over a valid grid
      const invPos = this.getGridPositionFromScreenCoords(
        this.inventoryGrid,
        targetX,
        targetY
      );
      const storPos = this.getGridPositionFromScreenCoords(
        this.storageGrid,
        targetX,
        targetY
      );

      if (invPos || storPos) {
        const grid = invPos ? this.inventoryGrid : this.storageGrid;
        const gridPos = invPos || storPos;

        // Calculate what the snapped position would be
        const snappedScreenX = grid.x + gridPos.x * this.gridCellSize;
        const snappedScreenY = grid.y + gridPos.y * this.gridCellSize;

        // Apply gentle snapping if we're close (within 10 pixels)
        const snapThreshold = 10;
        if (Math.abs(targetX - snappedScreenX) < snapThreshold) {
          snapX = snappedScreenX;
        }
        if (Math.abs(targetY - snappedScreenY) < snapThreshold) {
          snapY = snappedScreenY;
        }
      }

      item.x = snapX;
      item.y = snapY;

      // Show placement preview based on item's current position
      const itemTopLeftX = item.x;
      const itemTopLeftY = item.y;

      const invPreviewPos = this.getGridPositionFromScreenCoords(
        this.inventoryGrid,
        itemTopLeftX,
        itemTopLeftY
      );
      if (invPreviewPos) {
        const canPlace = this.canPlaceItemAt(
          this.inventoryGrid,
          item,
          invPreviewPos.x,
          invPreviewPos.y
        );
        this.showPlacementPreview(
          item,
          this.inventoryGrid,
          invPreviewPos.x,
          invPreviewPos.y,
          canPlace
        );
      } else {
        const storPreviewPos = this.getGridPositionFromScreenCoords(
          this.storageGrid,
          itemTopLeftX,
          itemTopLeftY
        );
        if (storPreviewPos) {
          const canPlace = this.canPlaceItemAt(
            this.storageGrid,
            item,
            storPreviewPos.x,
            storPreviewPos.y
          );
          this.showPlacementPreview(
            item,
            this.storageGrid,
            storPreviewPos.x,
            storPreviewPos.y,
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

  hidePlacementPreview() {
    if (this.placementPreview) {
      this.removeSprite(this.placementPreview);
      this.placementPreview = null;
    }
  }

  hideTooltip() {
    if (this.currentTooltip) {
      this.removeSprite(this.currentTooltip);
      this.currentTooltip = null;
    }
  }

  isRotationPointless(item) {
    const bounds = ShapeHelper.getBounds(item.shapePattern);

    // 1x1 items don't need rotation
    if (bounds.width === 1 && bounds.height === 1) {
      return true;
    }

    // Perfect squares with simple shapes don't change when rotated
    if (
      bounds.width === bounds.height &&
      (item.shape === "rectangle" || !item.shape)
    ) {
      return true;
    }

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

  placeItemInGrid(item, grid, gridX, gridY) {
    console.log(`📍 Placing ${item.name} at grid (${gridX}, ${gridY})`);

    // Subtract half a cell to fix the offset
    const screenX = grid.x + gridX * this.gridCellSize;
    const screenY = grid.y + gridY * this.gridCellSize;

    item.x = screenX;
    item.y = screenY;
    item.gridX = gridX;
    item.gridY = gridY;
    item.visible = true;

    if (!item.parent) {
      this.addSprite(item, "world");
    }

    console.log(`🎯 Placed ${item.name} at screen (${screenX}, ${screenY})`);
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

  startDragging(item, event) {
    console.log(`🖱️ Starting drag: ${item.name}`);

    event.stopPropagation();

    this.draggedItem = item;
    this.dragStartGrid = this.findItemGrid(item);
    item.isDragging = true;

    // Store original state (INCLUDING ROTATION)
    item.originalX = item.x;
    item.originalY = item.y;
    item.originalGridX = item.gridX;
    item.originalGridY = item.gridY;
    item.originalShapePattern = [...item.shapePattern]; // Store original shape
    item.originalGridWidth = item.gridWidth;
    item.originalGridHeight = item.gridHeight;
    item.rotationCount = item.rotationCount || 0;
    item.originalRotationCount = item.rotationCount;

    // Hide tooltip immediately
    this.hideTooltip();

    // Visual feedback
    item.alpha = 0.9;
    item.scale.set(1.05);

    // Move to top
    this.layers.world.removeChild(item);
    this.layers.world.addChild(item);

    // Calculate drag offset
    const globalPos = event.global;
    item.dragOffsetX = globalPos.x - item.x;
    item.dragOffsetY = globalPos.y - item.y;

    // Clear grid position temporarily
    item.gridX = -1;
    item.gridY = -1;

    this.updateInstructions();
  }

  stopDragging(event) {
    if (!this.draggedItem) return;

    console.log(`🖱️ Stopping drag: ${this.draggedItem.name}`);

    const item = this.draggedItem;

    // Use the item's current position (top-left corner) to determine placement
    const itemTopLeftX = item.x;
    const itemTopLeftY = item.y;

    // Try to find a valid placement using the item's position
    let placed = false;
    let targetGrid = null;
    let gridX = -1;
    let gridY = -1;

    // Check inventory grid first
    const invPos = this.getGridPositionFromScreenCoords(
      this.inventoryGrid,
      itemTopLeftX,
      itemTopLeftY
    );
    if (invPos) {
      console.log(
        `🎯 Trying inventory at (${invPos.x}, ${invPos.y}) with current rotation`
      );
      const canPlace = this.canPlaceItemAt(
        this.inventoryGrid,
        item,
        invPos.x,
        invPos.y
      );
      console.log(`   Can place in inventory: ${canPlace}`);

      if (canPlace) {
        targetGrid = this.inventoryGrid;
        gridX = invPos.x;
        gridY = invPos.y;
        placed = true;
      }
    }

    // Check storage grid if inventory failed
    if (!placed) {
      const storPos = this.getGridPositionFromScreenCoords(
        this.storageGrid,
        itemTopLeftX,
        itemTopLeftY
      );
      if (storPos) {
        console.log(
          `🎯 Trying storage at (${storPos.x}, ${storPos.y}) with current rotation`
        );
        const canPlace = this.canPlaceItemAt(
          this.storageGrid,
          item,
          storPos.x,
          storPos.y
        );
        console.log(`   Can place in storage: ${canPlace}`);

        if (canPlace) {
          targetGrid = this.storageGrid;
          gridX = storPos.x;
          gridY = storPos.y;
          placed = true;
        }
      }
    }

    if (placed) {
      // Successfully placed with current rotation
      this.placeItemInGrid(item, targetGrid, gridX, gridY);
      console.log(
        `✅ Placed ${item.name} at (${gridX}, ${gridY}) with rotation ${item.rotationCount}`
      );

      // Clear original state since placement succeeded
      delete item.originalShapePattern;
      delete item.originalGridWidth;
      delete item.originalGridHeight;
      delete item.originalRotationCount;
    } else {
      // REVERT TO ORIGINAL POSITION AND ROTATION
      console.log(
        `🔄 Reverting ${item.name} to original position and rotation`
      );

      // Restore original rotation
      if (item.originalShapePattern) {
        item.shapePattern = [...item.originalShapePattern];
        item.gridWidth = item.originalGridWidth;
        item.gridHeight = item.originalGridHeight;
        item.rotationCount = item.originalRotationCount;

        // Update visuals to original rotation
        this.updateItemVisuals(item);
      }

      // Place back in original position
      this.placeItemInGrid(
        item,
        this.dragStartGrid,
        item.originalGridX,
        item.originalGridY
      );
      console.log(
        `🔄 Returned ${item.name} to original position with original rotation`
      );

      // Clean up stored original state
      delete item.originalShapePattern;
      delete item.originalGridWidth;
      delete item.originalGridHeight;
      delete item.originalRotationCount;
    }

    // Reset visual state
    item.alpha = 1;
    item.scale.set(1);
    item.isDragging = false;

    // Clean up drag-specific properties
    delete item.dragOffsetX;
    delete item.dragOffsetY;
    delete item.originalX;
    delete item.originalY;
    delete item.originalGridX;
    delete item.originalGridY;

    // Clean up
    this.hideTooltip();
    this.hidePlacementPreview();
    this.draggedItem = null;
    this.dragStartGrid = null;

    // Update instructions
    this.updateInstructions();
  }

  rotateDraggedItem() {
    const item = this.draggedItem;
    if (!item) return;

    // Can't rotate simple items
    if (this.isRotationPointless(item)) {
      return;
    }

    // Rotate the shape pattern
    let newPattern = ShapeHelper.rotateClockwise(item.shapePattern);
    newPattern = ShapeHelper.normalize(newPattern);

    // Get new bounds
    const newBounds = ShapeHelper.getBounds(newPattern);

    // Update item properties
    item.shapePattern = newPattern;
    item.gridWidth = newBounds.width;
    item.gridHeight = newBounds.height;
    item.rotationCount = (item.rotationCount + 1) % 4;

    // Update visuals
    this.updateItemVisuals(item);
    this.updateInstructions();
  }

  showPlacementPreview(item, grid, gridX, gridY, canPlace) {
    this.hidePlacementPreview();

    const preview = new PIXI.Graphics();
    const color = canPlace ? 0x5f7ea0 : 0xe74c3c;
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

  initializePersistentData() {
    if (!this.items) {
      this.items = [];
    }
    console.log("📋 Inventory persistent data initialized");
  }

  updateInstructions() {
    if (this.instructionsText) {
      if (this.draggedItem) {
        this.instructionsText.text = `Dragging ${this.draggedItem.name} | Press R to rotate | Release to place`;
      } else {
        this.instructionsText.text =
          "Drag items | Press R while dragging to rotate";
      }
    }
  }

  updateItemVisuals(item) {
    console.log(`🎨 Updating visuals for ${item.name}`);

    // Store the text content before clearing
    const textElement = item.children.find(
      (child) => child instanceof PIXI.Text
    );
    const textContent = textElement ? textElement.text : item.name;

    // Clear all children
    item.removeChildren();

    // Redraw the item with new shape
    const cellSize = this.gridCellSize;
    const padding = 4;
    const bounds = ShapeHelper.getBounds(item.shapePattern);

    // Draw the new shape using the current pattern
    item.shapePattern.forEach(([cellX, cellY]) => {
      const cellGraphic = new PIXI.Graphics();

      // Cell background
      cellGraphic.beginFill(item.color);
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

    // Re-add the text
    const fontSize = Math.min(
      (bounds.width * cellSize - padding) / 8,
      (bounds.height * cellSize - padding) / 4,
      14
    );
    const text = new PIXI.Text(textContent, {
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

    // Re-add type indicator
    const typeIndicator = new PIXI.Graphics();
    const indicatorColor = this.getTypeColor(item.type);
    typeIndicator.beginFill(indicatorColor);
    typeIndicator.drawCircle(bounds.width * cellSize - 8, 8, 4);
    typeIndicator.endFill();
    item.addChild(typeIndicator);

    // Re-add glow effect for gems
    if (item.type === "gem") {
      this.addGemGlowEffect(
        item,
        bounds.width * cellSize,
        bounds.height * cellSize
      );
    }

    console.log(
      `✅ Updated visuals for ${item.name} with new ${bounds.width}x${bounds.height} shape`
    );
  }
}
