import { PixiScene } from "../core/PixiScene.js";

export class PixiSquadScene extends PixiScene {
  constructor() {
    super();
    
    // Squad management state
    this.selectedCharacter = null;
    this.hoveredCharacter = null;
    this.characterCards = [];
    this.squadSlots = [];
    this.actionButtons = [];
    
    // UI Areas
    this.rosterArea = { x: 50, y: 120, width: 500, height: 500 };
    this.squadArea = { x: 600, y: 120, width: 550, height: 300 };
    this.detailsArea = { x: 600, y: 450, width: 550, height: 250 };
    this.creationArea = { x: 50, y: 650, width: 1100, height: 120 };
    
    // Character creation
    this.showCreationPanel = false;
    this.selectedTemplate = null;
    this.customNameInput = "";
  }

  onEnter() {
    super.onEnter();
    
    this.createBackground();
    this.createSquadInterface();
    this.refreshDisplay();
    
    // Update game mode display
    const gameModeBtn = document.getElementById("gameMode");
    if (gameModeBtn) {
      gameModeBtn.textContent = "🎭 SQUAD";
    }

    // Update navigation buttons
    if (this.engine && this.engine.updateNavButtons) {
      this.engine.updateNavButtons("squad");
    }

    console.log("🎭 Squad management scene loaded");
  }

  createBackground() {
    // Main background
    const bg = new PIXI.Graphics();
    bg.beginFill(0x2c3e50);
    bg.drawRect(0, 0, this.engine.width, this.engine.height);
    bg.endFill();
    this.addGraphics(bg, "background");

    // Title
    const title = new PIXI.Text("🎭 SQUAD MANAGEMENT", {
      fontFamily: "Arial",
      fontSize: 32,
      fill: 0xffffff,
      align: "center",
      fontWeight: "bold",
    });
    title.anchor.set(0.5);
    title.x = this.engine.width / 2;
    title.y = 40;
    this.addSprite(title, "ui");

    // Subtitle
    const subtitle = new PIXI.Text("Manage your party • Select up to 3 characters for battle", {
      fontFamily: "Arial",
      fontSize: 16,
      fill: 0xbdc3c7,
      align: "center",
    });
    subtitle.anchor.set(0.5);
    subtitle.x = this.engine.width / 2;
    subtitle.y = 75;
    this.addSprite(subtitle, "ui");
  }

  createSquadInterface() {
    this.createRosterArea();
    this.createSquadArea();
    this.createDetailsArea();
    this.createActionButtons();
    this.createCharacterCreationArea();
  }

