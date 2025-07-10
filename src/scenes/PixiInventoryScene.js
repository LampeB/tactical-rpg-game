// Debug tool - Add this to your PixiInventoryScene.js temporarily
// This will help identify exactly where the issue is occurring

import { PixiScene } from "../core/PixiScene.js";

export class PixiInventoryScene extends PixiScene {
  constructor() {
    super();
    console.log("🔧 DEBUG: PixiInventoryScene constructor called");

    // Store original methods for debugging
    this.originalAddSprite = this.addSprite;
    this.addSprite = this.debugAddSprite;

    this.gridCellSize = 60;
    this.inventoryGrid = { x: 50, y: 100, cols: 10, rows: 8 };
    this.storageGrid = { x: 700, y: 100, cols: 8, rows: 6 };
    this.items = [];
    this.draggedItem = null;
  }

  debugAddSprite(sprite, layer = "world") {
    console.log("🔧 DEBUG: addSprite called", {
      spriteName: sprite.name || "unnamed",
      layer: layer,
      hasEngine: !!this.engine,
      hasContainer: !!this.container,
      hasLayers: !!this.layers,
      hasTargetLayer: !!(this.layers && this.layers[layer]),
      isActive: this.isActive,
    });

    const result = this.originalAddSprite.call(this, sprite, layer);

    console.log("🔧 DEBUG: addSprite result", {
      returned: result,
      spriteParent: !!sprite.parent,
      spriteVisible: sprite.visible,
      containerChildren: this.container.children.length,
      layerChildren: this.layers[layer]
        ? this.layers[layer].children.length
        : "layer not found",
    });

    return result;
  }

  onEnter() {
    console.log("🔧 DEBUG: PixiInventoryScene onEnter called");
    console.log("🔧 DEBUG: Engine state", {
      hasEngine: !!this.engine,
      hasApp: !!(this.engine && this.engine.app),
      hasStage: !!(this.engine && this.engine.app && this.engine.app.stage),
      stageChildren: this.engine?.app?.stage?.children?.length || "unknown",
    });

    // Call parent onEnter
    super.onEnter();

    console.log("🔧 DEBUG: After super.onEnter()", {
      isActive: this.isActive,
      containerParent: !!this.container.parent,
      containerVisible: this.container.visible,
      containerChildren: this.container.children.length,
    });

    // Test if we can add a simple graphic
    this.createTestGraphic();

    // Create background
    this.createBackground();

    // Create grids
    this.createGrids();

    // Create a super simple test item
    this.createSimpleTestItem();

    // Create normal items
    this.createBasicItems();

    console.log("🔧 DEBUG: Final scene state", {
      totalItems: this.items.length,
      containerChildren: this.container.children.length,
      worldLayerChildren: this.layers.world.children.length,
      backgroundLayerChildren: this.layers.background.children.length,
      uiLayerChildren: this.layers.ui.children.length,
    });
  }

  createTestGraphic() {
    console.log("🔧 DEBUG: Creating test graphic");

    // Create a simple red square to test basic rendering
    const testGraphic = new PIXI.Graphics();
    testGraphic.beginFill(0xff0000);
    testGraphic.drawRect(0, 0, 100, 100);
    testGraphic.endFill();
    testGraphic.x = 100;
    testGraphic.y = 100;
    testGraphic.name = "testGraphic";

    console.log("🔧 DEBUG: Test graphic created", {
      x: testGraphic.x,
      y: testGraphic.y,
      visible: testGraphic.visible,
    });

    this.addSprite(testGraphic, "world");
  }

