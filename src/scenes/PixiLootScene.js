import { HybridInventoryScene } from "../core/HybridInventoryScene.js";
import { ShapeHelper } from "../utils/ShapeHelper.js";

export class PixiLootScene extends HybridInventoryScene {
  constructor() {
    super();
    
    // Loot-specific properties
    this.lootData = null;
    this.returnScene = "world";
    this.title = "💎 TREASURE FOUND!";
    this.subtitle = "Drag items to character inventory or storage";
    this.context = null;
    this.showStats = false;
    this.stats = null;
    
    // Loot interface state
    this.draggedLootItem = null;
    this.lootPreview = null;
    
    // Mini grid dimensions for preview
    this.miniGridSize = 20;
    this.previewAreas = {
      characterGrid: { x: 50, y: 120, cols: 10, rows: 8 },
      storageList: { x: 300, y: 120, width: 200, height: 160 }
    };
  }

  setLootData(lootData, options = {}) {
    this.lootData = lootData;
    this.returnScene = options.returnScene || "world";
    this.title = options.title || "💎 TREASURE FOUND!";
    this.subtitle = options.subtitle || "Drag items to character inventory or storage";
    this.showStats = options.showStats || false;
    this.stats = options.stats || null;
    this.context = options.context;

    console.log("🎁 Loot scene configured:", {
      itemCount: this.lootData?.length || 0,
      returnScene: this.returnScene,
      showStats: this.showStats
    });
  }

  onEnter() {
    super.onEnter();
    this.createLootInterface();
    
    // Update game mode display
    const gameModeBtn = document.getElementById("gameMode");
    if (gameModeBtn) {
      gameModeBtn.textContent = "💎 LOOT";
    }

    console.log("💎 Loot scene entered");
  }

  createLootInterface() {
    console.log("🎨 Creating loot interface");
    
    // Create overlay
    const overlay = new PIXI.Graphics();
    overlay.beginFill(0x000000, 0.8);
    overlay.drawRect(0, 0, this.engine.width, this.engine.height);
    overlay.endFill();
    overlay.interactive = true;

    // Create main panel
    const panelWidth = 900;
    const panelHeight = this.showStats ? 650 : 600;
    const panel = new PIXI.Graphics();

    const panelColor = this.title.includes("VICTORY") ? 0x2e7d32 : 0x2c3e50;
    const borderColor = this.title.includes("VICTORY") ? 0x4caf50 : 0xf39c12;

    panel.beginFill(panelColor);
    panel.drawRoundedRect(0, 0, panelWidth, panelHeight, 15);
    panel.endFill();
    panel.lineStyle(3, borderColor);
    panel.drawRoundedRect(0, 0, panelWidth, panelHeight, 15);

    panel.x = this.engine.width / 2 - panelWidth / 2;
    panel.y = this.engine.height / 2 - panelHeight / 2;

    this.overlay = overlay;
    this.panel = panel;

    // Build interface components
    this.createTitle(panel, panelWidth);
    if (this.showStats) this.createStats(panel, panelWidth);
    this.createInstructions(panel, panelWidth);
    this.createInventoryPreviews(panel);
    this.createLootItems(panel);
    this.createCloseButton(panel, panelWidth, panelHeight);

    overlay.addChild(panel);
    this.addSprite(overlay, "effects");
    
    console.log("✅ Loot interface created");
  }

  createTitle(panel, panelWidth) {
    const title = new PIXI.Text(this.title, {
      fontFamily: "Arial",
      fontSize: 24,
      fill: 0xffd700,
      fontWeight: "bold",
      align: "center",
    });
    title.anchor.set(0.5);
    title.x = panelWidth / 2;
    title.y = 40;
    panel.addChild(title);
  }

  createStats(panel, panelWidth) {
    if (!this.showStats || !this.stats) return;

    const statsText = new PIXI.Text(
      `Battle completed in ${this.stats.turnCount} turns\n` +
      `Damage dealt: ${this.stats.damageDealt}\n` +
      `Skills used: ${this.stats.skillsUsed}`,
      {
        fontFamily: "Arial",
        fontSize: 14,
        fill: 0xffffff,
        align: "center",
        lineHeight: 18,
      }
    );
    statsText.anchor.set(0.5);
    statsText.x = panelWidth / 2;
    statsText.y = 80;
    panel.addChild(statsText);
  }

