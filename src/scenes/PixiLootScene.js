// src/scenes/PixiLootScene.js
import { PixiScene } from "../core/PixiScene.js";

export class PixiLootScene extends PixiScene {
  constructor() {
    super();
    this.lootData = null;
    this.returnScene = "world";
    this.title = "💎 TREASURE FOUND!";
    this.subtitle =
      "Drag items from the right to your inventory or storage on the left";
    this.draggedItem = null;
    this.inventoryGrid = { x: 30, y: 100, cols: 8, rows: 6, cellSize: 25 };
    this.storageGrid = { x: 250, y: 100, cols: 6, rows: 5, cellSize: 25 };
    this.preview = null;
  }

  // Method to set loot data when entering the scene
  setLootData(lootData, options = {}) {
    this.lootData = lootData;
    this.returnScene = options.returnScene || "world";
    this.title = options.title || "💎 TREASURE FOUND!";
    this.subtitle =
      options.subtitle ||
      "Drag items from the right to your inventory or storage on the left";

    // Optional stats display (for battle context)
    this.showStats = options.showStats || false;
    this.stats = options.stats || null;

    // Grid positioning adjustments based on context
    if (options.context === "battle") {
      this.inventoryGrid.y = 180;
      this.storageGrid.y = 180;
      this.inventoryGrid.rows = 5;
      this.storageGrid.rows = 4;
    } else {
      this.inventoryGrid.y = 100;
      this.storageGrid.y = 100;
      this.inventoryGrid.rows = 6;
      this.storageGrid.rows = 5;
    }
  }

  onEnter() {
    super.onEnter();

    // Create the loot interface
    this.createLootInterface();

    // Update game mode display
    const gameModeBtn = document.getElementById("gameMode");
    if (gameModeBtn) {
      gameModeBtn.textContent = "🎁 LOOTING";
    }

    console.log("Loot scene entered with items:", this.lootData?.length || 0);
  }

  onExit() {
    // Clean up drag operations
    this.draggedItem = null;
    this.preview = null;

    super.onExit();
  }