  createSimpleTestItem() {
    console.log("🔧 DEBUG: Creating simple test item");

    // Create the simplest possible item
    const simpleItem = new PIXI.Graphics();
    simpleItem.beginFill(0x00ff00); // Green
    simpleItem.drawRect(0, 0, 58, 58);
    simpleItem.endFill();
    simpleItem.x = this.storageGrid.x + 2;
    simpleItem.y = this.storageGrid.y + 2;
    simpleItem.name = "simpleTestItem";
    simpleItem.visible = true;

    console.log("🔧 DEBUG: Simple item created", {
      x: simpleItem.x,
      y: simpleItem.y,
      width: simpleItem.width,
      height: simpleItem.height,
      visible: simpleItem.visible,
    });

    // Add it directly to container to bypass any layer issues
    console.log("🔧 DEBUG: Adding simple item directly to container");
    this.container.addChild(simpleItem);

    console.log("🔧 DEBUG: Simple item added", {
      parent: !!simpleItem.parent,
      containerChildren: this.container.children.length,
    });

    // Also try adding through addSprite
    const simpleItem2 = new PIXI.Graphics();
    simpleItem2.beginFill(0x0000ff); // Blue
    simpleItem2.drawRect(0, 0, 58, 58);
    simpleItem2.endFill();
    simpleItem2.x = this.storageGrid.x + 120;
    simpleItem2.y = this.storageGrid.y + 2;
    simpleItem2.name = "simpleTestItem2";

    console.log("🔧 DEBUG: Adding second simple item through addSprite");
    this.addSprite(simpleItem2, "world");
  }

  createBackground() {
    console.log("🔧 DEBUG: Creating background");

    const bg = new PIXI.Graphics();
    bg.beginFill(0x27ae60);
    bg.drawRect(0, 0, this.engine.width, this.engine.height);
    bg.endFill();
    bg.name = "background";

    this.addSprite(bg, "background");

    // Add title
    const title = new PIXI.Text("📦 INVENTORY DEBUG", {
      fontFamily: "Arial",
      fontSize: 28,
      fill: 0xffffff,
      align: "center",
      fontWeight: "bold",
    });
    title.anchor.set(0.5);
    title.x = this.engine.width / 2;
    title.y = 40;
    title.name = "title";

    this.addSprite(title, "ui");

    console.log("🔧 DEBUG: Background and title created");
  }

  // Add this method to your PixiInventoryScene.js - replace the createGrid method

  // Replace these methods in your PixiInventoryScene.js for perfect alignment

  createGrid(gridData, color, name) {
    console.log(`🔧 Creating ${name} grid without stroke offset`);

    const grid = new PIXI.Graphics();

    // Draw background FIRST - no stroke
    grid.beginFill(color, 0.3);
    grid.drawRect(
      0,
      0,
      gridData.cols * this.gridCellSize,
      gridData.rows * this.gridCellSize
    );
    grid.endFill();

    // Draw internal grid lines with proper alignment
    grid.lineStyle({
      width: 1,
      color: 0xffffff,
      alpha: 0.5,
      alignment: 0.5, // Center the line exactly
    });

    // Vertical lines
    for (let col = 1; col < gridData.cols; col++) {
      const x = col * this.gridCellSize;
      grid.moveTo(x, 0);
      grid.lineTo(x, gridData.rows * this.gridCellSize);
    }

    // Horizontal lines
    for (let row = 1; row < gridData.rows; row++) {
      const y = row * this.gridCellSize;
      grid.moveTo(0, y);
      grid.lineTo(gridData.cols * this.gridCellSize, y);
    }

    // Draw outer border with inside alignment
    grid.lineStyle({
      width: 2,
      color: 0xffffff,
      alpha: 0.8,
      alignment: 0, // Draw border INSIDE
    });

    grid.drawRect(
      0,
      0,
      gridData.cols * this.gridCellSize,
      gridData.rows * this.gridCellSize
    );

    grid.x = gridData.x;
    grid.y = gridData.y;
    grid.name = name + "Graphics";
    grid.visible = true;

    this.addGraphics(grid, "world");
    return grid;
  }

  createGrids() {
    console.log("🔧 Creating grids with stroke fix");

    // Create grids with stroke fix
    this.inventoryGrid.graphics = this.createGrid(
      this.inventoryGrid,
      0x2ecc71,
      "Character Inventory"
    );
    this.storageGrid.graphics = this.createGrid(
      this.storageGrid,
      0x9b59b6,
      "Item Storage"
    );

    // Create labels
    //this.createGridLabels();

    console.log("✅ Grids created with stroke fix");
  }

  // Add these missing methods to your PixiInventoryScene.js

