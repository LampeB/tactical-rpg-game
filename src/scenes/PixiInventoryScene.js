import { HybridInventoryScene } from "../core/HybridInventoryScene.js";
import { ShapeHelper } from "../utils/ShapeHelper.js";
import { Grid } from "../models/Grid.js";

export class PixiInventoryScene extends HybridInventoryScene {
  constructor() {
    super(); // This calls HybridInventoryScene constructor
    
    // Squad-based inventory management
    this.selectedCharacter = null; // Currently selected character
    this.characterButtons = []; // Character selection buttons
    
    // UI areas (adjust to work with existing layout)
    this.characterSelectorArea = { x: 50, y: 60, width: 1100, height: 40 };
    
    // Navigation buttons
    this.navButtons = [];
    this.hoveredButton = -1;
    
    // Squad management
    this.isInitialized = false;
    
    // Inventory-specific settings (from parent class)
    this.showShapeOutlines = false;
    this.showDimensionInfo = false;
    
    // Skills display
    this.skillsContainer = null;
    this.skillsTitle = null;
  }

  onEnter() {
    super.onEnter();

    this.createSquadBackground();
    this.createCharacterSelector();
    this.createSquadInventoryArea();
    this.createSquadStorageArea();
    this.createSquadSkillsArea();
    this.createSquadNavigationButtons();

    // Initialize with first character from squad
    this.initializeWithSquad();

    // Update game mode display
    const gameModeBtn = document.getElementById("gameMode");
    if (gameModeBtn) {
      gameModeBtn.textContent = "🎒 SQUAD INVENTORY";
    }

    if (this.engine && this.engine.updateNavButtons) {
      this.engine.updateNavButtons("inventory");
    }

    console.log("📦 Squad-based inventory scene loaded");
  }

  // ============= SQUAD INITIALIZATION =============

  initializeWithSquad() {
    const roster = this.engine.characterRoster;
    if (!roster) {
      console.error("❌ Character roster not found!");
      this.createFallbackInventory();
      return;
    }

    const squad = roster.getActiveSquad();
    if (squad.length === 0) {
      console.warn("⚠️ No characters in squad!");
      this.createFallbackInventory();
      return;
    }

    // Select first character by default
    this.selectCharacter(squad[0]);

    // Setup shared storage if not initialized
    if (!this.isInitialized) {
      this.setupSharedStorage();
      this.isInitialized = true;
    }

    console.log(`👥 Initialized inventory for squad of ${squad.length}`);
  }

  createFallbackInventory() {
    // Create a fallback character if no squad exists
    console.warn("⚠️ Creating fallback inventory system");
    this.selectedCharacter = {
      name: "Hero",
      class: "Adventurer",
      portrait: "👤",
      inventory: new Grid(0, 0, 10, 8, 40)
    };
    this.refreshAllDisplays();
  }

  setupSharedStorage() {
    // Add some shared storage items if empty
    if (this.storageItems.length === 0) {
      const sharedItems = [
        { name: "Health Potion", color: 0xe74c3c, width: 1, height: 1, type: "consumable", quantity: 5 },
        { name: "Mana Potion", color: 0x3498db, width: 1, height: 1, type: "consumable", quantity: 3 },
        { name: "Iron Ore", color: 0x7f8c8d, width: 1, height: 1, type: "material", quantity: 10 },
        { name: "Magic Crystal", color: 0x9b59b6, width: 1, height: 1, type: "material", quantity: 2 },
        { name: "Dragon Scale", color: 0xf39c12, width: 1, height: 1, type: "material", quantity: 1 },
        { name: "Healing Herb", color: 0x27ae60, width: 1, height: 1, type: "consumable", quantity: 8 },
      ];
      
      sharedItems.forEach(itemData => {
        this.addToStorage(itemData);
      });
    }
  }

  // ============= BACKGROUND AND UI CREATION =============

  createSquadBackground() {
    // Main background
    const bg = new PIXI.Graphics();
    bg.beginFill(0x27ae60);
    bg.drawRect(0, 0, this.engine.width, this.engine.height);
    bg.endFill();
    this.addGraphics(bg, "background");

    // Title
    const title = new PIXI.Text("🎒 SQUAD INVENTORY", {
      fontFamily: "Arial",
      fontSize: 28,
      fill: 0xffffff,
      align: "center",
      fontWeight: "bold",
    });
    title.anchor.set(0.5);
    title.x = this.engine.width / 2;
    title.y = 30;
    this.addSprite(title, "ui");
  }

