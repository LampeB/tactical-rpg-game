import { PixiScene } from '../core/PixiScene.js';
import { SkillGenerator } from '../core/SkillGenerator.js';

export class PixiBattleScene extends PixiScene {
    constructor() {
        super();
        this.player = null;
        this.enemies = [];
        this.currentTurn = 'player';
        this.selectedSkill = null;
        this.selectedTarget = null;
        this.battleLog = [];
        this.logMaxLines = 12;
        this.turnOrder = [];
        this.currentTurnIndex = 0;
        this.battleState = 'selecting'; // selecting, animating, victory, defeat
        this.animationQueue = [];
        this.battleUI = {};
        this.buttons = [];
        this.hoveredButton = -1;
        
        // Battle stats
        this.battleStats = {
            turnCount: 0,
            damageDealt: 0,
            skillsUsed: 0
        };
    }
    
    onEnter() {
        super.onEnter();
        
        // Initialize battle
        this.initializeBattle();
        
        // Create battle UI
        this.createBattleBackground();
        this.createBattleUI();
        
        // Update game mode display
        const gameModeBtn = document.getElementById('gameMode');
        if (gameModeBtn) {
            gameModeBtn.textContent = '⚔️ BATTLE';
        }
        
        // ADD THIS - Update navigation buttons
        if (this.engine && this.engine.updateNavButtons) {
            this.engine.updateNavButtons('battle');
        }
        
        console.log('Battle scene loaded with PixiJS');
    }
    
    initializeBattle() {
        // Get inventory from inventory scene
        const inventoryScene = this.engine.scenes.get('inventory');
        let playerSkills = [];
        
        if (inventoryScene && inventoryScene.inventoryGrid) {
            // Generate skills from inventory
            playerSkills = SkillGenerator.generateSkillsFromInventory(inventoryScene.inventoryGrid);
            console.log('Generated skills from inventory:', playerSkills);
        } else {
            // Fallback to default skills
            playerSkills = SkillGenerator.getDefaultSkills();
            console.log('Using default skills (no inventory found)');
        }
    
        // Create player with dynamic skills
        this.player = {
            name: 'Hero',
            hp: 100,
            maxHp: 100,
            mp: 50,
            maxMp: 50,
            level: 1,
            attack: 20,
            defense: 10,
            speed: 12,
            skills: playerSkills
        };
    
        // Create enemies
        this.createEnemies();
    
        // Calculate turn order
        this.calculateTurnOrder();
    
        // Initialize battle log
        this.battleLog = [];
        this.addToBattleLog('Battle begins!');
        this.addToBattleLog(`${this.player.name} vs ${this.enemies.map(e => e.name).join(', ')}`);
        
        // Log player's available skills
        const skillList = this.player.skills.map(s => 
            `${s.name} (${s.sourceItems.join(', ')})`
        ).join(', ');
        this.addToBattleLog(`Available skills: ${skillList}`);
    }
    
    createEnemies() {
        const enemyTemplates = [
            {
                name: 'Goblin',
                hp: 60,
                maxHp: 60,
                mp: 20,
                maxMp: 20,
                attack: 15,
                defense: 5,
                speed: 8,
                skills: [
                    { name: 'Scratch', damage: 18, cost: 0, type: 'physical' },
                    { name: 'Bite', damage: 22, cost: 5, type: 'physical' }
                ]
            },
            {
                name: 'Orc Warrior',
                hp: 80,
                maxHp: 80,
                mp: 15,
                maxMp: 15,
                attack: 25,
                defense: 8,
                speed: 6,
                skills: [
                    { name: 'Heavy Strike', damage: 30, cost: 0, type: 'physical' },
                    { name: 'Battle Roar', damage: 15, cost: 8, type: 'magic' }
                ]
            },
            {
                name: 'Dark Wizard',
                hp: 70,
                maxHp: 70,
                mp: 60,
                maxMp: 60,
                attack: 12,
                defense: 4,
                speed: 10,
                skills: [
                    { name: 'Dark Bolt', damage: 28, cost: 12, type: 'magic' },
                    { name: 'Drain Life', damage: 20, cost: 15, type: 'magic' },
                    { name: 'Heal', damage: -25, cost: 10, type: 'healing' }
                ]
            }
        ];
        
        // Random number of enemies (1-3)
        const enemyCount = Math.floor(Math.random() * 3) + 1;
        this.enemies = [];
        
        for (let i = 0; i < enemyCount; i++) {
            const template = enemyTemplates[Math.floor(Math.random() * enemyTemplates.length)];
            const enemy = { ...template };
            enemy.isEnemy = true;
            enemy.id = i;
            this.enemies.push(enemy);
        }
    }
    