  createBasicItems() {
    console.log("📦 Creating basic items...");

    const itemsData = [
      {
        name: "Sword",
        color: 0xe74c3c,
        width: 1,
        height: 3,
        x: 0,
        y: 0,
        type: "weapon",
        description: "A sharp blade for combat",
      },
      {
        name: "Shield",
        color: 0x34495e,
        width: 2,
        height: 2,
        x: 2,
        y: 0,
        type: "armor",
        description: "A sturdy shield for defense",
      },
      {
        name: "Potion",
        color: 0x27ae60,
        width: 1,
        height: 1,
        x: 4,
        y: 0,
        type: "consumable",
        description: "A healing potion",
      },
      {
        name: "Staff",
        color: 0x9b59b6,
        width: 1,
        height: 2,
        x: 0,
        y: 3,
        type: "weapon",
        description: "A magical staff",
      },
      {
        name: "Gem",
        color: 0xf39c12,
        width: 1,
        height: 1,
        x: 2,
        y: 3,
        type: "gem",
        description: "A magical enhancement gem",
      },
      {
        name: "Bow",
        color: 0x16a085,
        width: 1,
        height: 2,
        x: 3,
        y: 3,
        type: "weapon",
        description: "A ranged weapon",
      },
    ];

    let itemsCreated = 0;

    // Create and place items
    itemsData.forEach((data, index) => {
      try {
        console.log(`Creating item ${index + 1}: ${data.name}`);
        const item = this.createRectangleItem(data);

        // Make sure item is visible
        item.visible = true;

        // Place item and verify it was added
        const placed = this.placeItemInGrid(
          item,
          this.storageGrid,
          data.x,
          data.y
        );

        if (placed) {
          itemsCreated++;
          console.log(
            `✅ Created and placed ${data.name} at (${data.x}, ${data.y})`
          );
        } else {
          console.error(`❌ Failed to place ${data.name}`);
        }
      } catch (error) {
        console.error(`❌ Failed to create ${data.name}:`, error);
      }
    });

    console.log(`📦 Created ${itemsCreated} items total`);
  }

  createRectangleItem(data) {
    console.log(`🔨 Creating rectangle item: ${data.name}`);

    const item = new PIXI.Container();

    // EXACT cell sizing - no padding adjustments
    const pixelWidth = data.width * this.gridCellSize;
    const pixelHeight = data.height * this.gridCellSize;

    console.log(`   Size: ${pixelWidth}x${pixelHeight} pixels`);

    // Item background with internal padding for visual separation
    const bg = new PIXI.Graphics();
    const padding = 4;

    bg.beginFill(data.color);
    bg.drawRoundedRect(
      padding / 2,
      padding / 2,
      pixelWidth - padding,
      pixelHeight - padding,
      4
    );
    bg.endFill();

    // Item border
    bg.lineStyle(2, 0x2c3e50);
    bg.drawRoundedRect(
      padding / 2,
      padding / 2,
      pixelWidth - padding,
      pixelHeight - padding,
      4
    );

    item.addChild(bg);

    // Item name
    const fontSize = Math.min(
      (pixelWidth - padding) / 8,
      (pixelHeight - padding) / 4,
      14
    );
    const text = new PIXI.Text(data.name, {
      fontFamily: "Arial",
      fontSize: fontSize,
      fill: 0xffffff,
      align: "center",
      fontWeight: "bold",
      stroke: 0x000000,
      strokeThickness: 1,
    });
    text.anchor.set(0.5);
    text.x = pixelWidth / 2;
    text.y = pixelHeight / 2;

    item.addChild(text);

    // Type indicator
    const typeIndicator = new PIXI.Graphics();
    const indicatorColor = this.getTypeColor(data.type);
    typeIndicator.beginFill(indicatorColor);
    typeIndicator.drawCircle(pixelWidth - 8, 8, 4);
    typeIndicator.endFill();
    item.addChild(typeIndicator);

    // Store properties
    item.name = data.name;
    item.type = data.type;
    item.color = data.color;
    item.description = data.description || "";
    item.width = data.width;
    item.height = data.height;
    item.gridX = -1;
    item.gridY = -1;
    item.visible = true;

    // Add methods
    item.isPlaced = function () {
      return this.gridX >= 0 && this.gridY >= 0;
    };

    // Make interactive
    item.interactive = true;
    item.cursor = "pointer";

    // Hover effects
    item.on("pointerover", () => {
      if (!this.draggedItem) {
        item.scale.set(1.05);
        this.showTooltip(item);
      }
    });

    item.on("pointerout", () => {
      if (!this.draggedItem) {
        item.scale.set(1);
        this.hideTooltip();
      }
    });

    // Drag functionality
    item.on("pointerdown", (event) => this.startDragging(item, event));

    // Add glow effect for gems
    if (data.type === "gem") {
      const glow = new PIXI.Graphics();
      glow.lineStyle(2, 0xffd700, 0.8);
      glow.drawRoundedRect(-2, -2, pixelWidth + 4, pixelHeight + 4, 6);
      item.addChildAt(glow, 0);

      // Animate glow
      let glowTime = Math.random() * Math.PI * 2;
      const animateGlow = () => {
        glowTime += 0.05;
        glow.alpha = 0.3 + Math.sin(glowTime) * 0.3;
        if (item.parent) {
          requestAnimationFrame(animateGlow);
        }
      };
      animateGlow();
    }

    this.items.push(item);

    console.log(`✅ Rectangle item created: ${data.name}`);
    return item;
  }