  createLootInterface() {
    // Create semi-transparent overlay
    const overlay = new PIXI.Graphics();
    overlay.beginFill(0x000000, 0.8);
    overlay.drawRect(0, 0, this.engine.width, this.engine.height);
    overlay.endFill();
    overlay.interactive = true;

    // Create main loot panel
    const panelWidth = 900;
    const panelHeight = this.showStats ? 650 : 600;
    const panel = new PIXI.Graphics();

    // Panel color based on context
    const panelColor = this.title.includes("VICTORY") ? 0x2e7d32 : 0x2c3e50;
    const borderColor = this.title.includes("VICTORY") ? 0x4caf50 : 0xf39c12;

    panel.beginFill(panelColor);
    panel.drawRoundedRect(0, 0, panelWidth, panelHeight, 15);
    panel.endFill();
    panel.lineStyle(3, borderColor);
    panel.drawRoundedRect(0, 0, panelWidth, panelHeight, 15);

    panel.x = this.engine.width / 2 - panelWidth / 2;
    panel.y = this.engine.height / 2 - panelHeight / 2;

    // Store references
    this.overlay = overlay;
    this.panel = panel;

    // Build interface components
    this.createTitle(panel, panelWidth);
    this.createStats(panel, panelWidth);
    this.createInstructions(panel, panelWidth);
    this.createInventoryGrids(panel);
    this.createLootItems(panel);
    this.createCloseButton(panel, panelWidth, panelHeight);

    overlay.addChild(panel);
    this.addSprite(overlay, "effects");
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

  createInventoryGrids(panel) {
    const baseY = this.showStats ? 40 : 0;

    // Character Inventory
    const invLabel = new PIXI.Text("🎒 Character Inventory", {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    invLabel.x = this.inventoryGrid.x;
    invLabel.y = this.inventoryGrid.y - 20 + baseY;
    panel.addChild(invLabel);

    const invGrid = new PIXI.Graphics();
    invGrid.beginFill(0x27ae60, 0.2);
    invGrid.drawRect(
      0,
      0,
      this.inventoryGrid.cols * this.inventoryGrid.cellSize,
      this.inventoryGrid.rows * this.inventoryGrid.cellSize
    );
    invGrid.endFill();
    invGrid.lineStyle(1, 0x2ecc71);

    // Draw inventory grid lines
    for (let col = 0; col <= this.inventoryGrid.cols; col++) {
      const x = col * this.inventoryGrid.cellSize;
      invGrid.moveTo(x, 0);
      invGrid.lineTo(x, this.inventoryGrid.rows * this.inventoryGrid.cellSize);
    }
    for (let row = 0; row <= this.inventoryGrid.rows; row++) {
      const y = row * this.inventoryGrid.cellSize;
      invGrid.moveTo(0, y);
      invGrid.lineTo(this.inventoryGrid.cols * this.inventoryGrid.cellSize, y);
    }

    invGrid.x = this.inventoryGrid.x;
    invGrid.y = this.inventoryGrid.y + baseY;
    panel.addChild(invGrid);

    // Storage
    const storageLabel = new PIXI.Text("📦 Storage", {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    storageLabel.x = this.storageGrid.x;
    storageLabel.y = this.storageGrid.y - 20 + baseY;
    panel.addChild(storageLabel);

    const storageGrid = new PIXI.Graphics();
    storageGrid.beginFill(0x8e44ad, 0.2);
    storageGrid.drawRect(
      0,
      0,
      this.storageGrid.cols * this.storageGrid.cellSize,
      this.storageGrid.rows * this.storageGrid.cellSize
    );
    storageGrid.endFill();
    storageGrid.lineStyle(1, 0x9b59b6);

    // Draw storage grid lines
    for (let col = 0; col <= this.storageGrid.cols; col++) {
      const x = col * this.storageGrid.cellSize;
      storageGrid.moveTo(x, 0);
      storageGrid.lineTo(x, this.storageGrid.rows * this.storageGrid.cellSize);
    }
    for (let row = 0; row <= this.storageGrid.rows; row++) {
      const y = row * this.storageGrid.cellSize;
      storageGrid.moveTo(0, y);
      storageGrid.lineTo(this.storageGrid.cols * this.storageGrid.cellSize, y);
    }

    storageGrid.x = this.storageGrid.x;
    storageGrid.y = this.storageGrid.y + baseY;
    panel.addChild(storageGrid);

    // Show existing items
    this.showExistingItems(panel, baseY);
  }

  showExistingItems(panel, baseY) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene) return;

    inventoryScene.items.forEach((item) => {
      if (item.gridX >= 0 && item.gridY >= 0) {
        const isInInventory =
          item.x >= inventoryScene.inventoryGrid.x &&
          item.x <
            inventoryScene.inventoryGrid.x +
              inventoryScene.inventoryGrid.cols * 40;

        const miniItem = new PIXI.Graphics();
        miniItem.beginFill(item.color || 0x3498db);
        miniItem.drawRect(
          0,
          0,
          item.width * this.inventoryGrid.cellSize - 2,
          item.height * this.inventoryGrid.cellSize - 2
        );
        miniItem.endFill();
        miniItem.lineStyle(1, 0x2c3e50);
        miniItem.drawRect(
          0,
          0,
          item.width * this.inventoryGrid.cellSize - 2,
          item.height * this.inventoryGrid.cellSize - 2
        );

        if (isInInventory) {
          const gridX = Math.floor(
            (item.x - inventoryScene.inventoryGrid.x) / 40
          );
          const gridY = Math.floor(
            (item.y - inventoryScene.inventoryGrid.y) / 40
          );
          miniItem.x =
            this.inventoryGrid.x + gridX * this.inventoryGrid.cellSize + 1;
          miniItem.y =
            this.inventoryGrid.y +
            gridY * this.inventoryGrid.cellSize +
            1 +
            baseY;
        } else {
          const gridX = Math.floor(
            (item.x - inventoryScene.storageGrid.x) / 40
          );
          const gridY = Math.floor(
            (item.y - inventoryScene.storageGrid.y) / 40
          );
          miniItem.x =
            this.storageGrid.x + gridX * this.storageGrid.cellSize + 1;
          miniItem.y =
            this.storageGrid.y + gridY * this.storageGrid.cellSize + 1 + baseY;
        }

        panel.addChild(miniItem);
      }
    });
  }

  createLootItems(panel) {
    const baseY = this.showStats ? 40 : 0;

    // Loot items area title
    const lootLabel = new PIXI.Text(
      this.title.includes("VICTORY") ? "⚔️ Battle Spoils" : "🎁 Found Items",
      {
        fontFamily: "Arial",
        fontSize: 16,
        fill: 0xffd700,
        fontWeight: "bold",
      }
    );
    lootLabel.x = 500;
    lootLabel.y = this.inventoryGrid.y - 20 + baseY;
    panel.addChild(lootLabel);

    // Create loot items
    if (this.lootData) {
      this.lootData.forEach((itemData, index) => {
        const item = this.createDraggableLootItem(itemData, index);
        item.x = 500 + (index % 3) * 120;
        item.y =
          this.inventoryGrid.y + 20 + baseY + Math.floor(index / 3) * 120;
        panel.addChild(item);
      });
    }
  }

  createDraggableLootItem(itemData, index) {
    const itemContainer = new PIXI.Container();

    // Item background
    const bg = new PIXI.Graphics();
    bg.beginFill(itemData.color);
    bg.drawRect(0, 0, itemData.width * 30, itemData.height * 30);
    bg.endFill();
    bg.lineStyle(2, 0x2c3e50);
    bg.drawRect(0, 0, itemData.width * 30, itemData.height * 30);

    // Item name
    const nameText = new PIXI.Text(itemData.name, {
      fontFamily: "Arial",
      fontSize: 10,
      fill: 0xffffff,
      align: "center",
      wordWrap: true,
      wordWrapWidth: itemData.width * 30,
    });
    nameText.anchor.set(0.5);
    nameText.x = (itemData.width * 30) / 2;
    nameText.y = (itemData.height * 30) / 2;

    // Item details
    const detailsText = new PIXI.Text(
      `${itemData.type}\n${itemData.width}x${itemData.height}`,
      {
        fontFamily: "Arial",
        fontSize: 8,
        fill: 0xbdc3c7,
        align: "center",
      }
    );
    detailsText.anchor.set(0.5);
    detailsText.x = (itemData.width * 30) / 2;
    detailsText.y = itemData.height * 30 + 15;

    itemContainer.addChild(bg);
    itemContainer.addChild(nameText);
    itemContainer.addChild(detailsText);

    // Add glow effect for special items
    if (
      itemData.type === "gem" ||
      itemData.name.includes("Mystic") ||
      itemData.name.includes("Elven") ||
      itemData.name.includes("Medal")
    ) {
      const glow = new PIXI.Graphics();
      glow.lineStyle(2, 0xffd700, 0.6);
      glow.drawRect(-2, -2, itemData.width * 30 + 4, itemData.height * 30 + 4);
      itemContainer.addChildAt(glow, 0);

      // Animate glow
      let time = 0;
      const animate = () => {
        time += 0.05;
        glow.alpha = 0.4 + Math.sin(time) * 0.3;
        if (this.isActive) {
          requestAnimationFrame(animate);
        }
      };
      animate();
    }

    // Store item data
    itemContainer.itemData = itemData;
    itemContainer.originalX = itemContainer.x;
    itemContainer.originalY = itemContainer.y;

    // Make draggable
    itemContainer.interactive = true;
    itemContainer.cursor = "pointer";

    itemContainer.on("pointerdown", (event) => {
      this.startDragging(itemContainer, event);
    });

    return itemContainer;
  }

  createCloseButton(panel, panelWidth, panelHeight) {
    const closeBtn = new PIXI.Graphics();
    closeBtn.beginFill(0xe74c3c);
    closeBtn.drawRoundedRect(0, 0, 100, 35, 5);
    closeBtn.endFill();
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

    closeBtn.on("pointerdown", () => {
      this.engine.switchScene(this.returnScene);
    });

    panel.addChild(closeBtn);
  }

  // Drag and drop functionality
  startDragging(item, event) {
    this.draggedItem = item;

    // Store original position
    item.originalX = item.x;
    item.originalY = item.y;

    // Make semi-transparent
    item.alpha = 0.8;

    // Move to top of panel
    this.panel.removeChild(item);
    this.panel.addChild(item);

    // Follow mouse
    const onMove = (event) => {
      if (this.draggedItem === item) {
        const localPos = this.panel.toLocal(event.global);
        item.x = localPos.x - (item.itemData.width * 30) / 2;
        item.y = localPos.y - (item.itemData.height * 30) / 2;

        // Show placement preview
        this.showPlacementPreview(item, localPos);
      }
    };

    const onEnd = (event) => {
      this.stopDragging(item, event);
      this.engine.app.stage.off("pointermove", onMove);
      this.engine.app.stage.off("pointerup", onEnd);
    };

    this.engine.app.stage.on("pointermove", onMove);
    this.engine.app.stage.on("pointerup", onEnd);
  }

  showPlacementPreview(item, localPos) {
    const baseY = this.showStats ? 40 : 0;

    // Clear previous preview
    if (this.preview) {
      this.panel.removeChild(this.preview);
    }

    // Check if over inventory grid
    const invGridY = this.inventoryGrid.y + baseY;
    if (
      localPos.x >= this.inventoryGrid.x &&
      localPos.x <
        this.inventoryGrid.x +
          this.inventoryGrid.cols * this.inventoryGrid.cellSize &&
      localPos.y >= invGridY &&
      localPos.y <
        invGridY + this.inventoryGrid.rows * this.inventoryGrid.cellSize
    ) {
      const gridX = Math.floor(
        (localPos.x - this.inventoryGrid.x) / this.inventoryGrid.cellSize
      );
      const gridY = Math.floor(
        (localPos.y - invGridY) / this.inventoryGrid.cellSize
      );

      if (this.canPlaceItem(item.itemData, "inventory", gridX, gridY)) {
        this.createPlacementPreview(
          item,
          this.inventoryGrid,
          gridX,
          gridY,
          0x2ecc71,
          baseY
        );
      } else {
        this.createPlacementPreview(
          item,
          this.inventoryGrid,
          gridX,
          gridY,
          0xe74c3c,
          baseY
        );
      }
    }

    // Check if over storage grid
    const storageGridY = this.storageGrid.y + baseY;
    if (
      localPos.x >= this.storageGrid.x &&
      localPos.x <
        this.storageGrid.x +
          this.storageGrid.cols * this.storageGrid.cellSize &&
      localPos.y >= storageGridY &&
      localPos.y <
        storageGridY + this.storageGrid.rows * this.storageGrid.cellSize
    ) {
      const gridX = Math.floor(
        (localPos.x - this.storageGrid.x) / this.storageGrid.cellSize
      );
      const gridY = Math.floor(
        (localPos.y - storageGridY) / this.storageGrid.cellSize
      );

      if (this.canPlaceItem(item.itemData, "storage", gridX, gridY)) {
        this.createPlacementPreview(
          item,
          this.storageGrid,
          gridX,
          gridY,
          0x2ecc71,
          baseY
        );
      } else {
        this.createPlacementPreview(
          item,
          this.storageGrid,
          gridX,
          gridY,
          0xe74c3c,
          baseY
        );
      }
    }
  }

  createPlacementPreview(item, grid, gridX, gridY, color, baseY) {
    const preview = new PIXI.Graphics();
    preview.beginFill(color, 0.3);
    preview.drawRect(
      0,
      0,
      item.itemData.width * grid.cellSize,
      item.itemData.height * grid.cellSize
    );
    preview.endFill();
    preview.lineStyle(2, color);
    preview.drawRect(
      0,
      0,
      item.itemData.width * grid.cellSize,
      item.itemData.height * grid.cellSize
    );

    preview.x = grid.x + gridX * grid.cellSize;
    preview.y = grid.y + gridY * grid.cellSize + baseY;

    this.preview = preview;
    this.panel.addChild(preview);
  }

  stopDragging(item, event) {
    if (this.draggedItem !== item) return;

    // Clear preview
    if (this.preview) {
      this.panel.removeChild(this.preview);
      this.preview = null;
    }

    const localPos = this.panel.toLocal(event.global);
    const baseY = this.showStats ? 40 : 0;
    let placed = false;

    // Check inventory placement
    const invGridY = this.inventoryGrid.y + baseY;
    if (
      localPos.x >= this.inventoryGrid.x &&
      localPos.x <
        this.inventoryGrid.x +
          this.inventoryGrid.cols * this.inventoryGrid.cellSize &&
      localPos.y >= invGridY &&
      localPos.y <
        invGridY + this.inventoryGrid.rows * this.inventoryGrid.cellSize
    ) {
      const gridX = Math.floor(
        (localPos.x - this.inventoryGrid.x) / this.inventoryGrid.cellSize
      );
      const gridY = Math.floor(
        (localPos.y - invGridY) / this.inventoryGrid.cellSize
      );

      if (this.canPlaceItem(item.itemData, "inventory", gridX, gridY)) {
        this.placeItem(item.itemData, "inventory", gridX, gridY);
        placed = true;
      }
    }

    // Check storage placement
    if (!placed) {
      const storageGridY = this.storageGrid.y + baseY;
      if (
        localPos.x >= this.storageGrid.x &&
        localPos.x <
          this.storageGrid.x +
            this.storageGrid.cols * this.storageGrid.cellSize &&
        localPos.y >= storageGridY &&
        localPos.y <
          storageGridY + this.storageGrid.rows * this.storageGrid.cellSize
      ) {
        const gridX = Math.floor(
          (localPos.x - this.storageGrid.x) / this.storageGrid.cellSize
        );
        const gridY = Math.floor(
          (localPos.y - storageGridY) / this.storageGrid.cellSize
        );

        if (this.canPlaceItem(item.itemData, "storage", gridX, gridY)) {
          this.placeItem(item.itemData, "storage", gridX, gridY);
          placed = true;
        }
      }
    }

    if (placed) {
      // Remove item from loot interface
      this.panel.removeChild(item);
      this.showMessage(`${item.itemData.name} collected!`);
    } else {
      // Return to original position
      item.x = item.originalX;
      item.y = item.originalY;
      item.alpha = 1;
    }

    this.draggedItem = null;
  }
  createInventoryItemForInventoryScene(itemData) {
    console.log(
      `Creating inventory item for inventory scene: ${itemData.name}`
    );

    // Create exactly the same way as PixiInventoryScene does
    const item = new PIXI.Container();

    // Item background
    const bg = new PIXI.Graphics();
    bg.beginFill(itemData.color);
    bg.drawRect(0, 0, itemData.width * 40 - 4, itemData.height * 40 - 4);
    bg.endFill();

    // Item border
    bg.lineStyle(2, 0x2c3e50);
    bg.drawRect(0, 0, itemData.width * 40 - 4, itemData.height * 40 - 4);

    // Item name
    const text = new PIXI.Text(itemData.name, {
      fontFamily: "Arial",
      fontSize: 12,
      fill: 0xffffff,
      align: "center",
    });
    text.anchor.set(0.5);
    text.x = (itemData.width * 40) / 2 - 2;
    text.y = (itemData.height * 40) / 2 - 2;

    item.addChild(bg);
    item.addChild(text);

    // Add highlight effect for gems
    if (
      itemData.name.includes("Gem") ||
      itemData.name.includes("Orb") ||
      itemData.name.includes("Crystal") ||
      itemData.type === "gem"
    ) {
      const highlight = new PIXI.Graphics();
      highlight.lineStyle(2, 0xffd700, 0.8);
      highlight.drawRect(
        0,
        0,
        itemData.width * 40 - 4,
        itemData.height * 40 - 4
      );
      item.addChild(highlight);

      let time = 0;
      const animate = () => {
        time += 0.05;
        highlight.alpha = 0.3 + Math.sin(time) * 0.3;
        requestAnimationFrame(animate);
      };
      animate();
    }

    // Copy ALL properties from itemData (this is crucial!)
    item.name = itemData.name;
    item.type = itemData.type;
    item.width = itemData.width;
    item.height = itemData.height;
    item.color = itemData.color;
    item.baseSkills = itemData.baseSkills || [];
    item.enhancements = itemData.enhancements || [];

    // Store the original item data
    item.itemData = itemData;
    item.gridX = -1;
    item.gridY = -1;

    // Add methods that the inventory scene expects
    item.isPlaced = function () {
      return this.gridX >= 0 && this.gridY >= 0;
    };

    item.canPlaceAt = function (grid, x, y) {
      // Check bounds
      if (
        x < 0 ||
        y < 0 ||
        x + this.width > grid.cols ||
        y + this.height > grid.rows
      ) {
        return false;
      }
      return true;
    };

    // Make interactive for dragging
    item.interactive = true;
    item.cursor = "pointer";

    console.log(
      `Created inventory-compatible item: ${item.name} (${item.width}x${item.height})`
    );

    return item;
  }
  createInventoryItemForInventoryScene(itemData) {
    console.log(
      `Creating inventory item for inventory scene: ${itemData.name}`
    );

    // Create exactly the same way as PixiInventoryScene does
    const item = new PIXI.Container();

    // Item background
    const bg = new PIXI.Graphics();
    bg.beginFill(itemData.color);
    bg.drawRect(0, 0, itemData.width * 40 - 4, itemData.height * 40 - 4);
    bg.endFill();

    // Item border
    bg.lineStyle(2, 0x2c3e50);
    bg.drawRect(0, 0, itemData.width * 40 - 4, itemData.height * 40 - 4);

    // Item name
    const text = new PIXI.Text(itemData.name, {
      fontFamily: "Arial",
      fontSize: 12,
      fill: 0xffffff,
      align: "center",
    });
    text.anchor.set(0.5);
    text.x = (itemData.width * 40) / 2 - 2;
    text.y = (itemData.height * 40) / 2 - 2;

    item.addChild(bg);
    item.addChild(text);

    // Add highlight effect for gems
    if (
      itemData.name.includes("Gem") ||
      itemData.name.includes("Orb") ||
      itemData.name.includes("Crystal") ||
      itemData.type === "gem"
    ) {
      const highlight = new PIXI.Graphics();
      highlight.lineStyle(2, 0xffd700, 0.8);
      highlight.drawRect(
        0,
        0,
        itemData.width * 40 - 4,
        itemData.height * 40 - 4
      );
      item.addChild(highlight);

      let time = 0;
      const animate = () => {
        time += 0.05;
        highlight.alpha = 0.3 + Math.sin(time) * 0.3;
        requestAnimationFrame(animate);
      };
      animate();
    }

    // Copy ALL properties from itemData (this is crucial!)
    item.name = itemData.name;
    item.type = itemData.type;
    item.width = itemData.width;
    item.height = itemData.height;
    item.color = itemData.color;
    item.baseSkills = itemData.baseSkills || [];
    item.enhancements = itemData.enhancements || [];

    // Store the original item data
    item.itemData = itemData;
    item.gridX = -1;
    item.gridY = -1;

    // Add methods that the inventory scene expects
    item.isPlaced = function () {
      return this.gridX >= 0 && this.gridY >= 0;
    };

    item.canPlaceAt = function (grid, x, y) {
      // Check bounds
      if (
        x < 0 ||
        y < 0 ||
        x + this.width > grid.cols ||
        y + this.height > grid.rows
      ) {
        return false;
      }
      return true;
    };

    // Make interactive for dragging
    item.interactive = true;
    item.cursor = "pointer";

    console.log(
      `Created inventory-compatible item: ${item.name} (${item.width}x${item.height})`
    );

    return item;
  }

  canPlaceItem(itemData, targetGrid, gridX, gridY) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene) return false;

    const grid =
      targetGrid === "inventory"
        ? inventoryScene.inventoryGrid
        : inventoryScene.storageGrid;

    // Check bounds
    if (
      gridX < 0 ||
      gridY < 0 ||
      gridX + itemData.width > grid.cols ||
      gridY + itemData.height > grid.rows
    ) {
      return false;
    }

    // Check for overlapping items
    for (const existingItem of inventoryScene.items) {
      if (existingItem.gridX >= 0 && existingItem.gridY >= 0) {
        const isInSameGrid =
          targetGrid === "inventory"
            ? existingItem.x >= grid.x &&
              existingItem.x < grid.x + grid.cols * 40
            : existingItem.x >= grid.x &&
              existingItem.x < grid.x + grid.cols * 40;

        if (isInSameGrid) {
          const existingGridX = Math.floor((existingItem.x - grid.x) / 40);
          const existingGridY = Math.floor((existingItem.y - grid.y) / 40);

          // Check if areas overlap
          if (
            !(
              gridX >= existingGridX + existingItem.width ||
              gridX + itemData.width <= existingGridX ||
              gridY >= existingGridY + existingItem.height ||
              gridY + itemData.height <= existingGridY
            )
          ) {
            return false;
          }
        }
      }
    }

    return true;
  }

  placeItem(itemData, targetGrid, gridX, gridY) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene) {
      console.error("Inventory scene not found! Cannot place item.");
      return false;
    }