    calculateTurnOrder() {
        const allCombatants = [this.player, ...this.enemies.filter(e => e.hp > 0)];
        
        // Sort by speed (higher speed goes first)
        this.turnOrder = allCombatants.sort((a, b) => {
            const speedA = a.speed + Math.random() * 5;
            const speedB = b.speed + Math.random() * 5;
            return speedB - speedA;
        });
        
        this.currentTurnIndex = 0;
        console.log('Turn order:', this.turnOrder.map(c => c.name));
    }
    
    createBattleBackground() {
        // Battle arena background
        const bg = new PIXI.Graphics();
        bg.beginFill(0x4a148c); // Deep purple
        bg.drawRect(0, 0, this.engine.width, this.engine.height);
        bg.endFill();
        
        // Add some atmospheric elements
        for (let i = 0; i < 20; i++) {
            bg.beginFill(0x6a1b9a, 0.3);
            bg.drawCircle(
                Math.random() * this.engine.width,
                Math.random() * this.engine.height,
                Math.random() * 30 + 10
            );
            bg.endFill();
        }
        
        this.addGraphics(bg, 'background');
        
        // Title
        const title = new PIXI.Text('BATTLE ARENA', {
            fontFamily: 'Arial',
            fontSize: 32,
            fill: 0xffffff,
            align: 'center',
            fontWeight: 'bold'
        });
        title.anchor.set(0.5);
        title.x = this.engine.width / 2;
        title.y = 40;
        this.addSprite(title, 'ui');
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
    }
    
    createPlayerDisplay() {
        const playerPanel = new PIXI.Graphics();
        playerPanel.beginFill(0x2e7d32, 0.8);
        playerPanel.drawRoundedRect(0, 0, 300, 150, 10);
        playerPanel.endFill();
        playerPanel.lineStyle(2, 0x4caf50);
        playerPanel.drawRoundedRect(0, 0, 300, 150, 10);
        playerPanel.x = 50;
        playerPanel.y = 100;
        
        this.addGraphics(playerPanel, 'ui');
        
        // Player name
        const playerName = new PIXI.Text(`🛡️ ${this.player.name} (Lv.${this.player.level})`, {
            fontFamily: 'Arial',
            fontSize: 16,
            fill: 0xffffff,
            fontWeight: 'bold'
        });
        playerName.x = 60;
        playerName.y = 115;
        this.addSprite(playerName, 'ui');
        
        // Player stats will be updated in updateBattleDisplay
        this.battleUI.playerHpText = new PIXI.Text('', {
            fontFamily: 'Arial',
            fontSize: 12,
            fill: 0xffffff
        });
        this.battleUI.playerHpText.x = 60;
        this.battleUI.playerHpText.y = 140;
        this.addSprite(this.battleUI.playerHpText, 'ui');
        
        this.battleUI.playerMpText = new PIXI.Text('', {
            fontFamily: 'Arial',
            fontSize: 12,
            fill: 0xffffff
        });
        this.battleUI.playerMpText.x = 60;
        this.battleUI.playerMpText.y = 160;
        this.addSprite(this.battleUI.playerMpText, 'ui');
        
        // HP Bar
        this.battleUI.playerHpBar = new PIXI.Graphics();
        this.battleUI.playerHpBar.x = 60;
        this.battleUI.playerHpBar.y = 180;
        this.addGraphics(this.battleUI.playerHpBar, 'ui');
        
        // MP Bar
        this.battleUI.playerMpBar = new PIXI.Graphics();
        this.battleUI.playerMpBar.x = 60;
        this.battleUI.playerMpBar.y = 200;
        this.addGraphics(this.battleUI.playerMpBar, 'ui');
    }
    
