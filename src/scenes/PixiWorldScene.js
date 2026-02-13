import { PixiScene } from "../core/PixiScene.js";

export class PixiWorldScene extends PixiScene {
  constructor() {
    super();
    this.player = null;
    this.worldObjects = [];
    this.camera = { x: 0, y: 0 };
    
    // Responsive world dimensions (will be calculated based on viewport)
    this.worldMultiplier = 3; // World is 3x the viewport size
    this.worldWidth = 0;
    this.worldHeight = 0;
    
    // Responsive player properties
    this.basePlayerSpeed = 3;
    this.playerSpeed = 3; // Will be scaled responsively
    this.playerSize = 16; // Will be scaled responsively
    
    // Responsive object scaling
    this.baseObjectScale = 1;
    this.objectScale = 1; // Will be calculated responsively
    
    // Persistent state
    this.isInitialized = false;
    this.playerPosition = { x: 0, y: 0 }; // Will be calculated relative to world center
    this.worldState = {
      removedCrystals: [], // Track which crystals have been used
      openedChests: [], // Track which chests have been opened
      discoveredItems: [], // Track found items
    };
    
    // UI elements for responsive updates
    this.messageContainer = null;
    this.activeMessages = [];
  }

  onEnter() {
    super.onEnter();
    
    // Calculate responsive world dimensions
    this.updateWorldDimensions();

    if (!this.isInitialized) {
      // First time entering - create everything
      this.createWorld();
      this.createPlayer();
      this.createWorldObjects();
      this.setupMessageSystem();
      this.isInitialized = true;
      console.log("Responsive world scene initialized for first time");
    } else {
      // Returning to world - restore player position and update display
      this.restorePlayerPosition();
      this.updateCamera();
      this.updateAllObjectScaling();
      console.log("Returned to responsive world scene, restored position:", this.playerPosition);
    }

    // Update game mode display
    const gameModeBtn = document.getElementById("gameMode");
    if (gameModeBtn) {
      gameModeBtn.textContent = "🌍 EXPLORING";
    }

    // Update navigation buttons
    if (this.engine && this.engine.updateNavButtons) {
      this.engine.updateNavButtons("world");
    } else {
      this.updateNavigationButtons();
    }

    console.log(`World exploration scene active: ${this.worldWidth}x${this.worldHeight} world`);
  }

  onResize(newWidth, newHeight) {
    super.onResize(newWidth, newHeight);
    
    // Recalculate world dimensions and scaling
    this.updateWorldDimensions();
    
    // Update world background
    this.updateWorldBackground();
    
    // Update all object scaling
    this.updateAllObjectScaling();
    
    // Update camera to maintain relative position
    this.updateCamera();
    
    // Update message system
    this.updateMessageSystem();
    
    console.log(`World scene resized: ${newWidth}x${newHeight}, world: ${this.worldWidth}x${this.worldHeight}`);
  }

  updateWorldDimensions() {
    // Calculate world size based on viewport
    this.worldWidth = this.viewportWidth * this.worldMultiplier;
    this.worldHeight = this.viewportHeight * this.worldMultiplier;
    
    // Update responsive scaling
    this.playerSpeed = this.getScaledSize(this.basePlayerSpeed);
    this.playerSize = this.getScaledSize(16);
    this.objectScale = this.scaleFactor;
    
    // Set initial player position to world center if not set
    if (this.playerPosition.x === 0 && this.playerPosition.y === 0) {
      this.playerPosition.x = this.worldWidth / 2;
      this.playerPosition.y = this.worldHeight / 2;
    }
    
    console.log("World dimensions updated:", {
      worldSize: `${this.worldWidth}x${this.worldHeight}`,
      playerSpeed: this.playerSpeed,
      playerSize: this.playerSize,
      objectScale: this.objectScale.toFixed(2),
      playerPosition: this.playerPosition,
    });
  }

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

