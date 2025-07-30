// src/scenes/PixiInventoryScene.js - Refactored to use base class
import { InventoryBaseScene } from "../core/InventoryBaseScene.js";
import { ShapeHelper } from "../utils/ShapeHelper.js";

export class PixiInventoryScene extends InventoryBaseScene {
  constructor() {
    super();

    // Inventory-specific properties
    this.showShapeOutlines = false;
    this.showDimensionInfo = false;
    this.isInitialized = false;
  }

  onEnter() {
    super.onEnter();

    this.createBackground();
    this.createGrids();

    if (!this.isInitialized) {
      this.createStarterItems();
      this.isInitialized = true;
    } else {
      // Restore items that were added from other scenes
      this.items.forEach((item) => {
        if (!item.parent) {
          this.addSprite(item, "world");
        }
      });
    }

    this.createInstructions();
  }

  // =================== INVENTORY-SPECIFIC METHODS ===================

  createBackground() {
    const bg = new PIXI.Graphics();
    bg.beginFill(0x27ae60);
    bg.drawRect(0, 0, this.engine.width, this.engine.height);
    bg.endFill();
    this.addSprite(bg, "background");

    // Title
    const title = new PIXI.Text("🎒 INVENTORY MANAGEMENT", {
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
  }

  createGrids() {
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

    // Add grid labels
    const invLabel = new PIXI.Text("🎒 Character Inventory", {
      fontFamily: "Arial",
      fontSize: 16,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    invLabel.x = this.inventoryGrid.x;
    invLabel.y = this.inventoryGrid.y - 30;
    this.addSprite(invLabel, "ui");

    const storageLabel = new PIXI.Text("📦 Item Storage", {
      fontFamily: "Arial",
      fontSize: 16,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    storageLabel.x = this.storageGrid.x;
    storageLabel.y = this.storageGrid.y - 30;
    this.addSprite(storageLabel, "ui");
  }

  createInstructions() {
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
  }

  // =================== ITEM CREATION ===================

  createItem(data) {
    const item = new PIXI.Container();
    const cellSize = this.gridCellSize;
    const padding = 4;

    // Get shape pattern
    let shapePattern = this.getShapePattern(data);
    const bounds = ShapeHelper.getBounds(shapePattern);

    // Draw the shape
    shapePattern.forEach(([cellX, cellY]) => {
      const cellGraphic = new PIXI.Graphics();
      cellGraphic.beginFill(data.color);
      cellGraphic.drawRoundedRect(
        padding / 2,
        padding / 2,
        cellSize - padding,
        cellSize - padding,
        4
      );
      cellGraphic.endFill();
      cellGraphic.lineStyle(2, 0x2c3e50);
      cellGraphic.drawRoundedRect(
        padding / 2,
        padding / 2,
        cellSize - padding,
        cellSize - padding,
        4
      );
      cellGraphic.x = cellX * cellSize;
      cellGraphic.y = cellY * cellSize;
      item.addChild(cellGraphic);
    });

    // Add text and indicators
    this.addItemText(item, data, bounds, cellSize);
    this.addTypeIndicator(item, data, bounds, cellSize);

    // Store properties
    this.setItemProperties(item, data, bounds, shapePattern);

    // Make interactive
    this.makeItemInteractive(item);

    // Add to items array
    this.items.push(item);

    return item;
  }

  getShapePattern(data) {
    if (!data.shape || data.shape === "rectangle") {
      return ShapeHelper.createRectangle(data.width, data.height);
    }

    let pattern;
    switch (data.shape) {
      case "T":
        pattern = ShapeHelper.createTShape(
          data.stemLength || 3,
          data.topWidth || 3,
          data.orientation || "up"
        );
        break;
      case "U":
        pattern = ShapeHelper.createUShape(
          data.height || 3,
          data.width || 3,
          data.orientation || "up"
        );
        break;
      case "L":
        pattern = ShapeHelper.createLShape(
          data.armLength || 3,
          data.orientation || "tl"
        );
        break;
      default:
        const predefined = ShapeHelper.getPreDefinedShapes();
        pattern =
          predefined[data.shape] ||
          ShapeHelper.createRectangle(data.width, data.height);
    }

    return ShapeHelper.normalize(pattern);
  }

  setItemProperties(item, data, bounds, shapePattern) {
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
    item.rotationCount = 0;
  }

  // =================== DRAG AND DROP ===================

  handleMouseDown(event) {
    const clickedItem = this.findItemUnderMouse(event.global.x, event.global.y);
    if (clickedItem && clickedItem.interactive) {
      this.startDragging(clickedItem, event);
    }
  }

  startDragging(item, event) {
    event.stopPropagation();

    this.draggedItem = item;
    this.dragStartGrid = this.findItemGrid(item);
    item.isDragging = true;

    // Store original state
    this.storeOriginalState(item);

    // Visual feedback
    item.alpha = 0.9;
    item.scale.set(1.05);
    this.hideTooltip();

    // Move to top and calculate offset
    this.layers.world.removeChild(item);
    this.layers.world.addChild(item);

    const globalPos = event.global;
    item.dragOffsetX = globalPos.x - item.x;
    item.dragOffsetY = globalPos.y - item.y;

    item.gridX = -1;
    item.gridY = -1;
    this.updateInstructions();
  }

  // =================== INPUT HANDLING ===================

  handleKeyDown(event) {
    if (event.code === "KeyR" && this.draggedItem) {
      this.rotateDraggedItem();
    }
  }

  // =================== HELPER METHODS ===================

  updateInstructions() {
    if (this.instructionsText) {
      if (this.draggedItem) {
        this.instructionsText.text = `Dragging ${this.draggedItem.name} | Press R to rotate | Release to place`;
      } else {
        this.instructionsText.text =
          "Drag items | Press R while dragging to rotate";
      }
    }
  } // Add these missing methods to src/scenes/PixiInventoryScene.js

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
            this.storageGrid,
            item,
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

  addItemText(item, data, bounds, cellSize) {
    const fontSize = Math.min(
      (bounds.width * cellSize - 4) / 8,
      (bounds.height * cellSize - 4) / 4,
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
  }

  addTypeIndicator(item, data, bounds, cellSize) {
    const typeIndicator = new PIXI.Graphics();
    const indicatorColor = this.getTypeColor(data.type);
    typeIndicator.beginFill(indicatorColor);
    typeIndicator.drawCircle(bounds.width * cellSize - 8, 8, 4);
    typeIndicator.endFill();
    item.addChild(typeIndicator);
  }

  makeItemInteractive(item) {
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

  storeOriginalState(item) {
    item.originalX = item.x;
    item.originalY = item.y;
    item.originalGridX = item.gridX;
    item.originalGridY = item.gridY;
    item.originalShapePattern = [...item.shapePattern];
    item.originalGridWidth = item.gridWidth;
    item.originalGridHeight = item.gridHeight;
    item.originalRotationCount = item.rotationCount || 0;
  }

  handleMouseMove(event) {
    if (this.draggedItem) {
      const globalPos = event.global;
      const item = this.draggedItem;

      // Update item position using the drag offset
      const targetX = globalPos.x - item.dragOffsetX;
      const targetY = globalPos.y - item.dragOffsetY;

      item.x = targetX;
      item.y = targetY;

      // Show placement preview
      const invPos = this.getGridPosition(this.inventoryGrid, targetX, targetY);
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
          targetX,
          targetY
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

  handleMouseUp(event) {
    if (this.draggedItem) {
      this.stopDragging(event);
    }
  }

  stopDragging(event) {
    if (!this.draggedItem) return;

    const item = this.draggedItem;
    const itemTopLeftX = item.x;
    const itemTopLeftY = item.y;

    let placed = false;
    let targetGrid = null;
    let gridX = -1;
    let gridY = -1;

    // Try inventory first
    const invPos = this.getGridPosition(
      this.inventoryGrid,
      itemTopLeftX,
      itemTopLeftY
    );
    if (
      invPos &&
      this.canPlaceItemAt(this.inventoryGrid, item, invPos.x, invPos.y)
    ) {
      targetGrid = this.inventoryGrid;
      gridX = invPos.x;
      gridY = invPos.y;
      placed = true;
    }

    // Try storage if inventory failed
    if (!placed) {
      const storPos = this.getGridPosition(
        this.storageGrid,
        itemTopLeftX,
        itemTopLeftY
      );
      if (
        storPos &&
        this.canPlaceItemAt(this.storageGrid, item, storPos.x, storPos.y)
      ) {
        targetGrid = this.storageGrid;
        gridX = storPos.x;
        gridY = storPos.y;
        placed = true;
      }
    }

    if (placed) {
      // Successfully placed
      this.placeItemInGrid(item, targetGrid, gridX, gridY);
      console.log(`✅ Placed ${item.name} at (${gridX}, ${gridY})`);
    } else {
      // Revert to original position and rotation
      console.log(`🔄 Reverting ${item.name} to original position`);

      if (item.originalShapePattern) {
        item.shapePattern = [...item.originalShapePattern];
        item.gridWidth = item.originalGridWidth;
        item.gridHeight = item.originalGridHeight;
        item.rotationCount = item.originalRotationCount;
        this.updateItemVisuals(item);
      }

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
    this.updateInstructions();
  }

  rotateDraggedItem() {
    const item = this.draggedItem;
    if (!item || this.isRotationPointless(item)) return;

    // Rotate the shape pattern using ShapeHelper
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
    this.addItemText(item, { name: textContent }, bounds, cellSize);

    // Re-add type indicator
    this.addTypeIndicator(item, item, bounds, cellSize);

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
}
