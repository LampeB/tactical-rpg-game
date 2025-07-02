import { Scene } from '../core/Scene.js';

export class MenuScene extends Scene {
    constructor() {
        super();
        this.selectedOption = 0;
        this.menuOptions = [
            { text: 'Start Game', action: () => this.engine.switchScene('inventory') },
            { text: 'Battle Mode', action: () => this.engine.switchScene('battle') },
            { text: 'Settings', action: () => this.showSettings() },
            { text: 'Credits', action: () => this.showCredits() }
        ];
    }
    
    onEnter() {
        super.onEnter();
        
        // Menu navigation
        this.engine.inputManager.onKeyPress('ArrowUp', () => this.navigateMenu(-1));
        this.engine.inputManager.onKeyPress('ArrowDown', () => this.navigateMenu(1));
        this.engine.inputManager.onKeyPress('Enter', () => this.selectOption());
        this.engine.inputManager.onKeyPress('Space', () => this.selectOption());
        
        // Quick navigation
        this.engine.inputManager.onKeyPress('KeyI', () => this.engine.switchScene('inventory'));
        this.engine.inputManager.onKeyPress('KeyB', () => this.engine.switchScene('battle'));
    }
    
    navigateMenu(direction) {
        this.selectedOption = (this.selectedOption + direction + this.menuOptions.length) % this.menuOptions.length;
    }
    
    selectOption() {
        this.menuOptions[this.selectedOption].action();
    }
    
    showSettings() {
        console.log('Settings menu would open here');
        // TODO: Implement settings screen
    }
    
    showCredits() {
        console.log('Credits would show here');
        // TODO: Implement credits screen
    }
    
    update(deltaTime) {
        // Handle mouse selection
        if (this.engine.inputManager.isMouseClicked()) {
            const mouse = this.engine.inputManager.getMousePosition();
            this.handleMouseClick(mouse);
        }
    }
    
    handleMouseClick(mouse) {
        const menuStartY = 320;
        const optionHeight = 50;
        
        this.menuOptions.forEach((option, index) => {
            const optionY = menuStartY + index * optionHeight;
            if (mouse.x >= 400 && mouse.x <= 800 && 
                mouse.y >= optionY && mouse.y <= optionY + 40) {
                this.selectedOption = index;
                this.selectOption();
            }
        });
    }
    
    render(ctx) {
        // Background
        ctx.fillStyle = '#3498db';
        ctx.fillRect(50, 50, this.engine.width - 100, this.engine.height - 100);
        
        // Title
        ctx.fillStyle = '#ffffff';
        ctx.font = '48px Arial';
        ctx.textAlign = 'center';
        ctx.fillText('TACTICAL RPG', this.engine.width / 2, 150);
        
        // Subtitle
        ctx.font = '24px Arial';
        ctx.fillStyle = '#ecf0f1';
        ctx.fillText('Inventory Battle System', this.engine.width / 2, 200);
        
        // Version info
        ctx.font = '14px Arial';
        ctx.fillText('v1.0.0 - Modular Architecture', this.engine.width / 2, 230);
        
        // Menu options
        ctx.font = '24px Arial';
        this.menuOptions.forEach((option, index) => {
            const y = 320 + index * 50;
            
            // Highlight selected option
            if (index === this.selectedOption) {
                ctx.fillStyle = 'rgba(255, 255, 255, 0.2)';
                ctx.fillRect(400, y - 25, 400, 40);
            }
            
            ctx.fillStyle = index === this.selectedOption ? '#f39c12' : '#ffffff';
            ctx.fillText(option.text, this.engine.width / 2, y);
        });
        
        // Instructions
        ctx.font = '16px Arial';
        ctx.fillStyle = '#ecf0f1';
        ctx.fillText('Use Arrow Keys + Enter, or Click to Select', this.engine.width / 2, 600);
        ctx.fillText('Quick Keys: I = Inventory, B = Battle', this.engine.width / 2, 630);
        
        // Architecture info
        ctx.font = '12px Arial';
        ctx.fillStyle = '#bdc3c7';
        ctx.fillText('Clean modular architecture with ES6 modules', this.engine.width / 2, 720);
    }
}