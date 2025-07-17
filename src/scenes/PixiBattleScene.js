import { PixiScene } from "../core/PixiScene.js";
import { SkillGenerator } from "../core/SkillGenerator.js";

export class PixiBattleScene extends PixiScene {
  constructor() {
    super();
    this.player = null;
    this.enemies = [];
    this.currentTurn = "player";
    this.selectedSkill = null;
    this.selectedTarget = null;
    this.battleLog = [];
    this.logMaxLines = 12;
    this.turnOrder = [];
    this.currentTurnIndex = 0;
    this.battleState = "selecting"; // selecting, animating, victory, defeat
    this.animationQueue = [];
    this.battleUI = {};
    this.buttons = [];
    this.hoveredButton = -1;

    // Battle stats
    this.battleStats = {
      turnCount: 0,
      damageDealt: 0,
      skillsUsed: 0,
    };

    // Responsive design properties
    this.layout = {
      isPortrait: false,
      isMobile: false,
      scale: 1,
      padding: 20,
    };

    // Layout breakpoints
    this.breakpoints = {
      mobile: 768,
      tablet: 1024,
      desktop: 1200,
    };
  }

  onEnter() {
    super.onEnter();

    // Calculate responsive layout
    this.calculateLayout();

    // Initialize battle
    this.initializeBattle();

    // Create battle UI
    this.createBattleBackground();
    this.createBattleUI();

    // Update game mode display
    const gameModeBtn = document.getElementById("gameMode");
    if (gameModeBtn) {
      gameModeBtn.textContent = "⚔️ BATTLE";
    }

    // Update navigation buttons
    if (this.engine && this.engine.updateNavButtons) {
      this.engine.updateNavButtons("battle");
    }

    // Handle window resize
    window.addEventListener("resize", () => this.handleResize());

    console.log("Battle scene loaded with responsive PixiJS interface");
  }

  onExit() {
    // Clean up resize handler
    window.removeEventListener("resize", this.handleResize);

    // Clean up animations
    this.animationQueue = [];
    this.battleState = "selecting";
    this.selectedSkill = null;
    this.selectedTarget = null;

    super.onExit();
  }

  calculateLayout() {
    const width = this.engine.width;
    const height = this.engine.height;
    
    // Determine device type and orientation
    this.layout.isPortrait = height > width;
    this.layout.isMobile = width < this.breakpoints.mobile;
    this.layout.isTablet = width >= this.breakpoints.mobile && width < this.breakpoints.desktop;
    this.layout.isDesktop = width >= this.breakpoints.desktop;
    
    // Calculate scaling factor
    this.layout.scale = Math.min(width / 1200, height / 800);
    this.layout.scale = Math.max(0.5, Math.min(1.5, this.layout.scale));
    
    // Adjust padding based on screen size
    this.layout.padding = this.layout.isMobile ? 10 : 20;
    
    // Calculate responsive dimensions
    this.layout.dimensions = {
      // Character display areas
      playerArea: {
        width: this.layout.isMobile ? width * 0.45 : Math.min(300, width * 0.25),
        height: this.layout.isMobile ? height * 0.2 : Math.min(180, height * 0.22),
        x: this.layout.padding,
        y: this.layout.isMobile ? height * 0.1 : height * 0.12,
      },
      
      // Enemy area calculations
      enemyArea: {
        width: this.layout.isMobile ? width * 0.45 : Math.min(280, width * 0.23),
        height: this.layout.isMobile ? height * 0.18 : Math.min(160, height * 0.2),
        spacing: this.layout.isMobile ? 15 : 25,
      },
      
      // Skills panel
      skillsPanel: {
        width: this.layout.isPortrait ? width * 0.9 : Math.min(450, width * 0.35),
        height: this.layout.isPortrait ? height * 0.25 : Math.min(300, height * 0.4),
        x: this.layout.padding,
        y: this.layout.isPortrait ? height * 0.45 : height * 0.5,
      },
      
      // Battle log
      battleLog: {
        width: this.layout.isPortrait ? width * 0.9 : Math.min(550, width * 0.42),
        height: this.layout.isPortrait ? height * 0.2 : Math.min(250, height * 0.35),
        x: this.layout.isPortrait ? this.layout.padding : width * 0.55,
        y: this.layout.isPortrait ? height * 0.72 : height * 0.5,
      },
      
      // Turn indicator
      turnIndicator: {
        width: Math.min(250, width * 0.4),
        height: Math.min(40, height * 0.06),
        x: width / 2,
        y: Math.max(30, height * 0.05),
      },
      
      // Action buttons
      actionButtons: {
        width: Math.min(130, width * 0.15),
        height: Math.min(40, height * 0.05),
        spacing: this.layout.isMobile ? 10 : 15,
        y: height - Math.max(60, height * 0.08),
      },
    };
    
    // Font scaling
    this.layout.fonts = {
      title: Math.max(16, Math.min(32, 32 * this.layout.scale)),
      subtitle: Math.max(12, Math.min(18, 18 * this.layout.scale)),
      body: Math.max(10, Math.min(14, 14 * this.layout.scale)),
      small: Math.max(8, Math.min(12, 12 * this.layout.scale)),
      button: Math.max(10, Math.min(14, 14 * this.layout.scale)),
    };

    console.log("Layout calculated:", this.layout);
  }

  handleResize() {
    if (!this.isActive) return;
    
    // Recalculate layout
    this.calculateLayout();
    
    // Clear and recreate UI
    this.clearUI();
    this.createBattleUI();
    
    console.log("Battle scene resized and updated");
  }

  clearUI() {
    // Remove all UI elements
    this.layers.ui.removeChildren();
    this.layers.effects.removeChildren();
    this.battleUI = {};
    this.buttons = [];
  }

