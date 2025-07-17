import { PixiScene } from '../core/PixiScene.js';

export class PixiMenuScene extends PixiScene {
    constructor() {
        super();
        this.buttons = [];
        this.hoveredButton = -1;
        
        // Menu layout configuration
        this.menuConfig = {
            titleOffset: { x: 0, y: -200 },
            subtitleOffset: { x: 0, y: -140 },
            versionOffset: { x: 0, y: -100 },
            buttonStartOffset: { x: 0, y: -20 },
            buttonSpacing: 80,
            buttonWidth: 350,
            buttonHeight: 60,
        };
        
        // Responsive elements references
        this.titleElement = null;
        this.subtitleElement = null;
        this.versionElement = null;
        this.backgroundElement = null;
    }
    
    onEnter() {
        super.onEnter();
        
        // Create all menu elements
        this.createBackground();
        this.createTitle();
        this.createSubtitle();
        this.createVersion();
        this.createMenuButtons();
        
        // Update game mode display
        const gameModeBtn = document.getElementById('gameMode');
        if (gameModeBtn) {
            gameModeBtn.textContent = '📋 MENU';
        }
        
        console.log('Menu scene loaded with responsive viewport support');
    }
    
    onResize(newWidth, newHeight) {
        super.onResize(newWidth, newHeight);
        
        // Update menu configuration based on screen size
        this.updateMenuConfig();
        
        // Recreate buttons with new sizes
        this.recreateButtons();
        
        console.log(`Menu scene resized to ${newWidth}x${newHeight}`);
    }
    
    updateMenuConfig() {
        // Adjust spacing and sizes based on viewport
        const baseSpacing = this.isMobile ? 60 : 80;
        const baseButtonWidth = this.isMobile ? 280 : 350;
        const baseButtonHeight = this.isMobile ? 50 : 60;
        
        this.menuConfig = {
            titleOffset: { 
                x: 0, 
                y: this.isMobile ? -this.viewportHeight * 0.3 : -200 
            },
            subtitleOffset: { 
                x: 0, 
                y: this.isMobile ? -this.viewportHeight * 0.22 : -140 
            },
            versionOffset: { 
                x: 0, 
                y: this.isMobile ? -this.viewportHeight * 0.18 : -100 
            },
            buttonStartOffset: { 
                x: 0, 
                y: this.isMobile ? -this.viewportHeight * 0.1 : -20 
            },
            buttonSpacing: this.getScaledSize(baseSpacing),
            buttonWidth: this.getScaledSize(baseButtonWidth),
            buttonHeight: this.getScaledSize(baseButtonHeight),
        };
    }
    
    createBackground() {
        // Create animated gradient background
        this.backgroundElement = new PIXI.Graphics();
        this.updateBackground();
        
        this.makeResponsive(this.backgroundElement, {
            anchor: { x: 'center', y: 'center' },
            offset: { x: 0, y: 0 },
            scale: false
        });
        
        this.addGraphics(this.backgroundElement, 'background');
    }
    
    updateBackground() {
        if (!this.backgroundElement) return;
        
        this.backgroundElement.clear();
        
        // Main background
        this.backgroundElement.beginFill(0x3498db);
        this.backgroundElement.drawRect(
            -this.viewportWidth / 2, 
            -this.viewportHeight / 2, 
            this.viewportWidth, 
            this.viewportHeight
        );
        this.backgroundElement.endFill();
        
        // Add decorative elements scaled to viewport
        const numOrbs = this.isMobile ? 8 : 15;
        const orbSize = this.getScaledSize(this.isMobile ? 40 : 60);
        
        for (let i = 0; i < numOrbs; i++) {
            const x = (Math.random() - 0.5) * this.viewportWidth;
            const y = (Math.random() - 0.5) * this.viewportHeight;
            const alpha = 0.1 + Math.random() * 0.2;
            
            this.backgroundElement.beginFill(0xffffff, alpha);
            this.backgroundElement.drawCircle(x, y, orbSize);
            this.backgroundElement.endFill();
        }
    }
    

    
    createTitle() {
        this.titleElement = new PIXI.Text('TACTICAL RPG', {
            fontFamily: 'Arial',
            fontSize: this.getResponsiveFontSize(this.isMobile ? 32 : 48),
            fill: 0xffffff,
            align: 'center',
            fontWeight: 'bold',
            stroke: 0x2c3e50,
            strokeThickness: this.isMobile ? 2 : 4,
        });
        
        this.titleElement.anchor.set(0.5);
        
        this.makeResponsive(this.titleElement, {
            anchor: { x: 'center', y: 'center' },
            offset: this.menuConfig.titleOffset,
            scale: true,
            minScale: 0.6,
            maxScale: 1.4
        });
        
        this.addSprite(this.titleElement, 'ui');
    }
    

    
    createSubtitle() {
        this.subtitleElement = new PIXI.Text('Enhanced with PixiJS', {
            fontFamily: 'Arial',
            fontSize: this.getResponsiveFontSize(this.isMobile ? 16 : 24),
            fill: 0x64b5f6,
            align: 'center',
            fontWeight: 'normal',
        });
        
        this.subtitleElement.anchor.set(0.5);
        
        this.makeResponsive(this.subtitleElement, {
            anchor: { x: 'center', y: 'center' },
            offset: this.menuConfig.subtitleOffset,
            scale: true,
            minScale: 0.7,
            maxScale: 1.2
        });
        
        this.addSprite(this.subtitleElement, 'ui');
    }
    
