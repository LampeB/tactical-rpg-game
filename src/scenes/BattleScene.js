import { Scene } from '../core/Scene.js';
import { Character } from '../models/Character.js';
import { Grid } from '../models/Grid.js';
import { GameData } from '../data/GameData.js';

export class BattleScene extends Scene {
    constructor() {
        super();
        this.player = new Character('Hero', 100, 50);
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
        
        this.initializeBattle();
    }
    
    initializeBattle() {
        // Set up player inventory (empty for now - will be copied from inventory scene)
        this.player.inventory = new Grid(0, 0, 10, 8, 40);
        
        // Create enemies based on difficulty
        this.createEnemies('normal');
        
        // Determine turn order
        this.calculateTurnOrder();
        
        this.addToLog('Battle begins!');
        this.addToLog(`${this.player.name} vs ${this.enemies.map(e => e.name).join(', ')}`);
    }
    
    createEnemies(difficulty = 'normal') {
        const templates = GameData.createEnemyTemplates();
        
        switch (difficulty) {
            case 'easy':
                this.enemies = [this.createEnemyFromTemplate(templates.goblin)];
                break;
            case 'normal':
                this.enemies = [
                    this.createEnemyFromTemplate(templates.goblin),
                    this.createEnemyFromTemplate(templates.orc)
                ];
                break;
            case 'hard':
                this.enemies = [
                    this.createEnemyFromTemplate(templates.goblin),
                    this.createEnemyFromTemplate(templates.orc),
                    this.createEnemyFromTemplate(templates.wizard)
                ];
                break;
        }
    }
    
    createEnemyFromTemplate(template) {
        const enemy = new Character(template.name, template.maxHp, template.maxMp);
        enemy.baseAttack = template.baseAttack;
        enemy.baseDefense = template.baseDefense;
        enemy.baseSpeed = template.baseSpeed;
        enemy.aiSkills = template.skills;
        enemy.isEnemy = true;
        return enemy;
    }
    
    calculateTurnOrder() {
        const allCombatants = [this.player, ...this.enemies.filter(e => e.isAlive())];
        
        // Sort by speed (higher speed goes first)
        this.turnOrder = allCombatants.sort((a, b) => {
            const speedA = a.getSpeed() + Math.random() * 5; // Add some randomness
            const speedB = b.getSpeed() + Math.random() * 5;
            return speedB - speedA;
        });
        
        this.currentTurnIndex = 0;
    }
    
    getCurrentActor() {
        if (this.turnOrder.length === 0) return null;
        return this.turnOrder[this.currentTurnIndex];
    }
    
    nextTurn() {
        this.currentTurnIndex = (this.currentTurnIndex + 1) % this.turnOrder.length;
        
        // Skip defeated characters
        let attempts = 0;
        while (!this.getCurrentActor()?.isAlive() && attempts < this.turnOrder.length) {
            this.currentTurnIndex = (this.currentTurnIndex + 1) % this.turnOrder.length;
            attempts++;
        }
        
        // Check for battle end conditions
        if (this.checkBattleEnd()) {
            return;
        }
        
        const currentActor = this.getCurrentActor();
        if (currentActor?.isEnemy) {
            // AI turn
            setTimeout(() => this.executeAITurn(), 1000);
        } else {
            // Player turn
            this.battleState = 'selecting';
            this.selectedSkill = null;
            this.selectedTarget = null;
        }
    }
    
    checkBattleEnd() {
        const aliveEnemies = this.enemies.filter(e => e.isAlive());
        
        if (!this.player.isAlive()) {
            this.battleState = 'defeat';
            this.addToLog('You have been defeated!');
            return true;
        }
        
        if (aliveEnemies.length === 0) {
            this.battleState = 'victory';
            this.addToLog('Victory! All enemies defeated!');
            this.giveRewards();
            return true;
        }
        
        return false;
    }
    
    giveRewards() {
        const expGained = this.enemies.length * 25 + Math.floor(Math.random() * 20);
        const leveledUp = this.player.gainExperience(expGained);
        
        this.addToLog(`Gained ${expGained} experience!`);
        
        if (leveledUp) {
            const levelResult = this.player.levelUp();
            this.addToLog(levelResult.message);
        }
    }
    
