import { HybridInventoryScene } from "../core/HybridInventoryScene.js";
import { ShapeHelper } from "../utils/ShapeHelper.js";

export class PixiLootScene extends HybridInventoryScene {
  constructor() {
    super();
    
    // Override layout for three-area design
    this.characterGrid = { x: 50, y: 120, cols: 8, rows: 6 };
    this.lootGrid = { x: 600, y: 120, cols: 8, rows: 6 };
    this.storageList = { x: 50, y: 450, width: 1100, height: 200 };
    
    // Loot-specific properties
    this.lootData = null;
    this.returnScene = "world";
    this.title = "💎 TREASURE FOUND!";
    this.subtitle = "Drag items between character inventory, loot, and storage";
    this.context = null;
    this.showStats = false;
    this.stats = null;
    
    // Loot grid management
    this.lootItems = []; // Items in the loot grid
    
    // Update storage for horizontal layout
    this.storageItemHeight = 40;
    this.storageItemWidth = 200;
    this.storageItemsPerRow = 5;
    this.storageMaxVisible = 10; // 2 rows of 5 items
  }

  setLootData(lootData, options = {}) {
    this.lootData = lootData || [];
    this.returnScene = options.returnScene || "world";
    this.title = options.title || "💎 TREASURE FOUND!";
    this.subtitle = options.subtitle || "Drag items between character inventory, loot, and storage";
    this.showStats = options.showStats || false;
    this.stats = options.stats || null;
    this.context = options.context;

    console.log("🎁 Loot scene configured:", {
      itemCount: this.lootData.length,
      returnScene: this.returnScene,
      showStats: this.showStats
    });
  }

  onEnter() {
    super.onEnter();
    this.createLootSceneLayout();
    
    // Update game mode display
    const gameModeBtn = document.getElementById("gameMode");
    if (gameModeBtn) {
      gameModeBtn.textContent = "💎 LOOT";
    }

    console.log("💎 Loot scene entered with grid layout");
  }

  createLootSceneLayout() {
    this.createBackground();
    this.createCharacterGrid();
    this.createLootGrid();
    this.createStorageList();
    this.loadExistingInventory();
    this.placeLootItems();
    this.createUI();
  }

  createBackground() {
    const bg = new PIXI.Graphics();
    
    // Create a victory/treasure themed background
    const bgColor = this.title.includes("VICTORY") ? 0x1b5e20 : 0x4a148c;
    bg.beginFill(bgColor);
    bg.drawRect(0, 0, this.engine.width, this.engine.height);
    bg.endFill();
    
    // Add some sparkle effects for loot
    for (let i = 0; i < 15; i++) {
      bg.beginFill(0xffd700, 0.3);
      this.drawStar(bg, 
        Math.random() * this.engine.width,
        Math.random() * this.engine.height,
        5, Math.random() * 8 + 4, Math.random() * 4 + 2
      );
      bg.endFill();
    }
    
    this.addSprite(bg, "background");

    // Title
    const title = new PIXI.Text(this.title, {
      fontFamily: "Arial",
      fontSize: 32,
      fill: 0xffd700,
      align: "center",
      fontWeight: "bold",
      stroke: 0x000000,
      strokeThickness: 2,
    });
    title.anchor.set(0.5);
    title.x = this.engine.width / 2;
    title.y = 40;
    this.addSprite(title, "ui");

    // Stats if available
    if (this.showStats && this.stats) {
      const statsText = new PIXI.Text(
        `Battle completed in ${this.stats.turnCount} turns • ${this.stats.damageDealt} damage dealt • ${this.stats.skillsUsed} skills used`,
        {
          fontFamily: "Arial",
          fontSize: 14,
          fill: 0xffffff,
          align: "center",
        }
      );
      statsText.anchor.set(0.5);
      statsText.x = this.engine.width / 2;
      statsText.y = 75;
      this.addSprite(statsText, "ui");
    }
  }

