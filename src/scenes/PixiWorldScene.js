import { PixiScene } from "../core/PixiScene.js";

export class PixiWorldScene extends PixiScene {
  constructor() {
    super();
    this.player = null;
    this.worldObjects = [];
    this.camera = { x: 0, y: 0 };
    this.playerSpeed = 3;
    this.worldWidth = 2560;
    this.worldHeight = 1440;

    // Persistent state
    this.isInitialized = false;
    this.playerPosition = { x: 400, y: 300 }; // Default starting position
    this.worldState = {
      removedCrystals: [], // Track which crystals have been used
      openedChests: [], // Track which chests have been opened
      discoveredItems: [], // Track found items
    };
  }

  onEnter() {
    super.onEnter();

    if (!this.isInitialized) {
      // First time entering - create everything
      this.createWorld();
      this.createPlayer();
      this.createWorldObjects();
      this.isInitialized = true;
      console.log("World scene initialized for first time");
    } else {
      // Returning to world - restore player position and update display
      this.restorePlayerPosition();
      this.updateCamera();
      console.log(
        "Returned to world scene, restored position:",
        this.playerPosition
      );
    }

    // Update game mode display
    const gameModeBtn = document.getElementById("gameMode");
    if (gameModeBtn) {
      gameModeBtn.textContent = "🌍 EXPLORING";
    }

    // UPDATE NAVIGATION BUTTONS - Add this section
    if (this.engine && this.engine.updateNavButtons) {
      this.engine.updateNavButtons("world");
    } else {
      // Fallback: directly update buttons
      this.updateNavigationButtons();
    }

    console.log("World exploration scene active");
  }

  // ADD THIS NEW METHOD to PixiWorldScene
  updateNavigationButtons() {
    const buttons = {
      menu: document.getElementById("menuBtn"),
      inventory: document.getElementById("inventoryBtn"),
      world: document.getElementById("worldBtn"),
      battle: document.getElementById("battleBtn"),
    };

    Object.keys(buttons).forEach((scene) => {
      const btn = buttons[scene];
      if (btn) {
        if (scene === "world") {
          btn.classList.add("active");
        } else {
          btn.classList.remove("active");
        }
      }
    });
  }

  onExit() {
    // Save current player position before leaving
    if (this.player) {
      this.playerPosition.x = this.player.x;
      this.playerPosition.y = this.player.y;
      console.log("Saved player position:", this.playerPosition);
    }

    // Clean up animations but keep objects
    this.worldObjects.forEach((obj) => {
      if (obj.sprite.animationId) {
        clearInterval(obj.sprite.animationId);
      }
    });

    super.onExit();
  }

  restorePlayerPosition() {
    if (this.player) {
      this.player.x = this.playerPosition.x;
      this.player.y = this.playerPosition.y;
      console.log("Player restored to position:", this.playerPosition);
    }
  }

  createWorld() {
    // Create world background
    const worldBg = new PIXI.Graphics();
    worldBg.beginFill(0x2d5016); // Forest green
    worldBg.drawRect(0, 0, this.worldWidth, this.worldHeight);
    worldBg.endFill();

    // Add some ground texture
    for (let x = 0; x < this.worldWidth; x += 64) {
      for (let y = 0; y < this.worldHeight; y += 64) {
        if (Math.random() < 0.3) {
          worldBg.beginFill(0x228b22);
          worldBg.drawRect(x, y, 32, 32);
          worldBg.endFill();
        }
      }
    }

    this.addGraphics(worldBg, "background");
  }

  createPlayer() {
    this.player = new PIXI.Graphics();

    // Player body
    this.player.beginFill(0x4a90e2);
    this.player.drawRect(-8, -12, 16, 24);
    this.player.endFill();

    // Player head
    this.player.beginFill(0xfdbcb4);
    this.player.drawCircle(0, -20, 8);
    this.player.endFill();

    // Player weapon
    this.player.beginFill(0x8b4513);
    this.player.drawRect(-2, -30, 4, 15);
    this.player.endFill();

    // Set initial position
    this.player.x = this.playerPosition.x;
    this.player.y = this.playerPosition.y;

    this.addSprite(this.player, "world");
  }