    executeAITurn() {
        const enemy = this.getCurrentActor();
        if (!enemy || !enemy.isAlive()) {
            this.nextTurn();
            return;
        }
        
        // Simple AI: random skill, target player
        const availableSkills = enemy.aiSkills.filter(skill => enemy.mp >= skill.cost);
        
        if (availableSkills.length === 0) {
            this.addToLog(`${enemy.name} has no MP and skips turn.`);
            this.nextTurn();
            return;
        }
        
        const selectedSkill = availableSkills[Math.floor(Math.random() * availableSkills.length)];
        const target = selectedSkill.type === 'healing' ? enemy : this.player;
        
        this.executeSkill(enemy, selectedSkill, target);
    }
    
    executeSkill(actor, skill, target) {
        const result = actor.useSkill(skill, target);
        
        if (result.success) {
            this.addToLog(result.message);
            
            // Add animation to queue
            this.animationQueue.push({
                type: 'skill',
                actor: actor,
                target: target,
                skill: skill,
                damage: result.damageDealt || 0,
                duration: 500
            });
            
            this.battleState = 'animating';
            setTimeout(() => {
                this.battleState = 'selecting';
                this.nextTurn();
            }, 600);
        } else {
            this.addToLog(result.message);
            this.nextTurn();
        }
    }
    
    addToLog(message) {
        this.battleLog.push(message);
        if (this.battleLog.length > this.logMaxLines) {
            this.battleLog.shift();
        }
    }
    
    onEnter() {
        super.onEnter();
        
        // Battle controls
        this.engine.inputManager.onKeyPress('KeyM', () => this.engine.switchScene('menu'));
        this.engine.inputManager.onKeyPress('KeyI', () => this.engine.switchScene('inventory'));
        this.engine.inputManager.onKeyPress('Escape', () => this.engine.switchScene('menu'));
        
        // Battle actions
        this.engine.inputManager.onKeyPress('KeyA', () => this.quickAttack());
        this.engine.inputManager.onKeyPress('KeyH', () => this.quickHeal());
        this.engine.inputManager.onKeyPress('Space', () => this.skipTurn());
        
        // Reset battle state
        this.battleState = 'selecting';
        this.selectedSkill = null;
        this.selectedTarget = null;
    }
    
    quickAttack() {
        if (!this.isPlayerTurn()) return;
        
        const skills = this.player.getAvailableSkills();
        const attackSkill = skills.find(s => s.type === 'physical' || s.type === 'magic');
        
        if (attackSkill && this.enemies.length > 0) {
            const target = this.enemies.find(e => e.isAlive());
            if (target) {
                this.executeSkill(this.player, attackSkill, target);
            }
        }
    }
    
    quickHeal() {
        if (!this.isPlayerTurn()) return;
        
        const skills = this.player.getAvailableSkills();
        const healSkill = skills.find(s => s.type === 'healing');
        
        if (healSkill) {
            this.executeSkill(this.player, healSkill, this.player);
        }
    }
    
    skipTurn() {
        if (!this.isPlayerTurn()) return;
        
        this.addToLog(`${this.player.name} skips turn.`);
        this.nextTurn();
    }
    
    isPlayerTurn() {
        return this.battleState === 'selecting' && 
               this.getCurrentActor() === this.player;
    }
    
    update(deltaTime) {
        if (this.engine.inputManager.isMouseClicked()) {
            this.handleMouseClick();
        }
        
        // Process animations
        if (this.animationQueue.length > 0) {
            // Simple animation processing
            this.animationQueue = this.animationQueue.filter(anim => {
                anim.duration -= deltaTime;
                return anim.duration > 0;
            });
        }
    }
    
    handleMouseClick() {
        if (!this.isPlayerTurn()) return;
        
        const mouse = this.engine.inputManager.getMousePosition();
        
        // Check skill selection
        if (this.handleSkillClick(mouse)) return;
        
        // Check target selection
        if (this.selectedSkill) {
            this.handleTargetClick(mouse);
        }
    }
    
    handleSkillClick(mouse) {
        const skills = this.player.getAvailableSkills();
        const skillPanelX = 50;
        const skillPanelY = 400;
        const skillButtonHeight = 35;
        const skillButtonWidth = 300;
        
        for (let i = 0; i < skills.length; i++) {
            const skill = skills[i];
            const buttonY = skillPanelY + 30 + i * (skillButtonHeight + 5);
            
            if (mouse.x >= skillPanelX + 10 && 
                mouse.x <= skillPanelX + 10 + skillButtonWidth &&
                mouse.y >= buttonY && 
                mouse.y <= buttonY + skillButtonHeight) {
                
                if (this.player.canUseSkill(skill)) {
                    this.selectedSkill = skill;
                    this.addToLog(`Selected ${skill.name}. Choose target.`);
                    return true;
                } else {
                    this.addToLog(`Not enough MP for ${skill.name}!`);
                    return true;
                }
            }
        }
        
        return false;
    }
    
