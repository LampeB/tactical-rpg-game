// Debug tool - Add this to your PixiInventoryScene.js temporarily
// This will help identify exactly where the issue is occurring

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

  createRectangleItem(data) {
    const item = new PIXI.Container();

    // EXACT cell sizing - no padding adjustments
    const pixelWidth = data.width * this.gridCellSize;
    const pixelHeight = data.height * this.gridCellSize;

    // Item background with internal padding for visual separation
    const bg = new PIXI.Graphics();
    const padding = 4;

    bg.beginFill(data.color);
    bg.drawRoundedRect(
      padding / 2,
      padding / 2,
      pixelWidth - padding,
      pixelHeight - padding,
      4
    );
    bg.endFill();

    // Item border
    bg.lineStyle(2, 0x2c3e50);
    bg.drawRoundedRect(
      padding / 2,
      padding / 2,
      pixelWidth - padding,
      pixelHeight - padding,
      4
    );

    item.addChild(bg);

    // Item name
    const fontSize = Math.min(
      (pixelWidth - padding) / 8,
      (pixelHeight - padding) / 4,
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
    text.x = pixelWidth / 2;
    text.y = pixelHeight / 2;

    item.addChild(text);

    // Type indicator
    const typeIndicator = new PIXI.Graphics();
    const indicatorColor = this.getTypeColor(data.type);
    typeIndicator.beginFill(indicatorColor);
    typeIndicator.drawCircle(pixelWidth - 8, 8, 4);
    typeIndicator.endFill();
    item.addChild(typeIndicator);

    // Store properties
    item.name = data.name;
    item.type = data.type;
    item.color = data.color;
    item.description = data.description || "";
    item.gridWidth = data.width;
    item.gridHeight = data.height;
    item.originalData = data;
    item.gridX = -1;
    item.gridY = -1;
    item.visible = true;

    // Add methods
    item.isPlaced = function () {
      return this.gridX >= 0 && this.gridY >= 0;
    };

    // Make interactive - UPDATED SECTION
    item.interactive = true;
    item.cursor = "pointer";
    item.buttonMode = true;

    // Keep hover effects only
    item.on("pointerover", () => {
      if (!(this.draggedItem || item.isDragging)) {
        item.scale.set(1.05);
        this.showTooltip(item);
      }
    });

    item.on("pointerout", () => {
      if (!(this.draggedItem || item.isDragging)) {
        item.scale.set(1);
        this.hideTooltip();
      }
    });

    // REMOVED: item.on("pointerdown", (event) => this.startDragging(item, event));
    // Now using global handleMouseDown instead

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

  canPlaceItemAt(grid, item, gridX, gridY) {
    // Use gridWidth/gridHeight instead of width/height
    const itemGridWidth = item.gridWidth || item.originalData?.width || 1;
    const itemGridHeight = item.gridHeight || item.originalData?.height || 1;

    // Check bounds
    if (
      gridX < 0 ||
      gridY < 0 ||
      gridX + itemGridWidth > grid.cols ||
      gridY + itemGridHeight > grid.rows
    ) {
      return false;
    }

    // Check for overlapping items
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

      const otherGridWidth =
        otherItem.gridWidth || otherItem.originalData?.width || 1;
      const otherGridHeight =
        otherItem.gridHeight || otherItem.originalData?.height || 1;

      // Check overlap
      const itemRight = gridX + itemGridWidth;
      const itemBottom = gridY + itemGridHeight;
      const otherRight = otherItem.gridX + otherGridWidth;
      const otherBottom = otherItem.gridY + otherGridHeight;

      const overlaps = !(
        gridX >= otherRight ||
        itemRight <= otherItem.gridX ||
        gridY >= otherBottom ||
        itemBottom <= otherItem.gridY
      );

      if (overlaps) {
        return false;
      }
    }

    return true;
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

  showPlacementPreview(item, grid, gridX, gridY, canPlace) {
    this.hidePlacementPreview();

    const preview = new PIXI.Graphics();
    const color = canPlace ? 0x2ecc71 : 0xe74c3c;
    const alpha = canPlace ? 0.3 : 0.5;

    // Use grid dimensions, not pixel dimensions
    const itemGridWidth = item.gridWidth || item.originalData?.width || 1;
    const itemGridHeight = item.gridHeight || item.originalData?.height || 1;

    const previewWidth = itemGridWidth * this.gridCellSize;
    const previewHeight = itemGridHeight * this.gridCellSize;
    const padding = 4;

    // Draw with the same padding offset as the actual items
    preview.beginFill(color, alpha);
    preview.drawRoundedRect(
      padding / 2,
      padding / 2,
      previewWidth - padding,
      previewHeight - padding,
      4
    );
    preview.endFill();

    preview.lineStyle(2, color, 0.8);
    preview.drawRoundedRect(
      padding / 2,
      padding / 2,
      previewWidth - padding,
      previewHeight - padding,
      4
    );

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

  findItemUnderMouse(mouseX, mouseY) {
    console.log(`🔍 Looking for item under mouse at (${mouseX}, ${mouseY})`);

    // Check items in reverse order (top to bottom)
    for (let i = this.items.length - 1; i >= 0; i--) {
      const item = this.items[i];

      if (!item.visible || item.gridX < 0 || item.gridY < 0) {
        continue;
      }

      // Use GRID dimensions, not pixel dimensions
      const itemGridWidth = item.gridWidth || item.originalData?.width || 1;
      const itemGridHeight = item.gridHeight || item.originalData?.height || 1;
      const itemPixelWidth = itemGridWidth * this.gridCellSize;
      const itemPixelHeight = itemGridHeight * this.gridCellSize;

      const withinBounds =
        mouseX >= item.x &&
        mouseX < item.x + itemPixelWidth && // Changed <= to
        mouseY >= item.y &&
        mouseY < item.y + itemPixelHeight; // Changed <= to

      console.log(
        `   Checking ${item.name} at (${item.x}, ${
          item.y
        }) size (${itemPixelWidth}x${itemPixelHeight}): ${
          withinBounds ? "HIT" : "miss"
        }`
      );

      if (withinBounds) {
        return item;
      }
    }

    console.log(`   No item found under mouse`);
    return null;
  }
}