  getTypeColor(type) {
    const colors = {
      weapon: 0xe74c3c,
      armor: 0x34495e,
      gem: 0xf39c12,
      consumable: 0x27ae60,
      accessory: 0x9b59b6,
      material: 0x95a5a6,
    };
    return colors[type] || 0x95a5a6;
  }

  placeItemInGrid(item, grid, gridX, gridY) {
    console.log(`📍 Placing ${item.name} at grid (${gridX}, ${gridY})`);

    // EXACT positioning with stroke fix
    const screenX = grid.x + gridX * this.gridCellSize;
    const screenY = grid.y + gridY * this.gridCellSize;

    item.x = screenX;
    item.y = screenY;
    item.gridX = gridX;
    item.gridY = gridY;
    item.visible = true;

    const added = this.addSprite(item, "world");

    console.log(`🎯 Placed ${item.name} at screen (${screenX}, ${screenY})`);
    return true;
  }

  // Also add these utility methods you might be missing

  showTooltip(item) {
    const tooltip = new PIXI.Container();

    const bg = new PIXI.Graphics();
    bg.beginFill(0x2c3e50, 0.95);
    bg.drawRoundedRect(0, 0, 200, 80, 8);
    bg.endFill();
    bg.lineStyle(2, 0x3498db);
    bg.drawRoundedRect(0, 0, 200, 80, 8);

    const title = new PIXI.Text(item.name, {
      fontFamily: "Arial",
      fontSize: 14,
      fill: 0xffffff,
      fontWeight: "bold",
    });
    title.x = 10;
    title.y = 10;

    const info = new PIXI.Text(
      [
        `Type: ${item.type}`,
        `Size: ${item.width}×${item.height}`,
        item.description,
      ].join("\n"),
      {
        fontFamily: "Arial",
        fontSize: 10,
        fill: 0xecf0f1,
        lineHeight: 12,
      }
    );
    info.x = 10;
    info.y = 30;

    tooltip.addChild(bg);
    tooltip.addChild(title);
    tooltip.addChild(info);

    // Position tooltip
    tooltip.x = item.x + item.width * this.gridCellSize + 10;
    tooltip.y = item.y;

    // Keep in bounds
    if (tooltip.x + 200 > this.engine.width) {
      tooltip.x = item.x - 210;
    }

    this.addSprite(tooltip, "ui");
    this.currentTooltip = tooltip;
  }

  hideTooltip() {
    if (this.currentTooltip) {
      this.removeSprite(this.currentTooltip);
      this.currentTooltip = null;
    }
  }

  resetItems() {
    console.log("🔄 Resetting items...");

    // Clear current items
    this.items.forEach((item) => this.removeSprite(item));
    this.items = [];

    // Recreate items
    this.createBasicItems();

    console.log(`✅ Items reset - ${this.items.length} items created`);
  }
}
