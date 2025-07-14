import { HybridInventoryScene } from "../core/HybridInventoryScene.js";
import { ShapeHelper } from "../utils/ShapeHelper.js";

export class PixiInventoryScene extends HybridInventoryScene {
  constructor() {
    super();
    
    // Inventory-specific settings
    this.showShapeOutlines = false;
    this.showDimensionInfo = false;
    this.isInitialized = false;
  }

  onEnter() {
    super.onEnter();

    this.createBackground();
    this.createCharacterGrid();
    this.createStorageList();

    if (!this.isInitialized) {
      this.createStarterItems();
      this.isInitialized = true;
    } else {
      // Restore any existing items
      this.restoreItems();
    }

    this.createUI();
    
    // Update game mode display
    const gameModeBtn = document.getElementById("gameMode");
    if (gameModeBtn) {
      gameModeBtn.textContent = "🎒 INVENTORY";
    }

    console.log(`✅ Inventory loaded: ${this.characterItems.length} grid items, ${this.storageItems.length} storage items`);
  }

  createBackground() {
    const bg = new PIXI.Graphics();
    bg.beginFill(0x27ae60);
    bg.drawRect(0, 0, this.engine.width, this.engine.height);
    bg.endFill();
    this.addSprite(bg, "background");

    // Title
    const title = new PIXI.Text("🎒 HYBRID INVENTORY", {
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

    // Grid label
    const gridLabel = new PIXI.Text("Character Inventory (Grid-based)", {
      fontFamily: "Arial",
      fontSize: 16,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    gridLabel.x = this.characterGrid.x;
    gridLabel.y = this.characterGrid.y - 25;
    this.addSprite(gridLabel, "ui");

    // Storage label
    const storageLabel = new PIXI.Text("Storage (Unlimited)", {
      fontFamily: "Arial",
      fontSize: 16,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    storageLabel.x = this.storageList.x;
    storageLabel.y = this.storageList.y - 25;
    this.addSprite(storageLabel, "ui");
  }

  createUI() {
    // Instructions
    this.instructionsText = new PIXI.Text(
      "Drag items between grid and storage | Mouse wheel to scroll storage | R while dragging to rotate",
      {
        fontFamily: "Arial",
        fontSize: 14,
        fill: 0xffffff,
        align: "center",
      }
    );
    this.instructionsText.anchor.set(0.5);
    this.instructionsText.x = this.engine.width / 2;
    this.instructionsText.y = this.engine.height - 40;
    this.addSprite(this.instructionsText, "ui");

    // Storage info
    this.storageInfoText = new PIXI.Text("", {
      fontFamily: "Arial",
      fontSize: 12,
      fill: 0xecf0f1,
    });
    this.storageInfoText.x = this.storageList.x;
    this.storageInfoText.y = this.storageList.y + this.storageList.height + 10;
    this.addSprite(this.storageInfoText, "ui");

    this.updateStorageInfo();

    // Action buttons
    this.createActionButtons();
  }

  createActionButtons() {
    const buttons = [
      { text: "Reset Items", action: () => this.resetItems() },
      { text: "Clear Grid", action: () => this.clearGrid() },
      { text: "Sort Storage", action: () => this.sortStorage() },
      { text: "Add Test Items", action: () => this.addTestItems() },
    ];

    buttons.forEach((btnData, index) => {
      const button = new PIXI.Graphics();
      button.beginFill(0x3498db);
      button.drawRoundedRect(0, 0, 120, 35, 5);
      button.endFill();
      button.lineStyle(1, 0x2980b9);
      button.drawRoundedRect(0, 0, 120, 35, 5);

      const buttonText = new PIXI.Text(btnData.text, {
        fontFamily: "Arial",
        fontSize: 12,
        fill: 0xffffff,
        fontWeight: "bold",
        align: "center",
      });
      buttonText.anchor.set(0.5);
      buttonText.x = 60;
      buttonText.y = 17;
      button.addChild(buttonText);

      button.x = 50 + index * 140;
      button.y = this.engine.height - 80;
      button.interactive = true;
      button.cursor = "pointer";

      button.on("pointerover", () => {
        button.tint = 0xcccccc;
      });

      button.on("pointerout", () => {
        button.tint = 0xffffff;
      });

      button.on("pointerdown", btnData.action);

      this.addSprite(button, "ui");
    });
  }

  updateStorageInfo() {
    if (this.storageInfoText) {
      const total = this.storageItems.length;
      const totalQuantity = this.storageItems.reduce((sum, item) => sum + (item.quantity || 1), 0);
      this.storageInfoText.text = `${total} item types, ${totalQuantity} total items`;
    }
  }

  createStarterItems() {
    console.log("🎯 Creating starter items");

    // Grid items (shaped items for character inventory)
    const gridStarterItems = [
      {
        name: "Iron Sword",
        color: 0xe74c3c,
        width: 1,
        height: 3,
        type: "weapon",
        description: "A sturdy iron blade",
      },
      {
        name: "Magic Staff",
        color: 0x9b59b6,
        shape: "T",
        stemLength: 3,
        topWidth: 3,
        orientation: "up",
        type: "weapon",
        description: "A T-shaped magical staff",
      },
      {
        name: "Elven Bow",
        color: 0x16a085,
        shape: "U",
        width: 3,
        height: 3,
        orientation: "up",
        type: "weapon",
        description: "A graceful U-shaped bow",
      },
    ];

    // Storage items (various consumables and materials)
    const storageStarterItems = [
      { name: "Health Potion", color: 0xe74c3c, width: 1, height: 1, type: "consumable", quantity: 5 },
      { name: "Mana Potion", color: 0x3498db, width: 1, height: 1, type: "consumable", quantity: 3 },
      { name: "Iron Ore", color: 0x7f8c8d, width: 1, height: 1, type: "material", quantity: 10 },
      { name: "Magic Crystal", color: 0x9b59b6, width: 1, height: 1, type: "material", quantity: 2 },
      { name: "Dragon Scale", color: 0xf39c12, width: 1, height: 1, type: "material", quantity: 1 },
      { name: "Healing Herb", color: 0x27ae60, width: 1, height: 1, type: "consumable", quantity: 8 },
      { name: "Fire Gem", color: 0xe67e22, width: 1, height: 1, type: "gem", quantity: 3 },
      { name: "Ice Shard", color: 0x3498db, width: 1, height: 1, type: "material", quantity: 6 },
    ];

    // Place grid items in character inventory
    gridStarterItems.forEach((itemData, index) => {
      const item = this.createGridItem(itemData);
      
      // Try different positions
      const positions = [
        { x: 0, y: 0 },
        { x: 2, y: 0 },
        { x: 5, y: 0 },
        { x: 0, y: 4 },
        { x: 3, y: 4 },
      ];

      if (index < positions.length) {
        const pos = positions[index];
        if (this.canPlaceInGrid(item, pos.x, pos.y)) {
          this.placeInGrid(item, pos.x, pos.y);
          this.addSprite(item, "world");
        }
      }
    });

    // Add storage items
    storageStarterItems.forEach(itemData => {
      this.addToStorage(itemData);
    });

    console.log("✅ Starter items created");
  }

  restoreItems() {
    // Re-add grid items to display
    this.characterItems.forEach(item => {
      if (!item.parent) {
        this.addSprite(item, "world");
      }
    });

    // Refresh storage display
    this.refreshStorageDisplay();
  }

  // ============= ROTATION SYSTEM =============

  handleKeyDown(event) {
    if (event.code === "KeyR" && this.draggedItem && this.dragSource === "grid") {
      this.rotateDraggedItem();
    }
  }

  rotateDraggedItem() {
    const item = this.draggedItem;
    if (!item || this.isRotationPointless(item)) return;

    console.log(`🔄 Rotating ${item.name}`);

    // Store original state if first rotation
    if (!item.originalShapePattern) {
      item.originalShapePattern = [...item.shapePattern];
      item.originalGridWidth = item.gridWidth;
      item.originalGridHeight = item.gridHeight;
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
  }

  isRotationPointless(item) {
    const bounds = ShapeHelper.getBounds(item.shapePattern);
    
    // 1x1 items don't need rotation
    if (bounds.width === 1 && bounds.height === 1) return true;
    
    // Perfect squares don't change when rotated
    if (bounds.width === bounds.height && 
        (item.shape === "rectangle" || !item.shape)) return true;
    
    return false;
  }

  updateItemVisuals(item) {
    console.log(`🎨 Updating visuals for ${item.name}`);

    // Store the text content before clearing
    const textElement = item.children.find(child => child instanceof PIXI.Text);
    const textContent = textElement ? textElement.text : item.name;

    // Clear all children
    item.removeChildren();

    // Redraw with new shape
    const cellSize = this.gridCellSize;
    const padding = 4;
    const bounds = ShapeHelper.getBounds(item.shapePattern);

    // Draw the new shape
    item.shapePattern.forEach(([cellX, cellY]) => {
      const cellGraphic = new PIXI.Graphics();

      cellGraphic.beginFill(item.color);
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

    // Re-add text
    const fontSize = Math.min((bounds.width * cellSize - padding) / 8, 14);
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

    console.log(`✅ Updated visuals for ${item.name} (${bounds.width}x${bounds.height})`);
  }

  // Override mouse up to handle rotation state restoration
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
      
      // Clear rotation state since placement succeeded
      delete item.originalShapePattern;
      delete item.originalGridWidth;
      delete item.originalGridHeight;
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
      // Return to original position/state
      if (this.dragSource === "grid") {
        // Restore original rotation if it was rotated
        if (item.originalShapePattern) {
          item.shapePattern = [...item.originalShapePattern];
          item.gridWidth = item.originalGridWidth;
          item.gridHeight = item.originalGridHeight;
          this.updateItemVisuals(item);
          
          delete item.originalShapePattern;
          delete item.originalGridWidth;
          delete item.originalGridHeight;
        }
        
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
    this.updateStorageInfo();
  }

  // ============= ACTION METHODS =============

  resetItems() {
    console.log("🔄 Resetting all items");
    
    // Clear everything
    this.characterItems.forEach(item => this.removeSprite(item));
    this.characterItems = [];
    this.storageItems = [];
    
    // Recreate starter items
    this.createStarterItems();
    this.updateStorageInfo();
  }

  clearGrid() {
    console.log("🧹 Clearing character inventory grid");
    
    // Move all grid items to storage
    const itemsToMove = [...this.characterItems];
    itemsToMove.forEach(item => {
      this.addToStorage(item.originalData);
      this.removeFromGrid(item);
    });
    
    this.updateStorageInfo();
  }

  sortStorage() {
    console.log("📊 Sorting storage");
    
    // Sort by type, then by name
    this.storageItems.sort((a, b) => {
      if (a.type !== b.type) {
        return a.type.localeCompare(b.type);
      }
      return a.name.localeCompare(b.name);
    });
    
    this.storageScroll = 0;
    this.refreshStorageDisplay();
  }

  addTestItems() {
    console.log("🧪 Adding test items");
    
    const testItems = [
      { name: "Test Potion", color: 0xff6b35, type: "consumable", quantity: 3 },
      { name: "Magic Dust", color: 0x9b59b6, type: "material", quantity: 5 },
      { name: "Gold Coin", color: 0xf1c40f, type: "currency", quantity: 50 },
      { name: "Ancient Scroll", color: 0xd4af37, type: "quest", quantity: 1 },
    ];
    
    testItems.forEach(item => this.addToStorage(item));
    this.updateStorageInfo();
  }

  // ============= OVERRIDE MOUSE HANDLING =============

  handleMouseWheel(event) {
    super.handleMouseWheel(event);
    this.updateStorageInfo();
  }

  // Override addToStorage to update info
  addToStorage(itemData) {
    const result = super.addToStorage(itemData);
    this.updateStorageInfo();
    return result;
  }

  // Override removeFromStorage to update info
  removeFromStorage(itemData, quantity = 1) {
    const result = super.removeFromStorage(itemData, quantity);
    this.updateStorageInfo();
    return result;
  }
}