  createInstructions(panel, panelWidth) {
    const instructions = new PIXI.Text(this.subtitle, {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xecf0f1,
      align: "center",
    });
    instructions.anchor.set(0.5);
    instructions.x = panelWidth / 2;
    instructions.y = this.showStats ? 120 : 70;
    panel.addChild(instructions);
  }

  createInventoryPreviews(panel) {
    const baseY = this.showStats ? 40 : 0;
    
    // Character inventory preview
    this.createCharacterGridPreview(panel, baseY);
    
    // Storage preview
    this.createStorageListPreview(panel, baseY);
  }

  createCharacterGridPreview(panel, baseY) {
    const preview = this.previewAreas.characterGrid;
    
    // Label
    const label = new PIXI.Text("🎒 Character Inventory", {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    label.x = preview.x;
    label.y = preview.y - 20 + baseY;
    panel.addChild(label);

    // Grid background
    const gridBg = new PIXI.Graphics();
    gridBg.beginFill(0x2ecc71, 0.2);
    gridBg.drawRect(0, 0, preview.cols * this.miniGridSize, preview.rows * this.miniGridSize);
    gridBg.endFill();
    
    // Grid lines
    gridBg.lineStyle(1, 0x2ecc71, 0.5);
    for (let col = 0; col <= preview.cols; col++) {
      const x = col * this.miniGridSize;
      gridBg.moveTo(x, 0);
      gridBg.lineTo(x, preview.rows * this.miniGridSize);
    }
    for (let row = 0; row <= preview.rows; row++) {
      const y = row * this.miniGridSize;
      gridBg.moveTo(0, y);
      gridBg.lineTo(preview.cols * this.miniGridSize, y);
    }
    
    gridBg.x = preview.x;
    gridBg.y = preview.y + baseY;
    panel.addChild(gridBg);

    // Show existing items in character inventory
    this.showCharacterInventoryItems(panel, preview, baseY);
  }

  createStorageListPreview(panel, baseY) {
    const preview = this.previewAreas.storageList;
    
    // Label
    const label = new PIXI.Text("📦 Storage (Unlimited)", {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    label.x = preview.x;
    label.y = preview.y - 20 + baseY;
    panel.addChild(label);

    // Storage background
    const storageBg = new PIXI.Graphics();
    storageBg.beginFill(0x8e44ad, 0.2);
    storageBg.drawRect(0, 0, preview.width, preview.height);
    storageBg.endFill();
    storageBg.lineStyle(1, 0x9b59b6);
    storageBg.drawRect(0, 0, preview.width, preview.height);
    
    storageBg.x = preview.x;
    storageBg.y = preview.y + baseY;
    panel.addChild(storageBg);

    // Show storage item count
    this.showStorageInfo(panel, preview, baseY);
  }

  showCharacterInventoryItems(panel, preview, baseY) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene || !inventoryScene.characterItems) return;

    inventoryScene.characterItems.forEach(item => {
      if (item.gridX >= 0 && item.gridY >= 0) {
        // Create mini version of the item shape
        const miniItem = new PIXI.Graphics();
        const shapePattern = item.shapePattern || [[0, 0]];
        
        shapePattern.forEach(([cellX, cellY]) => {
          miniItem.beginFill(item.color || 0x3498db);
          miniItem.drawRect(
            (item.gridX + cellX) * this.miniGridSize + 1,
            (item.gridY + cellY) * this.miniGridSize + 1,
            this.miniGridSize - 2,
            this.miniGridSize - 2
          );
          miniItem.endFill();
        });
        
        miniItem.x = preview.x;
        miniItem.y = preview.y + baseY;
        panel.addChild(miniItem);
      }
    });
  }

  showStorageInfo(panel, preview, baseY) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene || !inventoryScene.storageItems) return;

    const itemCount = inventoryScene.storageItems.length;
    const totalQuantity = inventoryScene.storageItems.reduce(
      (sum, item) => sum + (item.quantity || 1), 0
    );

    const infoText = new PIXI.Text(
      `${itemCount} item types\n${totalQuantity} total items\n\n(Drag here for\nunlimited storage)`,
      {
        fontFamily: "Arial",
        fontSize: 11,
        fill: 0xecf0f1,
        align: "center",
        lineHeight: 14,
      }
    );
    infoText.anchor.set(0.5);
    infoText.x = preview.x + preview.width / 2;
    infoText.y = preview.y + preview.height / 2 + baseY;
    panel.addChild(infoText);
  }