    handleTargetClick(mouse) {
        // Check if clicking on an enemy
        for (let i = 0; i < this.enemies.length; i++) {
            const enemy = this.enemies[i];
            if (!enemy.isAlive()) continue;
            
            const enemyX = 700 + (i % 2) * 250;
            const enemyY = 100 + Math.floor(i / 2) * 200;
            
            if (mouse.x >= enemyX && mouse.x <= enemyX + 200 &&
                mouse.y >= enemyY && mouse.y <= enemyY + 150) {
                
                if (this.selectedSkill.type === 'healing') {
                    this.addToLog('Cannot target enemy with healing spell!');
                    return;
                }
                
                this.executeSkill(this.player, this.selectedSkill, enemy);
                return;
            }
        }
        
        // Check if clicking on player (for healing)
        if (mouse.x >= 100 && mouse.x <= 300 && mouse.y >= 100 && mouse.y <= 250) {
            if (this.selectedSkill.type === 'healing') {
                this.executeSkill(this.player, this.selectedSkill, this.player);
            } else {
                this.addToLog('Cannot target yourself with attack!');
            }
        }
    }
    
    render(ctx) {
        // Background
        ctx.fillStyle = '#8e44ad';
        ctx.fillRect(0, 0, this.engine.width, this.engine.height);
        
        // Battle arena background
        ctx.fillStyle = 'rgba(44, 62, 80, 0.3)';
        ctx.fillRect(50, 50, this.engine.width - 100, 300);
        
        // Title
        ctx.fillStyle = '#ffffff';
        ctx.font = '28px Arial';
        ctx.textAlign = 'center';
        ctx.fillText('BATTLE SYSTEM', this.engine.width / 2, 30);
        
        // Render characters
        this.renderPlayer(ctx);
        this.renderEnemies(ctx);
        
        // Render UI
        this.renderSkillPanel(ctx);
        this.renderBattleLog(ctx);
        this.renderTurnIndicator(ctx);
        this.renderBattleStatus(ctx);
        
        // Render animations
        this.renderAnimations(ctx);
        
        // Instructions
        ctx.fillStyle = '#ecf0f1';
        ctx.font = '12px Arial';
        ctx.textAlign = 'center';
        ctx.fillText('Click skills then targets | A: quick attack | H: quick heal | Space: skip | M: menu', 
                    this.engine.width / 2, this.engine.height - 10);
    }
    
    renderPlayer(ctx) {
        const x = 100;
        const y = 100;
        const width = 200;
        const height = 150;
        
        // Player box
        const isPlayerTurn = this.isPlayerTurn();
        ctx.fillStyle = isPlayerTurn ? 'rgba(46, 204, 113, 0.8)' : 'rgba(52, 73, 94, 0.8)';
        ctx.fillRect(x, y, width, height);
        ctx.strokeStyle = isPlayerTurn ? '#2ecc71' : '#ecf0f1';
        ctx.lineWidth = isPlayerTurn ? 3 : 2;
        ctx.strokeRect(x, y, width, height);
        
        this.renderCharacterInfo(ctx, this.player, x, y, width, height);
        
        // Selected skill indicator
        if (this.selectedSkill) {
            ctx.fillStyle = '#f39c12';
            ctx.font = '12px Arial';
            ctx.textAlign = 'left';
            ctx.fillText(`Selected: ${this.selectedSkill.name}`, x + 10, y + height + 15);
        }
    }
    
    renderEnemies(ctx) {
        this.enemies.forEach((enemy, index) => {
            if (!enemy.isAlive()) return;
            
            const x = 700 + (index % 2) * 250;
            const y = 100 + Math.floor(index / 2) * 200;
            const width = 200;
            const height = 150;
            
            // Enemy box
            const isEnemyTurn = this.getCurrentActor() === enemy;
            ctx.fillStyle = isEnemyTurn ? 'rgba(231, 76, 60, 0.8)' : 'rgba(52, 73, 94, 0.8)';
            ctx.fillRect(x, y, width, height);
            ctx.strokeStyle = isEnemyTurn ? '#e74c3c' : '#ecf0f1';
            ctx.lineWidth = isEnemyTurn ? 3 : 2;
            ctx.strokeRect(x, y, width, height);
            
            this.renderCharacterInfo(ctx, enemy, x, y, width, height);
        });
    }
    