    // Ensure inventory scene has persistent data initialized
    inventoryScene.initializePersistentData();

    const grid =
      targetGrid === "inventory"
        ? inventoryScene.inventoryGrid
        : inventoryScene.storageGrid;

    console.log(
      `📦 Placing ${itemData.name} in ${targetGrid} at grid ${gridX},${gridY}`
    );

    // Create item compatible with inventory scene
    const item = this.createInventoryItemForInventoryScene(itemData);

    // Position the item correctly
    item.x = grid.x + gridX * 40 + 2;
    item.y = grid.y + gridY * 40 + 2;
    item.gridX = gridX;
    item.gridY = gridY;

    console.log(`Item positioned at screen: ${item.x}, ${item.y}`);

    // Add to inventory scene's persistent items array
    inventoryScene.items.push(item);

    // Add drag functionality immediately
    item.on("pointerdown", (event) => {
      if (inventoryScene.startDragging) {
        inventoryScene.startDragging(item, event);
      }
    });

    console.log(`✅ Item ${itemData.name} added to inventory data`);
    console.log(`Total items now: ${inventoryScene.items.length}`);

    // If inventory scene is currently active, also add to visual display
    if (inventoryScene.isActive) {
      inventoryScene.addSprite(item, "world");
      console.log(`🎨 Item also added to active inventory display`);
    } else {
      console.log(
        `📋 Item stored in data - will render when inventory scene becomes active`
      );
    }