    createEnemyDisplays() {
        this.battleUI.enemyDisplays = [];
        
        this.enemies.forEach((enemy, index) => {
            const enemyPanel = new PIXI.Graphics();
            enemyPanel.beginFill(0xd32f2f, 0.8);
            enemyPanel.drawRoundedRect(0, 0, 250, 120, 10);
            enemyPanel.endFill();
            enemyPanel.lineStyle(2, 0xf44336);
            enemyPanel.drawRoundedRect(0, 0, 250, 120, 10);
            
            const x = 800 + (index % 2) * 280;
            const y = 100 + Math.floor(index / 2) * 140;
            enemyPanel.x = x;
            enemyPanel.y = y;
            
            // Make enemy panel interactive for targeting
            enemyPanel.interactive = true;
            enemyPanel.cursor = 'pointer';
            enemyPanel.enemyId = index;
            
            enemyPanel.on('pointerdown', () => {
                if (this.selectedSkill && this.isPlayerTurn()) {
                    this.targetEnemy(enemy);
                }
            });
            
            enemyPanel.on('pointerover', () => {
                if (this.selectedSkill && this.isPlayerTurn()) {
                    enemyPanel.tint = 0xffff88;
                }
            });
            
            enemyPanel.on('pointerout', () => {
                enemyPanel.tint = 0xffffff;
            });
            
            this.addGraphics(enemyPanel, 'ui');
            
            // Enemy name
            const enemyName = new PIXI.Text(`👹 ${enemy.name}`, {
                fontFamily: 'Arial',
                fontSize: 14,
                fill: 0xffffff,
                fontWeight: 'bold'
            });
            enemyName.x = x + 10;
            enemyName.y = y + 10;
            this.addSprite(enemyName, 'ui');
            
            // Enemy stats
            const enemyHpText = new PIXI.Text('', {
                fontFamily: 'Arial',
                fontSize: 11,
                fill: 0xffffff
            });
            enemyHpText.x = x + 10;
            enemyHpText.y = y + 35;
            this.addSprite(enemyHpText, 'ui');
            
            const enemyMpText = new PIXI.Text('', {
                fontFamily: 'Arial',
                fontSize: 11,
                fill: 0xffffff
            });
            enemyMpText.x = x + 10;
            enemyMpText.y = y + 50;
            this.addSprite(enemyMpText, 'ui');
            
            // HP Bar
            const enemyHpBar = new PIXI.Graphics();
            enemyHpBar.x = x + 10;
            enemyHpBar.y = y + 70;
            this.addGraphics(enemyHpBar, 'ui');
            
            // MP Bar
            const enemyMpBar = new PIXI.Graphics();
            enemyMpBar.x = x + 10;
            enemyMpBar.y = y + 85;
            this.addGraphics(enemyMpBar, 'ui');
            
            this.battleUI.enemyDisplays.push({
                panel: enemyPanel,
                hpText: enemyHpText,
                mpText: enemyMpText,
                hpBar: enemyHpBar,
                mpBar: enemyMpBar,
                enemy: enemy
            });
        });
    }
    
    createSkillsPanel() {
        const skillsPanel = new PIXI.Graphics();
        skillsPanel.beginFill(0x1976d2, 0.9);
        skillsPanel.drawRoundedRect(0, 0, 400, 250, 10);
        skillsPanel.endFill();
        skillsPanel.lineStyle(2, 0x2196f3);
        skillsPanel.drawRoundedRect(0, 0, 400, 250, 10);
        skillsPanel.x = 50;
        skillsPanel.y = 300;
        
        this.addGraphics(skillsPanel, 'ui');
        
        // Skills title
        const skillsTitle = new PIXI.Text('⚔️ SKILLS', {
            fontFamily: 'Arial',
            fontSize: 16,
            fill: 0xffffff,
            fontWeight: 'bold'
        });
        skillsTitle.x = 60;
        skillsTitle.y = 315;
        this.addSprite(skillsTitle, 'ui');
        
        // Create skill buttons
        this.createSkillButtons();
    }
    