    renderCharacterInfo(ctx, character, x, y, width, height) {
        // Name
        ctx.fillStyle = '#ffffff';
        ctx.font = '16px Arial';
        ctx.textAlign = 'left';
        ctx.fillText(character.name, x + 10, y + 20);
        
        // Level (if applicable)
        if (character.level) {
            ctx.font = '12px Arial';
            ctx.fillText(`Lv.${character.level}`, x + width - 50, y + 20);
        }
        
        // HP Bar
        const hpBarWidth = width - 20;
        const hpBarHeight = 20;
        const hpBarY = y + 30;
        
        ctx.fillStyle = '#e74c3c';
        ctx.fillRect(x + 10, hpBarY, hpBarWidth, hpBarHeight);
        
        const hpPercent = character.getHpPercentage();
        ctx.fillStyle = hpPercent > 0.5 ? '#27ae60' : hpPercent > 0.25 ? '#f39c12' : '#e74c3c';
        ctx.fillRect(x + 10, hpBarY, hpBarWidth * hpPercent, hpBarHeight);
        
        ctx.strokeStyle = '#2c3e50';
        ctx.lineWidth = 1;
        ctx.strokeRect(x + 10, hpBarY, hpBarWidth, hpBarHeight);
        
        // HP Text
        ctx.fillStyle = '#ffffff';
        ctx.font = '11px Arial';
        ctx.textAlign = 'center';
        ctx.fillText(`${character.hp}/${character.maxHp}`, x + 10 + hpBarWidth / 2, hpBarY + 14);
        
        // MP Bar
        const mpBarY = y + 55;
        const mpBarHeight = 15;
        
        ctx.fillStyle = '#3498db';
        ctx.fillRect(x + 10, mpBarY, hpBarWidth, mpBarHeight);
        
        const mpPercent = character.getMpPercentage();
        ctx.fillStyle = '#9b59b6';
        ctx.fillRect(x + 10, mpBarY, hpBarWidth * mpPercent, mpBarHeight);
        
        ctx.strokeStyle = '#2c3e50';
        ctx.strokeRect(x + 10, mpBarY, hpBarWidth, mpBarHeight);
        
        // MP Text
        ctx.fillStyle = '#ffffff';
        ctx.font = '9px Arial';
        ctx.fillText(`${character.mp}/${character.maxMp}`, x + 10 + hpBarWidth / 2, mpBarY + 11);
        
        // Stats
        ctx.fillStyle = '#ecf0f1';
        ctx.font = '10px Arial';
        ctx.textAlign = 'left';
        ctx.fillText(`ATK: ${character.getAttack()}`, x + 10, y + 85);
        ctx.fillText(`DEF: ${character.getDefense()}`, x + 70, y + 85);
        ctx.fillText(`SPD: ${character.getSpeed()}`, x + 130, y + 85);
    }
    
    renderSkillPanel(ctx) {
        if (!this.isPlayerTurn()) return;
        
        const skills = this.player.getAvailableSkills();
        const panelX = 50;
        const panelY = 400;
        const panelWidth = 350;
        const panelHeight = 350;
        
        // Panel background
        ctx.fillStyle = 'rgba(52, 73, 94, 0.9)';
        ctx.fillRect(panelX, panelY, panelWidth, panelHeight);
        ctx.strokeStyle = '#ecf0f1';
        ctx.lineWidth = 2;
        ctx.strokeRect(panelX, panelY, panelWidth, panelHeight);
        
        // Title
        ctx.fillStyle = '#ecf0f1';
        ctx.font = '16px Arial';
        ctx.textAlign = 'left';
        ctx.fillText('Available Skills', panelX + 10, panelY + 20);
        
        if (skills.length === 0) {
            ctx.fillStyle = '#bdc3c7';
            ctx.font = '14px Arial';
            ctx.fillText('No skills - configure inventory first', panelX + 10, panelY + 50);
            return;
        }
        
        // Render skill buttons
        skills.forEach((skill, index) => {
            const buttonY = panelY + 30 + index * 40;
            const buttonHeight = 35;
            const buttonWidth = panelWidth - 20;
            
            // Button background
            const canUse = this.player.canUseSkill(skill);
            const isSelected = this.selectedSkill === skill;
            
            let buttonColor = GameData.getSkillTypeColor(skill.type);
            if (!canUse) buttonColor = '#7f8c8d';
            if (isSelected) buttonColor = '#f39c12';
            
            ctx.fillStyle = buttonColor;
            ctx.fillRect(panelX + 10, buttonY, buttonWidth, buttonHeight);
            ctx.strokeStyle = '#2c3e50';
            ctx.lineWidth = isSelected ? 2 : 1;
            ctx.strokeRect(panelX + 10, buttonY, buttonWidth, buttonHeight);
            
            // Skill info
            ctx.fillStyle = canUse ? '#ffffff' : '#bdc3c7';
            ctx.font = 'bold 12px Arial';
            ctx.textAlign = 'left';
            ctx.fillText(skill.name, panelX + 15, buttonY + 15);
            
            ctx.font = '10px Arial';
            ctx.fillText(`${skill.damage} DMG | ${skill.cost} MP | ${skill.type}`, 
                        panelX + 15, buttonY + 28);
        });
    }
    
