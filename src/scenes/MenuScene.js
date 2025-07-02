import { Scene } from "../core/Scene.js";

export class MenuScene extends Scene {
  constructor() {
    super();
    this.menuOptions = [
      {
        text: "Inventory Management",
        action: () => this.engine.switchScene("inventory"),
      },
      { text: "Battle Mode", action: () => this.engine.switchScene("battle") },
      { text: "Settings", action: () => this.showSettings() },
      { text: "Credits", action: () => this.showCredits() },
    ];
    this.hoveredOption = -1;

    // Button dimensions - calculated in render
    this.buttonWidth = 350;
    this.buttonHeight = 50;
    this.buttonSpacing = 70;
    this.buttonStartY = 300;
  }

  onEnter() {
    super.onEnter();
    console.log("Menu scene entered - mouse controls active");
  }

  showSettings() {
    console.log("Settings clicked!");
    alert("Settings menu coming soon!");
  }

  showCredits() {
    console.log("Credits clicked!");
    alert("Made with love using modular architecture!");
  }

  update(deltaTime) {
    const mouse = this.engine.inputManager.getMousePosition();

    // Calculate button positions (same as in render)
    this.hoveredOption = -1;

    for (let i = 0; i < this.menuOptions.length; i++) {
      const buttonX = this.engine.width / 2 - this.buttonWidth / 2;
      const buttonY = this.buttonStartY + i * this.buttonSpacing;

      // Check if mouse is over this button
      if (
        mouse.x >= buttonX &&
        mouse.x <= buttonX + this.buttonWidth &&
        mouse.y >= buttonY &&
        mouse.y <= buttonY + this.buttonHeight
      ) {
        this.hoveredOption = i;
        break;
      }
    }

    // Handle clicks
    if (this.engine.inputManager.isMouseClicked()) {
      console.log("Mouse clicked at:", mouse.x, mouse.y);
      console.log("Hovered option:", this.hoveredOption);

      if (this.hoveredOption >= 0) {
        // ⬇️ ADD THE DEBUG CODE RIGHT HERE ⬇️
        console.log(
          "🚀 EXECUTING ACTION:",
          this.menuOptions[this.hoveredOption].text
        );
        console.log(
          "🚀 Action function:",
          this.menuOptions[this.hoveredOption].action
        );
        // console.log("🚀 Engine object:", this.engine);
        // console.log("🚀 Engine switchScene method:", this.engine.switchScene);

        try {
          this.menuOptions[this.hoveredOption].action();
          console.log("✅ Action executed successfully");
        } catch (error) {
          console.error("❌ Action failed:", error);
        }
      }
    }
  }

  render(ctx) {
    // Background
    ctx.fillStyle = "#3498db";
    ctx.fillRect(50, 50, this.engine.width - 100, this.engine.height - 100);

    // Title
    ctx.fillStyle = "#ffffff";
    ctx.font = "48px Arial";
    ctx.textAlign = "center";
    ctx.fillText("TACTICAL RPG", this.engine.width / 2, 150);

    // Subtitle
    ctx.font = "24px Arial";
    ctx.fillStyle = "#ecf0f1";
    ctx.fillText("Inventory Battle System", this.engine.width / 2, 200);

    // Version info
    ctx.font = "14px Arial";
    ctx.fillText("v1.0.0 - Mouse Controls Only", this.engine.width / 2, 230);

    // Menu buttons
    this.menuOptions.forEach((option, index) => {
      const buttonX = this.engine.width / 2 - this.buttonWidth / 2;
      const buttonY = this.buttonStartY + index * this.buttonSpacing;
      const isHovered = index === this.hoveredOption;

      // Button background
      ctx.fillStyle = isHovered ? "#f39c12" : "rgba(255, 255, 255, 0.2)";
      ctx.fillRect(buttonX, buttonY, this.buttonWidth, this.buttonHeight);

      // Button border
      ctx.strokeStyle = "#ffffff";
      ctx.lineWidth = 2;
      ctx.strokeRect(buttonX, buttonY, this.buttonWidth, this.buttonHeight);

      // Button text
      ctx.fillStyle = isHovered ? "#2c3e50" : "#ffffff";
      ctx.font = "24px Arial";
      ctx.textAlign = "center";
      ctx.fillText(option.text, buttonX + this.buttonWidth / 2, buttonY + 35);
    });

    // Instructions
    ctx.font = "16px Arial";
    ctx.fillStyle = "#ecf0f1";
    ctx.fillText("Click buttons to navigate", this.engine.width / 2, 650);

    // Debug info
    if (this.hoveredOption >= 0) {
      ctx.font = "14px Arial";
      ctx.fillStyle = "#f39c12";
      ctx.fillText(
        `Hovering: ${this.menuOptions[this.hoveredOption].text}`,
        this.engine.width / 2,
        680
      );
    }

    // Mouse position debug (remove this later)
    const mouse = this.engine.inputManager.getMousePosition();
    ctx.font = "12px Arial";
    ctx.fillStyle = "#ffffff";
    ctx.textAlign = "left";
    ctx.fillText(`Mouse: ${mouse.x}, ${mouse.y}`, 60, 80);
  }
}
