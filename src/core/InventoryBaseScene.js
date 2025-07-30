// src/core/InventoryBaseScene.js
import { PixiScene } from "./PixiScene.js";

export class InventoryBaseScene extends PixiScene {
  constructor() {
    super();
    
    // Common inventory properties
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
  }

  // =================== GRID MANAGEMENT ===================

  createGrid(gridData, color, name) {
    const grid = new PIXI.Graphics();

    // Draw background
    grid.beginFill(color, 0.3);
    grid.drawRect(
      0,
      0,
      gridData.cols * this.gridCellSize,
      gridData.rows * this.gridCellSize
    );
    grid.endFill();

    // Draw grid lines
    grid.lineStyle({
      width: 1,
      color: 0xffffff,
      alpha: 0.5,
      alignment: 0.5,
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

    // Draw border
    grid.lineStyle({
      width: 2,
      color: 0xffffff,
      alpha: 0.8,
      alignment: 0,
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

  getGridPosition(grid, screenX, screenY) {
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

  findItemGrid(item) {
    const itemX = item.isDragging ? item.originalX : item.x;
    const itemY = item.isDragging ? item.originalY : item.y;

    // Check inventory grid
    if (
      itemX >= this.inventoryGrid.x &&
      itemX < this.inventoryGrid.x + this.inventoryGrid.cols * this.gridCellSize &&
      itemY >= this.inventoryGrid.y &&
      itemY < this.inventoryGrid.y + this.inventoryGrid.rows * this.gridCellSize
    ) {
      return this.inventoryGrid;
    }

    return this.storageGrid;
  }

  // =================== ITEM MANAGEMENT ===================

  canPlaceItemAt(grid, item, gridX, gridY) {
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

    // Check for overlapping with other items
    for (const otherItem of this.items) {
      if (otherItem === item || otherItem.gridX < 0 || otherItem.gridY < 0) {
        continue;
      }

      const otherItemGrid = this.findItemGrid(otherItem);
      if (otherItemGrid !== grid) {
        continue;
      }

      // Check overlap using shape patterns if available
      if (item.shapePattern && otherItem.shapePattern) {
        const hasOverlap = this.checkShapeOverlap(
          item.shapePattern, gridX, gridY,
          otherItem.shapePattern, otherItem.gridX, otherItem.gridY
        );
        if (hasOverlap) return false;
      } else {
        // Fallback to bounding box collision
        if (!(
          gridX >= otherItem.gridX + (otherItem.gridWidth || 1) ||
          gridX + itemGridWidth <= otherItem.gridX ||
          gridY >= otherItem.gridY + (otherItem.gridHeight || 1) ||
          gridY + itemGridHeight <= otherItem.gridY
        )) {
          return false;
        }
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

  placeItemInGrid(item, grid, gridX, gridY) {
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

    return true;
  }

  findItemUnderMouse(mouseX, mouseY) {
    for (let i = this.items.length - 1; i >= 0; i--) {
      const item = this.items[i];

      if (!item.visible || item.gridX < 0 || item.gridY < 0) {
        continue;
      }

      let mouseGridX = -1;
      let mouseGridY = -1;

      // Check which grid the mouse is over
      if (
        mouseX >= this.inventoryGrid.x &&
        mouseX < this.inventoryGrid.x + this.inventoryGrid.cols * this.gridCellSize &&
        mouseY >= this.inventoryGrid.y &&
        mouseY < this.inventoryGrid.y + this.inventoryGrid.rows * this.gridCellSize
      ) {
        mouseGridX = Math.floor((mouseX - this.inventoryGrid.x) / this.gridCellSize);
        mouseGridY = Math.floor((mouseY - this.inventoryGrid.y) / this.gridCellSize);
      } else if (
        mouseX >= this.storageGrid.x &&
        mouseX < this.storageGrid.x + this.storageGrid.cols * this.gridCellSize &&
        mouseY >= this.storageGrid.y &&
        mouseY < this.storageGrid.y + this.storageGrid.rows * this.gridCellSize
      ) {
        mouseGridX = Math.floor((mouseX - this.storageGrid.x) / this.gridCellSize);
        mouseGridY = Math.floor((mouseY - this.storageGrid.y) / this.gridCellSize);
      }

      if (mouseGridX >= 0 && mouseGridY >= 0) {
        // Check if mouse is over any cell of this item
        const shapePattern = item.shapePattern || [[0, 0]];
        for (const [cellX, cellY] of shapePattern) {
          const absoluteCellX = item.gridX + cellX;
          const absoluteCellY = item.gridY + cellY;

          if (mouseGridX === absoluteCellX && mouseGridY === absoluteCellY) {
            return item;
          }
        }
      }
    }

    return null;
  }

  // =================== VISUAL HELPERS ===================

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

  showPlacementPreview(item, grid, gridX, gridY, canPlace) {
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

  // =================== TOOLTIP SYSTEM ===================

  showTooltip(item) {
    this.hideTooltip();

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
        `Size: ${item.gridWidth || item.width || 1}×${item.gridHeight || item.height || 1}`,
        item.description || "",
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
    tooltip.x = item.x + (item.gridWidth || 1) * this.gridCellSize + 10;
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

  // =================== UTILITY METHODS ===================

  initializePersistentData() {
    if (!this.items) {
      this.items = [];
    }
  }

  onExit() {
    this.hidePlacementPreview();
    this.hideTooltip();
    this.draggedItem = null;
    super.onExit();
  }
}