    renderBattleLog(ctx) {
        const logX = 450;
        const logY = 400;
        const logWidth = 700;
        const logHeight = 350;
        
        // Log background
        ctx.fillStyle = 'rgba(44, 62, 80, 0.9)';
        ctx.fillRect(logX, logY, logWidth, logHeight);
        ctx.strokeStyle = '#ecf0f1';
        ctx.lineWidth = 2;
        ctx.strokeRect(logX, logY, logWidth, logHeight);
        
        // Log title
        ctx.fillStyle = '#ecf0f1';
        ctx.font = '16px Arial';
        ctx.textAlign = 'left';
        ctx.fillText('Battle Log', logX + 10, logY + 20);
        
        // Log messages
        ctx.font = '12px Arial';
        this.battleLog.forEach((message, index) => {
            const alpha = Math.max(0.4, 1 - (this.battleLog.length - index - 1) * 0.1);
            ctx.fillStyle = `rgba(236, 240, 241, ${alpha})`;
            ctx.fillText(message, logX + 10, logY + 40 + index * 16);
        });
    }
    
    renderTurnIndicator(ctx) {
        const currentActor = this.getCurrentActor();
        if (!currentActor) return;
        
        ctx.fillStyle = 'rgba(52, 73, 94, 0.9)';
        ctx.fillRect(this.engine.width / 2 - 100, 60, 200, 30);
        ctx.strokeStyle = '#ecf0f1';
        ctx.lineWidth = 2;
        ctx.strokeRect(this.engine.width / 2 - 100, 60, 200, 30);
        
        ctx.fillStyle = '#ffffff';
        ctx.font = '14px Arial';
        ctx.textAlign = 'center';
        ctx.fillText(`${currentActor.name}'s Turn`, this.engine.width / 2, 80);
    }
    
    renderBattleStatus(ctx) {
        if (this.battleState === 'victory' || this.battleState === 'defeat') {
            // Victory/Defeat overlay
            ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
            ctx.fillRect(0, 0, this.engine.width, this.engine.height);
            
            ctx.fillStyle = this.battleState === 'victory' ? '#27ae60' : '#e74c3c';
            ctx.font = '48px Arial';
            ctx.textAlign = 'center';
            const text = this.battleState === 'victory' ? 'VICTORY!' : 'DEFEAT!';
            ctx.fillText(text, this.engine.width / 2, this.engine.height / 2);
            
            ctx.fillStyle = '#ffffff';
            ctx.font = '18px Arial';
            ctx.fillText('Press M to return to menu', this.engine.width / 2, this.engine.height / 2 + 50);
        }
    }
    
    renderAnimations(ctx) {
        // Simple animation rendering
        this.animationQueue.forEach(anim => {
            if (anim.type === 'skill') {
                // Flash effect on target
                const alpha = Math.sin(Date.now() * 0.01) * 0.5 + 0.5;
                ctx.fillStyle = `rgba(255, 255, 255, ${alpha * 0.3})`;
                
                // Find target position and flash
                if (anim.target === this.player) {
                    ctx.fillRect(100, 100, 200, 150);
                } else {
                    // Find enemy position
                    const enemyIndex = this.enemies.indexOf(anim.target);
                    if (enemyIndex >= 0) {
                        const x = 700 + (enemyIndex % 2) * 250;
                        const y = 100 + Math.floor(enemyIndex / 2) * 200;
                        ctx.fillRect(x, y, 200, 150);
                    }
                }
            }
        });
    }
}