    createSkillButtons() {
        this.buttons = [];
        
        this.player.skills.forEach((skill, index) => {
            const button = new PIXI.Graphics();
            const buttonWidth = 360;
            const buttonHeight = 45;
            const buttonX = 60;
            const buttonY = 340 + index * 50;
            
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
            button.cursor = 'pointer';
            button.skillIndex = index;
            
            // Skill icon
            const skillIcon = new PIXI.Graphics();
            skillIcon.beginFill(skillTypeColor);
            skillIcon.drawCircle(20, 22, 15);
            skillIcon.endFill();
            button.addChild(skillIcon);
            
            // Skill name and stats
            const skillText = new PIXI.Text(`${skill.name} - ${skill.damage} DMG - ${skill.cost} MP`, {
                fontFamily: 'Arial',
                fontSize: 12,
                fill: 0xffffff,
                fontWeight: 'bold'
            });
            skillText.x = 45;
            skillText.y = 8;
            button.addChild(skillText);
            
            // Source items
            const sourceText = new PIXI.Text(`From: ${skill.sourceItems.join(' + ')}`, {
                fontFamily: 'Arial',
                fontSize: 10,
                fill: 0xcccccc
            });
            sourceText.x = 45;
            sourceText.y = 25;
            button.addChild(sourceText);
            
            // Button events
            button.on('pointerover', () => {
                button.tint = 0xdddddd;
            });
            
            button.on('pointerout', () => {
                button.tint = 0xffffff;
            });
            
            button.on('pointerdown', () => {
                this.selectSkill(skill, index);
            });
            
            this.addGraphics(button, 'ui');
            this.buttons.push(button);
        });
    }
    
    createBattleLogPanel() {
        const logPanel = new PIXI.Graphics();
        logPanel.beginFill(0x263238, 0.9);
        logPanel.drawRoundedRect(0, 0, 650, 200, 10);
        logPanel.endFill();
        logPanel.lineStyle(2, 0x455a64);
        logPanel.drawRoundedRect(0, 0, 650, 200, 10);
        logPanel.x = 500;
        logPanel.y = 350;
        
        this.addGraphics(logPanel, 'ui');
        
        // Log title
        const logTitle = new PIXI.Text('📜 BATTLE LOG', {
            fontFamily: 'Arial',
            fontSize: 14,
            fill: 0xffffff,
            fontWeight: 'bold'
        });
        logTitle.x = 515;
        logTitle.y = 365;
        this.addSprite(logTitle, 'ui');
        
        // Battle log text container
        this.battleUI.logContainer = new PIXI.Container();
        this.battleUI.logContainer.x = 515;
        this.battleUI.logContainer.y = 390;
        this.addSprite(this.battleUI.logContainer, 'ui');
    }
    
    createTurnIndicator() {
        this.battleUI.turnIndicator = new PIXI.Text('', {
            fontFamily: 'Arial',
            fontSize: 18,
            fill: 0xffd700,
            fontWeight: 'bold',
            align: 'center'
        });
        this.battleUI.turnIndicator.anchor.set(0.5);
        this.battleUI.turnIndicator.x = this.engine.width / 2;
        this.battleUI.turnIndicator.y = 80;
        this.addSprite(this.battleUI.turnIndicator, 'ui');
    }
    
    createActionButtons() {
        const actionButtons = [
            { text: '🏃 Run Away', action: () => this.runAway() },
            { text: '🔄 Skip Turn', action: () => this.skipTurn() }
        ];
        
        actionButtons.forEach((btnData, index) => {
            const button = new PIXI.Graphics();
            button.beginFill(0x795548);
            button.drawRoundedRect(0, 0, 120, 35, 5);
            button.endFill();
            button.lineStyle(1, 0x8d6e63);
            button.drawRoundedRect(0, 0, 120, 35, 5);
            
            button.x = 60 + index * 140;
            button.y = 600;
            button.interactive = true;
            button.cursor = 'pointer';
            
            const buttonText = new PIXI.Text(btnData.text, {
                fontFamily: 'Arial',
                fontSize: 11,
                fill: 0xffffff,
                align: 'center'
            });
            buttonText.anchor.set(0.5);
            buttonText.x = 60;
            buttonText.y = 17;
            button.addChild(buttonText);
            
            button.on('pointerover', () => button.tint = 0xcccccc);
            button.on('pointerout', () => button.tint = 0xffffff);
            button.on('pointerdown', btnData.action);
            
            this.addGraphics(button, 'ui');
        });
    }
    