  initializeBattle() {
    // Get inventory from inventory scene
    const inventoryScene = this.engine.scenes.get("inventory");
    let playerSkills = [];

    if (inventoryScene && inventoryScene.inventoryGrid) {
      // Generate skills from inventory
      playerSkills = SkillGenerator.generateSkillsFromInventory(
        inventoryScene.inventoryGrid
      );
      console.log("Generated skills from inventory:", playerSkills);
    } else {
      // Fallback to default skills
      playerSkills = SkillGenerator.getDefaultSkills();
      console.log("Using default skills (no inventory found)");
    }

    // Create player with dynamic skills
    this.player = {
      name: "Hero",
      hp: 100,
      maxHp: 100,
      mp: 50,
      maxMp: 50,
      level: 1,
      attack: 20,
      defense: 10,
      speed: 12,
      skills: playerSkills,
    };

    // Create enemies
    this.createEnemies();

    // Calculate turn order
    this.calculateTurnOrder();

    // Initialize battle log
    this.battleLog = [];
    this.addToBattleLog("Battle begins!");
    this.addToBattleLog(
      `${this.player.name} vs ${this.enemies.map((e) => e.name).join(", ")}`
    );

    // Log player's available skills
    const skillList = this.player.skills
      .map((s) => `${s.name} (${s.sourceItems.join(", ")})`)
      .join(", ");
    this.addToBattleLog(`Available skills: ${skillList}`);
  }

  createEnemies() {
    const enemyTemplates = [
      {
        name: "Goblin",
        hp: 60,
        maxHp: 60,
        mp: 20,
        maxMp: 20,
        attack: 15,
        defense: 5,
        speed: 8,
        skills: [
          { name: "Scratch", damage: 18, cost: 0, type: "physical" },
          { name: "Bite", damage: 22, cost: 5, type: "physical" },
        ],
      },
      {
        name: "Orc Warrior",
        hp: 80,
        maxHp: 80,
        mp: 15,
        maxMp: 15,
        attack: 25,
        defense: 8,
        speed: 6,
        skills: [
          { name: "Heavy Strike", damage: 30, cost: 0, type: "physical" },
          { name: "Battle Roar", damage: 15, cost: 8, type: "magic" },
        ],
      },
      {
        name: "Dark Wizard",
        hp: 70,
        maxHp: 70,
        mp: 60,
        maxMp: 60,
        attack: 12,
        defense: 4,
        speed: 10,
        skills: [
          { name: "Dark Bolt", damage: 28, cost: 12, type: "magic" },
          { name: "Drain Life", damage: 20, cost: 15, type: "magic" },
          { name: "Heal", damage: -25, cost: 10, type: "healing" },
        ],
      },
    ];

    // Random number of enemies (1-3)
    const enemyCount = Math.floor(Math.random() * 3) + 1;
    this.enemies = [];

    for (let i = 0; i < enemyCount; i++) {
      const template =
        enemyTemplates[Math.floor(Math.random() * enemyTemplates.length)];
      const enemy = { ...template };
      enemy.isEnemy = true;
      enemy.id = i;
      this.enemies.push(enemy);
    }
  }

  calculateTurnOrder() {
    const allCombatants = [
      this.player,
      ...this.enemies.filter((e) => e.hp > 0),
    ];

    // Sort by speed (higher speed goes first)
    this.turnOrder = allCombatants.sort((a, b) => {
      const speedA = a.speed + Math.random() * 5;
      const speedB = b.speed + Math.random() * 5;
      return speedB - speedA;
    });

    this.currentTurnIndex = 0;
    console.log(
      "Turn order:",
      this.turnOrder.map((c) => c.name)
    );
  }

  createBattleBackground() {
    // Battle arena background
    const bg = new PIXI.Graphics();
    bg.beginFill(0x4a148c); // Deep purple
    bg.drawRect(0, 0, this.engine.width, this.engine.height);
    bg.endFill();

    // Add atmospheric elements scaled to screen size
    const numElements = Math.floor((this.engine.width * this.engine.height) / 50000);
    for (let i = 0; i < numElements; i++) {
      bg.beginFill(0x6a1b9a, 0.3);
      bg.drawCircle(
        Math.random() * this.engine.width,
        Math.random() * this.engine.height,
        Math.random() * 30 * this.layout.scale + 10
      );
      bg.endFill();
    }

    this.addGraphics(bg, "background");

    // Title
    const title = new PIXI.Text("BATTLE ARENA", {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.title,
      fill: 0xffffff,
      align: "center",
      fontWeight: "bold",
    });
    title.anchor.set(0.5);
    title.x = this.engine.width / 2;
    title.y = this.layout.dimensions.turnIndicator.y - 30;
    this.addSprite(title, "ui");
  }

  createBattleUI() {
    // Player area
    this.createPlayerDisplay();

    // Enemy area
    this.createEnemyDisplays();

    // Skills panel
    this.createSkillsPanel();

    // Battle log
    this.createBattleLogPanel();

    // Turn indicator
    this.createTurnIndicator();

    // Action buttons
    this.createActionButtons();

    // Initial display update
    this.updateBattleDisplay();
  }

