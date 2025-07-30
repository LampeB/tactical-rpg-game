import { PixiScene } from "../core/PixiScene.js";
import { SkillGenerator } from "../core/SkillGenerator.js";
import { COLORS, FONTS, UI, LAYOUT, RESPONSIVE, TIMING } from '../utils/Constants.js';
import { CHARACTER, ENEMIES, BATTLE } from '../utils/GameConfig.js';

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

    // Responsive design properties using constants
    this.layout = {
      isPortrait: false,
      isMobile: false,
      scale: RESPONSIVE.BASE_SCALE,
      padding: LAYOUT.PADDING,
    };

    // Layout breakpoints from constants
    this.breakpoints = {
      mobile: RESPONSIVE.MOBILE_MAX_WIDTH,
      tablet: RESPONSIVE.TABLET_MAX_WIDTH,
      desktop: 1200, // Could be added to constants if needed more places
    };
  }

  calculateLayout() {
    const width = this.engine.width;
    const height = this.engine.height;
    
    // Determine device type and orientation
    this.layout.isPortrait = height > width;
    this.layout.isMobile = width < this.breakpoints.mobile;
    this.layout.isTablet = width >= this.breakpoints.mobile && width < this.breakpoints.desktop;
    this.layout.isDesktop = width >= this.breakpoints.desktop;
    
    // Calculate scaling factor using responsive constants
    this.layout.scale = Math.min(width / 1200, height / 800);
    this.layout.scale = Math.max(RESPONSIVE.MIN_SCALE, Math.min(RESPONSIVE.MAX_SCALE, this.layout.scale));
    
    // Adjust padding based on screen size using constants
    this.layout.padding = this.layout.isMobile ? LAYOUT.MOBILE_PADDING : LAYOUT.PADDING;
    
    // Calculate responsive dimensions using UI constants
    this.layout.dimensions = {
      // Character display areas
      playerArea: {
        width: this.layout.isMobile ? width * 0.45 : Math.min(UI.PANEL.BATTLE_PLAYER_WIDTH, width * 0.25),
        height: this.layout.isMobile ? height * 0.2 : Math.min(UI.PANEL.BATTLE_PLAYER_HEIGHT + 60, height * 0.22),
        x: this.layout.padding,
        y: this.layout.isMobile ? height * 0.1 : height * 0.12,
      },
      
      // Enemy area calculations using constants
      enemyArea: {
        width: this.layout.isMobile ? width * 0.45 : Math.min(UI.PANEL.BATTLE_ENEMY_WIDTH + 80, width * 0.23),
        height: this.layout.isMobile ? height * 0.18 : Math.min(UI.PANEL.BATTLE_ENEMY_HEIGHT + 60, height * 0.2),
        spacing: this.layout.isMobile ? LAYOUT.MEDIUM_SPACING : LAYOUT.EXTRA_LARGE_SPACING + 5,
      },
      
      // Skills panel using UI constants
      skillsPanel: {
        width: this.layout.isPortrait ? width * 0.9 : Math.min(UI.PANEL.BATTLE_SKILLS_WIDTH + 200, width * 0.35),
        height: this.layout.isPortrait ? height * 0.25 : Math.min(UI.PANEL.BATTLE_SKILLS_MIN_HEIGHT + 100, height * 0.4),
        x: this.layout.padding,
        y: this.layout.isPortrait ? height * 0.45 : height * 0.5,
      },
      
      // Battle log using UI constants
      battleLog: {
        width: this.layout.isPortrait ? width * 0.9 : Math.min(UI.PANEL.BATTLE_LOG_WIDTH + 250, width * 0.42),
        height: this.layout.isPortrait ? height * 0.2 : Math.min(UI.PANEL.BATTLE_LOG_HEIGHT + 100, height * 0.35),
        x: this.layout.isPortrait ? this.layout.padding : width * 0.55,
        y: this.layout.isPortrait ? height * 0.72 : height * 0.5,
      },
      
      // Turn indicator using UI constants
      turnIndicator: {
        width: Math.min(UI.PANEL.TURN_INDICATOR_WIDTH + 50, width * 0.4),
        height: Math.min(UI.PANEL.TURN_INDICATOR_HEIGHT + 10, height * 0.06),
        x: width / 2,
        y: Math.max(30, height * 0.05),
      },
      
      // Action buttons using constants
      actionButtons: {
        width: Math.min(UI.BUTTON.MEDIUM_WIDTH + 30, width * 0.15),
        height: Math.min(UI.BUTTON.MEDIUM_HEIGHT + 5, height * 0.05),
        spacing: this.layout.isMobile ? LAYOUT.MEDIUM_SPACING : LAYOUT.LARGE_SPACING,
        y: height - Math.max(60, height * 0.08),
      },
    };
    
    // Font scaling using font constants
    this.layout.fonts = {
      title: Math.max(FONTS.SIZE.SUBTITLE, Math.min(FONTS.SIZE.HUGE_TITLE, FONTS.SIZE.HUGE_TITLE * this.layout.scale)),
      subtitle: Math.max(FONTS.SIZE.BODY, Math.min(FONTS.SIZE.TITLE, FONTS.SIZE.TITLE * this.layout.scale)),
      body: Math.max(FONTS.SIZE.SMALL, Math.min(FONTS.SIZE.SUBTITLE, FONTS.SIZE.SUBTITLE * this.layout.scale)),
      small: Math.max(FONTS.SIZE.TINY, Math.min(FONTS.SIZE.BODY, FONTS.SIZE.BODY * this.layout.scale)),
      button: Math.max(FONTS.SIZE.SMALL, Math.min(FONTS.SIZE.SUBTITLE, FONTS.SIZE.SUBTITLE * this.layout.scale)),
    };

    console.log("Layout calculated:", this.layout);
  }

  createPlayerDisplay() {
    const dims = this.layout.dimensions.playerArea;
    const playerPanel = new PIXI.Graphics();
    
    // Use color constants instead of hardcoded values
    playerPanel.beginFill(COLORS.PIXI.PLAYER_PANEL, COLORS.ALPHA.HIGH);
    playerPanel.drawRoundedRect(0, 0, dims.width, dims.height, LAYOUT.LARGE_RADIUS);
    playerPanel.endFill();
    playerPanel.lineStyle(LAYOUT.MEDIUM_BORDER, COLORS.PIXI.PLAYER_BORDER);
    playerPanel.drawRoundedRect(0, 0, dims.width, dims.height, LAYOUT.LARGE_RADIUS);
    playerPanel.x = dims.x;
    playerPanel.y = dims.y;

    this.addGraphics(playerPanel, "ui");

    // Player name using font constants
    const playerName = new PIXI.Text(
      `🛡️ ${this.player.name} (Lv.${this.player.level})`,
      {
        fontFamily: FONTS.FAMILY.PRIMARY,
        fontSize: this.layout.fonts.subtitle,
        fill: COLORS.PIXI.WHITE,
        fontWeight: FONTS.WEIGHT.BOLD,
      }
    );
    playerName.x = dims.x + LAYOUT.MEDIUM_SPACING;
    playerName.y = dims.y + LAYOUT.MEDIUM_SPACING;
    this.addSprite(playerName, "ui");

    // Player stats using spacing constants
    this.battleUI.playerHpText = new PIXI.Text("", {
      fontFamily: FONTS.FAMILY.PRIMARY,
      fontSize: this.layout.fonts.body,
      fill: COLORS.PIXI.WHITE,
    });
    this.battleUI.playerHpText.x = dims.x + LAYOUT.MEDIUM_SPACING;
    this.battleUI.playerHpText.y = dims.y + LAYOUT.MEDIUM_SPACING + LAYOUT.EXTRA_LARGE_SPACING + 5;
    this.addSprite(this.battleUI.playerHpText, "ui");

    // HP Bar using bar constants
    this.battleUI.playerHpBar = new PIXI.Graphics();
    this.battleUI.playerHpBar.x = dims.x + LAYOUT.MEDIUM_SPACING;
    this.battleUI.playerHpBar.y = dims.y + LAYOUT.MEDIUM_SPACING + (LAYOUT.EXTRA_LARGE_SPACING * 3);
    this.addGraphics(this.battleUI.playerHpBar, "ui");

    // MP Bar
    this.battleUI.playerMpBar = new PIXI.Graphics();
    this.battleUI.playerMpBar.x = dims.x + LAYOUT.MEDIUM_SPACING;
    this.battleUI.playerMpBar.y = dims.y + LAYOUT.MEDIUM_SPACING + (LAYOUT.EXTRA_LARGE_SPACING * 4) + 5;
    this.addGraphics(this.battleUI.playerMpBar, "ui");

    // Interactive events remain the same...
    playerPanel.interactive = true;
    playerPanel.cursor = "pointer";
    playerPanel.on("pointerdown", () => {
      if (this.selectedSkill && this.isPlayerTurn() && this.selectedSkill.type === "healing") {
        this.targetSelf();
      }
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
      // Use enemy color constants
      enemyPanel.beginFill(COLORS.PIXI.ENEMY_PANEL, COLORS.ALPHA.HIGH);
      enemyPanel.drawRoundedRect(0, 0, enemyDims.width, enemyDims.height, LAYOUT.LARGE_RADIUS);
      enemyPanel.endFill();
      enemyPanel.lineStyle(LAYOUT.MEDIUM_BORDER, COLORS.PIXI.ENEMY_BORDER);
      enemyPanel.drawRoundedRect(0, 0, enemyDims.width, enemyDims.height, LAYOUT.LARGE_RADIUS);
      enemyPanel.x = x;
      enemyPanel.y = y;

      // Enemy name using font constants
      const enemyName = new PIXI.Text(`👹 ${enemy.name}`, {
        fontFamily: FONTS.FAMILY.PRIMARY,
        fontSize: this.layout.fonts.body,
        fill: COLORS.PIXI.WHITE,
        fontWeight: FONTS.WEIGHT.BOLD,
      });
      enemyName.x = x + LAYOUT.MEDIUM_SPACING;
      enemyName.y = y + LAYOUT.MEDIUM_SPACING;
      this.addSprite(enemyName, "ui");

      // Enemy stats using consistent spacing
      const enemyHpText = new PIXI.Text("", {
        fontFamily: FONTS.FAMILY.PRIMARY,
        fontSize: this.layout.fonts.small,
        fill: COLORS.PIXI.WHITE,
      });
      enemyHpText.x = x + LAYOUT.MEDIUM_SPACING;
      enemyHpText.y = y + LAYOUT.MEDIUM_SPACING + LAYOUT.EXTRA_LARGE_SPACING + 5;
      this.addSprite(enemyHpText, "ui");

      // Store enemy display references...
      this.battleUI.enemyDisplays.push({
        panel: enemyPanel,
        hpText: enemyHpText,
        // ... other properties
        enemy: enemy,
      });
    });
  }

  createSkillsPanel() {
    const dims = this.layout.dimensions.skillsPanel;
    const skillsPanel = new PIXI.Graphics();
    
    // Use skills panel color constants
    skillsPanel.beginFill(COLORS.PIXI.SKILLS_PANEL, COLORS.ALPHA.MEDIUM_HIGH);
    skillsPanel.drawRoundedRect(0, 0, dims.width, dims.height, LAYOUT.LARGE_RADIUS);
    skillsPanel.endFill();
    skillsPanel.lineStyle(LAYOUT.MEDIUM_BORDER, COLORS.PIXI.SKILLS_BORDER);
    skillsPanel.drawRoundedRect(0, 0, dims.width, dims.height, LAYOUT.LARGE_RADIUS);
    skillsPanel.x = dims.x;
    skillsPanel.y = dims.y;

    this.addGraphics(skillsPanel, "ui");

    // Skills title using font constants
    const skillsTitle = new PIXI.Text("⚔️ SKILLS", {
      fontFamily: FONTS.FAMILY.PRIMARY,
      fontSize: this.layout.fonts.subtitle,
      fill: COLORS.PIXI.WHITE,
      fontWeight: FONTS.WEIGHT.BOLD,
    });
    skillsTitle.x = dims.x + LAYOUT.MEDIUM_SPACING;
    skillsTitle.y = dims.y + LAYOUT.MEDIUM_SPACING;
    this.addSprite(skillsTitle, "ui");

    // Create skill buttons
    this.createSkillButtons();
  }

  createSkillButtons() {
    this.buttons = [];
    const dims = this.layout.dimensions.skillsPanel;
    
    // Calculate button dimensions using UI constants
    const buttonWidth = dims.width - LAYOUT.PADDING;
    const buttonHeight = this.layout.isMobile ? UI.BUTTON.SKILL_HEIGHT_MOBILE : UI.BUTTON.SKILL_HEIGHT_DESKTOP;
    const buttonSpacing = this.layout.isMobile ? UI.BUTTON.SKILL_SPACING_MOBILE : UI.BUTTON.SKILL_SPACING_DESKTOP;
    const maxVisibleSkills = Math.floor((dims.height - 40) / (buttonHeight + buttonSpacing));

    this.player.skills.slice(0, maxVisibleSkills).forEach((skill, index) => {
      const button = new PIXI.Graphics();
      const buttonX = dims.x + LAYOUT.MEDIUM_SPACING;
      const buttonY = dims.y + 40 + index * (buttonHeight + buttonSpacing);

      // Button background with skill type color from GameConfig
      const skillTypeColor = SkillGenerator.getSkillTypeColor(skill.type);
      button.beginFill(skillTypeColor, COLORS.ALPHA.MEDIUM_LOW);
      button.drawRoundedRect(0, 0, buttonWidth, buttonHeight, LAYOUT.SMALL_RADIUS);
      button.endFill();
      button.lineStyle(LAYOUT.MEDIUM_BORDER, skillTypeColor);
      button.drawRoundedRect(0, 0, buttonWidth, buttonHeight, LAYOUT.SMALL_RADIUS);

      button.x = buttonX;
      button.y = buttonY;
      button.interactive = true;
      button.cursor = "pointer";
      button.skillIndex = index;

      // Skill name and stats using font constants
      const skillText = new PIXI.Text(
        `${skill.name} - ${skill.damage} DMG - ${skill.cost} MP`,
        {
          fontFamily: FONTS.FAMILY.PRIMARY,
          fontSize: this.layout.fonts.body,
          fill: COLORS.PIXI.WHITE,
          fontWeight: FONTS.WEIGHT.BOLD,
        }
      );
      skillText.x = LAYOUT.MEDIUM_SPACING + LAYOUT.EXTRA_LARGE_SPACING;
      skillText.y = LAYOUT.MEDIUM_SPACING;
      button.addChild(skillText);

      // Button events remain the same...
      button.on("pointerover", () => {
        if (this.player.mp >= skill.cost) {
          button.tint = 0xdddddd;
        }
      });

      this.addGraphics(button, "ui");
      this.buttons.push(button);
    });
  }

  createEnemies() {
    // Use enemy templates from GameConfig instead of hardcoded values
    const enemyTemplates = Object.values(ENEMIES.TEMPLATES);

    // Random number of enemies using battle configuration
    const enemyCount = Math.floor(Math.random() * 3) + 1;
    this.enemies = [];

    for (let i = 0; i < enemyCount; i++) {
      const template = enemyTemplates[Math.floor(Math.random() * enemyTemplates.length)];
      
      // Create enemy using template values from GameConfig
      const enemy = {
        name: template.name,
        hp: template.maxHp,
        maxHp: template.maxHp,
        mp: template.maxMp,
        maxMp: template.maxMp,
        attack: template.baseAttack,
        defense: template.baseDefense,
        speed: template.baseSpeed,
        isEnemy: true,
        skills: template.skills || [
          { name: "Attack", damage: template.baseAttack, cost: 0, type: "physical" },
        ],
      };

      this.enemies.push(enemy);
    }

    console.log("Created enemies:", this.enemies.map(e => e.name));
  }

  executeSkill(actor, skill, target) {
    // Use damage calculation from GameConfig
    let damage = skill.damage;
    if (damage > 0) {
      // Attack skill - use variance from BATTLE constants
      damage += Math.floor(Math.random() * (BATTLE.DAMAGE.VARIANCE_MAX * 20)) - 10; // ±10 variance based on constants
      damage = Math.max(BATTLE.DAMAGE.MIN_DAMAGE, damage - (target.defense || 0));
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

    // Clear selection
    this.selectedSkill = null;
    this.buttons.forEach((btn) => (btn.tint = COLORS.PIXI.WHITE));

    // Check battle end
    if (this.checkBattleEnd()) {
      return;
    }

    // Next turn with timing from constants
    setTimeout(() => {
      this.nextTurn();
      this.updateBattleDisplay();
    }, TIMING.BATTLE_ACTION_DELAY);
  }

  // ... rest of the methods remain similar but using constants where applicable
}