    // Battle logic methods
    getCurrentActor() {
        if (this.turnOrder.length === 0) return null;
        return this.turnOrder[this.currentTurnIndex];
    }
    
    isPlayerTurn() {
        return this.getCurrentActor() === this.player && this.battleState === 'selecting';
    }
    
    selectSkill(skill, index) {
        if (!this.isPlayerTurn()) return;
        
        if (this.player.mp < skill.cost) {
            this.addToBattleLog('Not enough MP!');
            return;
        }
        
        this.selectedSkill = skill;
        this.addToBattleLog(`Selected ${skill.name}. Choose target or click again to use.`);
        
        // If it's a healing skill, target self immediately
        if (skill.type === 'healing') {
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
            this.addToBattleLog('Cannot target defeated enemy!');
            return;
        }
        
        if (this.selectedSkill.type === 'healing') {
            this.addToBattleLog('Cannot use healing skills on enemies!');
            return;
        }
        
        this.executeSkill(this.player, this.selectedSkill, enemy);
    }
    
    targetSelf() {
        if (!this.selectedSkill || !this.isPlayerTurn()) return;
        
        if (this.selectedSkill.type !== 'healing') {
            this.addToBattleLog('Cannot target yourself with attack skills!');
            return;
        }
        
        this.executeSkill(this.player, this.selectedSkill, this.player);
    }
    
