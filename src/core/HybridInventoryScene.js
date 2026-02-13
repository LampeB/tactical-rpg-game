import { PixiScene } from "./PixiScene.js";
import { ShapeHelper } from "../utils/ShapeHelper.js";

export class HybridInventoryScene extends PixiScene {
  constructor() {
    super();
    
    this.gridCellSize = 60;
    
    // Grid-based character inventory
    this.characterGrid = { x: 50, y: 100, cols: 10, rows: 8 };
    this.characterItems = []; // Items placed in grid
    
    // List-based unlimited storage
    this.storageList = { x: 700, y: 100, width: 400, height: 500 };
    this.storageItems = []; // Items in list format
    this.storageScroll = 0;
    this.storageItemHeight = 50;
    this.storageMaxVisible = Math.floor(this.storageList.height / this.storageItemHeight);
    
    // Drag and drop state
    this.draggedItem = null;
    this.dragSource = null; // 'grid' or 'list'
    this.placementPreview = null;
    this.currentTooltip = null;
  }

  // ============= GRID MANAGEMENT (Character Inventory) =============
  
  createCharacterGrid() {
    const grid = this.characterGrid;
    const gridGraphics = new PIXI.Graphics();

    // Background
    gridGraphics.beginFill(0x2ecc71, 0.3);
    gridGraphics.drawRect(0, 0, grid.cols * this.gridCellSize, grid.rows * this.gridCellSize);
    gridGraphics.endFill();

    // Grid lines
    gridGraphics.lineStyle({ width: 1, color: 0xffffff, alpha: 0.5 });
    
    // Vertical lines
    for (let col = 1; col < grid.cols; col++) {
      const x = col * this.gridCellSize;
      gridGraphics.moveTo(x, 0);
      gridGraphics.lineTo(x, grid.rows * this.gridCellSize);
    }
    
    // Horizontal lines
    for (let row = 1; row < grid.rows; row++) {
      const y = row * this.gridCellSize;
      gridGraphics.moveTo(0, y);
      gridGraphics.lineTo(grid.cols * this.gridCellSize, y);
    }

    // Border
    gridGraphics.lineStyle({ width: 2, color: 0xffffff, alpha: 0.8 });
    gridGraphics.drawRect(0, 0, grid.cols * this.gridCellSize, grid.rows * this.gridCellSize);

    gridGraphics.x = grid.x;
    gridGraphics.y = grid.y;
    gridGraphics.name = "characterGridGraphics";

    this.addGraphics(gridGraphics, "world");
    return gridGraphics;
  }

  // ============= LIST MANAGEMENT (Storage) =============
  
  createStorageList() {
    const storage = this.storageList;
    const listGraphics = new PIXI.Graphics();

    // Background
    listGraphics.beginFill(0x8e44ad, 0.3);
    listGraphics.drawRect(0, 0, storage.width, storage.height);
    listGraphics.endFill();

    // Border
    listGraphics.lineStyle({ width: 2, color: 0xffffff, alpha: 0.8 });
    listGraphics.drawRect(0, 0, storage.width, storage.height);

    listGraphics.x = storage.x;
    listGraphics.y = storage.y;
    listGraphics.name = "storageListGraphics";

    this.addGraphics(listGraphics, "world");

    // Create scrollbar if needed
    this.createStorageScrollbar();
    
    return listGraphics;
  }

  createStorageScrollbar() {
    if (this.storageItems.length <= this.storageMaxVisible) return;

    const scrollbar = new PIXI.Graphics();
    const scrollHeight = this.storageList.height;
    const thumbHeight = Math.max(20, (this.storageMaxVisible / this.storageItems.length) * scrollHeight);
    const thumbY = (this.storageScroll / Math.max(1, this.storageItems.length - this.storageMaxVisible)) * (scrollHeight - thumbHeight);

    // Scrollbar track
    scrollbar.beginFill(0x34495e, 0.5);
    scrollbar.drawRect(0, 0, 10, scrollHeight);
    scrollbar.endFill();

    // Scrollbar thumb
    scrollbar.beginFill(0xecf0f1, 0.8);
    scrollbar.drawRect(1, thumbY, 8, thumbHeight);
    scrollbar.endFill();

    scrollbar.x = this.storageList.x + this.storageList.width - 12;
    scrollbar.y = this.storageList.y;
    scrollbar.name = "storageScrollbar";

    // Remove old scrollbar if exists
    const oldScrollbar = this.layers.ui.getChildByName("storageScrollbar");
    if (oldScrollbar) {
      this.layers.ui.removeChild(oldScrollbar);
    }

    this.addSprite(scrollbar, "ui");
    return scrollbar;
  }

