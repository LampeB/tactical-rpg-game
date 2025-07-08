import { PixiScene } from '../core/PixiScene.js';

export class PixiMenuScene extends PixiScene {
    constructor() {
        super();
        this.buttons = [];
        this.hoveredButton = -1;
    }
    
    onEnter() {
        super.onEnter();
        
        // Create background
        this.createBackground();
        
        // Create menu buttons
        this.createMenuButtons();
        
        // Update game mode display
        const gameModeBtn = document.getElementById('gameMode');
        if (gameModeBtn) {
            gameModeBtn.textContent = '📋 MENU';
        }
        
        console.log('Menu scene loaded with PixiJS');
    }
    
    createBackground() {
        // Gradient background
        const bg = new PIXI.Graphics();
        bg.beginFill(0x3498db);
        bg.drawRect(0, 0, this.engine.width, this.engine.height);
        bg.endFill();
        this.addGraphics(bg, 'background');
        
        // Title
        const title = new PIXI.Text('TACTICAL RPG', {
            fontFamily: 'Arial',
            fontSize: 48,
            fill: 0xffffff,
            align: 'center',
            fontWeight: 'bold'
        });
        title.anchor.set(0.5);
        title.x = this.engine.width / 2;
        title.y = 150;
        this.addSprite(title, 'ui');
        
        // Subtitle
        const subtitle = new PIXI.Text('Enhanced with PixiJS', {
            fontFamily: 'Arial',
            fontSize: 24,
            fill: 0x64b5f6,
            align: 'center'
        });
        subtitle.anchor.set(0.5);
        subtitle.x = this.engine.width / 2;
        subtitle.y = 200;
        
        this.addSprite(subtitle, 'ui');
    }
    
    createMenuButtons() {
        const buttonData = [
            { text: '🎒 Inventory Management', action: () => this.engine.switchScene('inventory') },
            { text: '⚔️ Battle Mode', action: () => this.engine.switchScene('battle') },
            { text: '🌍 World Exploration', action: () => this.engine.switchScene('world') },
            { text: '⚙️ Settings', action: () => this.showSettings() }
        ];
        
        buttonData.forEach((data, index) => {
            const button = this.createMenuButton(data.text, data.action, index);
            this.buttons.push(button);
        });
    }
    
    createMenuButton(text, action, index) {
        const buttonContainer = new PIXI.Container();
        
        // Button background
        const bg = new PIXI.Graphics();
        bg.beginFill(0x34495e);
        bg.drawRoundedRect(0, 0, 350, 50, 10);
        bg.endFill();
        
        // Button border
        bg.lineStyle(2, 0xecf0f1);
        bg.drawRoundedRect(0, 0, 350, 50, 10);
        
        // Button text
        const buttonText = new PIXI.Text(text, {
            fontFamily: 'Arial',
            fontSize: 18,
            fill: 0xffffff,
            align: 'center'
        });
        buttonText.anchor.set(0.5);
        buttonText.x = 175;
        buttonText.y = 25;
        
        buttonContainer.addChild(bg);
        buttonContainer.addChild(buttonText);
        
        // Position
        buttonContainer.x = this.engine.width / 2 - 175;
        buttonContainer.y = 300 + index * 70;
        
        // Make interactive
        buttonContainer.interactive = true;
        buttonContainer.cursor = 'pointer';
        
        // Hover effects
        buttonContainer.on('pointerover', () => {
            bg.clear();
            bg.beginFill(0xf39c12);
            bg.drawRoundedRect(0, 0, 350, 50, 10);
            bg.endFill();
            bg.lineStyle(2, 0xffffff);
            bg.drawRoundedRect(0, 0, 350, 50, 10);
            buttonText.style.fill = 0x2c3e50;
        });
        
        buttonContainer.on('pointerout', () => {
            bg.clear();
            bg.beginFill(0x34495e);
            bg.drawRoundedRect(0, 0, 350, 50, 10);
            bg.endFill();
            bg.lineStyle(2, 0xecf0f1);
            bg.drawRoundedRect(0, 0, 350, 50, 10);
            buttonText.style.fill = 0xffffff;
        });
        
        buttonContainer.on('pointerdown', action);
        
        this.addSprite(buttonContainer, 'ui');
        return buttonContainer;
    }
    
    showSettings() {
        console.log('Settings clicked - PixiJS version!');
        this.createSettingsPopup();
    }
    
    createSettingsPopup() {
        // Semi-transparent overlay
        const overlay = new PIXI.Graphics();
        overlay.beginFill(0x000000, 0.7);
        overlay.drawRect(0, 0, this.engine.width, this.engine.height);
        overlay.endFill();
        overlay.interactive = true;
        
        // Settings panel
        const panel = new PIXI.Graphics();
        panel.beginFill(0x34495e);
        panel.drawRoundedRect(0, 0, 400, 300, 15);
        panel.endFill();
        panel.lineStyle(3, 0xf39c12);
        panel.drawRoundedRect(0, 0, 400, 300, 15);
        
        panel.x = this.engine.width / 2 - 200;
        panel.y = this.engine.height / 2 - 150;
        
        // Title
        const title = new PIXI.Text('Settings', {
            fontFamily: 'Arial',
            fontSize: 24,
            fill: 0xffffff,
            align: 'center'
        });
        title.anchor.set(0.5);
        title.x = 200;
        title.y = 40;
        panel.addChild(title);
        
        // Settings text
        const settingsText = new PIXI.Text('PixiJS Engine Settings\n\n✨ Hardware Acceleration: ON\n🎨 Anti-aliasing: ON\n📊 Performance Monitor: ON\n🖱️ Interactive UI: ON', {
            fontFamily: 'Arial',
            fontSize: 14,
            fill: 0xecf0f1,
            align: 'center',
            lineHeight: 20
        });
        settingsText.anchor.set(0.5);
        settingsText.x = 200;
        settingsText.y = 150;
        panel.addChild(settingsText);
        
        // Close button
        const closeBtn = this.createSimpleButton('Close', 150, 230, () => {
            this.removeSprite(overlay);
        });
        panel.addChild(closeBtn);
        
        overlay.addChild(panel);
        this.addSprite(overlay, 'ui');
    }
    
    handleKeyDown(event) {
        if (event.code === 'Escape') {
            console.log('Escape pressed in menu');
        }
    }
}