    createVersion() {
        const versionText = `Viewport: ${this.viewportWidth}×${this.viewportHeight} | ${this.isMobile ? 'Mobile' : 'Desktop'} | ${this.isLandscape ? 'Landscape' : 'Portrait'}`;
        
        this.versionElement = new PIXI.Text(versionText, {
            fontFamily: 'Arial',
            fontSize: this.getResponsiveFontSize(this.isMobile ? 10 : 14),
            fill: 0xecf0f1,
            align: 'center',
            alpha: 0.8,
        });
        
        this.versionElement.anchor.set(0.5);
        
        this.makeResponsive(this.versionElement, {
            anchor: { x: 'center', y: 'center' },
            offset: this.menuConfig.versionOffset,
            scale: true,
            minScale: 0.8,
            maxScale: 1.0
        });
        
        this.addSprite(this.versionElement, 'ui');
    }
    
    createMenuButtons() {
        const buttonData = [
            { 
                text: '🎒 Inventory Management', 
                icon: '🎒',
                action: () => this.engine.switchScene('inventory'),
                color: 0x27ae60
            },
            { 
                text: '⚔️ Battle Mode', 
                icon: '⚔️',
                action: () => this.engine.switchScene('battle'),
                color: 0xe74c3c
            },
            { 
                text: '🌍 World Exploration', 
                icon: '🌍',
                action: () => this.engine.switchScene('world'),
                color: 0x3498db
            },
            { 
                text: '⚙️ Settings', 
                icon: '⚙️',
                action: () => this.showSettings(),
                color: 0x95a5a6
            }
        ];
        
        // Clear existing buttons
        this.buttons.forEach(button => {
            this.removeSprite(button);
        });
        this.buttons = [];
        
        buttonData.forEach((data, index) => {
            const button = this.createMenuButton(data, index);
            this.buttons.push(button);
        });
    }
    
    recreateButtons() {
        // Update button configuration
        this.updateMenuConfig();
        
        // Recreate buttons with new configuration
        this.createMenuButtons();
    }
    
    createMenuButton(data, index) {
        const buttonContainer = new PIXI.Container();
        const config = this.menuConfig;
        
        // Button background with responsive sizing
        const bg = new PIXI.Graphics();
        bg.beginFill(data.color, 0.8);
        bg.drawRoundedRect(0, 0, config.buttonWidth, config.buttonHeight, 10);
        bg.endFill();
        
        // Button border
        bg.lineStyle(this.getScaledSize(2), 0xffffff, 0.8);
        bg.drawRoundedRect(0, 0, config.buttonWidth, config.buttonHeight, 10);
        
        // Icon
        const iconText = new PIXI.Text(data.icon, {
            fontFamily: 'Arial',
            fontSize: this.getResponsiveFontSize(this.isMobile ? 20 : 28),
            fill: 0xffffff,
            align: 'center',
        });
        iconText.anchor.set(0.5);
        iconText.x = this.getScaledSize(40);
        iconText.y = config.buttonHeight / 2;
        
        // Button text
        const buttonText = new PIXI.Text(data.text, {
            fontFamily: 'Arial',
            fontSize: this.getResponsiveFontSize(this.isMobile ? 14 : 18),
            fill: 0xffffff,
            align: 'left',
            fontWeight: 'bold',
            wordWrap: this.isMobile,
            wordWrapWidth: config.buttonWidth - this.getScaledSize(80),
        });
        buttonText.anchor.set(0, 0.5);
        buttonText.x = this.getScaledSize(70);
        buttonText.y = config.buttonHeight / 2;
        
        buttonContainer.addChild(bg);
        buttonContainer.addChild(iconText);
        buttonContainer.addChild(buttonText);
        
        // Position button responsively
        const yOffset = config.buttonStartOffset.y + (index * config.buttonSpacing);
        
        this.makeResponsive(buttonContainer, {
            anchor: { x: 'center', y: 'center' },
            offset: { x: config.buttonStartOffset.x, y: yOffset },
            scale: true,
            minScale: 0.7,
            maxScale: 1.1
        });
        
        // Make interactive
        buttonContainer.interactive = true;
        buttonContainer.cursor = 'pointer';
        buttonContainer.buttonIndex = index;
        
        // Store references for hover effects
        buttonContainer.bg = bg;
        buttonContainer.iconText = iconText;
        buttonContainer.buttonText = buttonText;
        buttonContainer.originalColor = data.color;
        
        // Add hover effects
        buttonContainer.on('pointerover', () => {
            if (!this.isMobile) { // Reduce hover effects on mobile
                this.onButtonHover(buttonContainer, true);
            }
        });
        
        buttonContainer.on('pointerout', () => {
            this.onButtonHover(buttonContainer, false);
        });
        
        buttonContainer.on('pointerdown', (event) => {
            this.onButtonClick(buttonContainer, data.action, event);
        });
        
        this.addSprite(buttonContainer, 'ui');
        return buttonContainer;
    }
    
