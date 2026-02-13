import { HybridInventoryScene } from "../core/HybridInventoryScene.js";
import { ShapeHelper } from "../utils/ShapeHelper.js";

export class PixiInventoryScene extends HybridInventoryScene {
  constructor() {
    super();

    // Inventory-specific settings
    this.showShapeOutlines = false;
    this.showDimensionInfo = false;
    this.isInitialized = false;

    // UI elements references for responsive updates
    this.titleElement = null;
    this.gridLabelElement = null;
    this.storageLabelElement = null;
    this.instructionsElement = null;
    this.storageInfoElement = null;
    this.actionButtons = [];
  }

  onEnter() {
    super.onEnter();

    this.createBackground();
    this.createTitle();
    this.createLabels();
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
    const gameModeBtn = document.getElementById('gameMode');
    if (gameModeBtn) {
      gameModeBtn.textContent = '🎒 INVENTORY';
    }

    console.log(`✅ Responsive inventory loaded: ${this.characterItems.length} grid items, ${this.storageItems.length} storage items`);
  }

  onResize(newWidth, newHeight) {
    super.onResize(newWidth, newHeight);

    // Update all UI elements for new size
    this.updateTitleAndLabels();
    this.updateInstructions();
    this.updateActionButtons();
    this.updateStorageInfo();

    console.log(`Inventory scene resized to ${newWidth}x${newHeight}`);
  }

  createBackground() {
    // Remove existing background
    const existingBg = this.layers.background.getChildByName("inventoryBackground");
    if (existingBg) {
      this.layers.background.removeChild(existingBg);
    }

    const bg = new PIXI.Graphics();
    bg.beginFill(0x27ae60);
    bg.drawRect(-this.viewportWidth/2, -this.viewportHeight/2, this.viewportWidth, this.viewportHeight);
    bg.endFill();
    bg.name = "inventoryBackground";

    this.makeResponsive(bg, {
      anchor: { x: 'center', y: 'center' },
      offset: { x: 0, y: 0 },
      scale: false
    });

    this.addSprite(bg, 'background');
  }

  createTitle() {
    if (this.titleElement) {
      this.removeSprite(this.titleElement);
    }

    this.titleElement = new PIXI.Text('🎒 HYBRID INVENTORY', {
      fontFamily: 'Arial',
      fontSize: this.getResponsiveFontSize(this.isMobile ? 24 : 28),
      fill: 0xffffff,
      align: 'center',
      fontWeight: 'bold',
      stroke: 0x2c3e50,
      strokeThickness: this.isMobile ? 2 : 3,
    });

    this.titleElement.anchor.set(0.5);

    this.makeResponsive(this.titleElement, {
      anchor: { x: 'center', y: 'top' },
      offset: { x: 0, y: this.getResponsivePadding(40) },
      scale: true,
      minScale: 0.7,
      maxScale: 1.2
    });

    this.addSprite(this.titleElement, 'ui');
  }

  createLabels() {
    this.updateTitleAndLabels();
  }

  updateTitleAndLabels() {
    // Grid label
    if (this.gridLabelElement) {
      this.removeSprite(this.gridLabelElement);
    }

    this.gridLabelElement = new PIXI.Text('Character Inventory (Grid-based)', {
      fontFamily: 'Arial',
      fontSize: this.getResponsiveFontSize(16),
      fill: 0xffffff,
      fontWeight: 'bold',
    });
    this.gridLabelElement.x = this.characterGrid.x;
    this.gridLabelElement.y = this.characterGrid.y - this.getResponsivePadding(25);
    this.addSprite(this.gridLabelElement, 'ui');

    // Storage label
    if (this.storageLabelElement) {
      this.removeSprite(this.storageLabelElement);
    }

    this.storageLabelElement = new PIXI.Text('Storage (Unlimited)', {
      fontFamily: 'Arial',
      fontSize: this.getResponsiveFontSize(16),
      fill: 0xffffff,
      fontWeight: 'bold',
    });
    this.storageLabelElement.x = this.storageList.x;
    this.storageLabelElement.y = this.storageList.y - this.getResponsivePadding(25);
    this.addSprite(this.storageLabelElement, 'ui');
  }

  createUI() {
    this.createInstructions();
    this.createStorageInfo();
    this.createActionButtons();
  }

  createInstructions() {
    this.updateInstructions();
  }