  createWorldObjects() {
    // Create trees
    for (let i = 0; i < 30; i++) {
      this.createTree(
        Math.random() * this.worldWidth,
        Math.random() * this.worldHeight,
        i
      );
    }

    // Create battle crystals (only if not already removed)
    for (let i = 0; i < 8; i++) {
      if (!this.worldState.removedCrystals.includes(i)) {
        this.createBattleCrystal(
          200 + Math.random() * (this.worldWidth - 400),
          200 + Math.random() * (this.worldHeight - 400),
          i
        );
      }
    }

    // Create treasure chests
    for (let i = 0; i < 5; i++) {
      this.createTreasureChest(
        100 + Math.random() * (this.worldWidth - 200),
        100 + Math.random() * (this.worldHeight - 200),
        i
      );
    }

    // Create NPCs/Houses
    this.createHouse(800, 400, 0);
    this.createHouse(1200, 600, 1);
  }

  createTree(x, y, id) {
    const tree = new PIXI.Container();

    // Tree trunk
    const trunk = new PIXI.Graphics();
    trunk.beginFill(0x8b4513);
    trunk.drawRect(-6, -20, 12, 20);
    trunk.endFill();

    // Tree crown
    const crown = new PIXI.Graphics();
    crown.beginFill(0x228b22);
    crown.drawCircle(0, -30, 18);
    crown.endFill();

    tree.addChild(trunk);
    tree.addChild(crown);
    tree.x = x;
    tree.y = y;
    tree.treeId = id;

    // Make interactive
    tree.interactive = true;
    tree.cursor = "pointer";
    tree.on("pointerdown", () => {
      if (this.isPlayerNear(tree)) {
        this.interactWithTree(tree);
      }
    });

    this.worldObjects.push({ type: "tree", sprite: tree, x, y, id });
    this.addSprite(tree, "world");
  }

  createBattleCrystal(x, y, id) {
    const crystal = new PIXI.Graphics();

    // Crystal shape
    crystal.beginFill(0xff00ff);
    crystal.moveTo(0, -20);
    crystal.lineTo(-10, -5);
    crystal.lineTo(-8, 10);
    crystal.lineTo(0, 20);
    crystal.lineTo(8, 10);
    crystal.lineTo(10, -5);
    crystal.closePath();
    crystal.endFill();

    crystal.x = x;
    crystal.y = y;
    crystal.crystalId = id;

    // Floating animation
    let floatOffset = Math.random() * Math.PI * 2;
    crystal.originalY = y;

    // Store animation in the object for later cleanup
    crystal.animationId = setInterval(() => {
      crystal.y =
        crystal.originalY + Math.sin(Date.now() * 0.002 + floatOffset) * 8;
    }, 16);

    // Make interactive
    crystal.interactive = true;
    crystal.cursor = "pointer";
    crystal.on("pointerdown", () => {
      if (this.isPlayerNear(crystal)) {
        this.startBattle(crystal);
      }
    });

    this.worldObjects.push({ type: "crystal", sprite: crystal, x, y, id });
    this.addSprite(crystal, "world");
  }

  createTreasureChest(x, y, id) {
    const chest = new PIXI.Graphics();
    const isOpened = this.worldState.openedChests.includes(id);

    // Draw chest based on opened state
    this.drawChest(chest, isOpened);

    chest.x = x;
    chest.y = y;
    chest.chestId = id;
    chest.opened = isOpened;

    // Make interactive only if not opened
    if (!isOpened) {
      chest.interactive = true;
      chest.cursor = "pointer";
      chest.on("pointerdown", () => {
        if (this.isPlayerNear(chest)) {
          this.openChest(chest);
        }
      });
    }

    this.worldObjects.push({ type: "chest", sprite: chest, x, y, id });
    this.addSprite(chest, "world");
  }