    return true;
  }

  createInventoryItem(itemData) {
    // Create a container for the item
    const item = new PIXI.Container();

    // Item background
    const bg = new PIXI.Graphics();
    bg.beginFill(itemData.color);
    bg.drawRect(0, 0, itemData.width * 40 - 4, itemData.height * 40 - 4);
    bg.endFill();

    // Item border
    bg.lineStyle(2, 0x2c3e50);
    bg.drawRect(0, 0, itemData.width * 40 - 4, itemData.height * 40 - 4);

    // Item name
    const text = new PIXI.Text(itemData.name, {
      fontFamily: "Arial",
      fontSize: 12,
      fill: 0xffffff,
      align: "center",
    });
    text.anchor.set(0.5);
    text.x = (itemData.width * 40) / 2 - 2;
    text.y = (itemData.height * 40) / 2 - 2;

    item.addChild(bg);
    item.addChild(text);

    // Add highlight effect for gems
    if (itemData.type === "gem") {
      const highlight = new PIXI.Graphics();
      highlight.lineStyle(2, 0xffd700, 0.8);
      highlight.drawRect(
        0,
        0,
        itemData.width * 40 - 4,
        itemData.height * 40 - 4
      );
      item.addChild(highlight);

      let time = 0;
      const animate = () => {
        time += 0.05;
        highlight.alpha = 0.3 + Math.sin(time) * 0.3;
        requestAnimationFrame(animate);
      };
      animate();
    }

    // Copy all properties from itemData
    Object.assign(item, itemData);

    // Add inventory item properties
    item.itemData = itemData;
    item.gridX = -1;
    item.gridY = -1;

    // Add methods for inventory system
    item.isPlaced = function () {
      return this.gridX >= 0 && this.gridY >= 0;
    };

    item.canPlaceAt = function (grid, x, y) {
      return !(
        x < 0 ||
        y < 0 ||
        x + this.width > grid.cols ||
        y + this.height > grid.rows
      );
    };

    // Make interactive for dragging
    item.interactive = true;
    item.cursor = "pointer";

    return item;
  }

  createInventoryItemForInventoryScene(itemData) {
    console.log(
      `Creating inventory item for inventory scene: ${itemData.name}`
    );

    // Create exactly the same way as PixiInventoryScene does
    const item = new PIXI.Container();

    // Item background
    const bg = new PIXI.Graphics();
    bg.beginFill(itemData.color);
    bg.drawRect(0, 0, itemData.width * 40 - 4, itemData.height * 40 - 4);
    bg.endFill();

    // Item border
    bg.lineStyle(2, 0x2c3e50);
    bg.drawRect(0, 0, itemData.width * 40 - 4, itemData.height * 40 - 4);

    // Item name
    const text = new PIXI.Text(itemData.name, {
      fontFamily: "Arial",
      fontSize: 12,
      fill: 0xffffff,
      align: "center",
    });
    text.anchor.set(0.5);
    text.x = (itemData.width * 40) / 2 - 2;
    text.y = (itemData.height * 40) / 2 - 2;

    item.addChild(bg);
    item.addChild(text);

    // Add highlight effect for gems
    if (
      itemData.name.includes("Gem") ||
      itemData.name.includes("Orb") ||
      itemData.name.includes("Crystal") ||
      itemData.type === "gem"
    ) {
      const highlight = new PIXI.Graphics();
      highlight.lineStyle(2, 0xffd700, 0.8);
      highlight.drawRect(
        0,
        0,
        itemData.width * 40 - 4,
        itemData.height * 40 - 4
      );
      item.addChild(highlight);

      let time = 0;
      const animate = () => {
        time += 0.05;
        highlight.alpha = 0.3 + Math.sin(time) * 0.3;
        requestAnimationFrame(animate);
      };
      animate();
    }

    // Copy ALL properties from itemData (this is crucial!)
    item.name = itemData.name;
    item.type = itemData.type;
    item.width = itemData.width;
    item.height = itemData.height;
    item.color = itemData.color;
    item.baseSkills = itemData.baseSkills || [];
    item.enhancements = itemData.enhancements || [];

    // Store the original item data
    item.itemData = itemData;
    item.gridX = -1;
    item.gridY = -1;

    // Add methods that the inventory scene expects
    item.isPlaced = function () {
      return this.gridX >= 0 && this.gridY >= 0;
    };

    item.canPlaceAt = function (grid, x, y) {
      // Check bounds
      if (
        x < 0 ||
        y < 0 ||
        x + this.width > grid.cols ||
        y + this.height > grid.rows
      ) {
        return false;
      }
      return true;
    };

    // Make interactive for dragging
    item.interactive = true;
    item.cursor = "pointer";

    console.log(
      `Created inventory-compatible item: ${item.name} (${item.width}x${item.height})`
    );

    return item;
  }

  showMessage(text) {
    console.log(text);
    // Could add floating message here if desired
  }

  handleKeyDown(event) {
    if (event.code === "Escape") {
      this.engine.switchScene(this.returnScene);
    }
  }
}