    executeSkill(actor, skill, target) {
        // Calculate damage
        let damage = skill.damage;
        if (damage > 0) { // Attack skill
            damage += Math.floor(Math.random() * 10) - 5; // ±5 variance
            damage = Math.max(1, damage - (target.defense || 0));
        } else { // Healing skill
            damage = Math.abs(damage) + Math.floor(Math.random() * 5);
        }
        
        // Apply skill cost
        actor.mp -= skill.cost;
        actor.mp = Math.max(0, actor.mp);
        
        // Apply effect
        if (skill.type === 'healing') {
            target.hp = Math.min(target.maxHp, target.hp + damage);
            this.addToBattleLog(`${actor.name} heals ${target.name} for ${damage} HP!`);
        } else {
            target.hp -= damage;
            target.hp = Math.max(0, target.hp);
            this.addToBattleLog(`${actor.name} uses ${skill.name} on ${target.name} for ${damage} damage!`);
            
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
        this.buttons.forEach(btn => btn.tint = 0xffffff);
        
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
        while (this.getCurrentActor()?.hp <= 0 && attempts < this.turnOrder.length) {
            this.currentTurnIndex = (this.currentTurnIndex + 1) % this.turnOrder.length;
            attempts++;
        }
        
        const currentActor = this.getCurrentActor();
        if (currentActor?.isEnemy) {
            // AI turn
            this.battleState = 'ai_turn';
            setTimeout(() => this.executeAITurn(), 1000);
        } else {
            // Player turn
            this.battleState = 'selecting';
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
        const availableSkills = enemy.skills.filter(skill => enemy.mp >= skill.cost);
        
        if (availableSkills.length === 0) {
            this.addToBattleLog(`${enemy.name} has no MP and skips turn.`);
            this.nextTurn();
            return;
        }
        
        const selectedSkill = availableSkills[Math.floor(Math.random() * availableSkills.length)];
        
        // Choose target
        let target;
        if (selectedSkill.type === 'healing') {
            // Heal weakest ally or self
            const aliveEnemies = this.enemies.filter(e => e.hp > 0);
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
        const aliveEnemies = this.enemies.filter(e => e.hp > 0);
        
        if (this.player.hp <= 0) {
            this.battleState = 'defeat';
            this.addToBattleLog('💀 DEFEAT! You have been defeated!');
            this.showBattleEndScreen(false);
            return true;
        }
        
        if (aliveEnemies.length === 0) {
            this.battleState = 'victory';
            this.addToBattleLog('🎉 VICTORY! All enemies defeated!');
            this.showBattleEndScreen(true);
            return true;
        }
        
        return false;
    }
    
    showBattleEndScreen(victory) {
        // Semi-transparent overlay
        const overlay = new PIXI.Graphics();
        overlay.beginFill(0x000000, 0.8);
        overlay.drawRect(0, 0, this.engine.width, this.engine.height);
        overlay.endFill();
        overlay.interactive = true;
        
        // Result panel
        const panel = new PIXI.Graphics();
        panel.beginFill(victory ? 0x2e7d32 : 0xd32f2f);
        panel.drawRoundedRect(0, 0, 500, 350, 15);
        panel.endFill();
        panel.lineStyle(3, 0xffffff);
        panel.drawRoundedRect(0, 0, 500, 350, 15);
        
        panel.x = this.engine.width / 2 - 250;
        panel.y = this.engine.height / 2 - 175;
        
        // Title
        const title = new PIXI.Text(victory ? '🎉 VICTORY!' : '💀 DEFEAT!', {
            fontFamily: 'Arial',
            fontSize: 36,
            fill: 0xffffff,
            fontWeight: 'bold',
            align: 'center'
        });
        title.anchor.set(0.5);
        title.x = 250;
        title.y = 60;
        panel.addChild(title);
        
        // Battle stats
        const statsText = victory ? 
            `Turns: ${this.battleStats.turnCount}\nDamage Dealt: ${this.battleStats.damageDealt}\nSkills Used: ${this.battleStats.skillsUsed}\n\nReward: 100 Gold + Experience!` :
            `You fought bravely for ${this.battleStats.turnCount} turns.\nDamage Dealt: ${this.battleStats.damageDealt}\n\nBetter luck next time!`;
            
        const stats = new PIXI.Text(statsText, {
            fontFamily: 'Arial',
            fontSize: 14,
            fill: 0xffffff,
            align: 'center',
            lineHeight: 20
        });
        stats.anchor.set(0.5);
        stats.x = 250;
        stats.y = 150;
        panel.addChild(stats);
        
        // Continue button
        const continueBtn = new PIXI.Graphics();
        continueBtn.beginFill(0x1976d2);
        continueBtn.drawRoundedRect(0, 0, 150, 40, 5);
        continueBtn.endFill();
        continueBtn.lineStyle(2, 0x2196f3);
        continueBtn.drawRoundedRect(0, 0, 150, 40, 5);
        continueBtn.x = 175;
        continueBtn.y = 250;
        continueBtn.interactive = true;
        continueBtn.cursor = 'pointer';
        
        const btnText = new PIXI.Text('Continue', {
            fontFamily: 'Arial',
            fontSize: 16,
            fill: 0xffffff,
            fontWeight: 'bold'
        });
        btnText.anchor.set(0.5);
        btnText.x = 75;
        btnText.y = 20;
        continueBtn.addChild(btnText);
        
        continueBtn.on('pointerover', () => continueBtn.tint = 0xcccccc);
        continueBtn.on('pointerout', () => continueBtn.tint = 0xffffff);
        continueBtn.on('pointerdown', () => {
            this.engine.switchScene('world');
        });
        
        panel.addChild(continueBtn);
        overlay.addChild(panel);
        this.addSprite(overlay, 'ui');
    }
    
    runAway() {
        if (!this.isPlayerTurn()) return;
        
        if (Math.random() < 0.7) {
        this.addToBattleLog('Successfully ran away!');
            setTimeout(() => {
                this.engine.switchScene('world');
            }, 1500);
        } else {
            this.addToBattleLog('Could not escape!');
            this.nextTurn();
        }
    }
    
    skipTurn() {
        if (!this.isPlayerTurn()) return;
        
        this.addToBattleLog(`${this.player.name} skips turn.`);
        this.nextTurn();
    }
    
    addToBattleLog(message) {
        this.battleLog.push(message);
        if (this.battleLog.length > this.logMaxLines) {
            this.battleLog.shift();
        }
        
        this.updateBattleLogDisplay();
        console.log('Battle:', message);
    }
    
    updateBattleLogDisplay() {
        if (!this.battleUI.logContainer) return;
        
        // Clear existing log entries
        this.battleUI.logContainer.removeChildren();
        
        // Add current log entries
        this.battleLog.forEach((message, index) => {
            const logEntry = new PIXI.Text(message, {
                fontFamily: 'Arial',
                fontSize: 11,
                fill: 0xecf0f1,
                wordWrap: true,
                wordWrapWidth: 620
            });
            logEntry.y = index * 15;
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
            
            // Background
            this.battleUI.playerHpBar.beginFill(0x333333);
            this.battleUI.playerHpBar.drawRect(0, 0, 200, 8);
            this.battleUI.playerHpBar.endFill();
            
            // HP fill
            const hpColor = hpPercent > 0.5 ? 0x4caf50 : hpPercent > 0.25 ? 0xff9800 : 0xf44336;
            this.battleUI.playerHpBar.beginFill(hpColor);
            this.battleUI.playerHpBar.drawRect(0, 0, 200 * hpPercent, 8);
            this.battleUI.playerHpBar.endFill();
        }
        
        // Update player MP bar
        if (this.battleUI.playerMpBar) {
            this.battleUI.playerMpBar.clear();
            const mpPercent = this.player.mp / this.player.maxMp;
            
            // Background
            this.battleUI.playerMpBar.beginFill(0x333333);
            this.battleUI.playerMpBar.drawRect(0, 0, 200, 6);
            this.battleUI.playerMpBar.endFill();
            
            // MP fill
            this.battleUI.playerMpBar.beginFill(0x2196f3);
            this.battleUI.playerMpBar.drawRect(0, 0, 200 * mpPercent, 6);
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
            
            // Background
            display.hpBar.beginFill(0x333333);
            display.hpBar.drawRect(0, 0, 150, 8);
            display.hpBar.endFill();
            
            // HP fill
            const enemyHpColor = enemyHpPercent > 0.5 ? 0x4caf50 : enemyHpPercent > 0.25 ? 0xff9800 : 0xf44336;
            display.hpBar.beginFill(enemyHpColor);
            display.hpBar.drawRect(0, 0, 150 * enemyHpPercent, 8);
            display.hpBar.endFill();
            
            // Update enemy MP bar
            display.mpBar.clear();
            const enemyMpPercent = Math.max(0, enemy.mp / enemy.maxMp);
            
            // Background
            display.mpBar.beginFill(0x333333);
            display.mpBar.drawRect(0, 0, 150, 6);
            display.mpBar.endFill();
            
            // MP fill
            display.mpBar.beginFill(0x2196f3);
            display.mpBar.drawRect(0, 0, 150 * enemyMpPercent, 6);
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
        
        // Process any animations
        if (this.animationQueue.length > 0) {
            this.animationQueue = this.animationQueue.filter(anim => {
                anim.duration -= deltaTime;
                return anim.duration > 0;
            });
        }
    }
    
    // Input handling
    handleKeyDown(event) {
        if (event.code === 'Escape') {
            // Quick escape to world (with confirmation in a real game)
            this.engine.switchScene('world');
        } else if (event.code === 'Space') {
            if (this.isPlayerTurn()) {
                this.skipTurn();
            }
        } else if (event.code >= 'Digit1' && event.code <= 'Digit4') {
            // Quick skill selection with number keys
            const skillIndex = parseInt(event.code.replace('Digit', '')) - 1;
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
            if (mousePos.x >= 50 && mousePos.x <= 350 && 
                mousePos.y >= 100 && mousePos.y <= 250) {
                this.targetSelf();
            }
        }
    }
    
    // Cleanup when exiting scene
    onExit() {
        // Clear any ongoing animations or intervals
        this.animationQueue = [];
        
        // Reset battle state
        this.battleState = 'selecting';
        this.selectedSkill = null;
        this.selectedTarget = null;
        
        super.onExit();
    }
}