  drawChest(chest, isOpened) {
    chest.clear();

    if (isOpened) {
      // Open chest appearance
      chest.beginFill(0x654321);
      chest.drawRect(-20, -10, 40, 20);
      chest.endFill();

      // Chest lid (open)
      chest.beginFill(0xa0522d);
      chest.drawRect(-20, -25, 40, 10);
      chest.endFill();

      // Faded gold trim
      chest.lineStyle(1, 0xb8860b, 0.5);
      chest.drawRect(-20, -25, 40, 35);
    } else {
      // Closed chest appearance
      chest.beginFill(0x8b4513);
      chest.drawRect(-20, -10, 40, 20);
      chest.endFill();

      // Chest lid
      chest.beginFill(0xa0522d);
      chest.drawRect(-20, -15, 40, 10);
      chest.endFill();

      // Gold trim
      chest.lineStyle(2, 0xffd700);
      chest.drawRect(-20, -15, 40, 25);
    }
  }

  createHouse(x, y, id) {
    const house = new PIXI.Container();

    // House base
    const base = new PIXI.Graphics();
    base.beginFill(0x8b4513);
    base.drawRect(0, 0, 80, 60);
    base.endFill();

    // Roof
    const roof = new PIXI.Graphics();
    roof.beginFill(0x654321);
    roof.moveTo(0, 0);
    roof.lineTo(40, -20);
    roof.lineTo(80, 0);
    roof.closePath();
    roof.endFill();

    // Door
    const door = new PIXI.Graphics();
    door.beginFill(0x4a3c1d);
    door.drawRect(30, 30, 20, 30);
    door.endFill();

    house.addChild(base);
    house.addChild(roof);
    house.addChild(door);
    house.x = x;
    house.y = y;
    house.houseId = id;

    // Make interactive
    house.interactive = true;
    house.cursor = "pointer";
    house.on("pointerdown", () => {
      if (this.isPlayerNear(house)) {
        this.enterHouse(house);
      }
    });

    this.worldObjects.push({ type: "house", sprite: house, x, y, id });
    this.addSprite(house, "world");
  }

  // Player movement and camera
  update(deltaTime) {
    super.update(deltaTime);
    this.updatePlayerMovement();
    this.updateCamera();
  }

  updatePlayerMovement() {
    if (!this.player) return;

    let moved = false;
    let newX = this.player.x;
    let newY = this.player.y;

    // Check for movement keys
    if (this.keys["KeyW"] || this.keys["ArrowUp"]) {
      newY -= this.playerSpeed;
      moved = true;
    }
    if (this.keys["KeyS"] || this.keys["ArrowDown"]) {
      newY += this.playerSpeed;
      moved = true;
    }
    if (this.keys["KeyA"] || this.keys["ArrowLeft"]) {
      newX -= this.playerSpeed;
      moved = true;
    }
    if (this.keys["KeyD"] || this.keys["ArrowRight"]) {
      newX += this.playerSpeed;
      moved = true;
    }

    // World boundaries
    newX = Math.max(20, Math.min(this.worldWidth - 20, newX));
    newY = Math.max(20, Math.min(this.worldHeight - 20, newY));

    // Simple collision detection (avoid trees)
    let canMove = true;
    for (const obj of this.worldObjects) {
      if (obj.type === "tree" || obj.type === "house") {
        const distance = Math.sqrt(
          Math.pow(newX - obj.x, 2) + Math.pow(newY - obj.y, 2)
        );
        if (distance < 30) {
          canMove = false;
          break;
        }
      }
    }

    if (canMove) {
      this.player.x = newX;
      this.player.y = newY;

      // Update stored position
      this.playerPosition.x = newX;
      this.playerPosition.y = newY;
    }
  }

  updateCamera() {
    if (!this.player) return;

    // Center camera on player
    const targetCameraX = this.player.x - this.engine.width / 2;
    const targetCameraY = this.player.y - this.engine.height / 2;

    // Keep camera within world bounds
    this.camera.x = Math.max(
      0,
      Math.min(this.worldWidth - this.engine.width, targetCameraX)
    );
    this.camera.y = Math.max(
      0,
      Math.min(this.worldHeight - this.engine.height, targetCameraY)
    );

    // Apply camera to world layer
    this.layers.world.x = -this.camera.x;
    this.layers.world.y = -this.camera.y;
    this.layers.background.x = -this.camera.x;
    this.layers.background.y = -this.camera.y;
  }