  createSquadInventoryArea() {
    // Grid label with character name
    this.characterGridLabel = new PIXI.Text("Character Equipment (Grid-based)", {
      fontFamily: "Arial",
      fontSize: 16,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    this.characterGridLabel.x = this.characterGrid.x;
    this.characterGridLabel.y = this.characterGrid.y - 25;
    this.addSprite(this.characterGridLabel, "ui");
  }

  createSquadStorageArea() {
    // Storage label
    const storageLabel = new PIXI.Text("Shared Storage (Unlimited)", {
      fontFamily: "Arial",
      fontSize: 16,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    storageLabel.x = this.storageList.x;
    storageLabel.y = this.storageList.y - 25;
    this.addSprite(storageLabel, "ui");
  }

  createSquadSkillsArea() {
    const skillsY = this.characterGrid.y + this.characterGrid.rows * this.gridCellSize + 50;
    const skillsWidth = 1100;
    const skillsHeight = 200;
    
    // Skills panel background
    const skillsBg = new PIXI.Graphics();
    skillsBg.beginFill(0x2c3e50, 0.9);
    skillsBg.drawRoundedRect(0, 0, skillsWidth, skillsHeight, 10);
    skillsBg.endFill();
    skillsBg.lineStyle(2, 0x3498db);
    skillsBg.drawRoundedRect(0, 0, skillsWidth, skillsHeight, 10);
    skillsBg.x = 50;
    skillsBg.y = skillsY;
    this.addGraphics(skillsBg, "ui");

    // Title with character name
    this.skillsTitle = new PIXI.Text("⚔️ Available Skills", {
      fontFamily: "Arial",
      fontSize: 18,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    this.skillsTitle.x = 65;
    this.skillsTitle.y = skillsY + 15;
    this.addSprite(this.skillsTitle, "ui");

    // Skills container for dynamic content
    this.skillsContainer = new PIXI.Container();
    this.skillsContainer.x = 50;
    this.skillsContainer.y = skillsY;
    this.addSprite(this.skillsContainer, "ui");
  }

  // ============= CHARACTER SELECTOR =============

  createCharacterSelector() {
    const area = this.characterSelectorArea;
    
    // Background
    const selectorBg = new PIXI.Graphics();
    selectorBg.beginFill(0x34495e, 0.9);
    selectorBg.drawRoundedRect(0, 0, area.width, area.height, 5);
    selectorBg.endFill();
    selectorBg.lineStyle(1, 0x7f8c8d);
    selectorBg.drawRoundedRect(0, 0, area.width, area.height, 5);
    selectorBg.x = area.x;
    selectorBg.y = area.y;
    this.addGraphics(selectorBg, "ui");

    // Title
    const title = new PIXI.Text("👥 Select Character:", {
      fontFamily: "Arial",
      fontSize: 16,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    title.x = area.x + 10;
    title.y = area.y + 12;
    this.addSprite(title, "ui");

    this.refreshCharacterButtons();
  }

  refreshCharacterButtons() {
    // Clear existing buttons
    this.characterButtons.forEach(btn => this.removeSprite(btn));
    this.characterButtons = [];

    const roster = this.engine.characterRoster;
    if (!roster) return;

    const squad = roster.getActiveSquad();
    const area = this.characterSelectorArea;
    const buttonWidth = 200;
    const buttonHeight = 30;
    const startX = area.x + 150;
    const startY = area.y + 5;

    squad.forEach((character, index) => {
      const button = this.createCharacterButton(character, index);
      button.x = startX + index * (buttonWidth + 10);
      button.y = startY;
      
      this.characterButtons.push(button);
      this.addSprite(button, "ui");
    });
  }

  createCharacterButton(character, index) {
    const buttonContainer = new PIXI.Container();
    const buttonWidth = 200;
    const buttonHeight = 30;
    const isSelected = this.selectedCharacter === character;

    // Button background
    const bg = new PIXI.Graphics();
    bg.beginFill(isSelected ? 0x3498db : 0x2c3e50);
    bg.drawRoundedRect(0, 0, buttonWidth, buttonHeight, 5);
    bg.endFill();
    bg.lineStyle(1, isSelected ? 0xffffff : 0x7f8c8d);
    bg.drawRoundedRect(0, 0, buttonWidth, buttonHeight, 5);
    buttonContainer.addChild(bg);

    // Character info
    const text = new PIXI.Text(`${character.portrait} ${character.name} (${character.class})`, {
      fontFamily: "Arial",
      fontSize: 12,
      fill: 0xffffff,
      fontWeight: isSelected ? "bold" : "normal",
    });
    text.x = 8;
    text.y = 8;
    buttonContainer.addChild(text);

    // HP/MP indicator
    const statsText = new PIXI.Text(`${character.hp}/${character.maxHp} HP`, {
      fontFamily: "Arial",
      fontSize: 10,
      fill: 0xbdc3c7,
    });
    statsText.x = buttonWidth - 60;
    statsText.y = 10;
    buttonContainer.addChild(statsText);

    // Store references
    buttonContainer.character = character;
    buttonContainer.bg = bg;
    buttonContainer.interactive = true;
    buttonContainer.cursor = "pointer";

    // Event handlers
    buttonContainer.on("pointerdown", () => {
      this.selectCharacter(character);
    });

    buttonContainer.on("pointerover", () => {
      if (!isSelected) {
        bg.tint = 0xdddddd;
      }
    });

    buttonContainer.on("pointerout", () => {
      bg.tint = 0xffffff;
    });

    return buttonContainer;
  }

  selectCharacter(character) {
    console.log(`👤 Selected character: ${character.name}`);
    
    // Save current character's inventory state
    if (this.selectedCharacter && this.selectedCharacter.inventory) {
      this.saveCharacterInventory(this.selectedCharacter);
    }

    // Switch to new character
    this.selectedCharacter = character;
    
    // Load new character's inventory
    this.loadCharacterInventory(character);
    
    // Refresh all displays
    this.refreshAllDisplays();
  }

  // ============= INVENTORY MANAGEMENT =============

  loadCharacterInventory(character) {
    // Clear current character grid
    this.characterItems.forEach(item => this.removeSprite(item));
    this.characterItems = [];

    // Load character's inventory items
    if (character.inventory && character.inventory.items) {
      character.inventory.items.forEach(item => {
        if (item.isPlaced && item.isPlaced()) {
          // Create grid item for display
          const displayItem = this.createGridItem(item);
          this.placeInGrid(displayItem, item.gridX, item.gridY);
          this.addSprite(displayItem, "world");
        }
      });
    }

    console.log(`📦 Loaded inventory for ${character.name}: ${character.inventory?.items?.length || 0} items`);
  }

  saveCharacterInventory(character) {
    if (!character.inventory) {
      // Create inventory if it doesn't exist
      character.inventory = new Grid(0, 0, 10, 8, 40);
    }

    // Clear character's inventory
    character.inventory.clear();
    
    // Save current grid state to character's inventory
    this.characterItems.forEach(item => {
      if (item.isPlaced && item.isPlaced()) {
        const originalItem = this.createInventoryItem(item.originalData || item);
        character.inventory.placeItem(originalItem, item.gridX, item.gridY);
      }
    });

    console.log(`💾 Saved inventory for ${character.name}`);
  }

  createInventoryItem(itemData) {
    // Use the method from CharacterRoster if available
    const roster = this.engine.characterRoster;
    if (roster && roster.createInventoryItem) {
      return roster.createInventoryItem(itemData);
    }

    // Fallback item creation
    return {
      id: itemData.id || Math.random().toString(36).substr(2, 9),
      name: itemData.name,
      type: itemData.type,
      width: itemData.width || 1,
      height: itemData.height || 1,
      color: itemData.color || '#3498db',
      shape: itemData.shape || 'rectangle',
      baseSkills: itemData.baseSkills || [],
      enhancements: itemData.enhancements || [],
      gridX: -1,
      gridY: -1,
      dragging: false,
      isHighlighted: false,
      
      isPlaced: function() {
        return this.gridX >= 0 && this.gridY >= 0;
      },

      canPlaceAt: function(grid, x, y) {
        if (x < 0 || y < 0 || x + this.width > grid.cols || y + this.height > grid.rows) {
          return false;
        }

        for (let dy = 0; dy < this.height; dy++) {
          for (let dx = 0; dx < this.width; dx++) {
            const cell = grid.cells[y + dy][x + dx];
            if (cell !== null && cell !== this) {
              return false;
            }
          }
        }

        return true;
      }
    };
  }

  // ============= SKILLS SYSTEM =============

  generateSkillsForSelectedCharacter() {
    if (!this.selectedCharacter) {
      return [];
    }

    console.log(`⚔️ Generating skills for ${this.selectedCharacter.name}`);
    
    // Use the character's actual inventory for skill generation
    const characterInventory = this.selectedCharacter.inventory;
    if (!characterInventory || !characterInventory.generateSkills) {
      return this.getDefaultSkills();
    }

    return characterInventory.generateSkills();
  }

  getDefaultSkills() {
    return [
      {
        name: "Punch",
        description: "Basic unarmed attack",
        damage: 15,
        cost: 0,
        type: "physical",
        sourceItems: ["Bare Hands"],
        getSourceItemNames: () => "Bare Hands"
      }
    ];
  }

  refreshSkillsDisplay() {
    // Clear existing skills display
    if (this.skillsContainer) {
      this.skillsContainer.removeChildren();
    }

    const skills = this.generateSkillsForSelectedCharacter();
    
    if (skills.length === 0) {
      this.showNoSkillsMessage();
      return;
    }

    this.renderSkillsGrid(skills);
  }

  showNoSkillsMessage() {
    const message = new PIXI.Text(
      `${this.selectedCharacter?.name || "Character"} has no equipped items.\nPlace weapons and items in their inventory to generate skills.`,
      {
        fontFamily: "Arial",
        fontSize: 16,
        fill: 0x95a5a6,
        align: "center",
        lineHeight: 20,
      }
    );
    message.anchor.set(0.5);
    message.x = 550;
    message.y = 100;
    
    if (this.skillsContainer) {
      this.skillsContainer.addChild(message);
    }
  }

  renderSkillsGrid(skills) {
    const skillWidth = 250;
    const skillHeight = 70;
    const skillSpacing = 15;
    const skillsPerRow = 4;
    const startX = 20;
    const startY = 50;

    skills.forEach((skill, index) => {
      const col = index % skillsPerRow;
      const row = Math.floor(index / skillsPerRow);
      const x = startX + col * (skillWidth + skillSpacing);
      const y = startY + row * (skillHeight + skillSpacing);
      
      const skillCard = this.createSkillCard(skill, x, y, skillWidth, skillHeight);
      if (this.skillsContainer) {
        this.skillsContainer.addChild(skillCard);
      }
    });
  }

  createSkillCard(skill, x, y, width, height) {
    const card = new PIXI.Container();
    card.x = x;
    card.y = y;

    // Background with skill type color
    const bg = new PIXI.Graphics();
    const skillColor = this.getSkillTypeColor(skill.type);
    bg.beginFill(skillColor, 0.8);
    bg.drawRoundedRect(0, 0, width, height, 5);
    bg.endFill();
    bg.lineStyle(1, 0x2c3e50);
    bg.drawRoundedRect(0, 0, width, height, 5);
    card.addChild(bg);

    // Skill name
    const skillName = new PIXI.Text(skill.name, {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    skillName.x = 8;
    skillName.y = 8;
    card.addChild(skillName);

    // Skill stats
    const skillStats = new PIXI.Text(
      `Damage: ${skill.damage} | Cost: ${skill.cost} MP | Type: ${skill.type}`,
      {
        fontFamily: "Arial",
        fontSize: 11,
        fill: 0xffffff,
      }
    );
    skillStats.x = 8;
    skillStats.y = 28;
    card.addChild(skillStats);

    // Source items
    const sourceText = new PIXI.Text(
      `From: ${skill.getSourceItemNames ? skill.getSourceItemNames() : (skill.sourceItems ? skill.sourceItems.join(", ") : "Unknown")}`,
      {
        fontFamily: "Arial",
        fontSize: 9,
        fill: 0xecf0f1,
        wordWrap: true,
        wordWrapWidth: width - 16,
      }
    );
    sourceText.x = 8;
    sourceText.y = 48;
    card.addChild(sourceText);

    return card;
  }

  getSkillTypeColor(type) {
    const colors = {
      physical: 0xe74c3c,
      magic: 0x9b59b6,
      ranged: 0x16a085,
      defensive: 0x34495e,
      healing: 0x27ae60
    };
    return colors[type] || 0x7f8c8d;
  }

  // ============= NAVIGATION =============

  createSquadNavigationButtons() {
    const buttons = [
      { text: "🏠 Menu", action: () => this.engine.switchScene("menu"), color: 0x95a5a6 },
      { text: "🎭 Squad", action: () => this.engine.switchScene("squad"), color: 0xf39c12 },
      { text: "🌍 World", action: () => this.engine.switchScene("world"), color: 0x27ae60 },
      { text: "⚔️ Battle", action: () => this.engine.switchScene("battle"), color: 0xe74c3c },
    ];

    buttons.forEach((btnData, index) => {
      const button = this.createSquadButton(
        btnData.text,
        50 + index * 140,
        this.engine.height - 60,
        120,
        35,
        btnData.color,
        btnData.action
      );
      this.navButtons.push(button);
    });
  }

  createSquadButton(text, x, y, width, height, color, onClick) {
    const button = new PIXI.Container();

    const bg = new PIXI.Graphics();
    bg.beginFill(color);
    bg.drawRoundedRect(0, 0, width, height, 5);
    bg.endFill();
    bg.lineStyle(1, 0xffffff);
    bg.drawRoundedRect(0, 0, width, height, 5);
    button.addChild(bg);

    const buttonText = new PIXI.Text(text, {
      fontFamily: "Arial",
      fontSize: 12,
      fill: 0xffffff,
      fontWeight: "bold",
      align: "center",
    });
    buttonText.anchor.set(0.5);
    buttonText.x = width / 2;
    buttonText.y = height / 2;
    button.addChild(buttonText);

    button.x = x;
    button.y = y;
    button.interactive = true;
    button.cursor = "pointer";

    button.on("pointerover", () => {
      bg.tint = 0xcccccc;
    });

    button.on("pointerout", () => {
      bg.tint = 0xffffff;
    });

    button.on("pointerdown", onClick);

    this.addSprite(button, "ui");
    return button;
  }

  // ============= DISPLAY UPDATES =============

  refreshAllDisplays() {
    // Update character selector buttons
    this.refreshCharacterButtons();
    
    // Update skills title with character name
    if (this.skillsTitle && this.selectedCharacter) {
      this.skillsTitle.text = `⚔️ ${this.selectedCharacter.name}'s Skills`;
    }

    // Update character grid label
    if (this.characterGridLabel && this.selectedCharacter) {
      this.characterGridLabel.text = `${this.selectedCharacter.name}'s Equipment (${this.selectedCharacter.class})`;
    }
    
    // Refresh skills display
    this.refreshSkillsDisplay();
    
    console.log(`🔄 Refreshed displays for ${this.selectedCharacter?.name || "No Character"}`);
  }

  // ============= INPUT HANDLING =============

  update(deltaTime) {
    super.update(deltaTime);
    
    // Handle input for character switching
    const input = this.engine.inputManager;
    
    if (input.isKeyPressed("Digit1")) {
      this.selectCharacterByIndex(0);
    } else if (input.isKeyPressed("Digit2")) {
      this.selectCharacterByIndex(1);
    } else if (input.isKeyPressed("Digit3")) {
      this.selectCharacterByIndex(2);
    }
  }

  selectCharacterByIndex(index) {
    const roster = this.engine.characterRoster;
    if (!roster) return;
    
    const squad = roster.getActiveSquad();
    if (index < squad.length) {
      this.selectCharacter(squad[index]);
    }
  }

  handleKeyDown(event) {
    super.handleKeyDown(event);
    
    switch (event.code) {
      case "KeyQ":
        this.selectCharacterByIndex(0);
        break;
      case "KeyW":
        this.selectCharacterByIndex(1);
        break;
      case "KeyE":
        this.selectCharacterByIndex(2);
        break;
      case "Tab":
        event.preventDefault();
        this.cycleToNextCharacter();
        break;
    }
  }

  cycleToNextCharacter() {
    const roster = this.engine.characterRoster;
    if (!roster) return;
    
    const squad = roster.getActiveSquad();
    if (squad.length <= 1) return;
    
    const currentIndex = squad.indexOf(this.selectedCharacter);
    const nextIndex = (currentIndex + 1) % squad.length;
    this.selectCharacter(squad[nextIndex]);
  }

  // ============= OVERRIDE DRAG AND DROP =============

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
      
      // Save to character's inventory
      if (this.selectedCharacter) {
        this.saveCharacterInventory(this.selectedCharacter);
      }
    } else if (this.isOverStorageArea(mouseX, mouseY)) {
      // Drop in storage
      if (this.dragSource === "grid") {
        // Move from grid to storage
        this.addToStorage(item.originalData);
        this.removeFromGrid(item);
        
        // Save character's inventory
        if (this.selectedCharacter) {
          this.saveCharacterInventory(this.selectedCharacter);
        }
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
    
    // Refresh skills after inventory changes
    this.refreshSkillsDisplay();
  }

  // ============= CLEANUP =============

  onExit() {
    // Save current character's inventory before leaving
    if (this.selectedCharacter && this.selectedCharacter.inventory) {
      this.saveCharacterInventory(this.selectedCharacter);
    }

    super.onExit();
  }
}