  createLootItems(panel) {
    const baseY = this.showStats ? 40 : 0;

    // Loot area label
    const lootLabel = new PIXI.Text(
      this.title.includes("VICTORY") ? "⚔️ Battle Spoils" : "🎁 Found Items",
      {
        fontFamily: "Arial",
        fontSize: 16,
        fill: 0xffd700,
        fontWeight: "bold",
      }
    );
    lootLabel.x = 550;
    lootLabel.y = this.previewAreas.characterGrid.y - 20 + baseY;
    panel.addChild(lootLabel);

    // Create loot items
    if (this.lootData && this.lootData.length > 0) {
      this.lootData.forEach((itemData, index) => {
        const lootItem = this.createDraggableLootItem(itemData, index);
        lootItem.x = 550 + (index % 3) * 100;
        lootItem.y = this.previewAreas.characterGrid.y + 20 + baseY + Math.floor(index / 3) * 100;
        panel.addChild(lootItem);
      });
    } else {
      // No loot message
      const noLootText = new PIXI.Text("No items found", {
        fontFamily: "Arial",
        fontSize: 14,
        fill: 0x95a5a6,
        align: "center",
      });
      noLootText.anchor.set(0.5);
      noLootText.x = 650;
      noLootText.y = this.previewAreas.characterGrid.y + 100 + baseY;
      panel.addChild(noLootText);
    }
  }

  createDraggableLootItem(itemData, index) {
    const itemContainer = new PIXI.Container();
    const itemSize = 80;

    // Item background
    const bg = new PIXI.Graphics();
    bg.beginFill(itemData.color || 0x95a5a6);
    bg.drawRoundedRect(0, 0, itemSize, itemSize, 8);
    bg.endFill();
    bg.lineStyle(2, 0x2c3e50);
    bg.drawRoundedRect(0, 0, itemSize, itemSize, 8);
    itemContainer.addChild(bg);

    // Item name
    const nameText = new PIXI.Text(itemData.name, {
      fontFamily: "Arial",
      fontSize: 10,
      fill: 0xffffff,
      align: "center",
      fontWeight: "bold",
      wordWrap: true,
      wordWrapWidth: itemSize - 10,
    });
    nameText.anchor.set(0.5);
    nameText.x = itemSize / 2;
    nameText.y = itemSize / 2 - 8;
    itemContainer.addChild(nameText);

    // Item type
    const typeText = new PIXI.Text(itemData.type, {
      fontFamily: "Arial",
      fontSize: 8,
      fill: 0xbdc3c7,
      align: "center",
    });
    typeText.anchor.set(0.5);
    typeText.x = itemSize / 2;
    typeText.y = itemSize / 2 + 8;
    itemContainer.addChild(typeText);

    // Quantity if > 1
    if (itemData.quantity && itemData.quantity > 1) {
      const quantityBg = new PIXI.Graphics();
      quantityBg.beginFill(0xf39c12);
      quantityBg.drawCircle(0, 0, 10);
      quantityBg.endFill();
      quantityBg.x = itemSize - 12;
      quantityBg.y = 12;
      itemContainer.addChild(quantityBg);

      const quantityText = new PIXI.Text(itemData.quantity.toString(), {
        fontFamily: "Arial",
        fontSize: 8,
        fill: 0xffffff,
        fontWeight: "bold",
        align: "center",
      });
      quantityText.anchor.set(0.5);
      quantityText.x = itemSize - 12;
      quantityText.y = 12;
      itemContainer.addChild(quantityText);
    }

    // Add special effects for valuable items
    if (itemData.type === "gem" || 
        itemData.name.includes("Medal") || 
        itemData.name.includes("Epic") ||
        itemData.name.includes("Legendary")) {
      
      const glow = new PIXI.Graphics();
      glow.lineStyle(3, 0xffd700, 0.6);
      glow.drawRoundedRect(-3, -3, itemSize + 6, itemSize + 6, 11);
      itemContainer.addChildAt(glow, 0);

      // Animate glow
      let time = Math.random() * Math.PI * 2;
      const animate = () => {
        time += 0.08;
        glow.alpha = 0.4 + Math.sin(time) * 0.4;
        if (this.isActive) {
          requestAnimationFrame(animate);
        }
      };
      animate();
    }

    // Store item data and make interactive
    itemContainer.itemData = itemData;
    itemContainer.originalX = itemContainer.x;
    itemContainer.originalY = itemContainer.y;
    itemContainer.interactive = true;
    itemContainer.cursor = "pointer";

    // Add drag handlers
    itemContainer.on("pointerdown", (event) => {
      this.startLootDragging(itemContainer, event);
    });

    return itemContainer;
  }