  // Interaction methods
  isPlayerNear(object) {
    if (!this.player) return false;

    const distance = Math.sqrt(
      Math.pow(this.player.x - object.x, 2) +
        Math.pow(this.player.y - object.y, 2)
    );

    return distance < 50;
  }

  interactWithTree(tree) {
    if (Math.random() < 0.3) {
      this.showMessage("Found an apple! 🍎");
      this.worldState.discoveredItems.push(`apple_${tree.treeId}`);
    } else {
      this.showMessage("Just a tree...");
    }
  }

  startBattle(crystal) {
    this.showMessage("⚔️ Battle encounter!");

    // Save player position before battle
    this.playerPosition.x = this.player.x;
    this.playerPosition.y = this.player.y;

    // Mark crystal as removed
    this.worldState.removedCrystals.push(crystal.crystalId);

    // Remove crystal from world
    this.removeSprite(crystal);
    const objIndex = this.worldObjects.findIndex(
      (obj) => obj.sprite === crystal
    );
    if (objIndex > -1) {
      this.worldObjects.splice(objIndex, 1);
    }

    // Clean up crystal animation
    if (crystal.animationId) {
      clearInterval(crystal.animationId);
    }

    console.log("Starting battle, saved position:", this.playerPosition);

    // Go to battle scene after short delay
    setTimeout(() => {
      this.engine.switchScene("battle");
    }, 1000);
  }

  // Add this to src/scenes/PixiWorldScene.js - replace the openChest method and add new methods

  openChest(chest) {
    if (chest.opened) {
      this.showMessage("Chest is empty.");
      return;
    }

    // Mark chest as opened
    chest.opened = true;
    this.worldState.openedChests.push(chest.chestId);

    // Update chest appearance
    this.drawChest(chest, true);

    // Make non-interactive
    chest.interactive = false;
    chest.cursor = "default";

    // Generate loot for this chest
    const loot = this.generateLoot(chest.chestId);

    // Switch to loot scene with chest context
    const lootScene = this.engine.scenes.get("loot");
    lootScene.setLootData(loot, {
      returnScene: "world",
      title: "💎 TREASURE FOUND!",
      subtitle:
        "Drag items from the right to your inventory or storage on the left",
      context: "chest",
    });

    this.engine.switchScene("loot");
  }

  generateLoot(chestId) {
    // Same loot generation logic as before
    const lootTables = [
      // Chest 0 - Basic loot
      [
        {
          name: "Iron Dagger",
          color: 0x8c8c8c,
          width: 1,
          height: 2,
          type: "weapon",
          baseSkills: [
            {
              name: "Quick Strike",
              description: "Fast dagger attack",
              damage: 18,
              cost: 1,
              type: "physical",
            },
          ],
        },
        {
          name: "Health Potion",
          color: 0xe74c3c,
          width: 1,
          height: 1,
          type: "consumable",
          baseSkills: [
            {
              name: "Heal",
              description: "Restore health",
              damage: -30,
              cost: 0,
              type: "healing",
            },
          ],
        },
      ],
      // Add other chest loot tables...
    ];

    const selectedLoot = lootTables[chestId] || lootTables[0];
    const numItems =
      Math.random() < 0.7
        ? selectedLoot.length
        : Math.floor(selectedLoot.length / 2) + 1;

    return selectedLoot.slice(0, numItems);
  }