  updateInstructions() {
    if (this.instructionsElement) {
      this.removeSprite(this.instructionsElement);
    }

    const instructionText = this.isMobile
      ? "Drag items • Scroll storage • R to rotate"
      : "Drag items between grid and storage | Mouse wheel to scroll storage | R while dragging to rotate";

    this.instructionsElement = new PIXI.Text(instructionText, {
      fontFamily: 'Arial',
      fontSize: this.getResponsiveFontSize(this.isMobile ? 12 : 14),
      fill: 0xffffff,
      align: 'center',
      wordWrap: this.isMobile,
      wordWrapWidth: this.viewportWidth - this.getResponsivePadding(40),
    });

    this.instructionsElement.anchor.set(0.5);

    this.makeResponsive(this.instructionsElement, {
      anchor: { x: 'center', y: 'bottom' },
      offset: { x: 0, y: -this.getResponsivePadding(40) },
      scale: true,
      minScale: 0.8,
      maxScale: 1.0
    });

    this.addSprite(this.instructionsElement, 'ui');
  }

  createStorageInfo() {
    this.updateStorageInfo();
  }

  updateStorageInfo() {
    if (this.storageInfoElement) {
      this.removeSprite(this.storageInfoElement);
    }

    const total = this.storageItems.length;
    const totalQuantity = this.storageItems.reduce((sum, item) => sum + (item.quantity || 1), 0);

    this.storageInfoElement = new PIXI.Text(`${total} item types, ${totalQuantity} total items`, {
      fontFamily: 'Arial',
      fontSize: this.getResponsiveFontSize(12),
      fill: 0xecf0f1,
    });

    this.storageInfoElement.x = this.storageList.x;
    this.storageInfoElement.y = this.storageList.y + this.storageList.height + this.getResponsivePadding(10);
    this.addSprite(this.storageInfoElement, 'ui');
  }

  createActionButtons() {
    this.updateActionButtons();
  }

  updateActionButtons() {
    // Remove existing buttons
    this.actionButtons.forEach(button => {
      this.removeSprite(button);
    });
    this.actionButtons = [];

    const buttons = [
      { text: 'Reset Items', action: () => this.resetItems() },
      { text: 'Clear Grid', action: () => this.clearGrid() },
      { text: 'Sort Storage', action: () => this.sortStorage() },
      { text: 'Add Test Items', action: () => this.addTestItems() },
    ];

    const buttonWidth = this.getScaledSize(this.isMobile ? 100 : 120);
    const buttonHeight = this.getScaledSize(this.isMobile ? 30 : 35);
    const buttonSpacing = this.getResponsivePadding(this.isMobile ? 110 : 140);
    const startX = this.getResponsivePadding(50);

    buttons.forEach((btnData, index) => {
      const button = new PIXI.Graphics();
      button.beginFill(0x3498db);
      button.drawRoundedRect(0, 0, buttonWidth, buttonHeight, 5);
      button.endFill();
      button.lineStyle(1, 0x2980b9);
      button.drawRoundedRect(0, 0, buttonWidth, buttonHeight, 5);

      const buttonText = new PIXI.Text(btnData.text, {
        fontFamily: 'Arial',
        fontSize: this.getResponsiveFontSize(this.isMobile ? 10 : 12),
        fill: 0xffffff,
        fontWeight: 'bold',
        align: 'center',
      });
      buttonText.anchor.set(0.5);
      buttonText.x = buttonWidth / 2;
      buttonText.y = buttonHeight / 2;
      button.addChild(buttonText);

      button.x = startX + (index * buttonSpacing);
      button.y = this.viewportHeight - this.getResponsivePadding(this.isMobile ? 60 : 80);
      button.interactive = true;
      button.cursor = 'pointer';

      // Store references for hover effects
      button.bg = button;
      button.text = buttonText;

      button.on('pointerover', () => {
        if (!this.isMobile) {
          button.tint = 0xcccccc;
        }
      });

      button.on('pointerout', () => {
        button.tint = 0xffffff;
      });

      button.on('pointerdown', btnData.action);

      this.addSprite(button, 'ui');
      this.actionButtons.push(button);
    });
  }

  // =================== STARTER ITEMS ===================