  createCloseButton(panel, panelWidth, panelHeight) {
    const closeBtn = new PIXI.Graphics();
    closeBtn.beginFill(0xe74c3c);
    closeBtn.drawRoundedRect(0, 0, 100, 35, 5);
    closeBtn.endFill();
    closeBtn.lineStyle(1, 0xc0392b);
    closeBtn.drawRoundedRect(0, 0, 100, 35, 5);
    
    closeBtn.x = panelWidth / 2 - 50;
    closeBtn.y = panelHeight - 50;
    closeBtn.interactive = true;
    closeBtn.cursor = "pointer";

    const closeText = new PIXI.Text("Close", {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    closeText.anchor.set(0.5);
    closeText.x = 50;
    closeText.y = 17;
    closeBtn.addChild(closeText);

    closeBtn.on("pointerover", () => {
      closeBtn.tint = 0xcccccc;
    });

    closeBtn.on("pointerout", () => {
      closeBtn.tint = 0xffffff;
    });

    closeBtn.on("pointerdown", () => {
      this.engine.switchScene(this.returnScene);
    });

    panel.addChild(closeBtn);
  }

  // ============= DRAG AND DROP FOR LOOT =============

  startLootDragging(item, event) {
    console.log(`🖱️ Starting loot drag: ${item.itemData.name}`);
    
    this.draggedLootItem = item;
    item.alpha = 0.8;
    item.scale.set(1.1);

    // Store original position
    item.originalX = item.x;
    item.originalY = item.y;

    // Move to top of panel
    this.panel.removeChild(item);
    this.panel.addChild(item);

    // Calculate drag offset
    const localPos = this.panel.toLocal(event.global);
    item.dragOffsetX = localPos.x - item.x;
    item.dragOffsetY = localPos.y - item.y;

    // Setup mouse handlers
    const onMove = (event) => {
      if (this.draggedLootItem === item) {
        const localPos = this.panel.toLocal(event.global);
        item.x = localPos.x - item.dragOffsetX;
        item.y = localPos.y - item.dragOffsetY;
        
        // Show drop preview
        this.showLootDropPreview(item, localPos);
      }
    };

    const onEnd = (event) => {
      this.stopLootDragging(item, event);
      this.engine.app.stage.off("pointermove", onMove);
      this.engine.app.stage.off("pointerup", onEnd);
    };

    this.engine.app.stage.on("pointermove", onMove);
    this.engine.app.stage.on("pointerup", onEnd);
  }

  showLootDropPreview(item, localPos) {
    // Clear previous preview
    if (this.lootPreview) {
      this.panel.removeChild(this.lootPreview);
      this.lootPreview = null;
    }

    const baseY = this.showStats ? 40 : 0;
    
    // Check if over character grid
    const gridArea = this.previewAreas.characterGrid;
    if (localPos.x >= gridArea.x && 
        localPos.x <= gridArea.x + gridArea.cols * this.miniGridSize &&
        localPos.y >= gridArea.y + baseY && 
        localPos.y <= gridArea.y + baseY + gridArea.rows * this.miniGridSize) {
      
      // Show grid drop preview
      const preview = new PIXI.Graphics();
      preview.beginFill(0x2ecc71, 0.5);
      preview.drawRoundedRect(0, 0, gridArea.cols * this.miniGridSize, gridArea.rows * this.miniGridSize, 4);
      preview.endFill();
      preview.x = gridArea.x;
      preview.y = gridArea.y + baseY;
      
      this.panel.addChild(preview);
      this.lootPreview = preview;
      return;
    }

    // Check if over storage area
    const storageArea = this.previewAreas.storageList;
    if (localPos.x >= storageArea.x && 
        localPos.x <= storageArea.x + storageArea.width &&
        localPos.y >= storageArea.y + baseY && 
        localPos.y <= storageArea.y + baseY + storageArea.height) {
      
      // Show storage drop preview
      const preview = new PIXI.Graphics();
      preview.beginFill(0x9b59b6, 0.5);
      preview.drawRoundedRect(0, 0, storageArea.width, storageArea.height, 4);
      preview.endFill();
      preview.x = storageArea.x;
      preview.y = storageArea.y + baseY;
      
      this.panel.addChild(preview);
      this.lootPreview = preview;
    }
  }

  stopLootDragging(item, event) {
    if (!this.draggedLootItem || this.draggedLootItem !== item) return;

    console.log(`🖱️ Stopping loot drag: ${item.itemData.name}`);

    const localPos = this.panel.toLocal(event.global);
    const baseY = this.showStats ? 40 : 0;
    let transferred = false;

    // Check if dropped on character grid
    const gridArea = this.previewAreas.characterGrid;
    if (localPos.x >= gridArea.x && 
        localPos.x <= gridArea.x + gridArea.cols * this.miniGridSize &&
        localPos.y >= gridArea.y + baseY && 
        localPos.y <= gridArea.y + baseY + gridArea.rows * this.miniGridSize) {
      
      transferred = this.transferToCharacterInventory(item.itemData);
    }
    
    // Check if dropped on storage area
    else {
      const storageArea = this.previewAreas.storageList;
      if (localPos.x >= storageArea.x && 
          localPos.x <= storageArea.x + storageArea.width &&
          localPos.y >= storageArea.y + baseY && 
          localPos.y <= storageArea.y + baseY + storageArea.height) {
        
        transferred = this.transferToStorage(item.itemData);
      }
    }

    if (transferred) {
      // Remove item from loot interface
      this.panel.removeChild(item);
      this.showTransferMessage(item.itemData.name, transferred);
      
      // Remove from loot data
      const index = this.lootData.indexOf(item.itemData);
      if (index > -1) {
        this.lootData.splice(index, 1);
      }
    } else {
      // Return to original position
      item.x = item.originalX;
      item.y = item.originalY;
      item.alpha = 1;
      item.scale.set(1);
    }

    // Clear preview
    if (this.lootPreview) {
      this.panel.removeChild(this.lootPreview);
      this.lootPreview = null;
    }

    this.draggedLootItem = null;
  }

  transferToCharacterInventory(itemData) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene) {
      console.error("❌ Inventory scene not found!");
      return false;
    }

    console.log(`📦 Attempting to transfer ${itemData.name} to character inventory`);

    // Create the item
    const newItem = inventoryScene.createGridItem(itemData);
    
    // Try to find a place for it in the character grid
    for (let y = 0; y <= inventoryScene.characterGrid.rows - newItem.gridHeight; y++) {
      for (let x = 0; x <= inventoryScene.characterGrid.cols - newItem.gridWidth; x++) {
        if (inventoryScene.canPlaceInGrid(newItem, x, y)) {
          inventoryScene.placeInGrid(newItem, x, y);
          
          // Add to scene if it's currently active
          if (inventoryScene.isActive) {
            inventoryScene.addSprite(newItem, "world");
          }
          
          console.log(`✅ Transferred ${itemData.name} to character grid at (${x}, ${y})`);
          return "character";
        }
      }
    }

    // No space in character inventory, try storage instead
    inventoryScene.addToStorage(itemData);
    console.log(`📚 No space in character inventory, moved ${itemData.name} to storage`);
    return "storage";
  }

  transferToStorage(itemData) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene) {
      console.error("❌ Inventory scene not found!");
      return false;
    }

    console.log(`📚 Transferring ${itemData.name} to storage`);
    inventoryScene.addToStorage(itemData);
    return "storage";
  }

  showTransferMessage(itemName, destination) {
    const message = destination === "character" 
      ? `${itemName} added to character inventory`
      : `${itemName} added to storage`;
    
    console.log(`✅ ${message}`);
    
    // Create floating message
    const messageText = new PIXI.Text(message, {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0x2ecc71,
      fontWeight: "bold",
      align: "center",
    });
    messageText.anchor.set(0.5);
    messageText.x = this.panel.width / 2;
    messageText.y = 100;
    
    this.panel.addChild(messageText);
    
    // Animate and remove
    let alpha = 1;
    const fadeOut = () => {
      alpha -= 0.05;
      messageText.alpha = alpha;
      messageText.y -= 1;
      
      if (alpha <= 0) {
        this.panel.removeChild(messageText);
      } else {
        requestAnimationFrame(fadeOut);
      }
    };
    
    setTimeout(() => fadeOut(), 1000);
  }
}