  showDragDropLootInterface(loot) {
    // Create semi-transparent overlay
    const overlay = new PIXI.Graphics();
    overlay.beginFill(0x000000, 0.8);
    overlay.drawRect(0, 0, this.engine.width, this.engine.height);
    overlay.endFill();
    overlay.interactive = true;

    // Create main loot panel
    const panelWidth = 900;
    const panelHeight = 600;
    const panel = new PIXI.Graphics();
    panel.beginFill(0x2c3e50);
    panel.drawRoundedRect(0, 0, panelWidth, panelHeight, 15);
    panel.endFill();
    panel.lineStyle(3, 0xf39c12);
    panel.drawRoundedRect(0, 0, panelWidth, panelHeight, 15);

    panel.x = this.engine.width / 2 - panelWidth / 2;
    panel.y = this.engine.height / 2 - panelHeight / 2;

    // Title
    const title = new PIXI.Text("💎 TREASURE FOUND!", {
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

    // Instructions
    const instructions = new PIXI.Text(
      "Drag items from the right to your inventory or storage on the left",
      {
        fontFamily: "Arial",
        fontSize: 14,
        fill: 0xecf0f1,
        align: "center",
      }
    );
    instructions.anchor.set(0.5);
    instructions.x = panelWidth / 2;
    instructions.y = 70;
    panel.addChild(instructions);

    // Create inventory and storage grids on the left
    this.createLootInventoryGrids(panel);

    // Create loot items on the right
    this.createDraggableLootItems(panel, loot);

    // Close button
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
      this.removeSprite(overlay);
      this.currentLootInterface = null;
    });

    panel.addChild(closeBtn);
    overlay.addChild(panel);
    this.addSprite(overlay, "effects");

    // Store reference for drag operations
    this.currentLootInterface = {
      overlay: overlay,
      panel: panel,
      draggedItem: null,
      inventoryGrid: { x: 30, y: 100, cols: 8, rows: 6, cellSize: 25 },
      storageGrid: { x: 250, y: 100, cols: 6, rows: 5, cellSize: 25 },
    };
  }