  createLootGrid() {
    const grid = this.lootGrid;
    const gridGraphics = new PIXI.Graphics();

    // Loot grid has a golden theme
    gridGraphics.beginFill(0xf39c12, 0.3);
    gridGraphics.drawRect(0, 0, grid.cols * this.gridCellSize, grid.rows * this.gridCellSize);
    gridGraphics.endFill();

    // Grid lines
    gridGraphics.lineStyle({ width: 1, color: 0xffd700, alpha: 0.7 });
    
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

    // Border with golden glow
    gridGraphics.lineStyle({ width: 3, color: 0xffd700, alpha: 1 });
    gridGraphics.drawRect(0, 0, grid.cols * this.gridCellSize, grid.rows * this.gridCellSize);

    gridGraphics.x = grid.x;
    gridGraphics.y = grid.y;
    gridGraphics.name = "lootGridGraphics";

    this.addGraphics(gridGraphics, "world");

    // Grid label
    const label = new PIXI.Text("🎁 Found Loot", {
      fontFamily: "Arial",
      fontSize: 18,
      fill: 0xffd700,
      fontWeight: "bold",
    });
    label.x = grid.x;
    label.y = grid.y - 30;
    this.addSprite(label, "ui");

    return gridGraphics;
  }

  createCharacterGrid() {
    const result = super.createCharacterGrid();
    
    // Update character grid label
    const label = new PIXI.Text("🎒 Character Inventory", {
      fontFamily: "Arial",
      fontSize: 18,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    label.x = this.characterGrid.x;
    label.y = this.characterGrid.y - 30;
    this.addSprite(label, "ui");
    
    return result;
  }

  createStorageList() {
    const storage = this.storageList;
    const listGraphics = new PIXI.Graphics();

    // Horizontal storage area background
    listGraphics.beginFill(0x8e44ad, 0.3);
    listGraphics.drawRect(0, 0, storage.width, storage.height);
    listGraphics.endFill();

    // Border
    listGraphics.lineStyle({ width: 2, color: 0x9b59b6, alpha: 0.8 });
    listGraphics.drawRect(0, 0, storage.width, storage.height);

    listGraphics.x = storage.x;
    listGraphics.y = storage.y;
    listGraphics.name = "storageListGraphics";

    this.addGraphics(listGraphics, "world");

    // Storage label
    const label = new PIXI.Text("📦 Storage (Unlimited)", {
      fontFamily: "Arial",
      fontSize: 18,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    label.x = storage.x;
    label.y = storage.y - 30;
    this.addSprite(label, "ui");

    return listGraphics;
  }

  loadExistingInventory() {
    console.log("📦 Loading existing character inventory");
    
    const inventoryScene = this.engine.scenes.get("inventory");
    
    // Check if inventory scene has been initialized with items
    const hasExistingInventory = inventoryScene && 
                                inventoryScene.isInitialized && 
                                inventoryScene.characterItems && 
                                inventoryScene.characterItems.length > 0;

    if (hasExistingInventory) {
      console.log("Loading from existing inventory scene");
      
      // Copy existing character items
      inventoryScene.characterItems.forEach(existingItem => {
        if (existingItem.gridX >= 0 && existingItem.gridY >= 0) {
          // Create a copy of the item for the loot scene
          const itemCopy = this.createGridItem(existingItem.originalData);
          this.placeInGrid(itemCopy, existingItem.gridX, existingItem.gridY);
          this.addSprite(itemCopy, "world");
        }
      });

      // Copy storage items
      if (inventoryScene.storageItems) {
        this.storageItems = [...inventoryScene.storageItems];
        this.refreshStorageDisplay();
      }
    } else {
      console.log("No existing inventory found, creating default starter items");
      this.createDefaultInventory();
    }

    console.log(`✅ Loaded ${this.characterItems.length} character items and ${this.storageItems.length} storage items`);
  }

  createDefaultInventory() {
    console.log("🎒 Creating default character inventory");

    // Default character starting equipment
    const defaultItems = [
      {
        name: "Iron Sword",
        color: 0xe74c3c,
        width: 1,
        height: 3,
        type: "weapon",
        description: "A reliable iron blade for any adventurer",
        baseSkills: [
          {
            name: "Slash",
            description: "Basic sword attack",
            damage: 20,
            cost: 0,
            type: "physical",
          },
        ],
      },
      {
        name: "Wooden Shield",
        color: 0x8b4513,
        width: 2,
        height: 2,
        type: "armor",
        description: "Simple protection for new adventurers",
        baseSkills: [
          {
            name: "Block",
            description: "Defensive stance",
            damage: 0,
            cost: 2,
            type: "defensive",
          },
        ],
        enhancements: [
          {
            targetTypes: ["physical"],
            nameModifier: (name) => `Shielded ${name}`,
            descriptionModifier: (desc) => desc + " with shield protection",
            damageBonus: 3,
          },
        ],
      },
      {
        name: "Health Potion",
        color: 0xe74c3c,
        width: 1,
        height: 1,
        type: "consumable",
        description: "Restores health when consumed",
        baseSkills: [
          {
            name: "Heal",
            description: "Restore health",
            damage: -25,
            cost: 0,
            type: "healing",
          },
        ],
      },
    ];

    // Default storage items
    const defaultStorageItems = [
      { name: "Bread", color: 0xdeb887, width: 1, height: 1, type: "consumable", quantity: 3, description: "Basic sustenance" },
      { name: "Copper Coin", color: 0xcd7f32, width: 1, height: 1, type: "currency", quantity: 25, description: "Common currency" },
      { name: "Rope", color: 0x8b4513, width: 1, height: 1, type: "tool", quantity: 1, description: "Useful for climbing" },
    ];

    // Place default items in character grid
    const placements = [
      { x: 0, y: 0 }, // Sword
      { x: 2, y: 0 }, // Shield  
      { x: 5, y: 0 }, // Potion
    ];

    defaultItems.forEach((itemData, index) => {
      const item = this.createGridItem(itemData);
      
      if (index < placements.length) {
        const pos = placements[index];
        if (this.canPlaceInGrid(item, pos.x, pos.y)) {
          this.placeInGrid(item, pos.x, pos.y);
          this.addSprite(item, "world");
          console.log(`✅ Placed default ${itemData.name} at (${pos.x}, ${pos.y})`);
        } else {
          // Fallback to auto-placement
          this.autoPlaceInGrid(item);
        }
      } else {
        this.autoPlaceInGrid(item);
      }
    });

    // Add default storage items
    defaultStorageItems.forEach(itemData => {
      this.addToStorage(itemData);
    });

    this.refreshStorageDisplay();
    console.log("✅ Default inventory created");
  }

  autoPlaceInGrid(item) {
    // Try to find any available spot in the character grid
    for (let y = 0; y <= this.characterGrid.rows - item.gridHeight; y++) {
      for (let x = 0; x <= this.characterGrid.cols - item.gridWidth; x++) {
        if (this.canPlaceInGrid(item, x, y)) {
          this.placeInGrid(item, x, y);
          this.addSprite(item, "world");
          console.log(`✅ Auto-placed ${item.name} at (${x}, ${y})`);
          return true;
        }
      }
    }
    
    // If no space in grid, add to storage instead
    console.log(`⚠️ No space for ${item.name}, adding to storage`);
    this.addToStorage(item.originalData);
    return false;
  }

  placeLootItems() {
    if (!this.lootData || this.lootData.length === 0) {
      console.log("No loot items to place");
      return;
    }

    console.log(`🎁 Placing ${this.lootData.length} loot items`);

    this.lootData.forEach((itemData, index) => {
      const lootItem = this.createLootGridItem(itemData);
      
      // Try to find a spot in the loot grid
      let placed = false;
      for (let y = 0; y <= this.lootGrid.rows - lootItem.gridHeight && !placed; y++) {
        for (let x = 0; x <= this.lootGrid.cols - lootItem.gridWidth && !placed; x++) {
          if (this.canPlaceInLootGrid(lootItem, x, y)) {
            this.placeInLootGrid(lootItem, x, y);
            this.addSprite(lootItem, "world");
            placed = true;
          }
        }
      }

      if (!placed) {
        console.warn(`⚠️ Could not place ${itemData.name} in loot grid, adding to storage`);
        this.addToStorage(itemData);
      }
    });

    console.log(`✅ Placed ${this.lootItems.length} items in loot grid`);
  }

  createLootGridItem(data) {
    console.log(`🔨 Creating loot grid item: ${data.name}`);

    const item = this.createGridItem(data);
    item.storageType = "loot"; // Mark as loot item
    
    // Add special loot effects
    this.addLootEffects(item, data);
    
    // Override the interactive behavior for loot items
    this.makeLootItemInteractive(item);
    
    return item;
  }

  addLootEffects(item, data) {
    // Add glow effect for valuable items
    if (data.type === "gem" || 
        data.name.includes("Medal") || 
        data.name.includes("Epic") ||
        data.name.includes("Legendary") ||
        data.name.includes("Dragon")) {
      
      const glow = new PIXI.Graphics();
      glow.lineStyle(3, 0xffd700, 0.8);
      
      // Draw glow around the item shape
      const padding = 6;
      const shapePattern = item.shapePattern || [[0, 0]];
      shapePattern.forEach(([cellX, cellY]) => {
        glow.drawRoundedRect(
          cellX * this.gridCellSize - padding,
          cellY * this.gridCellSize - padding,
          this.gridCellSize + padding * 2,
          this.gridCellSize + padding * 2,
          8
        );
      });
      
      item.addChildAt(glow, 0);

      // Animate glow
      let time = Math.random() * Math.PI * 2;
      const animate = () => {
        time += 0.05;
        glow.alpha = 0.4 + Math.sin(time) * 0.4;
        if (this.isActive && item.parent) {
          requestAnimationFrame(animate);
        }
      };
      animate();
    }
  }

  makeLootItemInteractive(item) {
    this.makeItemInteractive(item);
    
    // Add special hover effect for loot items
    item.on("pointerover", () => {
      if (!this.draggedItem) {
        item.scale.set(1.1);
        this.showTooltip(item);
        
        // Add sparkle effect on hover
        this.addSparkleEffect(item);
      }
    });

    item.on("pointerout", () => {
      if (!this.draggedItem) {
        item.scale.set(1);
        this.hideTooltip();
      }
    });
  }

  addSparkleEffect(item) {
    const sparkles = new PIXI.Container();
    
    for (let i = 0; i < 5; i++) {
      const sparkle = new PIXI.Graphics();
      sparkle.beginFill(0xffd700);
      this.drawStar(sparkle, 0, 0, 4, 4, 2);
      sparkle.endFill();
      
      sparkle.x = Math.random() * item.gridWidth * this.gridCellSize;
      sparkle.y = Math.random() * item.gridHeight * this.gridCellSize;
      sparkle.scale.set(0.5);
      
      sparkles.addChild(sparkle);
    }
    
    item.addChild(sparkles);
    
    // Remove sparkles after animation
    setTimeout(() => {
      if (sparkles.parent) {
        item.removeChild(sparkles);
      }
    }, 1000);
  }

  // ============= HELPER METHODS =============

  drawStar(graphics, x, y, points, outerRadius, innerRadius) {
    const step = Math.PI / points;
    const halfStep = step / 2;
    
    graphics.moveTo(x + outerRadius, y);
    
    for (let i = 1; i <= points * 2; i++) {
      const radius = i % 2 === 0 ? outerRadius : innerRadius;
      const angle = i * halfStep;
      graphics.lineTo(
        x + Math.cos(angle) * radius,
        y + Math.sin(angle) * radius
      );
    }
    
    graphics.closePath();
  }

  createUI() {
    // Instructions
    const instructions = new PIXI.Text(
      this.subtitle + " | ESC or click Close to return",
      {
        fontFamily: "Arial",
        fontSize: 14,
        fill: 0xffffff,
        align: "center",
      }
    );
    instructions.anchor.set(0.5);
    instructions.x = this.engine.width / 2;
    instructions.y = this.engine.height - 40;
    this.addSprite(instructions, "ui");

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
      { text: "Take All Loot", action: () => this.takeAllLoot() },
      { text: "Send All to Storage", action: () => this.sendAllToStorage() },
      { text: "Close", action: () => this.closeLootScene() },
    ];

    buttons.forEach((btnData, index) => {
      const button = new PIXI.Graphics();
      button.beginFill(index === 2 ? 0xe74c3c : 0x27ae60);
      button.drawRoundedRect(0, 0, 140, 35, 5);
      button.endFill();
      button.lineStyle(1, index === 2 ? 0xc0392b : 0x229954);
      button.drawRoundedRect(0, 0, 140, 35, 5);

      const buttonText = new PIXI.Text(btnData.text, {
        fontFamily: "Arial",
        fontSize: 12,
        fill: 0xffffff,
        fontWeight: "bold",
        align: "center",
      });
      buttonText.anchor.set(0.5);
      buttonText.x = 70;
      buttonText.y = 17;
      button.addChild(buttonText);

      button.x = this.engine.width - 450 + index * 150;
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

  // ============= LOOT GRID OPERATIONS =============

  canPlaceInLootGrid(item, gridX, gridY) {
    const grid = this.lootGrid;
    
    // Check bounds
    if (gridX < 0 || gridY < 0 ||
        gridX + item.gridWidth > grid.cols ||
        gridY + item.gridHeight > grid.rows) {
      return false;
    }

    // Check overlaps with existing loot items
    const itemShapePattern = item.shapePattern || [[0, 0]];
    
    for (const otherItem of this.lootItems) {
      if (otherItem === item || otherItem.gridX < 0 || otherItem.gridY < 0) continue;

      const otherShapePattern = otherItem.shapePattern || [[0, 0]];
      if (this.checkShapeOverlap(itemShapePattern, gridX, gridY, otherShapePattern, otherItem.gridX, otherItem.gridY)) {
        return false;
      }
    }

    return true;
  }

  placeInLootGrid(item, gridX, gridY) {
    const grid = this.lootGrid;
    item.x = grid.x + gridX * this.gridCellSize;
    item.y = grid.y + gridY * this.gridCellSize;
    item.gridX = gridX;
    item.gridY = gridY;

    if (!this.lootItems.includes(item)) {
      this.lootItems.push(item);
    }

    console.log(`✅ Placed ${item.name} in loot grid at (${gridX}, ${gridY})`);
  }

  removeFromLootGrid(item) {
    const index = this.lootItems.indexOf(item);
    if (index > -1) {
      this.lootItems.splice(index, 1);
      this.removeSprite(item);
      console.log(`🗑️ Removed ${item.name} from loot grid`);
    }
  }

  getLootGridPosition(mouseX, mouseY) {
    const grid = this.lootGrid;
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

  // ============= OVERRIDE DRAG AND DROP =============

  findGridItemUnderMouse(mouseX, mouseY) {
    // Check character items first
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

    // Check loot items
    for (let i = this.lootItems.length - 1; i >= 0; i--) {
      const item = this.lootItems[i];
      if (!item.visible || item.gridX < 0 || item.gridY < 0) continue;

      const lootGridPos = this.getLootGridPosition(mouseX, mouseY);
      if (!lootGridPos) continue;

      const shapePattern = item.shapePattern || [[0, 0]];
      for (const [cellX, cellY] of shapePattern) {
        const absoluteCellX = item.gridX + cellX;
        const absoluteCellY = item.gridY + cellY;

        if (lootGridPos.x === absoluteCellX && lootGridPos.y === absoluteCellY) {
          return item;
        }
      }
    }

    return null;
  }

  startDragging(item, source, event) {
    console.log(`🖱️ Starting drag from ${source}: ${item.name || item.originalData?.name}`);

    this.draggedItem = item;
    this.dragSource = source;

    if (source === "grid" || source === "loot") {
      // Dragging from character grid or loot grid
      item.originalGridX = item.gridX;
      item.originalGridY = item.gridY;
      item.originalSource = item.storageType; // Remember if it came from loot or character
      item.gridX = -1;
      item.gridY = -1;
      
      // Remove from appropriate array
      if (item.storageType === "loot") {
        const index = this.lootItems.indexOf(item);
        if (index > -1) this.lootItems.splice(index, 1);
      }
      
      item.alpha = 0.8;
      item.scale.set(1.1);
      
      // Move to top layer
      this.layers.world.removeChild(item);
      this.layers.world.addChild(item);
    } else if (source === "list") {
      // Dragging from storage list
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

    // Show placement previews
    const charGridPos = this.getGridPosition(event.global.x, event.global.y);
    const lootGridPos = this.getLootGridPosition(event.global.x, event.global.y);
    
    if (charGridPos) {
      const canPlace = this.canPlaceInGrid(item, charGridPos.x, charGridPos.y);
      this.showGridPlacementPreview(item, charGridPos.x, charGridPos.y, canPlace, "character");
    } else if (lootGridPos) {
      const canPlace = this.canPlaceInLootGrid(item, lootGridPos.x, lootGridPos.y);
      this.showGridPlacementPreview(item, lootGridPos.x, lootGridPos.y, canPlace, "loot");
    } else {
      this.hidePlacementPreview();
    }
  }

  showGridPlacementPreview(item, gridX, gridY, canPlace, gridType) {
    this.hidePlacementPreview();

    const preview = new PIXI.Graphics();
    const color = canPlace ? (gridType === "loot" ? 0xf39c12 : 0x5f7ea0) : 0xe74c3c;
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

    const targetGrid = gridType === "loot" ? this.lootGrid : this.characterGrid;
    preview.x = targetGrid.x + gridX * this.gridCellSize;
    preview.y = targetGrid.y + gridY * this.gridCellSize;

    this.addSprite(preview, "ui");
    this.placementPreview = preview;
  }

  handleMouseUp(event) {
    if (!this.draggedItem) return;

    const item = this.draggedItem;
    const mouseX = event.global.x;
    const mouseY = event.global.y;

    let placed = false;

    // Try to place in character grid
    const charGridPos = this.getGridPosition(mouseX, mouseY);
    if (charGridPos && this.canPlaceInGrid(item, charGridPos.x, charGridPos.y)) {
      item.storageType = "grid";
      this.placeInGrid(item, charGridPos.x, charGridPos.y);
      placed = true;
      
      if (this.dragSource === "list") {
        this.removeFromStorage(item.originalData, 1);
      }
    } 
    // Try to place in loot grid
    else {
      const lootGridPos = this.getLootGridPosition(mouseX, mouseY);
      if (lootGridPos && this.canPlaceInLootGrid(item, lootGridPos.x, lootGridPos.y)) {
        item.storageType = "loot";
        this.placeInLootGrid(item, lootGridPos.x, lootGridPos.y);
        placed = true;
        
        if (this.dragSource === "list") {
          this.removeFromStorage(item.originalData, 1);
        }
      }
    }

    // Try storage area if not placed in grids
    if (!placed && this.isOverStorageArea(mouseX, mouseY)) {
      if (this.dragSource === "grid" || this.dragSource === "loot") {
        this.addToStorage(item.originalData);
        this.removeSprite(item);
        placed = true;
      } else {
        // Return to list
        this.removeSprite(item);
        placed = true;
      }
    }

    // Return to original position if not placed
    if (!placed) {
      if (this.dragSource === "grid") {
        item.storageType = "grid";
        this.placeInGrid(item, item.originalGridX, item.originalGridY);
      } else if (this.dragSource === "loot") {
        item.storageType = "loot";
        this.placeInLootGrid(item, item.originalGridX, item.originalGridY);
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

  takeAllLoot() {
    console.log("📦 Taking all loot to character inventory");
    
    const itemsToMove = [...this.lootItems];
    let movedCount = 0;
    let storageCount = 0;
    
    itemsToMove.forEach(item => {
      // Try to place in character inventory first
      let placed = false;
      for (let y = 0; y <= this.characterGrid.rows - item.gridHeight && !placed; y++) {
        for (let x = 0; x <= this.characterGrid.cols - item.gridWidth && !placed; x++) {
          if (this.canPlaceInGrid(item, x, y)) {
            this.removeFromLootGrid(item);
            item.storageType = "grid";
            this.placeInGrid(item, x, y);
            placed = true;
            movedCount++;
          }
        }
      }
      
      // If no space, move to storage
      if (!placed) {
        this.addToStorage(item.originalData);
        this.removeFromLootGrid(item);
        storageCount++;
      }
    });
    
    console.log(`✅ Moved ${movedCount} items to inventory, ${storageCount} to storage`);
    this.showMessage(`Moved ${movedCount} items to inventory${storageCount > 0 ? `, ${storageCount} to storage` : ''}`);
  }

  sendAllToStorage() {
    console.log("📚 Sending all loot to storage");
    
    const itemsToMove = [...this.lootItems];
    itemsToMove.forEach(item => {
      this.addToStorage(item.originalData);
      this.removeFromLootGrid(item);
    });
    
    console.log(`✅ Moved ${itemsToMove.length} items to storage`);
    this.showMessage(`Moved ${itemsToMove.length} items to storage`);
  }

  closeLootScene() {
    console.log("🚪 Closing loot scene, saving inventory state");
    
    // Save the current state back to the inventory scene
    this.saveInventoryState();
    
    // Return to the specified scene
    this.engine.switchScene(this.returnScene);
  }

  saveInventoryState() {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene) {
      console.warn("⚠️ Could not find inventory scene to save state");
      return;
    }

    console.log("💾 Saving inventory state to inventory scene");

    // Clear existing inventory items
    inventoryScene.characterItems = [];
    
    // Copy current character items back
    this.characterItems.forEach(item => {
      const inventoryItem = inventoryScene.createGridItem(item.originalData);
      inventoryScene.placeInGrid(inventoryItem, item.gridX, item.gridY);
    });

    // Update storage items
    inventoryScene.storageItems = [...this.storageItems];
    
    // Mark inventory scene as initialized with our data
    inventoryScene.isInitialized = true;
    
    console.log(`✅ Saved ${this.characterItems.length} character items and ${this.storageItems.length} storage items`);
    console.log("✅ Inventory scene marked as initialized");
  }

  showMessage(text) {
    console.log(text);
    
    // Create floating message
    const message = new PIXI.Text(text, {
      fontFamily: "Arial",
      fontSize: 16,
      fill: 0x2ecc71,
      fontWeight: "bold",
      align: "center",
      stroke: 0x000000,
      strokeThickness: 1,
    });
    
    message.anchor.set(0.5);
    message.x = this.engine.width / 2;
    message.y = this.engine.height / 2;
    
    this.addSprite(message, "effects");
    
    // Animate and remove
    let time = 0;
    const animate = () => {
      time += 0.05;
      message.y -= 1;
      message.alpha = Math.max(0, 1 - time / 1.5);
      
      if (message.alpha <= 0) {
        this.removeSprite(message);
      } else {
        requestAnimationFrame(animate);
      }
    };
    
    setTimeout(() => animate(), 500);
  }

  // ============= OVERRIDE STORAGE DISPLAY FOR HORIZONTAL LAYOUT =============

  createListItem(data, index) {
    const item = new PIXI.Container();
    const itemWidth = this.storageItemWidth;
    const itemHeight = this.storageItemHeight;

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

    // Item icon
    const icon = new PIXI.Graphics();
    icon.beginFill(data.color);
    icon.drawRoundedRect(0, 0, 24, 24, 4);
    icon.endFill();
    icon.x = 8;
    icon.y = (itemHeight - 24) / 2;
    item.addChild(icon);

    // Item name
    const nameText = new PIXI.Text(data.name, {
      fontFamily: "Arial",
      fontSize: 10,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    nameText.x = 40;
    nameText.y = 6;
    item.addChild(nameText);

    // Item type
    const typeText = new PIXI.Text(data.type, {
      fontFamily: "Arial",
      fontSize: 8,
      fill: 0xbdc3c7,
    });
    typeText.x = 40;
    typeText.y = 20;
    item.addChild(typeText);

    // Quantity
    if (data.quantity && data.quantity > 1) {
      const quantityText = new PIXI.Text(`×${data.quantity}`, {
        fontFamily: "Arial",
        fontSize: 10,
        fill: 0xf39c12,
        fontWeight: "bold",
      });
      quantityText.anchor.set(1, 0);
      quantityText.x = itemWidth - 5;
      quantityText.y = 6;
      item.addChild(quantityText);
    }

    // Set properties
    item.originalData = data;
    item.name = data.name;
    item.type = data.type;
    item.color = data.color;
    item.storageType = "list";
    item.listIndex = index;
    item.hoverBg = hoverBg;

    // Position in horizontal grid layout
    const row = Math.floor((index - this.storageScroll) / this.storageItemsPerRow);
    const col = (index - this.storageScroll) % this.storageItemsPerRow;
    
    item.x = this.storageList.x + 10 + col * (itemWidth + 10);
    item.y = this.storageList.y + 10 + row * (itemHeight + 10);

    // Only show if in visible range
    const visibleIndex = index - this.storageScroll;
    item.visible = visibleIndex >= 0 && visibleIndex < this.storageMaxVisible;

    this.makeListItemInteractive(item);
    return item;
  }

  updateStorageInfo() {
    if (this.storageInfoText) {
      const total = this.storageItems.length;
      const totalQuantity = this.storageItems.reduce((sum, item) => sum + (item.quantity || 1), 0);
      const lootCount = this.lootItems.length;
      this.storageInfoText.text = `Storage: ${total} types, ${totalQuantity} items • Loot Grid: ${lootCount} items • Drag items between areas`;
    }
  }

  // ============= KEYBOARD CONTROLS =============

  handleKeyDown(event) {
    if (event.code === "Escape") {
      this.closeLootScene();
    } else if (event.code === "KeyT") {
      this.takeAllLoot();
    } else if (event.code === "KeyS" && event.shiftKey) {
      this.sendAllToStorage();
    }
    
    // Call parent for rotation support
    super.handleKeyDown(event);
  }
}