import { PixiScene } from '../core/PixiScene.js';
import { COLORS, FONTS, UI, LAYOUT, RESPONSIVE } from '../utils/Constants.js';

export class PixiMenuScene extends PixiScene {
    constructor() {
        super();
        this.buttons = [];
        this.hoveredButton = -1;
        
        // Menu layout configuration using constants
        this.menuConfig = {
            titleOffset: { x: 0, y: UI.MENU.TITLE_OFFSET_Y },
            subtitleOffset: { x: 0, y: UI.MENU.SUBTITLE_OFFSET_Y },
            versionOffset: { x: 0, y: UI.MENU.VERSION_OFFSET_Y },
            buttonStartOffset: { x: 0, y: UI.MENU.BUTTON_START_OFFSET_Y },
            buttonSpacing: UI.MENU.BUTTON_SPACING,
            buttonWidth: UI.BUTTON.LARGE_WIDTH,
            buttonHeight: UI.BUTTON.LARGE_HEIGHT,
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
        // Adjust spacing and sizes based on viewport using constants
        const baseSpacing = this.isMobile ? UI.MENU.MOBILE_SPACING : UI.MENU.BUTTON_SPACING;
        const baseButtonWidth = this.isMobile ? UI.BUTTON.MOBILE_LARGE_WIDTH : UI.BUTTON.LARGE_WIDTH;
        const baseButtonHeight = this.isMobile ? UI.BUTTON.MOBILE_LARGE_HEIGHT : UI.BUTTON.LARGE_HEIGHT;
        
        this.menuConfig = {
            titleOffset: { 
                x: 0, 
                y: this.isMobile ? -this.viewportHeight * UI.MENU.MOBILE_TITLE_OFFSET_PERCENT : UI.MENU.TITLE_OFFSET_Y 
            },
            subtitleOffset: { 
                x: 0, 
                y: this.isMobile ? -this.viewportHeight * UI.MENU.MOBILE_SUBTITLE_OFFSET_PERCENT : UI.MENU.SUBTITLE_OFFSET_Y 
            },
            versionOffset: { 
                x: 0, 
                y: this.isMobile ? -this.viewportHeight * UI.MENU.MOBILE_VERSION_OFFSET_PERCENT : UI.MENU.VERSION_OFFSET_Y 
            },
            buttonStartOffset: { 
                x: 0, 
                y: this.isMobile ? -this.viewportHeight * 0.1 : UI.MENU.BUTTON_START_OFFSET_Y 
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
        
        // Main background using constants
        this.backgroundElement.beginFill(COLORS.PIXI.MENU_WORLD);
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
            const alpha = COLORS.ALPHA.VERY_LOW + Math.random() * COLORS.ALPHA.MEDIUM_LOW;
            
            this.backgroundElement.beginFill(COLORS.PIXI.WHITE, alpha);
            this.backgroundElement.drawCircle(x, y, orbSize);
            this.backgroundElement.endFill();
        }
    }
    
    createTitle() {
        this.titleElement = new PIXI.Text('TACTICAL RPG', {
            fontFamily: FONTS.FAMILY.PRIMARY,
            fontSize: this.getResponsiveFontSize(this.isMobile ? FONTS.SIZE.MOBILE_LARGE_TITLE * 1.6 : FONTS.SIZE.HUGE_TITLE * 1.7),
            fill: COLORS.PIXI.WHITE,
            align: FONTS.ALIGN.CENTER,
            fontWeight: FONTS.WEIGHT.BOLD,
            stroke: COLORS.PIXI.DARK_GRAY,
            strokeThickness: this.isMobile ? LAYOUT.MEDIUM_BORDER : LAYOUT.THICK_BORDER + 1,
        });
        
        this.titleElement.anchor.set(0.5);
        
        this.makeResponsive(this.titleElement, {
            anchor: { x: 'center', y: 'center' },
            offset: this.menuConfig.titleOffset,
            scale: true,
            minScale: RESPONSIVE.MIN_SCALE,
            maxScale: RESPONSIVE.MAX_SCALE
        });
        
        this.addSprite(this.titleElement, 'ui');
    }
    
    createSubtitle() {
        this.subtitleElement = new PIXI.Text('Enhanced with PixiJS', {
            fontFamily: FONTS.FAMILY.PRIMARY,
            fontSize: this.getResponsiveFontSize(this.isMobile ? FONTS.SIZE.MOBILE_SUBTITLE : FONTS.SIZE.TITLE),
            fill: 0x64b5f6, // Light blue - could be added to constants if used elsewhere
            align: FONTS.ALIGN.CENTER,
            fontWeight: FONTS.WEIGHT.NORMAL,
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
            fontFamily: FONTS.FAMILY.PRIMARY,
            fontSize: this.getResponsiveFontSize(this.isMobile ? FONTS.SIZE.MOBILE_SMALL : FONTS.SIZE.SUBTITLE),
            fill: COLORS.PIXI.LIGHT_GRAY,
            align: FONTS.ALIGN.CENTER,
            alpha: COLORS.ALPHA.HIGH,
        });
        
        this.versionElement.anchor.set(0.5);
        
        this.makeResponsive(this.versionElement, {
            anchor: { x: 'center', y: 'center' },
            offset: this.menuConfig.versionOffset,
            scale: true,
            minScale: RESPONSIVE.MOBILE_MIN_SCALE,
            maxScale: RESPONSIVE.BASE_SCALE
        });
        
        this.addSprite(this.versionElement, 'ui');
    }
    
    createMenuButtons() {
        const buttonData = [
            { 
                text: '🎒 Inventory Management', 
                icon: '🎒',
                action: () => this.engine.switchScene('inventory'),
                color: COLORS.PIXI.MENU_INVENTORY
            },
            { 
                text: '⚔️ Battle Mode', 
                icon: '⚔️',
                action: () => this.engine.switchScene('battle'),
                color: COLORS.PIXI.MENU_BATTLE
            },
            { 
                text: '🌍 World Exploration', 
                icon: '🌍',
                action: () => this.engine.switchScene('world'),
                color: COLORS.PIXI.MENU_WORLD
            },
            { 
                text: '⚙️ Settings', 
                icon: '⚙️',
                action: () => this.showSettings(),
                color: COLORS.PIXI.MENU_SETTINGS
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
        bg.beginFill(data.color, COLORS.ALPHA.HIGH);
        bg.drawRoundedRect(0, 0, config.buttonWidth, config.buttonHeight, LAYOUT.LARGE_RADIUS);
        bg.endFill();
        
        // Button border using constants
        bg.lineStyle(this.getScaledSize(LAYOUT.MEDIUM_BORDER), COLORS.PIXI.WHITE, COLORS.ALPHA.HIGH);
        bg.drawRoundedRect(0, 0, config.buttonWidth, config.buttonHeight, LAYOUT.LARGE_RADIUS);
        
        // Icon
        const iconText = new PIXI.Text(data.icon, {
            fontFamily: FONTS.FAMILY.PRIMARY,
            fontSize: this.getResponsiveFontSize(this.isMobile ? FONTS.SIZE.MOBILE_TITLE : FONTS.SIZE.LARGE_TITLE + 4),
            fill: COLORS.PIXI.WHITE,
            align: FONTS.ALIGN.CENTER,
        });
        iconText.anchor.set(0.5);
        iconText.x = this.getScaledSize(40);
        iconText.y = config.buttonHeight / 2;
        
        // Button text
        const buttonText = new PIXI.Text(data.text, {
            fontFamily: FONTS.FAMILY.PRIMARY,
            fontSize: this.getResponsiveFontSize(this.isMobile ? FONTS.SIZE.MOBILE_SUBTITLE : FONTS.SIZE.TITLE),
            fill: COLORS.PIXI.WHITE,
            align: FONTS.ALIGN.LEFT,
            fontWeight: FONTS.WEIGHT.BOLD,
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
        const targetScale = isHover ? 1.05 : RESPONSIVE.BASE_SCALE;
        const targetAlpha = isHover ? COLORS.ALPHA.OPAQUE : COLORS.ALPHA.HIGH;
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
        button.bg.drawRoundedRect(0, 0, this.menuConfig.buttonWidth, this.menuConfig.buttonHeight, LAYOUT.LARGE_RADIUS);
        button.bg.endFill();
        
        button.bg.lineStyle(
            this.getScaledSize(isHover ? LAYOUT.THICK_BORDER : LAYOUT.MEDIUM_BORDER), 
            COLORS.PIXI.WHITE, 
            isHover ? COLORS.ALPHA.OPAQUE : COLORS.ALPHA.HIGH
        );
        button.bg.drawRoundedRect(0, 0, this.menuConfig.buttonWidth, this.menuConfig.buttonHeight, LAYOUT.LARGE_RADIUS);
    }
    
    onButtonClick(button, action, event) {
        // Add click animation using constants
        button.scale.set(0.95);
        
        setTimeout(() => {
            if (button.parent) {
                button.scale.set(RESPONSIVE.BASE_SCALE);
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
        // Simple color lightening using bit operations
        const r = Math.min(255, ((color >> 16) & 0xFF) + 30);
        const g = Math.min(255, ((color >> 8) & 0xFF) + 30);
        const b = Math.min(255, (color & 0xFF) + 30);
        
        return (r << 16) | (g << 8) | b;
    }
    
    showSettings() {
        console.log('Settings clicked - PixiJS responsive version!');
        
        // Create settings overlay using constants
        const overlay = new PIXI.Graphics();
        overlay.beginFill(COLORS.PIXI.OVERLAY_DARK, COLORS.ALPHA.MEDIUM);
        overlay.drawRect(-this.viewportWidth, -this.viewportHeight, this.viewportWidth * 2, this.viewportHeight * 2);
        overlay.endFill();
        overlay.interactive = true;
        
        // Settings panel dimensions using responsive constants
        const panelWidth = Math.min(this.getScaledSize(600), this.viewportWidth - LAYOUT.PADDING * 2);
        const panelHeight = Math.min(this.getScaledSize(400), this.viewportHeight - LAYOUT.PADDING * 2);
        
        const panel = new PIXI.Graphics();
        panel.beginFill(COLORS.PIXI.DARK_GRAY, COLORS.ALPHA.HIGH);
        panel.drawRoundedRect(-panelWidth / 2, -panelHeight / 2, panelWidth, panelHeight, LAYOUT.EXTRA_LARGE_RADIUS);
        panel.endFill();
        panel.lineStyle(LAYOUT.THICK_BORDER, COLORS.PIXI.WHITE, COLORS.ALPHA.MEDIUM_HIGH);
        panel.drawRoundedRect(-panelWidth / 2, -panelHeight / 2, panelWidth, panelHeight, LAYOUT.EXTRA_LARGE_RADIUS);
        
        // Settings title
        const title = new PIXI.Text('⚙️ SETTINGS', {
            fontFamily: FONTS.FAMILY.PRIMARY,
            fontSize: this.getResponsiveFontSize(FONTS.SIZE.TITLE + 4),
            fill: COLORS.PIXI.WHITE,
            align: FONTS.ALIGN.CENTER,
            fontWeight: FONTS.WEIGHT.BOLD,
        });
        title.anchor.set(0.5, 0);
        title.x = 0;
        title.y = -panelHeight / 2 + LAYOUT.PADDING;
        panel.addChild(title);
        
        // Settings content using font constants
        const viewportInfo = this.engine.getViewportInfo();
        const settingsText = new PIXI.Text(
            `🖥️ Display: ${this.viewportWidth} × ${this.viewportHeight}\n` +
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
                fontFamily: FONTS.FAMILY.PRIMARY,
                fontSize: this.getResponsiveFontSize(this.isMobile ? FONTS.SIZE.MOBILE_BODY + 1 : FONTS.SIZE.SUBTITLE),
                fill: COLORS.PIXI.LIGHT_GRAY,
                align: FONTS.ALIGN.LEFT,
                lineHeight: this.getResponsivePadding(FONTS.SIZE.TITLE),
            }
        );
        settingsText.x = this.getResponsivePadding(LAYOUT.PADDING);
        settingsText.y = this.getResponsivePadding(LAYOUT.PADDING * 4);
        panel.addChild(settingsText);
        
        // Close button using UI constants
        const closeBtn = this.createSimpleButton(
            'Close', 
            panelWidth / 2 - this.getScaledSize(UI.BUTTON.MEDIUM_WIDTH + LAYOUT.PADDING), 
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
        
        // Add entrance animation using alpha constants
        overlay.alpha = COLORS.ALPHA.INVISIBLE;
        panel.scale.set(RESPONSIVE.MOBILE_MIN_SCALE);
        
        const animateIn = () => {
            overlay.alpha = Math.min(COLORS.ALPHA.OPAQUE, overlay.alpha + 0.1);
            panel.scale.set(Math.min(RESPONSIVE.BASE_SCALE, panel.scale.x + 0.05));
            
            if (overlay.alpha < COLORS.ALPHA.OPAQUE || panel.scale.x < RESPONSIVE.BASE_SCALE) {
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
    }
}