  createLootInventoryGrids(panel) {
    // Character Inventory (left top)
    const invLabel = new PIXI.Text("🎒 Character Inventory", {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    invLabel.x = 30;
    invLabel.y = 80;
    panel.addChild(invLabel);

    const invGrid = new PIXI.Graphics();
    invGrid.beginFill(0x27ae60, 0.2);
    invGrid.drawRect(0, 0, 200, 150);
    invGrid.endFill();
    invGrid.lineStyle(1, 0x2ecc71);

    // Draw inventory grid lines
    for (let col = 0; col <= 8; col++) {
      const x = col * 25;
      invGrid.moveTo(x, 0);
      invGrid.lineTo(x, 150);
    }
    for (let row = 0; row <= 6; row++) {
      const y = row * 25;
      invGrid.moveTo(0, y);
      invGrid.lineTo(200, y);
    }

    invGrid.x = 30;
    invGrid.y = 100;
    panel.addChild(invGrid);

    // Storage (left bottom)
    const storageLabel = new PIXI.Text("📦 Storage", {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    storageLabel.x = 250;
    storageLabel.y = 80;
    panel.addChild(storageLabel);

    const storageGrid = new PIXI.Graphics();
    storageGrid.beginFill(0x8e44ad, 0.2);
    storageGrid.drawRect(0, 0, 150, 125);
    storageGrid.endFill();
    storageGrid.lineStyle(1, 0x9b59b6);

    // Draw storage grid lines
    for (let col = 0; col <= 6; col++) {
      const x = col * 25;
      storageGrid.moveTo(x, 0);
      storageGrid.lineTo(x, 125);
    }
    for (let row = 0; row <= 5; row++) {
      const y = row * 25;
      storageGrid.moveTo(0, y);
      storageGrid.lineTo(150, y);
    }

    storageGrid.x = 250;
    storageGrid.y = 100;
    panel.addChild(storageGrid);

    // Show existing items in mini format
    this.showExistingItemsInLootInterface(panel);
  }

  addItemToStorage(itemData) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene) return;

    // Create item object compatible with inventory system
    const item = this.createInventoryItem(itemData);

    // Try to place in storage grid
    const placed = this.tryPlaceItemInGrid(item, inventoryScene.storageGrid);

    if (placed) {
      console.log(`Added ${item.name} to storage`);
      return true;
    } else {
      this.showMessage(`No space in storage for ${item.name}!`);
      return false;
    }
  }

  addItemToInventory(itemData) {
    const inventoryScene = this.engine.scenes.get("inventory");
    if (!inventoryScene) return;

    // Create item object compatible with inventory system
    const item = this.createInventoryItem(itemData);

    // Try to place in character inventory
    const placed = this.tryPlaceItemInGrid(item, inventoryScene.inventoryGrid);

    if (placed) {
      console.log(`Added ${item.name} to character inventory`);
      return true;
    } else {
      this.showMessage(`No space in inventory for ${item.name}!`);
      return false;
    }
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
    if (
      itemData.name.includes("Gem") ||
      itemData.name.includes("Orb") ||
      itemData.name.includes("Crystal")
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
      // Check bounds
      if (
        x < 0 ||
        y < 0 ||
        x + this.width > grid.cols ||
        y + this.height > grid.rows
      ) {
        return false;
      }

      // Check for overlapping items (simplified for loot)
      return true;
    };

    // Make interactive for dragging
    item.interactive = true;
    item.cursor = "pointer";

    return item;
  }

  tryPlaceItemInGrid(item, grid) {
    // Find first available spot
    for (let y = 0; y <= grid.rows - item.height; y++) {
      for (let x = 0; x <= grid.cols - item.width; x++) {
        if (this.canPlaceItemAt(grid, item, x, y)) {
          // Place the item
          item.x = grid.x + x * 40 + 2;
          item.y = grid.y + y * 40 + 2;
          item.gridX = x;
          item.gridY = y;

          // Add to inventory scene
          const inventoryScene = this.engine.scenes.get("inventory");
          if (inventoryScene) {
            inventoryScene.items.push(item);
            inventoryScene.addSprite(item, "world");

            // Add drag functionality
            item.on("pointerdown", (event) =>
              inventoryScene.startDragging(item, event)
            );
          }

          return true;
        }
      }
    }
    return false;
  }

  canPlaceItemAt(grid, item, x, y) {
    // Check bounds
    if (
      x < 0 ||
      y < 0 ||
      x + item.width > grid.cols ||
      y + item.height > grid.rows
    ) {
      return false;
    }

    // Check for overlapping items
    const inventoryScene = this.engine.scenes.get("inventory");
    if (inventoryScene) {
      for (const existingItem of inventoryScene.items) {
        if (existingItem.gridX >= 0 && existingItem.gridY >= 0) {
          // Check if the areas overlap
          if (
            !(
              x >= existingItem.gridX + existingItem.width ||
              x + item.width <= existingItem.gridX ||
              y >= existingItem.gridY + existingItem.height ||
              y + item.height <= existingItem.gridY
            )
          ) {
            return false;
          }
        }
      }
    }

    return true;
  }

  enterHouse(house) {
    this.showMessage("🏠 A cozy house. Nobody seems to be home.");
  }

  showMessage(text) {
    console.log(text);

    // Create floating message
    const message = new PIXI.Text(text, {
      fontFamily: "Arial",
      fontSize: 16,
      fill: 0xffd700,
      align: "center",
    });

    message.anchor.set(0.5);
    message.x = this.player.x;
    message.y = this.player.y - 40;

    this.addSprite(message, "effects");

    // Animate message
    let time = 0;
    const animate = () => {
      time += 0.05;
      message.y -= 1;
      message.alpha = Math.max(0, 1 - time / 2);

      if (message.alpha <= 0) {
        this.removeSprite(message);
      } else {
        requestAnimationFrame(animate);
      }
    };
    animate();
  }

  handleKeyDown(event) {
    if (event.code === "Space") {
      // Interact with nearby objects
      for (const obj of this.worldObjects) {
        if (this.isPlayerNear(obj.sprite)) {
          obj.sprite.emit("pointerdown");
          break;
        }
      }
    }
  }

  // Method to reset world state (for debugging or new game)
  resetWorldState() {
    this.worldState = {
      removedCrystals: [],
      openedChests: [],
      discoveredItems: [],
    };
    this.playerPosition = { x: 400, y: 300 };
    this.isInitialized = false;

    // Clear current world objects
    this.worldObjects.forEach((obj) => {
      if (obj.sprite.animationId) {
        clearInterval(obj.sprite.animationId);
      }
      this.removeSprite(obj.sprite);
    });
    this.worldObjects = [];

    console.log("World state reset");
  }
}
