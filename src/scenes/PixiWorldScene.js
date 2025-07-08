import { PixiScene } from '../core/PixiScene.js';

export class PixiWorldScene extends PixiScene {
    constructor() {
        super();
        this.player = null;
        this.worldObjects = [];
        this.camera = { x: 0, y: 0 };
        this.playerSpeed = 3;
        this.worldWidth = 2000;
        this.worldHeight = 1400;
        
        // Persistent state
        this.isInitialized = false;
        this.playerPosition = { x: 400, y: 300 }; // Default starting position
        this.worldState = {
            removedCrystals: [], // Track which crystals have been used
            openedChests: [], // Track which chests have been opened
            discoveredItems: [] // Track found items
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
            console.log('World scene initialized for first time');
        } else {
            // Returning to world - restore player position and update display
            this.restorePlayerPosition();
            this.updateCamera();
            console.log('Returned to world scene, restored position:', this.playerPosition);
        }
        
        // Update game mode display
        const gameModeBtn = document.getElementById('gameMode');
        if (gameModeBtn) {
            gameModeBtn.textContent = '🌍 EXPLORING';
        }
        
        // UPDATE NAVIGATION BUTTONS - Add this section
        if (this.engine && this.engine.updateNavButtons) {
            this.engine.updateNavButtons('world');
        } else {
            // Fallback: directly update buttons
            this.updateNavigationButtons();
        }
        
        console.log('World exploration scene active');
    }
    
    // ADD THIS NEW METHOD to PixiWorldScene
    updateNavigationButtons() {
        const buttons = {
            menu: document.getElementById('menuBtn'),
            inventory: document.getElementById('inventoryBtn'),
            world: document.getElementById('worldBtn'),
            battle: document.getElementById('battleBtn')
        };
        
        Object.keys(buttons).forEach(scene => {
            const btn = buttons[scene];
            if (btn) {
                if (scene === 'world') {
                    btn.classList.add('active');
                } else {
                    btn.classList.remove('active');
                }
            }
        });
    }
    
    onExit() {
        // Save current player position before leaving
        if (this.player) {
            this.playerPosition.x = this.player.x;
            this.playerPosition.y = this.player.y;
            console.log('Saved player position:', this.playerPosition);
        }
        
        // Clean up animations but keep objects
        this.worldObjects.forEach(obj => {
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
            console.log('Player restored to position:', this.playerPosition);
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
        
        this.addGraphics(worldBg, 'background');
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
        
        this.addSprite(this.player, 'world');
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
        tree.cursor = 'pointer';
        tree.on('pointerdown', () => {
            if (this.isPlayerNear(tree)) {
                this.interactWithTree(tree);
            }
        });
        
        this.worldObjects.push({ type: 'tree', sprite: tree, x, y, id });
        this.addSprite(tree, 'world');
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
            crystal.y = crystal.originalY + Math.sin(Date.now() * 0.002 + floatOffset) * 8;
        }, 16);
        
        // Make interactive
        crystal.interactive = true;
        crystal.cursor = 'pointer';
        crystal.on('pointerdown', () => {
            if (this.isPlayerNear(crystal)) {
                this.startBattle(crystal);
            }
        });
        
        this.worldObjects.push({ type: 'crystal', sprite: crystal, x, y, id });
        this.addSprite(crystal, 'world');
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
            chest.cursor = 'pointer';
            chest.on('pointerdown', () => {
                if (this.isPlayerNear(chest)) {
                    this.openChest(chest);
                }
            });
        }
        
        this.worldObjects.push({ type: 'chest', sprite: chest, x, y, id });
        this.addSprite(chest, 'world');
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
        house.cursor = 'pointer';
        house.on('pointerdown', () => {
            if (this.isPlayerNear(house)) {
                this.enterHouse(house);
            }
        });
        
        this.worldObjects.push({ type: 'house', sprite: house, x, y, id });
        this.addSprite(house, 'world');
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
        if (this.keys['KeyW'] || this.keys['ArrowUp']) {
            newY -= this.playerSpeed;
            moved = true;
        }
        if (this.keys['KeyS'] || this.keys['ArrowDown']) {
            newY += this.playerSpeed;
            moved = true;
        }
        if (this.keys['KeyA'] || this.keys['ArrowLeft']) {
            newX -= this.playerSpeed;
            moved = true;
        }
        if (this.keys['KeyD'] || this.keys['ArrowRight']) {
            newX += this.playerSpeed;
            moved = true;
        }
        
        // World boundaries
        newX = Math.max(20, Math.min(this.worldWidth - 20, newX));
        newY = Math.max(20, Math.min(this.worldHeight - 20, newY));
        
        // Simple collision detection (avoid trees)
        let canMove = true;
        for (const obj of this.worldObjects) {
            if (obj.type === 'tree' || obj.type === 'house') {
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
        this.camera.x = Math.max(0, Math.min(this.worldWidth - this.engine.width, targetCameraX));
        this.camera.y = Math.max(0, Math.min(this.worldHeight - this.engine.height, targetCameraY));
        
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
            this.showMessage('Found an apple! 🍎');
            this.worldState.discoveredItems.push(`apple_${tree.treeId}`);
        } else {
            this.showMessage('Just a tree...');
        }
    }
    
    startBattle(crystal) {
        this.showMessage('⚔️ Battle encounter!');
        
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
        
        console.log('Starting battle, saved position:', this.playerPosition);
        
        // Go to battle scene after short delay
        setTimeout(() => {
            this.engine.switchScene('battle');
        }, 1000);
    }
    
    openChest(chest) {
        if (chest.opened) {
            this.showMessage('Chest is empty.');
            return;
        }
        
        // Mark chest as opened
        chest.opened = true;
        this.worldState.openedChests.push(chest.chestId);
        
        // Update chest appearance
        this.drawChest(chest, true);
        
        // Make non-interactive
        chest.interactive = false;
        chest.cursor = 'default';
        
        const loot = ['Gold Coin', 'Health Potion', 'Magic Gem', 'Ancient Scroll'][Math.floor(Math.random() * 4)];
        this.showMessage(`Found ${loot}! 💎`);
        
        console.log('Opened chest', chest.chestId, 'found:', loot);
    }
    
    enterHouse(house) {
        this.showMessage('🏠 A cozy house. Nobody seems to be home.');
    }
    
    showMessage(text) {
        console.log(text);
        
        // Create floating message
        const message = new PIXI.Text(text, {
            fontFamily: 'Arial',
            fontSize: 16,
            fill: 0xffd700,
            align: 'center'
        });
        
        message.anchor.set(0.5);
        message.x = this.player.x;
        message.y = this.player.y - 40;
        
        this.addSprite(message, 'effects');
        
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
        if (event.code === 'Space') {
            // Interact with nearby objects
            for (const obj of this.worldObjects) {
                if (this.isPlayerNear(obj.sprite)) {
                    obj.sprite.emit('pointerdown');
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
            discoveredItems: []
        };
        this.playerPosition = { x: 400, y: 300 };
        this.isInitialized = false;
        
        // Clear current world objects
        this.worldObjects.forEach(obj => {
            if (obj.sprite.animationId) {
                clearInterval(obj.sprite.animationId);
            }
            this.removeSprite(obj.sprite);
        });
        this.worldObjects = [];
        
        console.log('World state reset');
    }
}