    onButtonHover(button, isHover) {
        const targetScale = isHover ? 1.05 : 1.0;
        const targetAlpha = isHover ? 1.0 : 0.8;
        const hoverColor = isHover ? this.lightenColor(button.originalColor) : button.originalColor;
        
        // Animate scale
        const animate = () => {
            const currentScale = button.scale.x;
            const diff = targetScale - currentScale;
            
            if (Math.abs(diff) > 0.01) {
                button.scale.set(currentScale + diff * 0.2);
                requestAnimationFrame(animate);
            } else {
                button.scale.set(targetScale);
            }
        };
        
        animate();
        
        // Update colors
        button.bg.clear();
        button.bg.beginFill(hoverColor, targetAlpha);
        button.bg.drawRoundedRect(0, 0, this.menuConfig.buttonWidth, this.menuConfig.buttonHeight, 10);
        button.bg.endFill();
        
        button.bg.lineStyle(this.getScaledSize(isHover ? 3 : 2), 0xffffff, isHover ? 1.0 : 0.8);
        button.bg.drawRoundedRect(0, 0, this.menuConfig.buttonWidth, this.menuConfig.buttonHeight, 10);
    }
    
    onButtonClick(button, action, event) {
        // Add click animation
        button.scale.set(0.95);
        
        setTimeout(() => {
            if (button.parent) {
                button.scale.set(1.0);
            }
        }, 100);
        
        // Execute action
        try {
            action();
        } catch (error) {
            console.error('Button action failed:', error);
        }
        
        // Prevent event bubbling
        event.stopPropagation();
    }
    
    lightenColor(color) {
        // Simple color lightening
        const r = Math.min(255, ((color >> 16) & 0xFF) + 30);
        const g = Math.min(255, ((color >> 8) & 0xFF) + 30);
        const b = Math.min(255, (color & 0xFF) + 30);
        
        return (r << 16) | (g << 8) | b;
    }
    
    showSettings() {
        console.log('Settings clicked - PixiJS responsive version!');
        this.createSettingsPopup();
    }
    
