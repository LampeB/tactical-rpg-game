console.log("🧪 Test module loaded successfully");

class TestGame {
    constructor() {
        console.log("🧪 TestGame constructor called");
        this.canvas = document.getElementById('gameCanvas');
        if (this.canvas) {
            console.log("🧪 Canvas found, adding click listener");
            this.canvas.addEventListener('click', (e) => {
                console.log("🧪 Game canvas clicked!", e.clientX, e.clientY);
                alert("Game click detected!");
            });
        }
    }
}

// Initialize immediately
const testGame = new TestGame();
window.testGame = testGame;
console.log("🧪 Test module initialization complete");