  createPlayerDisplay() {
    const dims = this.layout.dimensions.playerArea;
    const playerPanel = new PIXI.Graphics();
    
    playerPanel.beginFill(0x2e7d32, 0.8);
    playerPanel.drawRoundedRect(0, 0, dims.width, dims.height, 10);
    playerPanel.endFill();
    playerPanel.lineStyle(2, 0x4caf50);
    playerPanel.drawRoundedRect(0, 0, dims.width, dims.height, 10);
    playerPanel.x = dims.x;
    playerPanel.y = dims.y;

    this.addGraphics(playerPanel, "ui");

    // Player name
    const playerName = new PIXI.Text(
      `🛡️ ${this.player.name} (Lv.${this.player.level})`,
      {
        fontFamily: "Arial",
        fontSize: this.layout.fonts.subtitle,
        fill: 0xffffff,
        fontWeight: "bold",
      }
    );
    playerName.x = dims.x + 10;
    playerName.y = dims.y + 10;
    this.addSprite(playerName, "ui");

    // Player stats
    this.battleUI.playerHpText = new PIXI.Text("", {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.body,
      fill: 0xffffff,
    });
    this.battleUI.playerHpText.x = dims.x + 10;
    this.battleUI.playerHpText.y = dims.y + 35;
    this.addSprite(this.battleUI.playerHpText, "ui");

    this.battleUI.playerMpText = new PIXI.Text("", {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.body,
      fill: 0xffffff,
    });
    this.battleUI.playerMpText.x = dims.x + 10;
    this.battleUI.playerMpText.y = dims.y + 55;
    this.addSprite(this.battleUI.playerMpText, "ui");

    // HP Bar
    this.battleUI.playerHpBar = new PIXI.Graphics();
    this.battleUI.playerHpBar.x = dims.x + 10;
    this.battleUI.playerHpBar.y = dims.y + 75;
    this.addGraphics(this.battleUI.playerHpBar, "ui");

    // MP Bar
    this.battleUI.playerMpBar = new PIXI.Graphics();
    this.battleUI.playerMpBar.x = dims.x + 10;
    this.battleUI.playerMpBar.y = dims.y + 95;
    this.addGraphics(this.battleUI.playerMpBar, "ui");

    // Make player area interactive for self-targeting
    playerPanel.interactive = true;
    playerPanel.cursor = "pointer";
    playerPanel.on("pointerdown", () => {
      if (this.selectedSkill && this.isPlayerTurn() && this.selectedSkill.type === "healing") {
        this.targetSelf();
      }
    });

    playerPanel.on("pointerover", () => {
      if (this.selectedSkill && this.isPlayerTurn() && this.selectedSkill.type === "healing") {
        playerPanel.tint = 0x88ffff;
      }
    });

    playerPanel.on("pointerout", () => {
      playerPanel.tint = 0xffffff;
    });
  }

  createEnemyDisplays() {
    this.battleUI.enemyDisplays = [];
    const enemyDims = this.layout.dimensions.enemyArea;
    
    // Calculate enemy positions based on layout
    const enemiesPerRow = this.layout.isMobile ? 2 : 3;
    const startX = this.layout.isPortrait ? 
      this.layout.padding : 
      this.engine.width - enemyDims.width - this.layout.padding;
    
    this.enemies.forEach((enemy, index) => {
      const col = index % enemiesPerRow;
      const row = Math.floor(index / enemiesPerRow);
      
      const x = startX + col * (enemyDims.width + enemyDims.spacing);
      const y = this.layout.dimensions.playerArea.y + row * (enemyDims.height + enemyDims.spacing);

      const enemyPanel = new PIXI.Graphics();
      enemyPanel.beginFill(0xd32f2f, 0.8);
      enemyPanel.drawRoundedRect(0, 0, enemyDims.width, enemyDims.height, 10);
      enemyPanel.endFill();
      enemyPanel.lineStyle(2, 0xf44336);
      enemyPanel.drawRoundedRect(0, 0, enemyDims.width, enemyDims.height, 10);
      enemyPanel.x = x;
      enemyPanel.y = y;

      // Make enemy panel interactive for targeting
      enemyPanel.interactive = true;
      enemyPanel.cursor = "pointer";
      enemyPanel.enemyId = index;

      enemyPanel.on("pointerdown", () => {
        if (this.selectedSkill && this.isPlayerTurn()) {
          this.targetEnemy(enemy);
        }
      });

      enemyPanel.on("pointerover", () => {
        if (this.selectedSkill && this.isPlayerTurn() && this.selectedSkill.type !== "healing") {
          enemyPanel.tint = 0xffff88;
        }
      });

      enemyPanel.on("pointerout", () => {
        enemyPanel.tint = 0xffffff;
      });

      this.addGraphics(enemyPanel, "ui");

      // Enemy name
      const enemyName = new PIXI.Text(`👹 ${enemy.name}`, {
        fontFamily: "Arial",
        fontSize: this.layout.fonts.body,
        fill: 0xffffff,
        fontWeight: "bold",
      });
      enemyName.x = x + 10;
      enemyName.y = y + 10;
      this.addSprite(enemyName, "ui");

      // Enemy stats
      const enemyHpText = new PIXI.Text("", {
        fontFamily: "Arial",
        fontSize: this.layout.fonts.small,
        fill: 0xffffff,
      });
      enemyHpText.x = x + 10;
      enemyHpText.y = y + 35;
      this.addSprite(enemyHpText, "ui");

      const enemyMpText = new PIXI.Text("", {
        fontFamily: "Arial",
        fontSize: this.layout.fonts.small,
        fill: 0xffffff,
      });
      enemyMpText.x = x + 10;
      enemyMpText.y = y + 50;
      this.addSprite(enemyMpText, "ui");

      // HP Bar
      const enemyHpBar = new PIXI.Graphics();
      enemyHpBar.x = x + 10;
      enemyHpBar.y = y + 70;
      this.addGraphics(enemyHpBar, "ui");

      // MP Bar
      const enemyMpBar = new PIXI.Graphics();
      enemyMpBar.x = x + 10;
      enemyMpBar.y = y + 85;
      this.addGraphics(enemyMpBar, "ui");

      this.battleUI.enemyDisplays.push({
        panel: enemyPanel,
        hpText: enemyHpText,
        mpText: enemyMpText,
        hpBar: enemyHpBar,
        mpBar: enemyMpBar,
        enemy: enemy,
      });
    });
  }