    createSettingsPopup() {
        // Remove existing popup if any
        const existingPopup = this.layers.effects.getChildByName('settingsPopup');
        if (existingPopup) {
            this.layers.effects.removeChild(existingPopup);
        }
        
        // Semi-transparent overlay
        const overlay = new PIXI.Graphics();
        overlay.beginFill(0x000000, 0.7);
        overlay.drawRect(
            -this.viewportWidth / 2, 
            -this.viewportHeight / 2, 
            this.viewportWidth, 
            this.viewportHeight
        );
        overlay.endFill();
        overlay.interactive = true;
        overlay.name = 'settingsPopup';
        
        // Settings panel with responsive sizing
        const panelWidth = Math.min(this.getScaledSize(400), this.viewportWidth * 0.9);
        const panelHeight = Math.min(this.getScaledSize(300), this.viewportHeight * 0.7);
        
        const panel = new PIXI.Graphics();
        panel.beginFill(0x34495e);
        panel.drawRoundedRect(0, 0, panelWidth, panelHeight, 15);
        panel.endFill();
        panel.lineStyle(3, 0xf39c12);
        panel.drawRoundedRect(0, 0, panelWidth, panelHeight, 15);
        
        panel.x = -panelWidth / 2;
        panel.y = -panelHeight / 2;
        
        // Title
        const title = new PIXI.Text('Settings', {
            fontFamily: 'Arial',
            fontSize: this.getResponsiveFontSize(24),
            fill: 0xffffff,
            align: 'center',
            fontWeight: 'bold',
        });
        title.anchor.set(0.5);
        title.x = panelWidth / 2;
        title.y = this.getResponsivePadding(40);
        panel.addChild(title);
        
        // Settings content
        const viewportInfo = this.engine.getViewportInfo();
        const settingsText = new PIXI.Text(
            `Responsive PixiJS Engine Settings\n\n` +
            `🖥️ Viewport: ${viewportInfo.width} × ${viewportInfo.height}\n` +
            `📱 Device: ${this.isMobile ? 'Mobile' : 'Desktop'}\n` +
            `🔄 Orientation: ${this.isLandscape ? 'Landscape' : 'Portrait'}\n` +
            `📐 Aspect Ratio: ${viewportInfo.aspectRatio.toFixed(2)}\n` +
            `🔍 Scale Factor: ${this.scaleFactor.toFixed(2)}\n` +
            `✨ Hardware Acceleration: ON\n` +
            `🎨 Anti-aliasing: ON\n` +
            `📊 Performance Monitor: ON\n` +
            `🖱️ Interactive UI: ON\n` +
            `📱 Responsive Layout: ON`,
            {
                fontFamily: 'Arial',
                fontSize: this.getResponsiveFontSize(this.isMobile ? 11 : 14),
                fill: 0xecf0f1,
                align: 'left',
                lineHeight: this.getResponsivePadding(18),
            }
        );
        settingsText.x = this.getResponsivePadding(20);
        settingsText.y = this.getResponsivePadding(80);
        panel.addChild(settingsText);
        
        // Close button
        const closeBtn = this.createSimpleButton(
            'Close', 
            panelWidth / 2 - this.getScaledSize(60), 
            panelHeight - this.getResponsivePadding(50),
            () => {
                this.layers.effects.removeChild(overlay);
            },
            false
        );
        panel.addChild(closeBtn);
        
        overlay.addChild(panel);
        
        // Position overlay responsively
        this.makeResponsive(overlay, {
            anchor: { x: 'center', y: 'center' },
            offset: { x: 0, y: 0 },
            scale: false
        });
        
        this.addSprite(overlay, 'effects');
        
        // Add entrance animation
        overlay.alpha = 0;
        panel.scale.set(0.8);
        
        const animateIn = () => {
            overlay.alpha = Math.min(1, overlay.alpha + 0.1);
            panel.scale.set(Math.min(1, panel.scale.x + 0.05));
            
            if (overlay.alpha < 1 || panel.scale.x < 1) {
                requestAnimationFrame(animateIn);
            }
        };
        
        animateIn();
    }
    
    update(deltaTime) {
        super.update(deltaTime);
        
        // Update version info periodically
        if (this.versionElement && Math.random() < 0.01) { // 1% chance per frame
            const versionText = `Viewport: ${this.viewportWidth}×${this.viewportHeight} | ${this.isMobile ? 'Mobile' : 'Desktop'} | ${this.isLandscape ? 'Landscape' : 'Portrait'}`;
            this.versionElement.text = versionText;
        }
        
        // Update background if viewport changed significantly
        if (this.backgroundElement && Math.random() < 0.005) { // 0.5% chance per frame
            this.updateBackground();
        }
    }
    
    handleKeyDown(event) {
        if (event.code === 'Escape') {
            console.log('Escape pressed in responsive menu');
        } else if (event.code === 'Enter' || event.code === 'Space') {
            // Activate first button on Enter/Space
            if (this.buttons.length > 0) {
                this.buttons[0].emit('pointerdown', { stopPropagation: () => {} });
            }
        } else if (event.code === 'ArrowDown' || event.code === 'ArrowUp') {
            // Navigate through buttons with arrow keys
            this.navigateButtons(event.code === 'ArrowDown' ? 1 : -1);
        }
    }
    
    navigateButtons(direction) {
        this.hoveredButton = Math.max(0, Math.min(this.buttons.length - 1, this.hoveredButton + direction));
        
        // Visual feedback for keyboard navigation
        this.buttons.forEach((button, index) => {
            if (index === this.hoveredButton) {
                this.onButtonHover(button, true);
            } else {
                this.onButtonHover(button, false);
            }
        });
    }
    
    onExit() {
        // Clear any active animations
        this.isActive = false;
        
        super.onExit();
    }
}