  // ============= ITEM CREATION =============

  createGridItem(data) {
    console.log(`🔨 Creating grid item: ${data.name}`);

    const item = new PIXI.Container();
    const cellSize = this.gridCellSize;
    const padding = 4;

    // Get shape pattern
    let shapePattern = this.getShapePattern(data);
    shapePattern = ShapeHelper.normalize(shapePattern);
    const bounds = ShapeHelper.getBounds(shapePattern);

    // Draw shape cells
    shapePattern.forEach(([cellX, cellY]) => {
      const cellGraphic = new PIXI.Graphics();
      cellGraphic.beginFill(data.color);
      cellGraphic.drawRoundedRect(
        padding / 2, padding / 2,
        cellSize - padding, cellSize - padding, 4
      );
      cellGraphic.endFill();
      
      cellGraphic.lineStyle(2, 0x2c3e50);
      cellGraphic.drawRoundedRect(
        padding / 2, padding / 2,
        cellSize - padding, cellSize - padding, 4
      );

      cellGraphic.x = cellX * cellSize;
      cellGraphic.y = cellY * cellSize;
      item.addChild(cellGraphic);
    });

    // Add text
    const fontSize = Math.min((bounds.width * cellSize - padding) / 8, 14);
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

    // Set properties
    this.setItemProperties(item, data, shapePattern, bounds);
    item.storageType = "grid"; // Mark as grid item
    
    this.makeItemInteractive(item);
    this.characterItems.push(item);

    return item;
  }

