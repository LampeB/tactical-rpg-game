export class PixiInputManager {
    constructor() {
      console.log("🎮 Initializing responsive input manager");
  
      // Basic input state
      this.keys = {};
      this.mouse = {
        x: 0,
        y: 0,
        clicked: false,
        pressed: false,
        button: 0,
        lastX: 0,
        lastY: 0,
        deltaX: 0,
        deltaY: 0,
      };
  
      // Touch input state
      this.touches = new Map();
      this.touchStartTime = 0;
      this.touchTapThreshold = 200; // ms
      this.touchMoveThreshold = 10; // pixels
  
      // Screen and scaling properties
      this.screen = {
        width: window.innerWidth,
        height: window.innerHeight,
        devicePixelRatio: window.devicePixelRatio || 1,
        scale: 1,
        isFullscreen: false,
        isPortrait: false,
        isMobile: false,
        isTablet: false,
      };
  
      // Canvas and transformation properties
      this.canvas = null;
      this.pixiApp = null;
      this.canvasRect = null;
      this.transform = {
        offsetX: 0,
        offsetY: 0,
        scaleX: 1,
        scaleY: 1,
      };
  
      // Movement sensitivity scaling
      this.movementSensitivity = {
        base: 1,
        mobile: 0.8,
        tablet: 0.9,
        desktop: 1,
        current: 1,
      };
  
      // Event callbacks
      this.keyCallbacks = new Map();
      this.mouseCallbacks = new Map();
      this.touchCallbacks = new Map();
      this.resizeCallbacks = new Set();
  
      // Bound event handlers for cleanup
      this.boundHandlers = {
        keydown: this.onKeyDown.bind(this),
        keyup: this.onKeyUp.bind(this),
        mousedown: this.onMouseDown.bind(this),
        mouseup: this.onMouseUp.bind(this),
        mousemove: this.onMouseMove.bind(this),
        touchstart: this.onTouchStart.bind(this),
        touchend: this.onTouchEnd.bind(this),
        touchmove: this.onTouchMove.bind(this),
        touchcancel: this.onTouchCancel.bind(this),
        resize: this.onResize.bind(this),
        fullscreenchange: this.onFullscreenChange.bind(this),
        contextmenu: this.onContextMenu.bind(this),
      };
  
      // Device type detection
      this.detectDeviceType();
  
      // Initialize
      this.setupEventListeners();
      this.updateScreenInfo();
      this.updateMovementSensitivity();
  
      console.log("✅ Responsive input manager initialized", {
        isMobile: this.screen.isMobile,
        isTablet: this.screen.isTablet,
        devicePixelRatio: this.screen.devicePixelRatio,
        sensitivity: this.movementSensitivity.current,
      });
    }
  
    // ============= INITIALIZATION =============
  
    setPixiApp(app) {
      console.log("🎯 Connecting input manager to PixiJS app");
      this.pixiApp = app;
      this.canvas = app.view;
      this.updateCanvasRect();
      this.updateTransform();
      console.log("✅ Input manager connected to PixiJS");
    }
  
    detectDeviceType() {
      const userAgent = navigator.userAgent.toLowerCase();
      const width = window.innerWidth;
      const height = window.innerHeight;
  
      // Mobile detection
      this.screen.isMobile = /android|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(userAgent) ||
                            ('ontouchstart' in window && Math.max(width, height) < 1024);
  
      // Tablet detection (touch device but larger screen)
      this.screen.isTablet = ('ontouchstart' in window && !this.screen.isMobile) ||
                            (width >= 768 && width < 1024) ||
                            (height >= 768 && height < 1024);
  
      // Portrait detection
      this.screen.isPortrait = height > width;
  
      console.log("📱 Device type detected:", {
        isMobile: this.screen.isMobile,
        isTablet: this.screen.isTablet,
        isPortrait: this.screen.isPortrait,
        hasTouch: 'ontouchstart' in window,
      });
    }
  
    updateScreenInfo() {
      this.screen.width = window.innerWidth;
      this.screen.height = window.innerHeight;
      this.screen.devicePixelRatio = window.devicePixelRatio || 1;
      this.screen.isPortrait = this.screen.height > this.screen.width;
      this.screen.isFullscreen = this.isFullscreen();
  
      // Calculate base scale factor
      this.screen.scale = Math.min(
        this.screen.width / 1200,
        this.screen.height / 800
      );
      this.screen.scale = Math.max(0.5, Math.min(2, this.screen.scale));
  
      console.log("📐 Screen info updated:", {
        width: this.screen.width,
        height: this.screen.height,
        scale: this.screen.scale,
        isFullscreen: this.screen.isFullscreen,
        isPortrait: this.screen.isPortrait,
      });
    }
  
    updateCanvasRect() {
      if (this.canvas) {
        this.canvasRect = this.canvas.getBoundingClientRect();
        console.log("🎨 Canvas rect updated:", this.canvasRect);
      }
    }
  
    updateTransform() {
      if (!this.canvas || !this.canvasRect) return;
  
      // Calculate transformation for coordinate mapping
      this.transform.offsetX = this.canvasRect.left;
      this.transform.offsetY = this.canvasRect.top;
      this.transform.scaleX = this.canvas.width / this.canvasRect.width;
      this.transform.scaleY = this.canvas.height / this.canvasRect.height;
  
      console.log("🔄 Transform updated:", this.transform);
    }
  
    updateMovementSensitivity() {
      if (this.screen.isMobile) {
        this.movementSensitivity.current = this.movementSensitivity.mobile;
      } else if (this.screen.isTablet) {
        this.movementSensitivity.current = this.movementSensitivity.tablet;
      } else {
        this.movementSensitivity.current = this.movementSensitivity.desktop;
      }
  
      // Adjust for screen scale
      this.movementSensitivity.current *= this.screen.scale;
  
      console.log("🎯 Movement sensitivity updated:", this.movementSensitivity.current);
    }
  
    // ============= EVENT LISTENERS SETUP =============
  
    setupEventListeners() {
      console.log("🔌 Setting up event listeners");
  
      // Keyboard events
      document.addEventListener('keydown', this.boundHandlers.keydown);
      document.addEventListener('keyup', this.boundHandlers.keyup);
  
      // Mouse events
      document.addEventListener('mousedown', this.boundHandlers.mousedown);
      document.addEventListener('mouseup', this.boundHandlers.mouseup);
      document.addEventListener('mousemove', this.boundHandlers.mousemove);
  
      // Touch events
      document.addEventListener('touchstart', this.boundHandlers.touchstart, { passive: false });
      document.addEventListener('touchend', this.boundHandlers.touchend, { passive: false });
      document.addEventListener('touchmove', this.boundHandlers.touchmove, { passive: false });
      document.addEventListener('touchcancel', this.boundHandlers.touchcancel, { passive: false });
  
      // Window events
      window.addEventListener('resize', this.boundHandlers.resize);
      document.addEventListener('fullscreenchange', this.boundHandlers.fullscreenchange);
      document.addEventListener('webkitfullscreenchange', this.boundHandlers.fullscreenchange);
      document.addEventListener('mozfullscreenchange', this.boundHandlers.fullscreenchange);
      document.addEventListener('msfullscreenchange', this.boundHandlers.fullscreenchange);
  
      // Prevent context menu on touch devices
      document.addEventListener('contextmenu', this.boundHandlers.contextmenu);
  
      // Prevent default touch behaviors
      document.addEventListener('touchstart', (e) => {
        if (e.touches.length > 1) {
          e.preventDefault(); // Prevent pinch zoom
        }
      }, { passive: false });
  
      document.addEventListener('touchmove', (e) => {
        if (e.touches.length > 1) {
          e.preventDefault(); // Prevent pinch zoom
        }
      }, { passive: false });
  
      console.log("✅ Event listeners set up");
    }
  
    // ============= KEYBOARD EVENTS =============
  
    onKeyDown(event) {
      const keyCode = event.code;
      
      if (!this.keys[keyCode]) {
        this.keys[keyCode] = true;
        this.triggerKeyCallback(keyCode, 'down');
      }
  
      // Prevent default for game keys
      if (this.isGameKey(keyCode)) {
        event.preventDefault();
      }
    }
  
    onKeyUp(event) {
      const keyCode = event.code;
      this.keys[keyCode] = false;
      this.triggerKeyCallback(keyCode, 'up');
    }
  
    isGameKey(keyCode) {
      const gameKeys = [
        'Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight',
        'KeyW', 'KeyA', 'KeyS', 'KeyD', 'KeyQ', 'KeyE', 'KeyR',
        'KeyT', 'KeyY', 'KeyU', 'KeyI', 'KeyO', 'KeyP',
        'Digit1', 'Digit2', 'Digit3', 'Digit4', 'Digit5',
        'Escape', 'Enter', 'Tab', 'Backspace'
      ];
      return gameKeys.includes(keyCode);
    }
  
    // ============= MOUSE EVENTS =============
  
    onMouseDown(event) {
      this.updateMousePosition(event);
      this.mouse.pressed = true;
      this.mouse.clicked = true;
      this.mouse.button = event.button;
  
      this.triggerMouseCallback('down', {
        x: this.mouse.x,
        y: this.mouse.y,
        button: this.mouse.button,
        originalEvent: event,
      });
  
      console.log("🖱️ Mouse down:", this.mouse.x, this.mouse.y, this.mouse.button);
    }
  
    onMouseUp(event) {
      this.updateMousePosition(event);
      this.mouse.pressed = false;
      this.mouse.button = event.button;
  
      this.triggerMouseCallback('up', {
        x: this.mouse.x,
        y: this.mouse.y,
        button: this.mouse.button,
        originalEvent: event,
      });
  
      console.log("🖱️ Mouse up:", this.mouse.x, this.mouse.y);
    }
  
    onMouseMove(event) {
      this.updateMousePosition(event);
  
      this.triggerMouseCallback('move', {
        x: this.mouse.x,
        y: this.mouse.y,
        deltaX: this.mouse.deltaX,
        deltaY: this.mouse.deltaY,
        originalEvent: event,
      });
  
      // Update UI mouse position display
      this.updateMouseDisplay();
    }
  
    updateMousePosition(event) {
      this.mouse.lastX = this.mouse.x;
      this.mouse.lastY = this.mouse.y;
  
      if (this.canvasRect) {
        // Transform screen coordinates to canvas coordinates
        const clientX = event.clientX - this.transform.offsetX;
        const clientY = event.clientY - this.transform.offsetY;
  
        this.mouse.x = clientX * this.transform.scaleX;
        this.mouse.y = clientY * this.transform.scaleY;
      } else {
        // Fallback
        this.mouse.x = event.clientX;
        this.mouse.y = event.clientY;
      }
  
      // Calculate delta
      this.mouse.deltaX = this.mouse.x - this.mouse.lastX;
      this.mouse.deltaY = this.mouse.y - this.mouse.lastY;
    }
  
    // ============= TOUCH EVENTS =============
  
    onTouchStart(event) {
      console.log("👆 Touch start:", event.touches.length, "touches");
      
      this.touchStartTime = performance.now();
      
      for (let i = 0; i < event.touches.length; i++) {
        const touch = event.touches[i];
        const touchData = this.createTouchData(touch);
        this.touches.set(touch.identifier, touchData);
  
        // Treat first touch as mouse for compatibility
        if (i === 0) {
          this.updateMouseFromTouch(touch);
          this.mouse.pressed = true;
          this.mouse.clicked = true;
          this.mouse.button = 0;
        }
  
        this.triggerTouchCallback('start', touchData);
      }
  
      // Prevent default to avoid mouse events
      if (this.isGameTouch(event)) {
        event.preventDefault();
      }
    }
  
    onTouchEnd(event) {
      console.log("👆 Touch end:", event.changedTouches.length, "touches");
      
      const touchEndTime = performance.now();
      const touchDuration = touchEndTime - this.touchStartTime;
  
      for (let i = 0; i < event.changedTouches.length; i++) {
        const touch = event.changedTouches[i];
        const touchData = this.touches.get(touch.identifier);
  
        if (touchData) {
          // Update final position
          this.updateTouchPosition(touchData, touch);
  
          // Detect tap gesture
          const moved = Math.abs(touchData.deltaX) + Math.abs(touchData.deltaY);
          const isTap = touchDuration < this.touchTapThreshold && moved < this.touchMoveThreshold;
  
          touchData.isTap = isTap;
          touchData.duration = touchDuration;
  
          // Treat first touch as mouse for compatibility
          if (i === 0) {
            this.updateMouseFromTouch(touch);
            this.mouse.pressed = false;
          }
  
          this.triggerTouchCallback('end', touchData);
          this.touches.delete(touch.identifier);
        }
      }
  
      // Prevent default
      if (this.isGameTouch(event)) {
        event.preventDefault();
      }
    }
  
    onTouchMove(event) {
      for (let i = 0; i < event.touches.length; i++) {
        const touch = event.touches[i];
        const touchData = this.touches.get(touch.identifier);
  
        if (touchData) {
          this.updateTouchPosition(touchData, touch);
  
          // Treat first touch as mouse for compatibility
          if (i === 0) {
            this.updateMouseFromTouch(touch);
          }
  
          this.triggerTouchCallback('move', touchData);
        }
      }
  
      // Update UI mouse position display
      this.updateMouseDisplay();
  
      // Prevent default
      if (this.isGameTouch(event)) {
        event.preventDefault();
      }
    }
  
    onTouchCancel(event) {
      console.log("👆 Touch cancel:", event.changedTouches.length, "touches");
      
      for (let i = 0; i < event.changedTouches.length; i++) {
        const touch = event.changedTouches[i];
        const touchData = this.touches.get(touch.identifier);
  
        if (touchData) {
          this.triggerTouchCallback('cancel', touchData);
          this.touches.delete(touch.identifier);
        }
      }
  
      // Reset mouse state
      this.mouse.pressed = false;
      this.mouse.clicked = false;
    }
  
    createTouchData(touch) {
      const touchData = {
        id: touch.identifier,
        startX: 0,
        startY: 0,
        x: 0,
        y: 0,
        lastX: 0,
        lastY: 0,
        deltaX: 0,
        deltaY: 0,
        startTime: performance.now(),
        force: touch.force || 0,
        isTap: false,
        duration: 0,
      };
  
      this.updateTouchPosition(touchData, touch);
      touchData.startX = touchData.x;
      touchData.startY = touchData.y;
  
      return touchData;
    }
  
    updateTouchPosition(touchData, touch) {
      touchData.lastX = touchData.x;
      touchData.lastY = touchData.y;
  
      if (this.canvasRect) {
        // Transform screen coordinates to canvas coordinates
        const clientX = touch.clientX - this.transform.offsetX;
        const clientY = touch.clientY - this.transform.offsetY;
  
        touchData.x = clientX * this.transform.scaleX;
        touchData.y = clientY * this.transform.scaleY;
      } else {
        // Fallback
        touchData.x = touch.clientX;
        touchData.y = touch.clientY;
      }
  
      // Calculate delta
      touchData.deltaX = touchData.x - touchData.lastX;
      touchData.deltaY = touchData.y - touchData.lastY;
  
      // Update force if available
      touchData.force = touch.force || 0;
    }
  
    updateMouseFromTouch(touch) {
      if (this.canvasRect) {
        const clientX = touch.clientX - this.transform.offsetX;
        const clientY = touch.clientY - this.transform.offsetY;
  
        this.mouse.lastX = this.mouse.x;
        this.mouse.lastY = this.mouse.y;
        this.mouse.x = clientX * this.transform.scaleX;
        this.mouse.y = clientY * this.transform.scaleY;
        this.mouse.deltaX = this.mouse.x - this.mouse.lastX;
        this.mouse.deltaY = this.mouse.y - this.mouse.lastY;
      }
    }
  
    isGameTouch(event) {
      // Check if touch is on game canvas or game area
      if (!this.canvasRect) return false;
  
      const touch = event.touches[0] || event.changedTouches[0];
      if (!touch) return false;
  
      const rect = this.canvasRect;
      return touch.clientX >= rect.left &&
             touch.clientX <= rect.right &&
             touch.clientY >= rect.top &&
             touch.clientY <= rect.bottom;
    }
  
    // ============= WINDOW EVENTS =============
  
    onResize(event) {
      console.log("📐 Window resize detected");
      
      this.updateScreenInfo();
      this.detectDeviceType();
      this.updateCanvasRect();
      this.updateTransform();
      this.updateMovementSensitivity();
  
      // Trigger resize callbacks
      this.resizeCallbacks.forEach(callback => {
        try {
          callback({
            width: this.screen.width,
            height: this.screen.height,
            scale: this.screen.scale,
            isMobile: this.screen.isMobile,
            isTablet: this.screen.isTablet,
            isPortrait: this.screen.isPortrait,
          });
        } catch (error) {
          console.error("Error in resize callback:", error);
        }
      });
  
      console.log("✅ Resize handled");
    }
  
    onFullscreenChange(event) {
      const wasFullscreen = this.screen.isFullscreen;
      this.screen.isFullscreen = this.isFullscreen();
      
      if (wasFullscreen !== this.screen.isFullscreen) {
        console.log("🖥️ Fullscreen changed:", this.screen.isFullscreen);
        
        // Delay update to allow for transition
        setTimeout(() => {
          this.updateScreenInfo();
          this.updateCanvasRect();
          this.updateTransform();
          this.updateMovementSensitivity();
        }, 100);
      }
    }
  
    onContextMenu(event) {
      // Prevent context menu on touch devices during game interactions
      if (this.screen.isMobile || this.screen.isTablet) {
        if (this.isGameTouch(event)) {
          event.preventDefault();
        }
      }
    }
  
    // ============= UTILITY METHODS =============
  
    isFullscreen() {
      return !!(document.fullscreenElement ||
                document.webkitFullscreenElement ||
                document.mozFullScreenElement ||
                document.msFullscreenElement);
    }
  
    transformCoordinates(screenX, screenY) {
      if (!this.canvasRect) {
        return { x: screenX, y: screenY };
      }
  
      const clientX = screenX - this.transform.offsetX;
      const clientY = screenY - this.transform.offsetY;
  
      return {
        x: clientX * this.transform.scaleX,
        y: clientY * this.transform.scaleY,
      };
    }
  
    updateMouseDisplay() {
      const mousePosElement = document.getElementById("mousePos");
      if (mousePosElement) {
        mousePosElement.textContent = `${Math.floor(this.mouse.x)}, ${Math.floor(this.mouse.y)}`;
      }
    }
  
    // ============= CALLBACK MANAGEMENT =============
  
    onKeyPress(keyCode, callback) {
      if (!this.keyCallbacks.has(keyCode)) {
        this.keyCallbacks.set(keyCode, []);
      }
      this.keyCallbacks.get(keyCode).push(callback);
    }
  
    onMouseEvent(eventType, callback) {
      if (!this.mouseCallbacks.has(eventType)) {
        this.mouseCallbacks.set(eventType, []);
      }
      this.mouseCallbacks.get(eventType).push(callback);
    }
  
    onTouchEvent(eventType, callback) {
      if (!this.touchCallbacks.has(eventType)) {
        this.touchCallbacks.set(eventType, []);
      }
      this.touchCallbacks.get(eventType).push(callback);
    }
  
    onResize(callback) {
      this.resizeCallbacks.add(callback);
    }
  
    triggerKeyCallback(keyCode, eventType) {
      const callbacks = this.keyCallbacks.get(keyCode);
      if (callbacks) {
        callbacks.forEach(callback => {
          try {
            callback(eventType);
          } catch (error) {
            console.error("Error in key callback:", error);
          }
        });
      }
    }
  
    triggerMouseCallback(eventType, data) {
      const callbacks = this.mouseCallbacks.get(eventType);
      if (callbacks) {
        callbacks.forEach(callback => {
          try {
            callback(data);
          } catch (error) {
            console.error("Error in mouse callback:", error);
          }
        });
      }
    }
  
    triggerTouchCallback(eventType, data) {
      const callbacks = this.touchCallbacks.get(eventType);
      if (callbacks) {
        callbacks.forEach(callback => {
          try {
            callback(data);
          } catch (error) {
            console.error("Error in touch callback:", error);
          }
        });
      }
    }
  
    clearCallbacks() {
      this.keyCallbacks.clear();
      this.mouseCallbacks.clear();
      this.touchCallbacks.clear();
      this.resizeCallbacks.clear();
    }
  
    // ============= PUBLIC API =============
  
    update() {
      // Update method called by engine
      // Reset click state will be handled in lateUpdate
    }
  
    lateUpdate() {
      // Reset click state after all scenes have processed
      this.mouse.clicked = false;
    }
  
    isKeyPressed(keyCode) {
      return this.keys[keyCode] || false;
    }
  
    getMousePosition() {
      return { x: this.mouse.x, y: this.mouse.y };
    }
  
    getMouseDelta() {
      return { 
        x: this.mouse.deltaX * this.movementSensitivity.current,
        y: this.mouse.deltaY * this.movementSensitivity.current,
      };
    }
  
    isMouseClicked() {
      return this.mouse.clicked;
    }
  
    isMousePressed() {
      return this.mouse.pressed;
    }
  
    getTouchCount() {
      return this.touches.size;
    }
  
    getTouches() {
      return Array.from(this.touches.values());
    }
  
    getPrimaryTouch() {
      return this.touches.values().next().value || null;
    }
  
    // Movement helper with sensitivity scaling
    getMovementVector() {
      const movement = { x: 0, y: 0 };
      
      if (this.isKeyPressed('KeyW') || this.isKeyPressed('ArrowUp')) {
        movement.y -= 1;
      }
      if (this.isKeyPressed('KeyS') || this.isKeyPressed('ArrowDown')) {
        movement.y += 1;
      }
      if (this.isKeyPressed('KeyA') || this.isKeyPressed('ArrowLeft')) {
        movement.x -= 1;
      }
      if (this.isKeyPressed('KeyD') || this.isKeyPressed('ArrowRight')) {
        movement.x += 1;
      }
      
      // Normalize diagonal movement
      if (movement.x !== 0 && movement.y !== 0) {
        const length = Math.sqrt(movement.x * movement.x + movement.y * movement.y);
        movement.x /= length;
        movement.y /= length;
      }
  
      // Apply sensitivity scaling
      movement.x *= this.movementSensitivity.current;
      movement.y *= this.movementSensitivity.current;
      
      return movement;
    }
  
    // Device info getters
    isMobile() {
      return this.screen.isMobile;
    }
  
    isTablet() {
      return this.screen.isTablet;
    }
  
    isDesktop() {
      return !this.screen.isMobile && !this.screen.isTablet;
    }
  
    isPortrait() {
      return this.screen.isPortrait;
    }
  
    isLandscape() {
      return !this.screen.isPortrait;
    }
  
    isTouchDevice() {
      return 'ontouchstart' in window;
    }
  
    getScreenInfo() {
      return { ...this.screen };
    }
  
    getDevicePixelRatio() {
      return this.screen.devicePixelRatio;
    }
  
    // ============= CLEANUP =============
  
    destroy() {
      console.log("🧹 Destroying input manager");
  
      // Remove all event listeners
      document.removeEventListener('keydown', this.boundHandlers.keydown);
      document.removeEventListener('keyup', this.boundHandlers.keyup);
      document.removeEventListener('mousedown', this.boundHandlers.mousedown);
      document.removeEventListener('mouseup', this.boundHandlers.mouseup);
      document.removeEventListener('mousemove', this.boundHandlers.mousemove);
      document.removeEventListener('touchstart', this.boundHandlers.touchstart);
      document.removeEventListener('touchend', this.boundHandlers.touchend);
      document.removeEventListener('touchmove', this.boundHandlers.touchmove);
      document.removeEventListener('touchcancel', this.boundHandlers.touchcancel);
      window.removeEventListener('resize', this.boundHandlers.resize);
      document.removeEventListener('fullscreenchange', this.boundHandlers.fullscreenchange);
      document.removeEventListener('webkitfullscreenchange', this.boundHandlers.fullscreenchange);
      document.removeEventListener('mozfullscreenchange', this.boundHandlers.fullscreenchange);
      document.removeEventListener('msfullscreenchange', this.boundHandlers.fullscreenchange);
      document.removeEventListener('contextmenu', this.boundHandlers.contextmenu);
  
      // Clear all callbacks
      this.clearCallbacks();
  
      // Clear touches
      this.touches.clear();
  
      // Reset references
      this.canvas = null;
      this.pixiApp = null;
      this.canvasRect = null;
  
      console.log("✅ Input manager destroyed");
    }
  }