    // Clear active messages
    this.activeMessages = [];

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
    this.updateWorldBackground();
  }

  updateWorldBackground() {
    // Remove existing background
    const existingBg = this.layers.background.getChildByName("worldBackground");
    if (existingBg) {
      this.layers.background.removeChild(existingBg);
    }

    // Create responsive world background
    const worldBg = new PIXI.Graphics();
    worldBg.beginFill(0x2d5016); // Forest green
    worldBg.drawRect(0, 0, this.worldWidth, this.worldHeight);
    worldBg.endFill();

    // Add ground texture scaled to world size
    const textureSize = this.getScaledSize(64);
    const textureDensity = this.isMobile ? 0.2 : 0.3; // Reduce density on mobile
    
    for (let x = 0; x < this.worldWidth; x += textureSize) {
      for (let y = 0; y < this.worldHeight; y += textureSize) {
        if (Math.random() < textureDensity) {
          const patchSize = this.getScaledSize(32);
          worldBg.beginFill(0x228b22);
          worldBg.drawRect(x, y, patchSize, patchSize);
          worldBg.endFill();
        }
      }
    }

    worldBg.name = "worldBackground";
    this.addGraphics(worldBg, "background");
  }

  createPlayer() {
    if (this.player) {
      this.removeSprite(this.player);
    }

    this.player = new PIXI.Graphics();

    // Responsive player size
    const playerWidth = this.playerSize;
    const playerHeight = this.playerSize * 1.5;
    const headRadius = this.playerSize * 0.5;

    // Player body
    this.player.beginFill(0x4a90e2);
    this.player.drawRect(-playerWidth/2, -playerHeight/2, playerWidth, playerHeight);
    this.player.endFill();

    // Player head
    this.player.beginFill(0xfdbcb4);
    this.player.drawCircle(0, -playerHeight/2 - headRadius/2, headRadius);
    this.player.endFill();

    // Player weapon
    const weaponWidth = this.playerSize * 0.25;
    const weaponHeight = this.playerSize * 0.9;
    this.player.beginFill(0x8b4513);
    this.player.drawRect(-weaponWidth/2, -playerHeight/2 - weaponHeight, weaponWidth, weaponHeight);
    this.player.endFill();

    // Set initial position
    this.player.x = this.playerPosition.x;
    this.player.y = this.playerPosition.y;

    this.addSprite(this.player, "world");
  }

  createWorldObjects() {
    // Calculate responsive object counts based on world size
    const worldArea = this.worldWidth * this.worldHeight;
    const baseArea = 1920 * 1080; // Reference area
    const areaRatio = worldArea / baseArea;
    
    // Scale object counts
    const treeCount = Math.floor(30 * areaRatio);
    const crystalCount = Math.floor(8 * Math.min(areaRatio, 2)); // Cap crystals
    const chestCount = Math.floor(5 * Math.min(areaRatio, 2)); // Cap chests
    const houseCount = Math.floor(2 * Math.min(areaRatio, 1.5)); // Cap houses
    
    console.log("Creating world objects:", {
      trees: treeCount,
      crystals: crystalCount,
      chests: chestCount,
      houses: houseCount,
    });

    // Create trees
    for (let i = 0; i < treeCount; i++) {
      this.createTree(
        Math.random() * this.worldWidth,
        Math.random() * this.worldHeight,
        i
      );
    }

    // Create battle crystals (only if not already removed)
    for (let i = 0; i < crystalCount; i++) {
      if (!this.worldState.removedCrystals.includes(i)) {
        this.createBattleCrystal(
          this.getScaledSize(200) + Math.random() * (this.worldWidth - this.getScaledSize(400)),
          this.getScaledSize(200) + Math.random() * (this.worldHeight - this.getScaledSize(400)),
          i
        );
      }
    }

    // Create treasure chests
    for (let i = 0; i < chestCount; i++) {
      this.createTreasureChest(
        this.getScaledSize(100) + Math.random() * (this.worldWidth - this.getScaledSize(200)),
        this.getScaledSize(100) + Math.random() * (this.worldHeight - this.getScaledSize(200)),
        i
      );
    }

    // Create NPCs/Houses
    for (let i = 0; i < houseCount; i++) {
      this.createHouse(
        this.worldWidth * (0.3 + i * 0.4),
        this.worldHeight * (0.3 + i * 0.4),
        i
      );
    }
  }

  updateAllObjectScaling() {
    // Update all existing objects with new scaling
    this.worldObjects.forEach(obj => {
      if (obj.sprite && obj.sprite.parent) {
        this.updateObjectScale(obj);
      }
    });
    
    // Update player scaling
    if (this.player) {
      this.createPlayer();
    }
  }

  updateObjectScale(obj) {
    const sprite = obj.sprite;
    if (!sprite) return;

    // Apply responsive scaling
    sprite.scale.set(this.objectScale);
    
    // Update collision bounds if needed
    if (obj.collisionRadius) {
      obj.collisionRadius = obj.baseCollisionRadius * this.objectScale;
    }
  }

  createTree(x, y, id) {
    const tree = new PIXI.Container();
    const baseScale = this.objectScale;

    // Tree trunk
    const trunkWidth = 12 * baseScale;
    const trunkHeight = 20 * baseScale;
    const trunk = new PIXI.Graphics();
    trunk.beginFill(0x8b4513);
    trunk.drawRect(-trunkWidth/2, -trunkHeight, trunkWidth, trunkHeight);
    trunk.endFill();

    // Tree crown
    const crownRadius = 18 * baseScale;
    const crown = new PIXI.Graphics();
    crown.beginFill(0x228b22);
    crown.drawCircle(0, -trunkHeight - crownRadius/2, crownRadius);
    crown.endFill();

    tree.addChild(trunk);
    tree.addChild(crown);
    tree.x = x;
    tree.y = y;
    tree.treeId = id;

    // Store collision properties
    tree.baseCollisionRadius = 20;
    tree.collisionRadius = tree.baseCollisionRadius * baseScale;

    // Make interactive
    tree.interactive = true;
    tree.cursor = "pointer";
    tree.on("pointerdown", () => {
      if (this.isPlayerNear(tree)) {
        this.interactWithTree(tree);
      }
    });

    this.worldObjects.push({ type: "tree", sprite: tree, x, y, id, baseCollisionRadius: 20 });
    this.addSprite(tree, "world");
  }

  createBattleCrystal(x, y, id) {
    const crystal = new PIXI.Graphics();
    const baseScale = this.objectScale;
    const size = 10 * baseScale;

    // Crystal shape
    crystal.beginFill(0xff00ff);
    crystal.moveTo(0, -20 * baseScale);
    crystal.lineTo(-size, -5 * baseScale);
    crystal.lineTo(-size * 0.8, 10 * baseScale);
    crystal.lineTo(0, 20 * baseScale);
    crystal.lineTo(size * 0.8, 10 * baseScale);
    crystal.lineTo(size, -5 * baseScale);
    crystal.closePath();
    crystal.endFill();

    crystal.x = x;
    crystal.y = y;
    crystal.crystalId = id;

    // Floating animation
    let floatOffset = Math.random() * Math.PI * 2;
    crystal.originalY = y;
    const floatAmount = 8 * baseScale;

    // Store animation in the object for later cleanup
    crystal.animationId = setInterval(() => {
      crystal.y = crystal.originalY + Math.sin(Date.now() * 0.002 + floatOffset) * floatAmount;
    }, 16);

    // Store collision properties
    crystal.baseCollisionRadius = 15;
    crystal.collisionRadius = crystal.baseCollisionRadius * baseScale;

    // Make interactive
    crystal.interactive = true;
    crystal.cursor = "pointer";
    crystal.on("pointerdown", () => {
      if (this.isPlayerNear(crystal)) {
        this.startBattle(crystal);
      }
    });

    this.worldObjects.push({ type: "crystal", sprite: crystal, x, y, id, baseCollisionRadius: 15 });
    this.addSprite(crystal, "world");
  }

  createTreasureChest(x, y, id) {
    const chest = new PIXI.Graphics();
    const isOpened = this.worldState.openedChests.includes(id);
    const baseScale = this.objectScale;

    // Draw chest based on opened state
    this.drawChest(chest, isOpened, baseScale);

    chest.x = x;
    chest.y = y;
    chest.chestId = id;
    chest.opened = isOpened;

    // Store collision properties
    chest.baseCollisionRadius = 25;
    chest.collisionRadius = chest.baseCollisionRadius * baseScale;

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

    this.worldObjects.push({ type: "chest", sprite: chest, x, y, id, baseCollisionRadius: 25 });
    this.addSprite(chest, "world");
  }

  drawChest(chest, isOpened, scale = 1) {
    chest.clear();

    const width = 40 * scale;
    const height = 20 * scale;
    const lidHeight = 10 * scale;

    if (isOpened) {
      // Open chest appearance
      chest.beginFill(0x654321);
      chest.drawRect(-width/2, -height/2, width, height);
      chest.endFill();

      // Chest lid (open)
      chest.beginFill(0xa0522d);
      chest.drawRect(-width/2, -height/2 - lidHeight, width, lidHeight);
      chest.endFill();

      // Faded gold trim
      chest.lineStyle(Math.max(1, scale), 0xb8860b, 0.5);
      chest.drawRect(-width/2, -height/2 - lidHeight, width, height + lidHeight);
    } else {
      // Closed chest appearance
      chest.beginFill(0x8b4513);
      chest.drawRect(-width/2, -height/2, width, height);
      chest.endFill();

      // Chest lid
      chest.beginFill(0xa0522d);
      chest.drawRect(-width/2, -height/2 - lidHeight/2, width, lidHeight);
      chest.endFill();

      // Gold trim
      chest.lineStyle(Math.max(2, scale * 2), 0xffd700);
      chest.drawRect(-width/2, -height/2 - lidHeight/2, width, height + lidHeight/2);
    }
  }

  createHouse(x, y, id) {
    const house = new PIXI.Container();
    const baseScale = this.objectScale;

    // House dimensions
    const houseWidth = 80 * baseScale;
    const houseHeight = 60 * baseScale;
    const roofHeight = 20 * baseScale;

    // House base
    const base = new PIXI.Graphics();
    base.beginFill(0x8b4513);
    base.drawRect(-houseWidth/2, -houseHeight/2, houseWidth, houseHeight);
    base.endFill();

    // Roof
    const roof = new PIXI.Graphics();
    roof.beginFill(0x654321);
    roof.moveTo(-houseWidth/2, -houseHeight/2);
    roof.lineTo(0, -houseHeight/2 - roofHeight);
    roof.lineTo(houseWidth/2, -houseHeight/2);
    roof.closePath();
    roof.endFill();

    // Door
    const doorWidth = 20 * baseScale;
    const doorHeight = 30 * baseScale;
    const door = new PIXI.Graphics();
    door.beginFill(0x4a3c1d);
    door.drawRect(-doorWidth/2, houseHeight/2 - doorHeight, doorWidth, doorHeight);
    door.endFill();

    house.addChild(base);
    house.addChild(roof);
    house.addChild(door);
    house.x = x;
    house.y = y;
    house.houseId = id;

    // Store collision properties
    house.baseCollisionRadius = 50;
    house.collisionRadius = house.baseCollisionRadius * baseScale;

    // Make interactive
    house.interactive = true;
    house.cursor = "pointer";
    house.on("pointerdown", () => {
      if (this.isPlayerNear(house)) {
        this.enterHouse(house);
      }
    });

    this.worldObjects.push({ type: "house", sprite: house, x, y, id, baseCollisionRadius: 50 });
    this.addSprite(house, "world");
  }

  setupMessageSystem() {
    this.updateMessageSystem();
  }

  updateMessageSystem() {
    // Remove existing message container
    if (this.messageContainer) {
      this.removeSprite(this.messageContainer);
    }

    // Create new message container
    this.messageContainer = new PIXI.Container();
    this.messageContainer.name = "messageContainer";
    
    // Position message container responsively
    this.makeResponsive(this.messageContainer, {
      anchor: { x: 'center', y: 'center' },
      offset: { x: 0, y: 0 },
      scale: false
    });

    this.addSprite(this.messageContainer, "effects");
  }

  // Player movement and camera
  update(deltaTime) {
    super.update(deltaTime);
    this.updatePlayerMovement();
    this.updateCamera();
    this.updateMessages(deltaTime);
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
    const playerRadius = this.playerSize / 2;
    newX = Math.max(playerRadius, Math.min(this.worldWidth - playerRadius, newX));
    newY = Math.max(playerRadius, Math.min(this.worldHeight - playerRadius, newY));

    // Responsive collision detection
    let canMove = true;
    for (const obj of this.worldObjects) {
      if (obj.type === "tree" || obj.type === "house") {
        const distance = Math.sqrt(Math.pow(newX - obj.x, 2) + Math.pow(newY - obj.y, 2));
        const minDistance = playerRadius + obj.sprite.collisionRadius;
        if (distance < minDistance) {
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
    const targetCameraX = this.player.x - this.viewportWidth / 2;
    const targetCameraY = this.player.y - this.viewportHeight / 2;

    // Keep camera within world bounds
    this.camera.x = Math.max(0, Math.min(this.worldWidth - this.viewportWidth, targetCameraX));
    this.camera.y = Math.max(0, Math.min(this.worldHeight - this.viewportHeight, targetCameraY));

    // Apply camera to world layer
    this.layers.world.x = -this.camera.x;
    this.layers.world.y = -this.camera.y;
    this.layers.background.x = -this.camera.x;
    this.layers.background.y = -this.camera.y;
  }

  updateMessages(deltaTime) {
    // Update active messages
    this.activeMessages = this.activeMessages.filter(message => {
      message.timeLeft -= deltaTime;
      
      if (message.timeLeft <= 0) {
        // Remove expired message
        if (message.sprite && message.sprite.parent) {
          this.messageContainer.removeChild(message.sprite);
        }
        return false;
      }
      
      // Update message animation
      if (message.sprite) {
        message.sprite.y -= 0.5; // Float upward
        message.sprite.alpha = Math.max(0, message.timeLeft / message.duration);
      }
      
      return true;
    });
  }

  // Interaction methods
  isPlayerNear(object) {
    if (!this.player) return false;

    const distance = Math.sqrt(
      Math.pow(this.player.x - object.x, 2) + Math.pow(this.player.y - object.y, 2)
    );

    const interactionDistance = this.getScaledSize(50);
    return distance < interactionDistance;
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
    const objIndex = this.worldObjects.findIndex(obj => obj.sprite === crystal);
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

  openChest(chest) {
    if (chest.opened) {
      this.showMessage("Chest is empty.");
      return;
    }

    // Mark chest as opened
    chest.opened = true;
    this.worldState.openedChests.push(chest.chestId);

    // Update chest appearance
    this.drawChest(chest, true, this.objectScale);

    // Make non-interactive
    chest.interactive = false;
    chest.cursor = "default";

    // Generate loot for this chest
    const loot = this.generateLoot(chest.chestId);

    // Switch to loot scene with chest context
    const lootScene = this.engine.scenes.get("loot");
    if (lootScene) {
      lootScene.setLootData(loot, {
        returnScene: "world",
        title: "💎 TREASURE FOUND!",
        subtitle: "Drag items from the right to your inventory or storage on the left",
        context: "chest",
      });

      this.engine.switchScene("loot");
    }
  }

  generateLoot(chestId) {
    // Loot generation (same logic as before, but with responsive considerations)
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
      // Additional chest loot tables...
      [
        {
          name: "Magic Scroll",
          color: 0x9b59b6,
          width: 1,
          height: 1,
          type: "consumable",
          baseSkills: [
            {
              name: "Fireball",
              description: "Cast a fireball",
              damage: 25,
              cost: 8,
              type: "magic",
            },
          ],
        },
        {
          name: "Gold Coins",
          color: 0xf1c40f,
          width: 1,
          height: 1,
          type: "currency",
          quantity: 50,
        },
      ],
    ];

    const selectedLoot = lootTables[chestId % lootTables.length] || lootTables[0];
    const numItems = Math.random() < 0.7 ? selectedLoot.length : Math.floor(selectedLoot.length / 2) + 1;

    return selectedLoot.slice(0, numItems);
  }

  enterHouse(house) {
    this.showMessage("🏠 A cozy house. Nobody seems to be home.");
  }

  showMessage(text) {
    console.log(text);

    if (!this.messageContainer) {
      this.updateMessageSystem();
    }

    // Create floating message with responsive sizing
    const message = new PIXI.Text(text, {
      fontFamily: "Arial",
      fontSize: this.getResponsiveFontSize(16),
      fill: 0xffd700,
      align: "center",
      stroke: 0x000000,
      strokeThickness: Math.max(1, this.scaleFactor),
    });

    message.anchor.set(0.5);
    
    // Position relative to player in world coordinates
    const worldPlayerX = this.player.x;
    const worldPlayerY = this.player.y - this.getScaledSize(40);
    
    // Convert to camera-relative coordinates
    message.x = worldPlayerX - this.camera.x;
    message.y = worldPlayerY - this.camera.y;

    this.messageContainer.addChild(message);

    // Store message data for animation
    const messageData = {
      sprite: message,
      timeLeft: 3000, // 3 seconds
      duration: 3000,
    };

    this.activeMessages.push(messageData);
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
    } else if (event.code === "KeyM") {
      // Show world map or minimap
      this.showWorldInfo();
    }
  }

  showWorldInfo() {
    const info = `🌍 World Exploration
Size: ${this.worldWidth}x${this.worldHeight}
Player: (${Math.floor(this.player.x)}, ${Math.floor(this.player.y)})
Objects: ${this.worldObjects.length}
Discovered: ${this.worldState.discoveredItems.length} items
Opened chests: ${this.worldState.openedChests.length}
Crystals used: ${this.worldState.removedCrystals.length}`;

    this.showMessage(info);
  }

  // Method to reset world state (for debugging or new game)
  resetWorldState() {
    this.worldState = {
      removedCrystals: [],
      openedChests: [],
      discoveredItems: [],
    };
    this.playerPosition = { x: this.worldWidth / 2, y: this.worldHeight / 2 };
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