// src/utils/ShapeHelper.js - Helper for creating and managing custom item shapes

export class ShapeHelper {
  /**
   * Create a rectangular shape
   * @param {number} width - Width in grid cells
   * @param {number} height - Height in grid cells
   * @returns {Array} Array of [x, y] coordinates
   */
  static createRectangle(width, height) {
    const coords = [];
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        coords.push([x, y]);
      }
    }
    return coords;
  }

  /**
   * Create an L-shaped item
   * @param {number} armLength - Length of both arms
   * @param {string} orientation - 'tl', 'tr', 'bl', 'br' (top-left, top-right, etc.)
   * @returns {Array} Array of [x, y] coordinates
   */
  static createLShape(armLength, orientation = "tl") {
    const coords = [];

    switch (orientation) {
      case "tl": // Top-left L
        // Vertical arm
        for (let y = 0; y < armLength; y++) {
          coords.push([0, y]);
        }
        // Horizontal arm
        for (let x = 1; x < armLength; x++) {
          coords.push([x, armLength - 1]);
        }
        break;

      case "tr": // Top-right L
        // Vertical arm
        for (let y = 0; y < armLength; y++) {
          coords.push([armLength - 1, y]);
        }
        // Horizontal arm
        for (let x = 0; x < armLength - 1; x++) {
          coords.push([x, armLength - 1]);
        }
        break;

      case "bl": // Bottom-left L
        // Vertical arm
        for (let y = 0; y < armLength; y++) {
          coords.push([0, y]);
        }
        // Horizontal arm
        for (let x = 1; x < armLength; x++) {
          coords.push([x, 0]);
        }
        break;

      case "br": // Bottom-right L
        // Vertical arm
        for (let y = 0; y < armLength; y++) {
          coords.push([armLength - 1, y]);
        }
        // Horizontal arm
        for (let x = 0; x < armLength - 1; x++) {
          coords.push([x, 0]);
        }
        break;
    }

    return coords;
  }

  /**
   * Create a T-shaped item
   * @param {number} stemLength - Length of the stem
   * @param {number} topWidth - Width of the top bar
   * @param {string} orientation - 'up', 'down', 'left', 'right'
   * @returns {Array} Array of [x, y] coordinates
   */
  static createTShape(stemLength, topWidth, orientation = "up") {
    const coords = [];
    const center = Math.floor(topWidth / 2);

    switch (orientation) {
      case "up": // T pointing up
        // Top bar
        for (let x = 0; x < topWidth; x++) {
          coords.push([x, 0]);
        }
        // Stem
        for (let y = 1; y < stemLength; y++) {
          coords.push([center, y]);
        }
        break;

      case "down": // T pointing down
        // Stem
        for (let y = 0; y < stemLength - 1; y++) {
          coords.push([center, y]);
        }
        // Bottom bar
        for (let x = 0; x < topWidth; x++) {
          coords.push([x, stemLength - 1]);
        }
        break;

      case "left": // T pointing left
        // Left bar
        for (let y = 0; y < topWidth; y++) {
          coords.push([0, y]);
        }
        // Stem
        for (let x = 1; x < stemLength; x++) {
          coords.push([x, center]);
        }
        break;

      case "right": // T pointing right
        // Stem
        for (let x = 0; x < stemLength - 1; x++) {
          coords.push([x, center]);
        }
        // Right bar
        for (let y = 0; y < topWidth; y++) {
          coords.push([stemLength - 1, y]);
        }
        break;
    }

    return coords;
  }

  /**
   * Create a U-shaped item
   * @param {number} height - Height of the U
   * @param {number} width - Width of the U
   * @param {string} orientation - 'up', 'down', 'left', 'right'
   * @returns {Array} Array of [x, y] coordinates
   */
  static createUShape(height, width, orientation = "up") {
    const coords = [];

    switch (orientation) {
      case "up": // U opening upward
        // Left side
        for (let y = 0; y < height; y++) {
          coords.push([0, y]);
        }
        // Bottom
        for (let x = 1; x < width - 1; x++) {
          coords.push([x, height - 1]);
        }
        // Right side
        for (let y = 0; y < height; y++) {
          coords.push([width - 1, y]);
        }
        break;

      case "down": // U opening downward
        // Top
        for (let x = 0; x < width; x++) {
          coords.push([x, 0]);
        }
        // Left side
        for (let y = 1; y < height - 1; y++) {
          coords.push([0, y]);
        }
        // Right side
        for (let y = 1; y < height - 1; y++) {
          coords.push([width - 1, y]);
        }
        break;

      case "left": // U opening leftward
        // Top
        for (let x = 0; x < width; x++) {
          coords.push([x, 0]);
        }
        // Right side
        for (let y = 1; y < height - 1; y++) {
          coords.push([width - 1, y]);
        }
        // Bottom
        for (let x = 0; x < width; x++) {
          coords.push([x, height - 1]);
        }
        break;

      case "right": // U opening rightward
        // Left side
        for (let y = 0; y < height; y++) {
          coords.push([0, y]);
        }
        // Top
        for (let x = 1; x < width - 1; x++) {
          coords.push([x, 0]);
        }
        // Bottom
        for (let x = 1; x < width - 1; x++) {
          coords.push([x, height - 1]);
        }
        break;
    }

    return coords;
  }

  /**
   * Create a plus/cross shape
   * @param {number} armLength - Length of each arm from center
   * @returns {Array} Array of [x, y] coordinates
   */
  static createPlusShape(armLength) {
    const coords = [];
    const center = armLength;

    // Horizontal bar
    for (let x = 0; x < armLength * 2 + 1; x++) {
      coords.push([x, center]);
    }

    // Vertical bar
    for (let y = 0; y < armLength * 2 + 1; y++) {
      if (y !== center) {
        // Don't duplicate center
        coords.push([center, y]);
      }
    }

    return coords;
  }

  /**
   * Create a Z-shaped item
   * @param {number} width - Width of horizontal segments
   * @param {number} height - Total height
   * @param {boolean} mirrored - Whether to mirror the Z
   * @returns {Array} Array of [x, y] coordinates
   */
  static createZShape(width, height, mirrored = false) {
    const coords = [];

    if (!mirrored) {
      // Top horizontal
      for (let x = 0; x < width; x++) {
        coords.push([x, 0]);
      }

      // Diagonal
      for (let y = 1; y < height - 1; y++) {
        const x = Math.floor((width - 1) * (y / (height - 1)));
        coords.push([width - 1 - x, y]);
      }

      // Bottom horizontal
      for (let x = 0; x < width; x++) {
        coords.push([x, height - 1]);
      }
    } else {
      // Mirrored Z (S-like)
      // Top horizontal
      for (let x = 0; x < width; x++) {
        coords.push([x, 0]);
      }

      // Diagonal
      for (let y = 1; y < height - 1; y++) {
        const x = Math.floor((width - 1) * (y / (height - 1)));
        coords.push([x, y]);
      }

      // Bottom horizontal
      for (let x = 0; x < width; x++) {
        coords.push([x, height - 1]);
      }
    }

    return coords;
  }

  /**
   * Create a diamond shape
   * @param {number} size - Size of the diamond
   * @returns {Array} Array of [x, y] coordinates
   */
  static createDiamond(size) {
    const coords = [];
    const center = Math.floor(size / 2);

    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        const distance = Math.abs(x - center) + Math.abs(y - center);
        if (distance <= center) {
          coords.push([x, y]);
        }
      }
    }

    return coords;
  }

  /**
   * Create a hollow rectangle (frame)
   * @param {number} width - Width of the frame
   * @param {number} height - Height of the frame
   * @param {number} thickness - Thickness of the frame walls
   * @returns {Array} Array of [x, y] coordinates
   */
  static createFrame(width, height, thickness = 1) {
    const coords = [];

    // Top and bottom
    for (let y = 0; y < thickness; y++) {
      for (let x = 0; x < width; x++) {
        coords.push([x, y]); // Top
        if (y !== height - 1 - y) {
          // Avoid duplicates for thin frames
          coords.push([x, height - 1 - y]); // Bottom
        }
      }
    }

    // Left and right (excluding corners already added)
    for (let x = 0; x < thickness; x++) {
      for (let y = thickness; y < height - thickness; y++) {
        coords.push([x, y]); // Left
        if (x !== width - 1 - x) {
          // Avoid duplicates for thin frames
          coords.push([width - 1 - x, y]); // Right
        }
      }
    }

    return coords;
  }

  /**
   * Rotate a shape by 90 degrees clockwise
   * @param {Array} coords - Array of [x, y] coordinates
   * @returns {Array} Rotated coordinates
   */
  static rotateClockwise(coords) {
    // Find bounds
    const xs = coords.map((c) => c[0]);
    const ys = coords.map((c) => c[1]);
    const maxY = Math.max(...ys);

    // Rotate and normalize
    const rotated = coords.map(([x, y]) => [maxY - y, x]);

    // Normalize to start from (0, 0)
    return this.normalize(rotated);
  }

  /**
   * Rotate a shape by 90 degrees counter-clockwise
   * @param {Array} coords - Array of [x, y] coordinates
   * @returns {Array} Rotated coordinates
   */
  static rotateCounterClockwise(coords) {
    // Find bounds
    const xs = coords.map((c) => c[0]);
    const ys = coords.map((c) => c[1]);
    const maxX = Math.max(...xs);

    // Rotate and normalize
    const rotated = coords.map(([x, y]) => [y, maxX - x]);

    // Normalize to start from (0, 0)
    return this.normalize(rotated);
  }

  /**
   * Mirror a shape horizontally
   * @param {Array} coords - Array of [x, y] coordinates
   * @returns {Array} Mirrored coordinates
   */
  static mirrorHorizontal(coords) {
    const xs = coords.map((c) => c[0]);
    const maxX = Math.max(...xs);

    const mirrored = coords.map(([x, y]) => [maxX - x, y]);
    return this.normalize(mirrored);
  }

  /**
   * Mirror a shape vertically
   * @param {Array} coords - Array of [x, y] coordinates
   * @returns {Array} Mirrored coordinates
   */
  static mirrorVertical(coords) {
    const ys = coords.map((c) => c[1]);
    const maxY = Math.max(...ys);

    const mirrored = coords.map(([x, y]) => [x, maxY - y]);
    return this.normalize(mirrored);
  }

  /**
   * Normalize coordinates to start from (0, 0)
   * @param {Array} coords - Array of [x, y] coordinates
   * @returns {Array} Normalized coordinates
   */
  static normalize(coords) {
    if (coords.length === 0) return coords;

    const xs = coords.map((c) => c[0]);
    const ys = coords.map((c) => c[1]);
    const minX = Math.min(...xs);
    const minY = Math.min(...ys);

    return coords.map(([x, y]) => [x - minX, y - minY]);
  }

  /**
   * Create a shape from a text pattern
   * @param {string} pattern - Multi-line string where 'X' represents filled cells
   * @returns {Array} Array of [x, y] coordinates
   */
  static createFromPattern(pattern) {
    const lines = pattern.trim().split("\n");
    const coords = [];

    lines.forEach((line, y) => {
      [...line].forEach((char, x) => {
        if (char === "X" || char === "x" || char === "1") {
          coords.push([x, y]);
        }
      });
    });

    return this.normalize(coords);
  }

  /**
   * Get pre-defined shapes
   * @returns {Object} Object containing various pre-defined shapes
   */
  static getPreDefinedShapes() {
    return {
      // Tetris-like shapes
      tetrominoI: this.createRectangle(1, 4),
      tetrominoO: this.createRectangle(2, 2),
      tetrominoT: this.createTShape(3, 3, "down"),
      tetrominoS: this.createFromPattern("XX\n.XX"),
      tetrominoZ: this.createFromPattern(".XX\nXX."),
      tetrominoJ: this.createLShape(3, "bl"),
      tetrominoL: this.createLShape(3, "br"),

      // Weapon shapes
      sword: this.createRectangle(1, 3),
      dagger: this.createRectangle(1, 1),
      bow: this.createUShape(3, 3, "up"),
      staff: this.createTShape(3, 3, "up"),
      axe: this.createLShape(3, "tl"),
      hammer: this.createTShape(2, 3, "up"),

      // Armor shapes
      helmet: this.createUShape(2, 3, "down"),
      chestplate: this.createRectangle(2, 3),
      shield: this.createRectangle(2, 2),

      // Accessories
      ring: this.createFromPattern("X"),
      amulet: this.createFromPattern("X\nX"),
      belt: this.createFromPattern("XXXX"),

      // Special shapes
      cross: this.createPlusShape(1),
      diamond: this.createDiamond(3),
      frame: this.createFrame(4, 4, 1),

      // Complex shapes
      boot: this.createFromPattern("XX\nXX\nX."),
      crown: this.createFromPattern("X.X\nXXX"),
      key: this.createFromPattern("XX\n.X\n.X"),
      potion: this.createFromPattern(".X.\nXXX"),

      // Large complex items
      tower: this.createFromPattern("X\nX\nX\nX\nX"),
      castle: this.createFromPattern("X.X\nXXX\nXXX"),
      scroll: this.createFromPattern("XXXX\nXXXX"),
    };
  }

  /**
   * Validate a shape (check for connected components, etc.)
   * @param {Array} coords - Array of [x, y] coordinates
   * @returns {Object} Validation result
   */
  static validateShape(coords) {
    if (coords.length === 0) {
      return { valid: false, error: "Shape is empty" };
    }

    // Check for duplicate coordinates
    const coordSet = new Set(coords.map((c) => `${c[0]},${c[1]}`));
    if (coordSet.size !== coords.length) {
      return { valid: false, error: "Shape contains duplicate coordinates" };
    }

    // Check if shape is connected (all cells are reachable)
    const visited = new Set();
    const stack = [coords[0]];
    visited.add(`${coords[0][0]},${coords[0][1]}`);

    while (stack.length > 0) {
      const [x, y] = stack.pop();

      // Check all 4 adjacent cells
      [
        [0, 1],
        [0, -1],
        [1, 0],
        [-1, 0],
      ].forEach(([dx, dy]) => {
        const nx = x + dx;
        const ny = y + dy;
        const key = `${nx},${ny}`;

        if (coordSet.has(key) && !visited.has(key)) {
          visited.add(key);
          stack.push([nx, ny]);
        }
      });
    }

    if (visited.size !== coords.length) {
      return { valid: false, error: "Shape is not connected" };
    }

    return { valid: true };
  }

  /**
   * Get bounding box of a shape
   * @param {Array} coords - Array of [x, y] coordinates
   * @returns {Object} Bounding box {minX, minY, maxX, maxY, width, height}
   */
  static getBounds(coords) {
    if (coords.length === 0) {
      return { minX: 0, minY: 0, maxX: 0, maxY: 0, width: 0, height: 0 };
    }

    const xs = coords.map((c) => c[0]);
    const ys = coords.map((c) => c[1]);

    const minX = Math.min(...xs);
    const minY = Math.min(...ys);
    const maxX = Math.max(...xs);
    const maxY = Math.max(...ys);

    return {
      minX,
      minY,
      maxX,
      maxY,
      width: maxX - minX + 1,
      height: maxY - minY + 1,
    };
  }

  /**
   * Convert shape to visual ASCII representation
   * @param {Array} coords - Array of [x, y] coordinates
   * @param {string} fillChar - Character to use for filled cells
   * @param {string} emptyChar - Character to use for empty cells
   * @returns {string} ASCII representation
   */
  static toAscii(coords, fillChar = "X", emptyChar = ".") {
    const bounds = this.getBounds(coords);
    const coordSet = new Set(coords.map((c) => `${c[0]},${c[1]}`));

    const lines = [];
    for (let y = bounds.minY; y <= bounds.maxY; y++) {
      let line = "";
      for (let x = bounds.minX; x <= bounds.maxX; x++) {
        line += coordSet.has(`${x},${y}`) ? fillChar : emptyChar;
      }
      lines.push(line);
    }

    return lines.join("\n");
  }
}