  createSkillsPanel() {
    const dims = this.layout.dimensions.skillsPanel;
    const skillsPanel = new PIXI.Graphics();
    
    skillsPanel.beginFill(0x1976d2, 0.9);
    skillsPanel.drawRoundedRect(0, 0, dims.width, dims.height, 10);
    skillsPanel.endFill();
    skillsPanel.lineStyle(2, 0x2196f3);
    skillsPanel.drawRoundedRect(0, 0, dims.width, dims.height, 10);
    skillsPanel.x = dims.x;
    skillsPanel.y = dims.y;

    this.addGraphics(skillsPanel, "ui");

    // Skills title
    const skillsTitle = new PIXI.Text("⚔️ SKILLS", {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.subtitle,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    skillsTitle.x = dims.x + 10;
    skillsTitle.y = dims.y + 10;
    this.addSprite(skillsTitle, "ui");

    // Create skill buttons
    this.createSkillButtons();
  }

  createSkillButtons() {
    this.buttons = [];
    const dims = this.layout.dimensions.skillsPanel;
    
    // Calculate button dimensions
    const buttonWidth = dims.width - 20;
    const buttonHeight = this.layout.isMobile ? 50 : 40;
    const buttonSpacing = this.layout.isMobile ? 8 : 5;
    const maxVisibleSkills = Math.floor((dims.height - 40) / (buttonHeight + buttonSpacing));

    this.player.skills.slice(0, maxVisibleSkills).forEach((skill, index) => {
      const button = new PIXI.Graphics();
      const buttonX = dims.x + 10;
      const buttonY = dims.y + 40 + index * (buttonHeight + buttonSpacing);

      // Button background with skill type color
      const skillTypeColor = SkillGenerator.getSkillTypeColor(skill.type);
      button.beginFill(skillTypeColor, 0.3);
      button.drawRoundedRect(0, 0, buttonWidth, buttonHeight, 5);
      button.endFill();
      button.lineStyle(2, skillTypeColor);
      button.drawRoundedRect(0, 0, buttonWidth, buttonHeight, 5);

      button.x = buttonX;
      button.y = buttonY;
      button.interactive = true;
      button.cursor = "pointer";
      button.skillIndex = index;

      // Skill icon
      const skillIcon = new PIXI.Graphics();
      skillIcon.beginFill(skillTypeColor);
      skillIcon.drawCircle(15, buttonHeight / 2, 12);
      skillIcon.endFill();
      button.addChild(skillIcon);

      // Skill name and stats
      const skillText = new PIXI.Text(
        `${skill.name} - ${skill.damage} DMG - ${skill.cost} MP`,
        {
          fontFamily: "Arial",
          fontSize: this.layout.fonts.body,
          fill: 0xffffff,
          fontWeight: "bold",
        }
      );
      skillText.x = 35;
      skillText.y = 8;
      button.addChild(skillText);

      // Source items (if space allows)
      if (buttonHeight > 35) {
        const sourceText = new PIXI.Text(
          `From: ${skill.sourceItems.join(" + ")}`,
          {
            fontFamily: "Arial",
            fontSize: this.layout.fonts.small,
            fill: 0xcccccc,
          }
        );
        sourceText.x = 35;
        sourceText.y = 25;
        button.addChild(sourceText);
      }

      // Button events
      button.on("pointerover", () => {
        if (this.player.mp >= skill.cost) {
          button.tint = 0xdddddd;
        }
      });

      button.on("pointerout", () => {
        button.tint = 0xffffff;
      });

      button.on("pointerdown", () => {
        this.selectSkill(skill, index);
      });

      this.addGraphics(button, "ui");
      this.buttons.push(button);
    });
  }

  createBattleLogPanel() {
    const dims = this.layout.dimensions.battleLog;
    const logPanel = new PIXI.Graphics();
    
    logPanel.beginFill(0x263238, 0.9);
    logPanel.drawRoundedRect(0, 0, dims.width, dims.height, 10);
    logPanel.endFill();
    logPanel.lineStyle(2, 0x455a64);
    logPanel.drawRoundedRect(0, 0, dims.width, dims.height, 10);
    logPanel.x = dims.x;
    logPanel.y = dims.y;

    this.addGraphics(logPanel, "ui");

    // Log title
    const logTitle = new PIXI.Text("📜 BATTLE LOG", {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.subtitle,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    logTitle.x = dims.x + 10;
    logTitle.y = dims.y + 10;
    this.addSprite(logTitle, "ui");

    // Battle log text container
    this.battleUI.logContainer = new PIXI.Container();
    this.battleUI.logContainer.x = dims.x + 10;
    this.battleUI.logContainer.y = dims.y + 35;
    this.addSprite(this.battleUI.logContainer, "ui");

    // Set up scrolling for log if needed
    const logMask = new PIXI.Graphics();
    logMask.beginFill(0x000000);
    logMask.drawRect(dims.x + 10, dims.y + 35, dims.width - 20, dims.height - 45);
    logMask.endFill();
    this.battleUI.logContainer.mask = logMask;
    this.addGraphics(logMask, "ui");
  }

  createTurnIndicator() {
    const dims = this.layout.dimensions.turnIndicator;
    
    // Background
    const bg = new PIXI.Graphics();
    bg.beginFill(0x34495e, 0.9);
    bg.drawRoundedRect(-dims.width / 2, -dims.height / 2, dims.width, dims.height, 8);
    bg.endFill();
    bg.lineStyle(2, 0xecf0f1);
    bg.drawRoundedRect(-dims.width / 2, -dims.height / 2, dims.width, dims.height, 8);
    bg.x = dims.x;
    bg.y = dims.y;
    this.addGraphics(bg, "ui");

    this.battleUI.turnIndicator = new PIXI.Text("", {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.subtitle,
      fill: 0xffd700,
      fontWeight: "bold",
      align: "center",
    });
    this.battleUI.turnIndicator.anchor.set(0.5);
    this.battleUI.turnIndicator.x = dims.x;
    this.battleUI.turnIndicator.y = dims.y;
    this.addSprite(this.battleUI.turnIndicator, "ui");
  }

  createActionButtons() {
    const dims = this.layout.dimensions.actionButtons;
    const actionButtons = [
      { text: "🏃 Run", action: () => this.runAway() },
      { text: "🔄 Skip", action: () => this.skipTurn() },
      { text: "⚡ Auto", action: () => this.toggleAutoBattle() },
    ];

    actionButtons.forEach((btnData, index) => {
      const button = new PIXI.Graphics();
      const buttonX = this.layout.padding + index * (dims.width + dims.spacing);
      
      // Auto battle button gets different styling
      const isAutoBattle = btnData.text.includes("Auto");
      const bgColor = isAutoBattle && this.autoBattle ? 0xe74c3c : 0x795548;
      
      button.beginFill(bgColor);
      button.drawRoundedRect(0, 0, dims.width, dims.height, 5);
      button.endFill();
      button.lineStyle(1, isAutoBattle && this.autoBattle ? 0xc0392b : 0x8d6e63);
      button.drawRoundedRect(0, 0, dims.width, dims.height, 5);

      button.x = buttonX;
      button.y = dims.y;
      button.interactive = true;
      button.cursor = "pointer";

      const buttonText = new PIXI.Text(btnData.text, {
        fontFamily: "Arial",
        fontSize: this.layout.fonts.button,
        fill: 0xffffff,
        align: "center",
        fontWeight: "bold",
      });
      buttonText.anchor.set(0.5);
      buttonText.x = dims.width / 2;
      buttonText.y = dims.height / 2;
      button.addChild(buttonText);

      button.on("pointerover", () => {
        button.tint = 0xcccccc;
      });

      button.on("pointerout", () => {
        button.tint = 0xffffff;
      });

      button.on("pointerdown", btnData.action);

      this.addGraphics(button, "ui");
    });
  }

  // Battle logic methods
  getCurrentActor() {
    if (this.turnOrder.length === 0) return null;
    return this.turnOrder[this.currentTurnIndex];
  }

  isPlayerTurn() {
    return (
      this.getCurrentActor() === this.player && this.battleState === "selecting"
    );
  }

  selectSkill(skill, index) {
    if (!this.isPlayerTurn()) return;

    if (this.player.mp < skill.cost) {
      this.addToBattleLog("Not enough MP!");
      return;
    }

    this.selectedSkill = skill;
    this.addToBattleLog(
      `Selected ${skill.name}. Choose target.`
    );

    // If it's a healing skill, target self immediately
    if (skill.type === "healing") {
      this.targetSelf();
    }

    // Highlight selected skill button
    this.buttons.forEach((btn, i) => {
      if (i === index) {
        btn.tint = 0x4caf50;
      } else {
        btn.tint = 0xffffff;
      }
    });
  }

  targetEnemy(enemy) {
    if (!this.selectedSkill || !this.isPlayerTurn()) return;

    if (enemy.hp <= 0) {
      this.addToBattleLog("Cannot target defeated enemy!");
      return;
    }

    if (this.selectedSkill.type === "healing") {
      this.addToBattleLog("Cannot use healing skills on enemies!");
      return;
    }

    this.executeSkill(this.player, this.selectedSkill, enemy);
  }

  targetSelf() {
    if (!this.selectedSkill || !this.isPlayerTurn()) return;

    if (this.selectedSkill.type !== "healing") {
      this.addToBattleLog("Cannot target yourself with attack skills!");
      return;
    }

    this.executeSkill(this.player, this.selectedSkill, this.player);
  }

  executeSkill(actor, skill, target) {
    // Calculate damage
    let damage = skill.damage;
    if (damage > 0) {
      // Attack skill
      damage += Math.floor(Math.random() * 10) - 5; // ±5 variance
      damage = Math.max(1, damage - (target.defense || 0));
    } else {
      // Healing skill
      damage = Math.abs(damage) + Math.floor(Math.random() * 5);
    }

    // Apply skill cost
    actor.mp -= skill.cost;
    actor.mp = Math.max(0, actor.mp);

    // Apply effect
    if (skill.type === "healing") {
      target.hp = Math.min(target.maxHp, target.hp + damage);
      this.addToBattleLog(
        `${actor.name} heals ${target.name} for ${damage} HP!`
      );
    } else {
      target.hp -= damage;
      target.hp = Math.max(0, target.hp);
      this.addToBattleLog(
        `${actor.name} uses ${skill.name} on ${target.name} for ${damage} damage!`
      );

      if (actor === this.player) {
        this.battleStats.damageDealt += damage;
        this.battleStats.skillsUsed++;
      }
    }

    // Check for defeat
    if (target.hp <= 0 && target !== this.player) {
      this.addToBattleLog(`${target.name} is defeated!`);
    }

    // Clear selection
    this.selectedSkill = null;
    this.buttons.forEach((btn) => (btn.tint = 0xffffff));

    // Check battle end
    if (this.checkBattleEnd()) {
      return;
    }

    // Next turn
    this.nextTurn();
    this.updateBattleDisplay();
  }

  nextTurn() {
    this.battleStats.turnCount++;

    // Move to next combatant
    this.currentTurnIndex = (this.currentTurnIndex + 1) % this.turnOrder.length;

    // Skip defeated characters
    let attempts = 0;
    while (
      this.getCurrentActor()?.hp <= 0 &&
      attempts < this.turnOrder.length
    ) {
      this.currentTurnIndex =
        (this.currentTurnIndex + 1) % this.turnOrder.length;
      attempts++;
    }

    const currentActor = this.getCurrentActor();
    if (currentActor?.isEnemy) {
      // AI turn
      this.battleState = "ai_turn";
      setTimeout(() => this.executeAITurn(), 1000);
    } else {
      // Player turn
      this.battleState = "selecting";
    }

    this.updateTurnDisplay();
  }

  executeAITurn() {
    const enemy = this.getCurrentActor();
    if (!enemy || enemy.hp <= 0) {
      this.nextTurn();
      return;
    }

    // Simple AI: choose random available skill
    const availableSkills = enemy.skills.filter(
      (skill) => enemy.mp >= skill.cost
    );

    if (availableSkills.length === 0) {
      this.addToBattleLog(`${enemy.name} has no MP and skips turn.`);
      this.nextTurn();
      return;
    }

    const selectedSkill =
      availableSkills[Math.floor(Math.random() * availableSkills.length)];

    // Choose target
    let target;
    if (selectedSkill.type === "healing") {
      // Heal weakest ally or self
      const aliveEnemies = this.enemies.filter((e) => e.hp > 0);
      target = aliveEnemies.reduce((weakest, current) =>
        current.hp < weakest.hp ? current : weakest
      );
    } else {
      // Attack player
      target = this.player;
    }

    this.executeSkill(enemy, selectedSkill, target);
  }

  checkBattleEnd() {
    const aliveEnemies = this.enemies.filter((e) => e.hp > 0);

    if (this.player.hp <= 0) {
      this.battleState = "defeat";
      this.addToBattleLog("💀 DEFEAT! You have been defeated!");
      this.showBattleEndScreen(false);
      return true;
    }

    if (aliveEnemies.length === 0) {
      this.battleState = "victory";
      this.addToBattleLog("🎉 VICTORY! All enemies defeated!");
      this.showBattleEndScreen(true);
      return true;
    }

    return false;
  }

  showBattleEndScreen(victory) {
    if (!victory) {
      this.showDefeatScreen();
      return;
    }

    // Generate loot based on defeated enemies
    const loot = this.generateBattleLoot();

    if (loot.length > 0) {
      // Switch to loot scene with battle context
      const lootScene = this.engine.scenes.get("loot");
      lootScene.setLootData(loot, {
        returnScene: "world",
        title: "🎉 VICTORY!",
        subtitle:
          "Drag your battle rewards from the right to your inventory or storage",
        context: "battle",
        showStats: true,
        stats: {
          turnCount: this.battleStats.turnCount,
          damageDealt: this.battleStats.damageDealt,
          skillsUsed: this.battleStats.skillsUsed,
        },
      });

      this.engine.switchScene("loot");
    } else {
      // Show simple victory screen if no loot
      this.showSimpleVictoryScreen();
    }
  }

  showDefeatScreen() {
    // Create defeat overlay
    const overlay = new PIXI.Graphics();
    overlay.beginFill(0x000000, 0.8);
    overlay.drawRect(0, 0, this.engine.width, this.engine.height);
    overlay.endFill();
    overlay.interactive = true;

    // Defeat text
    const defeatText = new PIXI.Text("💀 DEFEAT!", {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.title * 1.5,
      fill: 0xe74c3c,
      fontWeight: "bold",
      align: "center",
    });
    defeatText.anchor.set(0.5);
    defeatText.x = this.engine.width / 2;
    defeatText.y = this.engine.height / 2 - 50;
    overlay.addChild(defeatText);

    // Return button
    const returnButton = new PIXI.Graphics();
    returnButton.beginFill(0x3498db);
    returnButton.drawRoundedRect(0, 0, 200, 50, 10);
    returnButton.endFill();
    returnButton.x = this.engine.width / 2 - 100;
    returnButton.y = this.engine.height / 2 + 20;
    returnButton.interactive = true;
    returnButton.cursor = "pointer";

    const returnText = new PIXI.Text("Return to World", {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.button,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    returnText.anchor.set(0.5);
    returnText.x = 100;
    returnText.y = 25;
    returnButton.addChild(returnText);

    returnButton.on("pointerdown", () => {
      this.engine.switchScene("world");
    });

    overlay.addChild(returnButton);
    this.addSprite(overlay, "effects");
  }

  showSimpleVictoryScreen() {
    // Create victory overlay
    const overlay = new PIXI.Graphics();
    overlay.beginFill(0x000000, 0.8);
    overlay.drawRect(0, 0, this.engine.width, this.engine.height);
    overlay.endFill();
    overlay.interactive = true;

    // Victory text
    const victoryText = new PIXI.Text("🎉 VICTORY!", {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.title * 1.5,
      fill: 0x27ae60,
      fontWeight: "bold",
      align: "center",
    });
    victoryText.anchor.set(0.5);
    victoryText.x = this.engine.width / 2;
    victoryText.y = this.engine.height / 2 - 50;
    overlay.addChild(victoryText);

    // Continue button
    const continueButton = new PIXI.Graphics();
    continueButton.beginFill(0x27ae60);
    continueButton.drawRoundedRect(0, 0, 200, 50, 10);
    continueButton.endFill();
    continueButton.x = this.engine.width / 2 - 100;
    continueButton.y = this.engine.height / 2 + 20;
    continueButton.interactive = true;
    continueButton.cursor = "pointer";

    const continueText = new PIXI.Text("Continue", {
      fontFamily: "Arial",
      fontSize: this.layout.fonts.button,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    continueText.anchor.set(0.5);
    continueText.x = 100;
    continueText.y = 25;
    continueButton.addChild(continueText);

    continueButton.on("pointerdown", () => {
      this.engine.switchScene("world");
    });

    overlay.addChild(continueButton);
    this.addSprite(overlay, "effects");
  }

  generateBattleLoot() {
    const loot = [];

    // Generate loot based on defeated enemies
    this.enemies.forEach((enemy) => {
      if (enemy.hp <= 0) {
        const enemyLoot = this.getEnemyLoot(enemy);
        loot.push(...enemyLoot);
      }
    });

    // Add bonus loot based on battle performance
    const bonusLoot = this.getBonusLoot();
    loot.push(...bonusLoot);

    return loot;
  }

  getEnemyLoot(enemy) {
    const lootTables = {
      Goblin: [
        {
          name: "Rusty Dagger",
          color: 0x8b4513,
          width: 1,
          height: 2,
          type: "weapon",
          baseSkills: [
            {
              name: "Stab",
              description: "Basic stabbing attack",
              damage: 15,
              cost: 0,
              type: "physical",
            },
          ],
        },
        {
          name: "Goblin Tooth",
          color: 0xfffaf0,
          width: 1,
          height: 1,
          type: "material",
        },
      ],
      "Orc Warrior": [
        {
          name: "Orcish Axe",
          color: 0x8b0000,
          width: 2,
          height: 2,
          type: "weapon",
          baseSkills: [
            {
              name: "Cleave",
              description: "Powerful axe swing",
              damage: 30,
              cost: 2,
              type: "physical",
            },
          ],
        },
        {
          name: "Berserker Gem",
          color: 0xff4500,
          width: 1,
          height: 1,
          type: "gem",
          enhancements: [
            {
              targetTypes: ["physical"],
              nameModifier: (name) => `Rage ${name}`,
              damageMultiplier: 1.4,
            },
          ],
        },
      ],
      "Dark Wizard": [
        {
          name: "Shadow Staff",
          color: 0x4b0082,
          width: 1,
          height: 3,
          type: "weapon",
          baseSkills: [
            {
              name: "Dark Bolt",
              description: "Shadowy magic attack",
              damage: 25,
              cost: 6,
              type: "magic",
            },
          ],
        },
        {
          name: "Mana Potion",
          color: 0x0000ff,
          width: 1,
          height: 1,
          type: "consumable",
          baseSkills: [
            {
              name: "Restore MP",
              description: "Restore mana points",
              damage: -40,
              cost: 0,
              type: "healing",
            },
          ],
        },
      ],
    };

    const enemyLootTable = lootTables[enemy.name] || [];
    return enemyLootTable.filter(() => Math.random() < 0.7);
  }

  getBonusLoot() {
    const bonusLoot = [];

    // Performance-based bonus loot
    if (this.battleStats.turnCount <= 5) {
      bonusLoot.push({
        name: "Victory Medal",
        color: 0xffd700,
        width: 1,
        height: 1,
        type: "trophy",
        baseSkills: [
          {
            name: "Inspire",
            description: "Boost morale",
            damage: 0,
            cost: 3,
            type: "defensive",
          },
        ],
      });
    }

    if (this.battleStats.skillsUsed >= 5) {
      bonusLoot.push({
        name: "Skill Shard",
        color: 0x40e0d0,
        width: 1,
        height: 1,
        type: "gem",
        enhancements: [
          { targetTypes: ["physical", "magic"], costModifier: -1 },
        ],
      });
    }

    // Random bonus items (25% chance)
    if (Math.random() < 0.25) {
      const randomBonusItems = [
        {
          name: "Health Potion",
          color: 0xff0000,
          width: 1,
          height: 1,
          type: "consumable",
          baseSkills: [
            {
              name: "Heal",
              description: "Restore health",
              damage: -35,
              cost: 0,
              type: "healing",
            },
          ],
        },
        {
          name: "Lucky Charm",
          color: 0xffd700,
          width: 1,
          height: 1,
          type: "gem",
          enhancements: [
            { targetTypes: ["physical", "magic"], damageBonus: 5 },
          ],
        },
      ];

      bonusLoot.push(
        randomBonusItems[Math.floor(Math.random() * randomBonusItems.length)]
      );
    }

    return bonusLoot;
  }

  runAway() {
    if (!this.isPlayerTurn()) return;

    if (Math.random() < 0.7) {
      this.addToBattleLog("Successfully ran away!");
      setTimeout(() => {
        this.engine.switchScene("world");
      }, 1500);
    } else {
      this.addToBattleLog("Could not escape!");
      this.nextTurn();
    }
  }

  skipTurn() {
    if (!this.isPlayerTurn()) return;

    this.addToBattleLog(`${this.player.name} skips turn.`);
    this.nextTurn();
  }

  toggleAutoBattle() {
    this.autoBattle = !this.autoBattle;
    this.addToBattleLog(`Auto battle ${this.autoBattle ? "enabled" : "disabled"}`);

    if (this.autoBattle && this.isPlayerTurn()) {
      this.executeAutoPlayerTurn();
    }
  }

  executeAutoPlayerTurn() {
    if (!this.isPlayerTurn() || !this.autoBattle) return;

    const skills = this.player.skills;
    if (skills.length === 0) {
      this.skipTurn();
      return;
    }

    // Simple AI: prefer attack skills, target first alive enemy
    const attackSkill = skills.find(
      (s) => s.type === "physical" || s.type === "magic"
    );
    const healSkill = skills.find((s) => s.type === "healing");

    let selectedSkill = null;
    let target = null;

    // Use heal if health is low
    if (this.player.hp / this.player.maxHp < 0.3 && healSkill) {
      selectedSkill = healSkill;
      target = this.player;
    } else if (attackSkill) {
      selectedSkill = attackSkill;
      target = this.enemies.find((e) => e.hp > 0);
    }

    if (selectedSkill && target) {
      setTimeout(
        () => this.executeSkill(this.player, selectedSkill, target),
        500
      );
    } else {
      this.skipTurn();
    }
  }

  addToBattleLog(message) {
    this.battleLog.push(message);
    if (this.battleLog.length > this.logMaxLines) {
      this.battleLog.shift();
    }

    this.updateBattleLogDisplay();
    console.log("Battle:", message);
  }

  updateBattleLogDisplay() {
    if (!this.battleUI.logContainer) return;

    // Clear existing log entries
    this.battleUI.logContainer.removeChildren();

    // Add current log entries
    const maxWidth = this.layout.dimensions.battleLog.width - 40;
    this.battleLog.forEach((message, index) => {
      const logEntry = new PIXI.Text(message, {
        fontFamily: "Arial",
        fontSize: this.layout.fonts.small,
        fill: 0xecf0f1,
        wordWrap: true,
        wordWrapWidth: maxWidth,
      });
      logEntry.y = index * (this.layout.fonts.small + 4);
      this.battleUI.logContainer.addChild(logEntry);
    });
  }

  updateTurnDisplay() {
    if (!this.battleUI.turnIndicator) return;

    const currentActor = this.getCurrentActor();
    if (currentActor) {
      this.battleUI.turnIndicator.text = `${currentActor.name}'s Turn`;
      if (currentActor === this.player) {
        this.battleUI.turnIndicator.style.fill = 0x4caf50;
      } else {
        this.battleUI.turnIndicator.style.fill = 0xf44336;
      }
    }
  }

  updateBattleDisplay() {
    // Update player display
    if (this.battleUI.playerHpText) {
      this.battleUI.playerHpText.text = `HP: ${this.player.hp}/${this.player.maxHp}`;
    }
    if (this.battleUI.playerMpText) {
      this.battleUI.playerMpText.text = `MP: ${this.player.mp}/${this.player.maxMp}`;
    }

    // Update player HP bar
    if (this.battleUI.playerHpBar) {
      this.battleUI.playerHpBar.clear();
      const hpPercent = this.player.hp / this.player.maxHp;
      const barWidth = Math.min(200, this.layout.dimensions.playerArea.width - 40);

      // Background
      this.battleUI.playerHpBar.beginFill(0x333333);
      this.battleUI.playerHpBar.drawRect(0, 0, barWidth, 8);
      this.battleUI.playerHpBar.endFill();

      // HP fill
      const hpColor =
        hpPercent > 0.5 ? 0x4caf50 : hpPercent > 0.25 ? 0xff9800 : 0xf44336;
      this.battleUI.playerHpBar.beginFill(hpColor);
      this.battleUI.playerHpBar.drawRect(0, 0, barWidth * hpPercent, 8);
      this.battleUI.playerHpBar.endFill();
    }

    // Update player MP bar
    if (this.battleUI.playerMpBar) {
      this.battleUI.playerMpBar.clear();
      const mpPercent = this.player.mp / this.player.maxMp;
      const barWidth = Math.min(200, this.layout.dimensions.playerArea.width - 40);

      // Background
      this.battleUI.playerMpBar.beginFill(0x333333);
      this.battleUI.playerMpBar.drawRect(0, 0, barWidth, 6);
      this.battleUI.playerMpBar.endFill();

      // MP fill
      this.battleUI.playerMpBar.beginFill(0x2196f3);
      this.battleUI.playerMpBar.drawRect(0, 0, barWidth * mpPercent, 6);
      this.battleUI.playerMpBar.endFill();
    }

    // Update enemy displays
    this.battleUI.enemyDisplays.forEach((display, index) => {
      const enemy = display.enemy;

      if (enemy.hp <= 0) {
        display.panel.alpha = 0.3;
        display.panel.interactive = false;
      } else {
        display.panel.alpha = 1;
        display.panel.interactive = true;
      }

      display.hpText.text = `HP: ${Math.max(0, enemy.hp)}/${enemy.maxHp}`;
      display.mpText.text = `MP: ${Math.max(0, enemy.mp)}/${enemy.maxMp}`;

      // Update enemy HP bar
      display.hpBar.clear();
      const enemyHpPercent = Math.max(0, enemy.hp / enemy.maxHp);
      const barWidth = Math.min(150, this.layout.dimensions.enemyArea.width - 40);

      // Background
      display.hpBar.beginFill(0x333333);
      display.hpBar.drawRect(0, 0, barWidth, 8);
      display.hpBar.endFill();

      // HP fill
      const enemyHpColor =
        enemyHpPercent > 0.5
          ? 0x4caf50
          : enemyHpPercent > 0.25
          ? 0xff9800
          : 0xf44336;
      display.hpBar.beginFill(enemyHpColor);
      display.hpBar.drawRect(0, 0, barWidth * enemyHpPercent, 8);
      display.hpBar.endFill();

      // Update enemy MP bar
      display.mpBar.clear();
      const enemyMpPercent = Math.max(0, enemy.mp / enemy.maxMp);

      // Background
      display.mpBar.beginFill(0x333333);
      display.mpBar.drawRect(0, 0, barWidth, 6);
      display.mpBar.endFill();

      // MP fill
      display.mpBar.beginFill(0x2196f3);
      display.mpBar.drawRect(0, 0, barWidth * enemyMpPercent, 6);
      display.mpBar.endFill();
    });

    // Update skill buttons availability
    this.buttons.forEach((button, index) => {
      const skill = this.player.skills[index];
      if (this.player.mp < skill.cost) {
        button.alpha = 0.5;
        button.interactive = false;
      } else {
        button.alpha = 1;
        button.interactive = true;
      }
    });

    this.updateTurnDisplay();
  }

  // Update loop
  update(deltaTime) {
    super.update(deltaTime);

    // Update battle display periodically
    this.updateBattleDisplay();

    // Auto battle logic
    if (
      this.autoBattle &&
      this.isPlayerTurn() &&
      this.battleState === "selecting"
    ) {
      setTimeout(() => this.executeAutoPlayerTurn(), 1000);
    }

    // Process any animations
    if (this.animationQueue.length > 0) {
      this.animationQueue = this.animationQueue.filter((anim) => {
        anim.duration -= deltaTime;
        return anim.duration > 0;
      });
    }
  }

  // Input handling
  handleKeyDown(event) {
    if (event.code === "Escape") {
      // Quick escape to world (with confirmation in a real game)
      this.engine.switchScene("world");
    } else if (event.code === "Space") {
      if (this.isPlayerTurn()) {
        this.skipTurn();
      }
    } else if (event.code >= "Digit1" && event.code <= "Digit9") {
      // Quick skill selection with number keys
      const skillIndex = parseInt(event.code.replace("Digit", "")) - 1;
      if (skillIndex < this.player.skills.length && this.isPlayerTurn()) {
        const skill = this.player.skills[skillIndex];
        this.selectSkill(skill, skillIndex);
      }
    }
  }

  handleMouseDown(event) {
    // Handle any additional mouse interactions
    if (this.selectedSkill && this.isPlayerTurn()) {
      // Check if clicking on player for self-targeting
      const mousePos = event.global;
      const playerArea = this.layout.dimensions.playerArea;
      
      if (
        mousePos.x >= playerArea.x &&
        mousePos.x <= playerArea.x + playerArea.width &&
        mousePos.y >= playerArea.y &&
        mousePos.y <= playerArea.y + playerArea.height
      ) {
        this.targetSelf();
      }
    }
  }
}