  createRosterArea() {
    const area = this.rosterArea;
    
    // Background panel
    const panel = new PIXI.Graphics();
    panel.beginFill(0x34495e, 0.9);
    panel.drawRoundedRect(0, 0, area.width, area.height, 10);
    panel.endFill();
    panel.lineStyle(2, 0x7f8c8d);
    panel.drawRoundedRect(0, 0, area.width, area.height, 10);
    panel.x = area.x;
    panel.y = area.y;
    this.addGraphics(panel, "ui");

    // Title
    const title = new PIXI.Text("📋 Available Characters", {
      fontFamily: "Arial",
      fontSize: 18,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    title.x = area.x + 15;
    title.y = area.y + 15;
    this.addSprite(title, "ui");

    // Scrollable area marker (for future scrolling implementation)
    this.rosterScrollArea = {
      x: area.x + 10,
      y: area.y + 50,
      width: area.width - 20,
      height: area.height - 60
    };
  }

  createSquadArea() {
    const area = this.squadArea;
    
    // Background panel
    const panel = new PIXI.Graphics();
    panel.beginFill(0x27ae60, 0.9);
    panel.drawRoundedRect(0, 0, area.width, area.height, 10);
    panel.endFill();
    panel.lineStyle(2, 0x2ecc71);
    panel.drawRoundedRect(0, 0, area.width, area.height, 10);
    panel.x = area.x;
    panel.y = area.y;
    this.addGraphics(panel, "ui");

    // Title
    const title = new PIXI.Text("⚔️ Active Squad", {
      fontFamily: "Arial",
      fontSize: 18,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    title.x = area.x + 15;
    title.y = area.y + 15;
    this.addSprite(title, "ui");

    // Squad size indicator
    this.squadSizeText = new PIXI.Text("", {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xecf0f1,
    });
    this.squadSizeText.x = area.x + area.width - 100;
    this.squadSizeText.y = area.y + 20;
    this.addSprite(this.squadSizeText, "ui");

    // Create squad slots
    this.createSquadSlots();
  }

  createSquadSlots() {
    const area = this.squadArea;
    const slotWidth = 160;
    const slotHeight = 200;
    const slotSpacing = 20;
    const startX = area.x + 20;
    const startY = area.y + 50;

    for (let i = 0; i < 3; i++) {
      const slot = new PIXI.Container();
      
      // Slot background
      const bg = new PIXI.Graphics();
      bg.beginFill(0x2c3e50, 0.5);
      bg.drawRoundedRect(0, 0, slotWidth, slotHeight, 8);
      bg.endFill();
      bg.lineStyle(2, 0x95a5a6, 0.5);
      bg.drawRoundedRect(0, 0, slotWidth, slotHeight, 8);
      slot.addChild(bg);

      // Slot number
      const slotNumber = new PIXI.Text(`${i + 1}`, {
        fontFamily: "Arial",
        fontSize: 24,
        fill: 0x95a5a6,
        fontWeight: "bold",
        align: "center",
      });
      slotNumber.anchor.set(0.5);
      slotNumber.x = slotWidth / 2;
      slotNumber.y = slotHeight / 2;
      slot.addChild(slotNumber);

      // Empty slot text
      const emptyText = new PIXI.Text("Empty Slot\nClick to assign", {
        fontFamily: "Arial",
        fontSize: 12,
        fill: 0x95a5a6,
        align: "center",
        lineHeight: 16,
      });
      emptyText.anchor.set(0.5);
      emptyText.x = slotWidth / 2;
      emptyText.y = slotHeight / 2 + 30;
      slot.addChild(emptyText);

      slot.x = startX + i * (slotWidth + slotSpacing);
      slot.y = startY;
      slot.slotIndex = i;
      slot.isEmpty = true;
      slot.characterData = null;
      slot.bg = bg;
      slot.slotNumber = slotNumber;
      slot.emptyText = emptyText;

      // Make interactive
      slot.interactive = true;
      slot.cursor = "pointer";
      slot.on("pointerdown", () => this.handleSquadSlotClick(slot));
      slot.on("pointerover", () => this.handleSquadSlotHover(slot, true));
      slot.on("pointerout", () => this.handleSquadSlotHover(slot, false));

      this.squadSlots.push(slot);
      this.addSprite(slot, "ui");
    }
  }

  createDetailsArea() {
    const area = this.detailsArea;
    
    // Background panel
    const panel = new PIXI.Graphics();
    panel.beginFill(0x8e44ad, 0.9);
    panel.drawRoundedRect(0, 0, area.width, area.height, 10);
    panel.endFill();
    panel.lineStyle(2, 0x9b59b6);
    panel.drawRoundedRect(0, 0, area.width, area.height, 10);
    panel.x = area.x;
    panel.y = area.y;
    this.addGraphics(panel, "ui");

    // Title
    const title = new PIXI.Text("📊 Character Details", {
      fontFamily: "Arial",
      fontSize: 18,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    title.x = area.x + 15;
    title.y = area.y + 15;
    this.addSprite(title, "ui");

    // Details container
    this.detailsContainer = new PIXI.Container();
    this.detailsContainer.x = area.x + 20;
    this.detailsContainer.y = area.y + 50;
    this.addSprite(this.detailsContainer, "ui");

    // Default no selection text
    this.showNoSelectionMessage();
  }

  createActionButtons() {
    const buttons = [
      { text: "🏠 Menu", action: () => this.engine.switchScene("menu"), color: 0x95a5a6 },
      { text: "🎒 Inventory", action: () => this.engine.switchScene("inventory"), color: 0x3498db },
      { text: "🌍 World", action: () => this.engine.switchScene("world"), color: 0x27ae60 },
      { text: "⚔️ Battle", action: () => this.engine.switchScene("battle"), color: 0xe74c3c },
    ];

    buttons.forEach((btnData, index) => {
      const button = this.createButton(
        btnData.text,
        50 + index * 140,
        this.engine.height - 60,
        120,
        35,
        btnData.color,
        btnData.action
      );
      this.actionButtons.push(button);
    });
  }

  createCharacterCreationArea() {
    const area = this.creationArea;
    
    // Background panel
    const panel = new PIXI.Graphics();
    panel.beginFill(0x34495e, 0.9);
    panel.drawRoundedRect(0, 0, area.width, area.height, 10);
    panel.endFill();
    panel.lineStyle(2, 0x7f8c8d);
    panel.drawRoundedRect(0, 0, area.width, area.height, 10);
    panel.x = area.x;
    panel.y = area.y;
    this.addGraphics(panel, "ui");

    // Title
    const title = new PIXI.Text("✨ Create New Character", {
      fontFamily: "Arial",
      fontSize: 18,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    title.x = area.x + 15;
    title.y = area.y + 15;
    this.addSprite(title, "ui");

    // Create class selection buttons
    this.createClassButtons();
  }

  createClassButtons() {
    const area = this.creationArea;
    const roster = this.engine.characterRoster;
    
    if (!roster) {
      console.warn("⚠️ Character roster not found");
      return;
    }

    const templates = roster.getCharacterTemplates();
    const buttonWidth = 150;
    const buttonHeight = 60;
    const startX = area.x + 20;
    const startY = area.y + 45;

    templates.forEach((template, index) => {
      const col = index % 6;
      const button = new PIXI.Container();

      // Button background
      const bg = new PIXI.Graphics();
      bg.beginFill(template.primaryColor, 0.8);
      bg.drawRoundedRect(0, 0, buttonWidth, buttonHeight, 5);
      bg.endFill();
      bg.lineStyle(2, 0xffffff, 0.8);
      bg.drawRoundedRect(0, 0, buttonWidth, buttonHeight, 5);
      button.addChild(bg);

      // Class portrait
      const portrait = new PIXI.Text(template.portrait, {
        fontFamily: "Arial",
        fontSize: 24,
        fill: 0xffffff,
      });
      portrait.x = 10;
      portrait.y = 8;
      button.addChild(portrait);

      // Class name
      const className = new PIXI.Text(template.name, {
        fontFamily: "Arial",
        fontSize: 14,
        fill: 0xffffff,
        fontWeight: "bold",
      });
      className.x = 45;
      className.y = 12;
      button.addChild(className);

      // Class description
      const description = new PIXI.Text(template.description.substring(0, 30) + "...", {
        fontFamily: "Arial",
        fontSize: 10,
        fill: 0xecf0f1,
        wordWrap: true,
        wordWrapWidth: buttonWidth - 50,
      });
      description.x = 45;
      description.y = 30;
      button.addChild(description);

      button.x = startX + col * (buttonWidth + 10);
      button.y = startY;
      button.templateKey = template.key;
      button.template = template;
      button.bg = bg;

      // Make interactive
      button.interactive = true;
      button.cursor = "pointer";
      button.on("pointerdown", () => this.handleClassSelection(template.key));
      button.on("pointerover", () => {
        bg.tint = 0xcccccc;
      });
      button.on("pointerout", () => {
        bg.tint = 0xffffff;
      });

      this.addSprite(button, "ui");
    });
  }

  // ============= CHARACTER DISPLAY =============

  refreshDisplay() {
    this.refreshRosterDisplay();
    this.refreshSquadDisplay();
    this.updateSquadSizeDisplay();
  }

  refreshRosterDisplay() {
    // Clear existing character cards
    this.characterCards.forEach(card => this.removeSprite(card));
    this.characterCards = [];

    const roster = this.engine.characterRoster;
    if (!roster) return;

    const characters = roster.getAvailableCharacters();
    const area = this.rosterScrollArea;
    const cardWidth = 220;
    const cardHeight = 80;
    const cardsPerRow = 2;
    const cardSpacing = 10;

    characters.forEach((character, index) => {
      const row = Math.floor(index / cardsPerRow);
      const col = index % cardsPerRow;
      
      const card = this.createCharacterCard(character);
      card.x = area.x + col * (cardWidth + cardSpacing);
      card.y = area.y + row * (cardHeight + cardSpacing);
      
      this.characterCards.push(card);
      this.addSprite(card, "ui");
    });
  }

  createCharacterCard(character) {
    const card = new PIXI.Container();
    const cardWidth = 220;
    const cardHeight = 80;

    // Background
    const bg = new PIXI.Graphics();
    bg.beginFill(character.primaryColor || 0x3498db, 0.3);
    bg.drawRoundedRect(0, 0, cardWidth, cardHeight, 8);
    bg.endFill();
    bg.lineStyle(2, character.primaryColor || 0x3498db, 0.8);
    bg.drawRoundedRect(0, 0, cardWidth, cardHeight, 8);
    card.addChild(bg);

    // Portrait
    const portrait = new PIXI.Text(character.portrait || "👤", {
      fontFamily: "Arial",
      fontSize: 32,
      fill: 0xffffff,
    });
    portrait.x = 10;
    portrait.y = 15;
    card.addChild(portrait);

    // Character info
    const nameText = new PIXI.Text(character.name, {
      fontFamily: "Arial",
      fontSize: 16,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    nameText.x = 55;
    nameText.y = 8;
    card.addChild(nameText);

    const classText = new PIXI.Text(`${character.class} • Lv.${character.level}`, {
      fontFamily: "Arial",
      fontSize: 12,
      fill: 0xecf0f1,
    });
    classText.x = 55;
    classText.y = 28;
    card.addChild(classText);

    const hpText = new PIXI.Text(`HP: ${character.hp}/${character.maxHp}`, {
      fontFamily: "Arial",
      fontSize: 10,
      fill: 0xbdc3c7,
    });
    hpText.x = 55;
    hpText.y = 45;
    card.addChild(hpText);

    const mpText = new PIXI.Text(`MP: ${character.mp}/${character.maxMp}`, {
      fontFamily: "Arial",
      fontSize: 10,
      fill: 0xbdc3c7,
    });
    mpText.x = 55;
    mpText.y = 58;
    card.addChild(mpText);

    // Squad indicator
    const roster = this.engine.characterRoster;
    if (roster && roster.isInSquad(character.id)) {
      const squadIndicator = new PIXI.Text("🗡️", {
        fontFamily: "Arial",
        fontSize: 16,
        fill: 0xf39c12,
      });
      squadIndicator.x = cardWidth - 25;
      squadIndicator.y = 10;
      card.addChild(squadIndicator);
    }

    // Store character reference
    card.characterData = character;
    card.bg = bg;

    // Make interactive
    card.interactive = true;
    card.cursor = "pointer";
    card.on("pointerdown", () => this.selectCharacter(character));
    card.on("pointerover", () => {
      bg.tint = 0xdddddd;
      this.hoveredCharacter = character;
    });
    card.on("pointerout", () => {
      bg.tint = 0xffffff;
      this.hoveredCharacter = null;
    });

    return card;
  }

  refreshSquadDisplay() {
    const roster = this.engine.characterRoster;
    if (!roster) return;

    const squad = roster.getActiveSquad();

    // Update each squad slot
    this.squadSlots.forEach((slot, index) => {
      this.clearSquadSlot(slot);
      
      if (index < squad.length) {
        this.fillSquadSlot(slot, squad[index]);
      }
    });
  }

  clearSquadSlot(slot) {
    // Remove character-specific children
    while (slot.children.length > 3) {
      slot.removeChildAt(3);
    }

    // Reset slot appearance
    slot.bg.clear();
    slot.bg.beginFill(0x2c3e50, 0.5);
    slot.bg.drawRoundedRect(0, 0, 160, 200, 8);
    slot.bg.endFill();
    slot.bg.lineStyle(2, 0x95a5a6, 0.5);
    slot.bg.drawRoundedRect(0, 0, 160, 200, 8);

    slot.slotNumber.visible = true;
    slot.emptyText.visible = true;
    slot.isEmpty = true;
    slot.characterData = null;
  }

  fillSquadSlot(slot, character) {
    slot.isEmpty = false;
    slot.characterData = character;
    slot.slotNumber.visible = false;
    slot.emptyText.visible = false;

    // Update background color
    slot.bg.clear();
    slot.bg.beginFill(character.primaryColor || 0x3498db, 0.8);
    slot.bg.drawRoundedRect(0, 0, 160, 200, 8);
    slot.bg.endFill();
    slot.bg.lineStyle(2, 0xffffff);
    slot.bg.drawRoundedRect(0, 0, 160, 200, 8);

    // Character portrait
    const portrait = new PIXI.Text(character.portrait || "👤", {
      fontFamily: "Arial",
      fontSize: 48,
      fill: 0xffffff,
    });
    portrait.anchor.set(0.5);
    portrait.x = 80;
    portrait.y = 40;
    slot.addChild(portrait);

    // Character name
    const nameText = new PIXI.Text(character.name, {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
      align: "center",
      wordWrap: true,
      wordWrapWidth: 140,
    });
    nameText.anchor.set(0.5);
    nameText.x = 80;
    nameText.y = 90;
    slot.addChild(nameText);

    // Character class and level
    const classText = new PIXI.Text(`${character.class}\nLevel ${character.level}`, {
      fontFamily: "Arial",
      fontSize: 12,
      fill: 0xecf0f1,
      align: "center",
      lineHeight: 14,
    });
    classText.anchor.set(0.5);
    classText.x = 80;
    classText.y = 120;
    slot.addChild(classText);

    // Stats
    const statsText = new PIXI.Text(
      `HP: ${character.hp}/${character.maxHp}\nMP: ${character.mp}/${character.maxMp}\nATK: ${character.getAttack()} DEF: ${character.getDefense()}`,
      {
        fontFamily: "Arial",
        fontSize: 10,
        fill: 0xbdc3c7,
        align: "center",
        lineHeight: 12,
      }
    );
    statsText.anchor.set(0.5);
    statsText.x = 80;
    statsText.y = 160;
    slot.addChild(statsText);

    // Remove button
    const removeBtn = new PIXI.Graphics();
    removeBtn.beginFill(0xe74c3c, 0.8);
    removeBtn.drawCircle(0, 0, 12);
    removeBtn.endFill();
    removeBtn.x = 140;
    removeBtn.y = 20;
    removeBtn.interactive = true;
    removeBtn.cursor = "pointer";
    removeBtn.on("pointerdown", (event) => {
      event.stopPropagation();
      this.removeFromSquad(character);
    });

    const removeText = new PIXI.Text("×", {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    removeText.anchor.set(0.5);
    removeText.x = 140;
    removeText.y = 20;
    slot.addChild(removeBtn);
    slot.addChild(removeText);
  }

  updateSquadSizeDisplay() {
    const roster = this.engine.characterRoster;
    if (!roster || !this.squadSizeText) return;

    const squadSize = roster.getSquadSize();
    const maxSize = roster.maxSquadSize;
    this.squadSizeText.text = `${squadSize}/${maxSize}`;
  }

  // ============= INTERACTION HANDLERS =============

  selectCharacter(character) {
    console.log(`👤 Selected character: ${character.name}`);
    this.selectedCharacter = character;
    this.showCharacterDetails(character);
  }

  showCharacterDetails(character) {
    // Clear previous details
    this.detailsContainer.removeChildren();

    if (!character) {
      this.showNoSelectionMessage();
      return;
    }

    // Character portrait and basic info
    const portrait = new PIXI.Text(character.portrait || "👤", {
      fontFamily: "Arial",
      fontSize: 64,
      fill: 0xffffff,
    });
    portrait.x = 20;
    portrait.y = 10;
    this.detailsContainer.addChild(portrait);

    const nameText = new PIXI.Text(character.name, {
      fontFamily: "Arial",
      fontSize: 24,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    nameText.x = 100;
    nameText.y = 20;
    this.detailsContainer.addChild(nameText);

    const classText = new PIXI.Text(`${character.class} • Level ${character.level}`, {
      fontFamily: "Arial",
      fontSize: 16,
      fill: 0xecf0f1,
    });
    classText.x = 100;
    classText.y = 50;
    this.detailsContainer.addChild(classText);

    // Experience bar
    const expPercent = character.experienceToNext > 0 ? character.experience / character.experienceToNext : 0;
    const expBarBg = new PIXI.Graphics();
    expBarBg.beginFill(0x34495e);
    expBarBg.drawRect(0, 0, 200, 8);
    expBarBg.endFill();
    expBarBg.x = 100;
    expBarBg.y = 75;
    this.detailsContainer.addChild(expBarBg);

    const expBarFill = new PIXI.Graphics();
    expBarFill.beginFill(0xf39c12);
    expBarFill.drawRect(0, 0, 200 * expPercent, 8);
    expBarFill.endFill();
    expBarFill.x = 100;
    expBarFill.y = 75;
    this.detailsContainer.addChild(expBarFill);

    const expText = new PIXI.Text(`EXP: ${character.experience}/${character.experienceToNext}`, {
      fontFamily: "Arial",
      fontSize: 10,
      fill: 0xbdc3c7,
    });
    expText.x = 100;
    expText.y = 88;
    this.detailsContainer.addChild(expText);

    // Stats
    const statsText = new PIXI.Text(
      `Health: ${character.hp}/${character.maxHp}\n` +
      `Mana: ${character.mp}/${character.maxMp}\n` +
      `Attack: ${character.getAttack()}\n` +
      `Defense: ${character.getDefense()}\n` +
      `Speed: ${character.getSpeed()}`,
      {
        fontFamily: "Arial",
        fontSize: 14,
        fill: 0xffffff,
        lineHeight: 18,
      }
    );
    statsText.x = 300;
    statsText.y = 20;
    this.detailsContainer.addChild(statsText);

    // Action buttons
    this.createCharacterActionButtons(character);
  }

  createCharacterActionButtons(character) {
    const roster = this.engine.characterRoster;
    if (!roster) return;

    const buttonY = 140;
    const isInSquad = roster.isInSquad(character.id);

    if (!isInSquad && roster.hasRoom()) {
      // Add to squad button
      const addBtn = this.createButton(
        "Add to Squad",
        20, buttonY, 120, 30,
        0x27ae60,
        () => this.addToSquad(character)
      );
      this.detailsContainer.addChild(addBtn);
    }

    if (isInSquad) {
      // Remove from squad button
      const removeBtn = this.createButton(
        "Remove from Squad",
        20, buttonY, 150, 30,
        0xe74c3c,
        () => this.removeFromSquad(character)
      );
      this.detailsContainer.addChild(removeBtn);
    }

    // View inventory button
    const inventoryBtn = this.createButton(
      "View Inventory",
      isInSquad ? 180 : 150, buttonY, 130, 30,
      0x3498db,
      () => this.viewCharacterInventory(character)
    );
    this.detailsContainer.addChild(inventoryBtn);

    // Delete character button
    const deleteBtn = this.createButton(
      "Delete",
      isInSquad ? 320 : 290, buttonY, 80, 30,
      0x95a5a6,
      () => this.deleteCharacter(character)
    );
    this.detailsContainer.addChild(deleteBtn);
  }

  showNoSelectionMessage() {
    const message = new PIXI.Text("Select a character to view details", {
      fontFamily: "Arial",
      fontSize: 16,
      fill: 0x95a5a6,
      align: "center",
    });
    message.anchor.set(0.5);
    message.x = 275;
    message.y = 100;
    this.detailsContainer.addChild(message);
  }

  handleSquadSlotClick(slot) {
    if (slot.isEmpty) {
      // Empty slot - assign selected character
      if (this.selectedCharacter) {
        this.addToSquad(this.selectedCharacter);
      }
    } else {
      // Occupied slot - select the character
      this.selectCharacter(slot.characterData);
    }
  }

  handleSquadSlotHover(slot, isHovering) {
    if (isHovering) {
      slot.bg.tint = 0xdddddd;
    } else {
      slot.bg.tint = 0xffffff;
    }
  }

  handleClassSelection(templateKey) {
    console.log(`✨ Creating new ${templateKey} character`);
    
    const roster = this.engine.characterRoster;
    if (!roster) return;

    const newCharacter = roster.createCharacter(templateKey);
    if (newCharacter) {
      this.refreshDisplay();
      this.selectCharacter(newCharacter);
    }
  }

  // ============= SQUAD OPERATIONS =============

  addToSquad(character) {
    const roster = this.engine.characterRoster;
    if (!roster) return;

    const success = roster.addToSquad(character.id);
    if (success) {
      this.refreshDisplay();
      this.showCharacterDetails(character);
    }
  }

  removeFromSquad(character) {
    const roster = this.engine.characterRoster;
    if (!roster) return;

    const success = roster.removeFromSquad(character.id);
    if (success) {
      this.refreshDisplay();
      this.showCharacterDetails(character);
    }
  }

  deleteCharacter(character) {
    // Simple confirmation (in a real game, you'd want a proper dialog)
    const confirmed = confirm(`Are you sure you want to delete ${character.name}?`);
    if (!confirmed) return;

    const roster = this.engine.characterRoster;
    if (!roster) return;

    const success = roster.removeCharacter(character.id);
    if (success) {
      this.selectedCharacter = null;
      this.refreshDisplay();
      this.showNoSelectionMessage();
    }
  }

  viewCharacterInventory(character) {
    // TODO: Switch to inventory scene with this character's inventory
    console.log(`👜 Viewing inventory for ${character.name}`);
    // For now, just switch to inventory scene
    this.engine.switchScene("inventory");
  }

  // ============= UTILITY METHODS =============

  createButton(text, x, y, width, height, color, onClick) {
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

    return button;
  }

  // ============= INPUT HANDLING =============

  handleKeyDown(event) {
    switch (event.code) {
      case "Escape":
        this.engine.switchScene("menu");
        break;
      case "KeyI":
        this.engine.switchScene("inventory");
        break;
      case "KeyW":
        this.engine.switchScene("world");
        break;
      case "KeyB":
        this.engine.switchScene("battle");
        break;
      case "F1":
        // Debug roster state
        if (this.engine.characterRoster) {
          this.engine.characterRoster.debugRosterState();
        }
        break;
    }
  }

  update(deltaTime) {
    super.update(deltaTime);
    // Add any continuous updates here if needed
  }

  onExit() {
    // Cleanup when leaving scene
    this.selectedCharacter = null;
    this.hoveredCharacter = null;
    super.onExit();
  }
}