  createStarterItems() {
    console.log('🎯 Creating responsive starter items');

    // Grid items (shaped items for character inventory)
    const gridStarterItems = [
      {
        name: 'Iron Sword',
        color: 0xe74c3c,
        width: 1,
        height: 3,
        type: 'weapon',
        description: 'A sturdy iron blade',
      },
      {
        name: 'Magic Staff',
        color: 0x9b59b6,
        shape: 'T',
        stemLength: 3,
        topWidth: 3,
        orientation: 'up',
        type: 'weapon',
        description: 'A T-shaped magical staff',
      },
      {
        name: 'Elven Bow',
        color: 0x16a085,
        shape: 'U',
        width: 3,
        height: 3,
        orientation: 'up',
        type: 'weapon',
        description: 'A graceful U-shaped bow',
      },
      {
        name: 'Battle Shield',
        color: 0x34495e,
        width: 2,
        height: 2,
        type: 'armor',
        description: 'A protective battle shield',
      },
    ];

    // Storage items (various consumables and materials)
    const storageStarterItems = [
      { name: 'Health Potion', color: 0xe74c3c, width: 1, height: 1, type: 'consumable', quantity: 5 },
      { name: 'Mana Potion', color: 0x3498db, width: 1, height: 1, type: 'consumable', quantity: 3 },
      { name: 'Iron Ore', color: 0x7f8c8d, width: 1, height: 1, type: 'material', quantity: 10 },
      { name: 'Magic Crystal', color: 0x9b59b6, width: 1, height: 1, type: 'material', quantity: 2 },
      { name: 'Dragon Scale', color: 0xf39c12, width: 1, height: 1, type: 'material', quantity: 1 },
      { name: 'Healing Herb', color: 0x27ae60, width: 1, height: 1, type: 'consumable', quantity: 8 },
      { name: 'Fire Gem', color: 0xe67e22, width: 1, height: 1, type: 'gem', quantity: 3 },
      { name: 'Ice Shard', color: 0x3498db, width: 1, height: 1, type: 'material', quantity: 6 },
      { name: 'Lightning Essence', color: 0xf1c40f, width: 1, height: 1, type: 'material', quantity: 2 },
      { name: 'Shadow Orb', color: 0x2c3e50, width: 1, height: 1, type: 'gem', quantity: 1 },
    ];

    // Place grid items in character inventory
    gridStarterItems.forEach((itemData, index) => {
      const item = this.createGridItem(itemData);

      // Try different positions that work with responsive grid
      const positions = [
        { x: 0, y: 0 },
        { x: 2, y: 0 },
        { x: 5, y: 0 },
        { x: 0, y: 4 },
        { x: 3, y: 4 },
        { x: 6, y: 4 },
      ];

      if (index < positions.length) {
        const pos = positions[index];
        if (this.canPlaceInGrid(item, pos.x, pos.y)) {
          this.placeInGrid(item, pos.x, pos.y);
          this.addSprite(item, 'world');
        }
      }
    });

    // Add storage items
    storageStarterItems.forEach(itemData => {
      this.addToStorage(itemData);
    });

    console.log('✅ Responsive starter items created');
  }

  restoreItems() {
    // Re-add grid items to display
    this.characterItems.forEach(item => {
      if (!item.parent) {
        this.addSprite(item, 'world');
      }
    });

    // Refresh storage display
    this.refreshStorageDisplay();
  }

  // ============= ROTATION SYSTEM =============

  handleKeyDown(event) {
    if (event.code === 'KeyR' && this.draggedItem && this.dragSource === 'grid') {
      this.rotateDraggedItem();
    }
  }

  rotateDraggedItem() {
    const item = this.draggedItem;
    if (!item || this.isRotationPointless(item)) return;

    console.log(`🔄 Rotating ${item.name} (responsive)`);

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

    // Update visuals with responsive sizing
    this.updateItemVisuals(item);
  }

  isRotationPointless(item) {
    const bounds = ShapeHelper.getBounds(item.shapePattern);

    // 1x1 items don't need rotation
    if (bounds.width === 1 && bounds.height === 1) return true;

    // Perfect squares don't change when rotated
    if (bounds.width === bounds.height &&
        (item.shape === 'rectangle' || !item.shape)) return true;

    return false;
  }