  createListItem(data, index) {
    console.log(`📝 Creating list item: ${data.name}`);

    const item = new PIXI.Container();
    const itemWidth = this.storageList.width - 20;
    const itemHeight = this.storageItemHeight - 4;

    // Background
    const bg = new PIXI.Graphics();
    const isEven = index % 2 === 0;
    bg.beginFill(isEven ? 0x34495e : 0x2c3e50, 0.8);
    bg.drawRoundedRect(0, 0, itemWidth, itemHeight, 4);
    bg.endFill();

    // Hover effect background
    const hoverBg = new PIXI.Graphics();
    hoverBg.beginFill(0x3498db, 0.3);
    hoverBg.drawRoundedRect(0, 0, itemWidth, itemHeight, 4);
    hoverBg.endFill();
    hoverBg.visible = false;

    item.addChild(bg);
    item.addChild(hoverBg);

    // Item icon (small colored square)
    const icon = new PIXI.Graphics();
    icon.beginFill(data.color);
    icon.drawRoundedRect(0, 0, 32, 32, 4);
    icon.endFill();
    icon.lineStyle(1, 0x2c3e50);
    icon.drawRoundedRect(0, 0, 32, 32, 4);
    icon.x = 8;
    icon.y = (itemHeight - 32) / 2;
    item.addChild(icon);

    // Item name
    const nameText = new PIXI.Text(data.name, {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    nameText.x = 50;
    nameText.y = 8;
    item.addChild(nameText);

    // Item info
    const infoText = new PIXI.Text(
      `${data.type} • ${data.width || 1}×${data.height || 1}${data.shape && data.shape !== 'rectangle' ? ` • ${data.shape}` : ''}`,
      {
        fontFamily: "Arial",
        fontSize: 11,
        fill: 0xbdc3c7,
      }
    );
    infoText.x = 50;
    infoText.y = 26;
    item.addChild(infoText);

    // Quantity (if applicable)
    if (data.quantity && data.quantity > 1) {
      const quantityText = new PIXI.Text(`×${data.quantity}`, {
        fontFamily: "Arial",
        fontSize: 12,
        fill: 0xf39c12,
        fontWeight: "bold",
      });
      quantityText.anchor.set(1, 0);
      quantityText.x = itemWidth - 10;
      quantityText.y = 8;
      item.addChild(quantityText);
    }

    // Set properties
    item.originalData = data;
    item.name = data.name;
    item.type = data.type;
    item.color = data.color;
    item.description = data.description || "";
    item.storageType = "list"; // Mark as list item
    item.listIndex = index;
    item.hoverBg = hoverBg; // Store reference for hover effects

    // Position in list
    const visibleIndex = index - this.storageScroll;
    item.x = this.storageList.x + 10;
    item.y = this.storageList.y + 10 + visibleIndex * this.storageItemHeight;

    // Only show if in visible range
    item.visible = visibleIndex >= 0 && visibleIndex < this.storageMaxVisible;

    this.makeListItemInteractive(item);

    return item;
  }

  getShapePattern(data) {
    if (!data.shape || data.shape === "rectangle") {
      return ShapeHelper.createRectangle(data.width, data.height);
    }

    let pattern;
    switch (data.shape) {
      case "T":
        pattern = ShapeHelper.createTShape(data.stemLength || 3, data.topWidth || 3, data.orientation || "up");
        break;
      case "L":
        pattern = ShapeHelper.createLShape(data.armLength || 3, data.orientation || "tl");
        break;
      case "U":
        pattern = ShapeHelper.createUShape(data.height || 3, data.width || 3, data.orientation || "up");
        break;
      // Add more shapes as needed
      default:
        pattern = ShapeHelper.createRectangle(data.width || 1, data.height || 1);
    }

    return ShapeHelper.normalize(pattern);
  }

  setItemProperties(item, data, shapePattern, bounds) {
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
    item.quantity = data.quantity || 1;
    item.rotationCount = 0;
  }

  // ============= INTERACTION =============

  makeItemInteractive(item) {
    item.interactive = true;
    item.cursor = "pointer";
    item.buttonMode = true;

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

    item.isPlaced = function () {
      return this.gridX >= 0 && this.gridY >= 0;
    };
  }

  makeListItemInteractive(item) {
    item.interactive = true;
    item.cursor = "pointer";
    item.buttonMode = true;

    item.on("pointerover", () => {
      if (!this.draggedItem) {
        item.hoverBg.visible = true;
        this.showTooltip(item);
      }
    });

    item.on("pointerout", () => {
      if (!this.draggedItem) {
        item.hoverBg.visible = false;
        this.hideTooltip();
      }
    });
  }

  // ============= STORAGE OPERATIONS =============

  addToStorage(itemData) {
    console.log(`📦 Adding ${itemData.name} to storage`);

    // Check if we can stack this item
    const existingItem = this.storageItems.find(
      stored => stored.name === itemData.name && 
                stored.type === itemData.type &&
                this.canStack(stored, itemData)
    );

    if (existingItem) {
      // Stack the item
      existingItem.quantity = (existingItem.quantity || 1) + (itemData.quantity || 1);
      console.log(`📚 Stacked ${itemData.name}, new quantity: ${existingItem.quantity}`);
    } else {
      // Add as new item
      const newStorageItem = { ...itemData };
      newStorageItem.quantity = newStorageItem.quantity || 1;
      this.storageItems.push(newStorageItem);
      console.log(`➕ Added new ${itemData.name} to storage`);
    }

    this.refreshStorageDisplay();
    return true;
  }

  removeFromStorage(itemData, quantity = 1) {
    const index = this.storageItems.findIndex(
      stored => stored.name === itemData.name && stored.type === itemData.type
    );

    if (index === -1) return false;

    const storedItem = this.storageItems[index];
    storedItem.quantity = (storedItem.quantity || 1) - quantity;

    if (storedItem.quantity <= 0) {
      this.storageItems.splice(index, 1);
      console.log(`🗑️ Removed ${itemData.name} from storage`);
    } else {
      console.log(`📉 Reduced ${itemData.name} quantity to ${storedItem.quantity}`);
    }

    this.refreshStorageDisplay();
    return true;
  }

  canStack(item1, item2) {
    // Only stack consumables and materials for now
    return (item1.type === "consumable" || item1.type === "material") &&
           item1.name === item2.name &&
           item1.type === item2.type;
  }

  refreshStorageDisplay() {
    console.log("🔄 Refreshing storage display");

    // Remove old list items
    this.layers.world.children = this.layers.world.children.filter(child => {
      if (child.storageType === "list") {
        this.layers.world.removeChild(child);
        return false;
      }
      return true;
    });

    // Create new list items
    this.storageItems.forEach((itemData, index) => {
      const listItem = this.createListItem(itemData, index);
      this.addSprite(listItem, "world");
    });

    // Update scrollbar
    this.createStorageScrollbar();
  }

  scrollStorage(delta) {
    const maxScroll = Math.max(0, this.storageItems.length - this.storageMaxVisible);
    this.storageScroll = Math.max(0, Math.min(maxScroll, this.storageScroll + delta));
    
    console.log(`📜 Scrolled storage: ${this.storageScroll}/${maxScroll}`);
    this.refreshStorageDisplay();
  }

  // ============= DRAG AND DROP =============

  handleMouseDown(event) {
    const mouseX = event.global.x;
    const mouseY = event.global.y;

    // Check for grid items
    const gridItem = this.findGridItemUnderMouse(mouseX, mouseY);
    if (gridItem) {
      this.startDragging(gridItem, "grid", event);
      return;
    }

    // Check for list items
    const listItem = this.findListItemUnderMouse(mouseX, mouseY);
    if (listItem) {
      this.startDragging(listItem, "list", event);
      return;
    }
  }

  findGridItemUnderMouse(mouseX, mouseY) {
    for (let i = this.characterItems.length - 1; i >= 0; i--) {
      const item = this.characterItems[i];
      if (!item.visible || item.gridX < 0 || item.gridY < 0) continue;

      const gridPos = this.getGridPosition(mouseX, mouseY);
      if (!gridPos) continue;

      const shapePattern = item.shapePattern || [[0, 0]];
      for (const [cellX, cellY] of shapePattern) {
        const absoluteCellX = item.gridX + cellX;
        const absoluteCellY = item.gridY + cellY;

        if (gridPos.x === absoluteCellX && gridPos.y === absoluteCellY) {
          return item;
        }
      }
    }
    return null;
  }

  findListItemUnderMouse(mouseX, mouseY) {
    // Check if mouse is in storage list area
    if (mouseX < this.storageList.x || 
        mouseX > this.storageList.x + this.storageList.width ||
        mouseY < this.storageList.y || 
        mouseY > this.storageList.y + this.storageList.height) {
      return null;
    }

    // Find which list item
    const relativeY = mouseY - this.storageList.y - 10;
    const itemIndex = Math.floor(relativeY / this.storageItemHeight) + this.storageScroll;
    
    if (itemIndex >= 0 && itemIndex < this.storageItems.length) {
      return { 
        originalData: this.storageItems[itemIndex], 
        listIndex: itemIndex,
        storageType: "list"
      };
    }
    
    return null;
  }

  getGridPosition(mouseX, mouseY) {
    const grid = this.characterGrid;
    if (mouseX < grid.x || mouseY < grid.y ||
        mouseX >= grid.x + grid.cols * this.gridCellSize ||
        mouseY >= grid.y + grid.rows * this.gridCellSize) {
      return null;
    }

    return {
      x: Math.floor((mouseX - grid.x) / this.gridCellSize),
      y: Math.floor((mouseY - grid.y) / this.gridCellSize),
    };
  }

  startDragging(item, source, event) {
    console.log(`🖱️ Starting drag from ${source}: ${item.name || item.originalData?.name}`);

    this.draggedItem = item;
    this.dragSource = source;

    if (source === "grid") {
      // Dragging from grid
      item.originalGridX = item.gridX;
      item.originalGridY = item.gridY;
      item.gridX = -1;
      item.gridY = -1;
      
      item.alpha = 0.8;
      item.scale.set(1.1);
      
      // Move to top layer
      this.layers.world.removeChild(item);
      this.layers.world.addChild(item);
    } else {
      // Dragging from list - create temporary grid item
      const tempItem = this.createGridItem(item.originalData);
      tempItem.alpha = 0.8;
      tempItem.scale.set(1.1);
      tempItem.originalListIndex = item.listIndex;
      
      this.draggedItem = tempItem;
      this.addSprite(tempItem, "world");
      
      // Position at mouse
      tempItem.x = event.global.x - tempItem.gridWidth * this.gridCellSize / 2;
      tempItem.y = event.global.y - tempItem.gridHeight * this.gridCellSize / 2;
    }

    this.hideTooltip();
  }

  handleMouseMove(event) {
    if (!this.draggedItem) return;

    const item = this.draggedItem;
    item.x = event.global.x - (item.gridWidth * this.gridCellSize) / 2;
    item.y = event.global.y - (item.gridHeight * this.gridCellSize) / 2;

    // Show grid placement preview if over character inventory
    const gridPos = this.getGridPosition(event.global.x, event.global.y);
    if (gridPos) {
      const canPlace = this.canPlaceInGrid(item, gridPos.x, gridPos.y);
      this.showGridPlacementPreview(item, gridPos.x, gridPos.y, canPlace);
    } else {
      this.hidePlacementPreview();
    }
  }

  handleMouseUp(event) {
    if (!this.draggedItem) return;

    const item = this.draggedItem;
    const mouseX = event.global.x;
    const mouseY = event.global.y;

    // Try to place in grid
    const gridPos = this.getGridPosition(mouseX, mouseY);
    if (gridPos && this.canPlaceInGrid(item, gridPos.x, gridPos.y)) {
      this.placeInGrid(item, gridPos.x, gridPos.y);
      
      if (this.dragSource === "list") {
        // Remove from storage list
        this.removeFromStorage(item.originalData, 1);
      }
    } else if (this.isOverStorageArea(mouseX, mouseY)) {
      // Drop in storage
      if (this.dragSource === "grid") {
        // Move from grid to storage
        this.addToStorage(item.originalData);
        this.removeFromGrid(item);
      } else {
        // Return to list
        this.removeSprite(item);
      }
    } else {
      // Return to original position
      if (this.dragSource === "grid") {
        this.placeInGrid(item, item.originalGridX, item.originalGridY);
      } else {
        this.removeSprite(item);
      }
    }

    // Cleanup
    this.draggedItem.alpha = 1;
    this.draggedItem.scale.set(1);
    this.draggedItem = null;
    this.dragSource = null;
    this.hidePlacementPreview();
  }

  // ============= GRID OPERATIONS =============

  canPlaceInGrid(item, gridX, gridY) {
    const grid = this.characterGrid;
    
    // Check bounds
    if (gridX < 0 || gridY < 0 ||
        gridX + item.gridWidth > grid.cols ||
        gridY + item.gridHeight > grid.rows) {
      return false;
    }

    // Check overlaps with existing items
    const itemShapePattern = item.shapePattern || [[0, 0]];
    
    for (const otherItem of this.characterItems) {
      if (otherItem === item || otherItem.gridX < 0 || otherItem.gridY < 0) continue;

      const otherShapePattern = otherItem.shapePattern || [[0, 0]];
      if (this.checkShapeOverlap(itemShapePattern, gridX, gridY, otherShapePattern, otherItem.gridX, otherItem.gridY)) {
        return false;
      }
    }

    return true;
  }

  checkShapeOverlap(pattern1, x1, y1, pattern2, x2, y2) {
    const cells1 = pattern1.map(([cellX, cellY]) => [x1 + cellX, y1 + cellY]);
    const cells2 = pattern2.map(([cellX, cellY]) => [x2 + cellX, y2 + cellY]);

    for (const [cell1X, cell1Y] of cells1) {
      for (const [cell2X, cell2Y] of cells2) {
        if (cell1X === cell2X && cell1Y === cell2Y) {
          return true;
        }
      }
    }
    return false;
  }

  placeInGrid(item, gridX, gridY) {
    const grid = this.characterGrid;
    item.x = grid.x + gridX * this.gridCellSize;
    item.y = grid.y + gridY * this.gridCellSize;
    item.gridX = gridX;
    item.gridY = gridY;

    if (!this.characterItems.includes(item)) {
      this.characterItems.push(item);
    }

    console.log(`✅ Placed ${item.name} in grid at (${gridX}, ${gridY})`);
  }

  removeFromGrid(item) {
    const index = this.characterItems.indexOf(item);
    if (index > -1) {
      this.characterItems.splice(index, 1);
      this.removeSprite(item);
      console.log(`🗑️ Removed ${item.name} from grid`);
    }
  }

  isOverStorageArea(mouseX, mouseY) {
    return mouseX >= this.storageList.x &&
           mouseX <= this.storageList.x + this.storageList.width &&
           mouseY >= this.storageList.y &&
           mouseY <= this.storageList.y + this.storageList.height;
  }

  // ============= VISUAL FEEDBACK =============

  showGridPlacementPreview(item, gridX, gridY, canPlace) {
    this.hidePlacementPreview();

    const preview = new PIXI.Graphics();
    const color = canPlace ? 0x5f7ea0 : 0xe74c3c;
    const alpha = canPlace ? 0.3 : 0.5;
    const padding = 4;

    const shapePattern = item.shapePattern || [[0, 0]];
    shapePattern.forEach(([cellX, cellY]) => {
      const cellGraphic = new PIXI.Graphics();
      cellGraphic.beginFill(color, alpha);
      cellGraphic.drawRoundedRect(
        padding / 2, padding / 2,
        this.gridCellSize - padding, this.gridCellSize - padding, 4
      );
      cellGraphic.endFill();

      cellGraphic.lineStyle(2, color, 0.8);
      cellGraphic.drawRoundedRect(
        padding / 2, padding / 2,
        this.gridCellSize - padding, this.gridCellSize - padding, 4
      );

      cellGraphic.x = cellX * this.gridCellSize;
      cellGraphic.y = cellY * this.gridCellSize;
      preview.addChild(cellGraphic);
    });

    preview.x = this.characterGrid.x + gridX * this.gridCellSize;
    preview.y = this.characterGrid.y + gridY * this.gridCellSize;

    this.addSprite(preview, "ui");
    this.placementPreview = preview;
  }

  hidePlacementPreview() {
    if (this.placementPreview) {
      this.removeSprite(this.placementPreview);
      this.placementPreview = null;
    }
  }

  showTooltip(item) {
    const tooltip = new PIXI.Container();

    const bg = new PIXI.Graphics();
    bg.beginFill(0x2c3e50, 0.95);
    bg.drawRoundedRect(0, 0, 200, 80, 8);
    bg.endFill();
    bg.lineStyle(2, 0x3498db);
    bg.drawRoundedRect(0, 0, 200, 80, 8);

    const itemName = item.name || item.originalData?.name || "Unknown Item";
    const itemType = item.type || item.originalData?.type || "unknown";
    const itemDesc = item.description || item.originalData?.description || "";

    const title = new PIXI.Text(itemName, {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    title.x = 10;
    title.y = 10;

    const info = new PIXI.Text(
      `Type: ${itemType}\n${itemDesc}`,
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
    tooltip.x = Math.min(this.engine.width - 220, event?.global?.x + 10 || 0);
    tooltip.y = Math.max(10, event?.global?.y - 90 || 0);

    this.addSprite(tooltip, "ui");
    this.currentTooltip = tooltip;
  }

  hideTooltip() {
    if (this.currentTooltip) {
      this.removeSprite(this.currentTooltip);
      this.currentTooltip = null;
    }
  }

  // ============= SCROLL HANDLING =============

  handleMouseWheel(event) {
    // Check if mouse is over storage area
    if (this.isOverStorageArea(event.global.x, event.global.y)) {
      const delta = event.deltaY > 0 ? 1 : -1;
      this.scrollStorage(delta);
      event.preventDefault();
    }
  }
}