  updateItemVisuals(item) {
    console.log(`🎨 Updating responsive visuals for ${item.name}`);

    // Store the text content before clearing
    const textElement = item.children.find(child => child instanceof PIXI.Text);
    const textContent = textElement ? textElement.text : item.name;

    // Clear all children
    item.removeChildren();

    // Redraw with new shape using responsive sizing
    const cellSize = this.gridCellSize;
    const padding = this.getResponsivePadding(4);
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

      cellGraphic.lineStyle(Math.max(2, this.scaleFactor * 2), 0x2c3e50);
      cellGraphic.drawRoundedRect(
        padding / 2, padding / 2,
        cellSize - padding, cellSize - padding, 4
      );

      cellGraphic.x = cellX * cellSize;
      cellGraphic.y = cellY * cellSize;
      item.addChild(cellGraphic);
    });

    // Re-add text with responsive font size
    const fontSize = this.getResponsiveFontSize(Math.min((bounds.width * cellSize - padding) / 8, 14));
    const text = new PIXI.Text(textContent, {
      fontFamily: 'Arial',
      fontSize: fontSize,
      fill: 0xffffff,
      align: 'center',
      fontWeight: 'bold',
      stroke: 0x000000,
      strokeThickness: Math.max(1, this.scaleFactor),
    });
    text.anchor.set(0.5);
    text.x = (bounds.width * cellSize) / 2;
    text.y = (bounds.height * cellSize) / 2;
    item.addChild(text);

    console.log(`✅ Updated responsive visuals for ${item.name} (${bounds.width}x${bounds.height})`);
  }

  // Override mouse up to handle rotation state restoration
  handleMouseUp(event) {
    if (!this.draggedItem) return;

    const item = this.draggedItem;
    const mouseX = event.normalizedGlobal ? event.normalizedGlobal.x : event.global.x;
    const mouseY = event.normalizedGlobal ? event.normalizedGlobal.y : event.global.y;

    // Try to place in grid
    const gridPos = this.getGridPosition(mouseX, mouseY);
    if (gridPos && this.canPlaceInGrid(item, gridPos.x, gridPos.y)) {
      this.placeInGrid(item, gridPos.x, gridPos.y);

      if (this.dragSource === 'list') {
        // Remove from storage list
        this.removeFromStorage(item.originalData, 1);
      }

      // Clear rotation state since placement succeeded
      delete item.originalShapePattern;
      delete item.originalGridWidth;
      delete item.originalGridHeight;
    } else if (this.isOverStorageArea(mouseX, mouseY)) {
      // Drop in storage
      if (this.dragSource === 'grid') {
        // Move from grid to storage
        this.addToStorage(item.originalData);
        this.removeFromGrid(item);
      } else {
        // Return to list
        this.removeSprite(item);
      }
    } else {
      // Return to original position/state
      if (this.dragSource === 'grid') {
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
    console.log('🔄 Resetting all responsive items');

    // Clear everything
    this.characterItems.forEach(item => this.removeSprite(item));
    this.characterItems = [];
    this.storageItems = [];

    // Recreate starter items
    this.createStarterItems();
    this.updateStorageInfo();
  }

  clearGrid() {
    console.log('🧹 Clearing character inventory grid');

    // Move all grid items to storage
    const itemsToMove = [...this.characterItems];
    itemsToMove.forEach(item => {
      this.addToStorage(item.originalData);
      this.removeFromGrid(item);
    });

    this.updateStorageInfo();
  }

  sortStorage() {
    console.log('📊 Sorting responsive storage');

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
    console.log('🧪 Adding responsive test items');

    const testItems = [
      { name: 'Test Potion', color: 0xff6b35, type: 'consumable', quantity: 3 },
      { name: 'Magic Dust', color: 0x9b59b6, type: 'material', quantity: 5 },
      { name: 'Gold Coin', color: 0xf1c40f, type: 'currency', quantity: 50 },
      { name: 'Ancient Scroll', color: 0xd4af37, type: 'quest', quantity: 1 },
      { name: 'Phoenix Feather', color: 0xe74c3c, type: 'material', quantity: 2 },
      { name: 'Moonstone', color: 0x9c88ff, type: 'gem', quantity: 1 },
    ];

    testItems.forEach(item => this.addToStorage(item));
    this.updateStorageInfo();
  }

  // ============= OVERRIDE METHODS FOR RESPONSIVE UPDATES =============

  addToStorage(itemData) {
    const result = super.addToStorage(itemData);
    this.updateStorageInfo();
    return result;
  }

  removeFromStorage(itemData, quantity = 1) {
    const result = super.removeFromStorage(itemData, quantity);
    this.updateStorageInfo();
    return result;
  }

  scrollStorage(delta) {
    super.scrollStorage(delta);
    this.updateStorageInfo();
  }

  refreshStorageDisplay() {
    super.refreshStorageDisplay();
    this.updateStorageInfo();
  }

  // ============= UPDATE METHOD =============

  update(deltaTime) {
    super.update(deltaTime);

    // Update background if needed
    if (Math.random() < 0.01) { // 1% chance per frame
      this.createBackground();
    }
  }
}
