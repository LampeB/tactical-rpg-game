export class Character {
  constructor(name, maxHp = 100, maxMp = 50) {
    // Basic properties
    this.name = name;
    this.maxHp = maxHp;
    this.maxMp = maxMp;
    this.hp = maxHp;
    this.mp = maxMp;
    
    // Roster system properties
    this.id = null; // Will be set by CharacterRoster
    this.class = "Adventurer"; // Character class
    this.description = "A brave adventurer"; // Character description
    this.portrait = "👤"; // Character emoji/portrait
    this.primaryColor = 0x3498db; // Character's theme color
    
    // Progression system
    this.level = 1;
    this.experience = 0;
    this.experienceToNext = 100;
    
    // Base stats (before equipment bonuses)
    this.baseAttack = 10;
    this.baseDefense = 5;
    this.baseSpeed = 10;
    
    // Inventory
    this.inventory = null; // Will be set to a Grid instance
    
    // Combat state
    this.isPlayer = false; // Set to true for player characters
    this.isEnemy = false; // Set to true for enemy characters
  }

  getAvailableSkills() {
    return this.inventory ? this.inventory.generateSkills() : [];
  }

  canUseSkill(skill) {
    return this.mp >= skill.cost;
  }

  useSkill(skill, target) {
    if (!this.canUseSkill(skill)) {
      return { 
        success: false, 
        message: `${this.name} doesn't have enough MP for ${skill.name}!` 
      };
    }
  
    // Apply skill cost
    this.mp -= skill.cost;
    this.mp = Math.max(0, this.mp);
  
    // Calculate damage with some variance
    let damage = skill.damage;
    if (damage > 0) {
      // Attack skill - add attack bonus and variance
      damage += Math.floor(this.getAttack() * 0.1); // 10% of attack as bonus
      damage += Math.floor(Math.random() * 6) - 3; // ±3 variance
      damage = Math.max(1, damage); // Minimum 1 damage
      
      // Apply target's defense
      if (target && target.getDefense) {
        damage = Math.max(1, damage - Math.floor(target.getDefense() * 0.5));
      }
    } else {
      // Healing skill - add some healing bonus
      damage = Math.abs(damage);
      damage += Math.floor(this.getAttack() * 0.05); // Small healing bonus
      damage += Math.floor(Math.random() * 4) - 1; // Small variance
    }
  
    let message = "";
    let damageDealt = 0;
  
    if (skill.type === "healing") {
      // Healing skill
      const healAmount = damage;
      const actualHeal = target.heal(healAmount);
      message = `${this.name} uses ${skill.name} on ${target.name} and heals ${actualHeal} HP!`;
      damageDealt = -actualHeal; // Negative for healing
    } else {
      // Attack skill
      if (target && target.takeDamage) {
        const wasDefeated = target.takeDamage(damage);
        message = `${this.name} uses ${skill.name} on ${target.name} for ${damage} damage!`;
        damageDealt = damage;
        
        if (wasDefeated) {
          message += ` ${target.name} is defeated!`;
        }
      } else {
        message = `${this.name} uses ${skill.name}!`;
      }
    }
  
    return {
      success: true,
      message: message,
      damageDealt: damageDealt,
      skillUsed: skill.name
    };
  }

  takeDamage(damage) {
    this.hp = Math.max(0, this.hp - damage);
    return this.hp <= 0; // Return true if defeated
  }

  heal(amount) {
    const oldHp = this.hp;
    this.hp = Math.min(this.maxHp, this.hp + amount);
    const actualHeal = this.hp - oldHp;
    
    if (actualHeal > 0) {
      console.log(`💖 ${this.name} healed ${actualHeal} HP (${this.hp}/${this.maxHp})`);
    }
    
    return actualHeal;
  }

  restoreMp(amount) {
    this.mp = Math.min(this.maxMp, this.mp + amount);
  }
  // Add these methods to the Character class (inside the class, before the closing brace)

  isAlive() {
    return this.hp > 0;
  }

  isDefeated() {
    return this.hp <= 0;
  }

  getHpPercentage() {
    return this.hp / this.maxHp;
  }

  getMpPercentage() {
    return this.mp / this.maxMp;
  }

  // Stats Calculation methods
  getAttack() {
    let totalAttack = this.baseAttack;
    
    // Add equipment bonuses from inventory
    if (this.inventory && this.inventory.items) {
      this.inventory.items.forEach(item => {
        if (item.type === "weapon" && item.isPlaced && item.isPlaced()) {
          // Weapons add to attack
          totalAttack += Math.floor(item.baseSkills?.length * 2) || 5;
        }
      });
    }
    
    return totalAttack;
  }
  
  getDefense() {
    let totalDefense = this.baseDefense;
    
    // Add equipment bonuses from inventory
    if (this.inventory && this.inventory.items) {
      this.inventory.items.forEach(item => {
        if (item.type === "armor" && item.isPlaced && item.isPlaced()) {
          // Armor adds to defense
          totalDefense += Math.floor((item.width * item.height) / 2) || 3;
        }
      });
    }
    
    return totalDefense;
  }
  
  getSpeed() {
    let totalSpeed = this.baseSpeed;
    
    // Add equipment bonuses from inventory
    if (this.inventory && this.inventory.items) {
      this.inventory.items.forEach(item => {
        if (item.type === "accessory" && item.isPlaced && item.isPlaced()) {
          // Accessories can add to speed
          totalSpeed += 2;
        }
      });
    }
    
    return totalSpeed;
  }

  gainExperience(amount) {
    this.experience += amount;
    console.log(`📈 ${this.name} gained ${amount} XP (${this.experience}/${this.experienceToNext})`);
    
    const levelUps = [];
    
    // Check for level up(s)
    while (this.experience >= this.experienceToNext) {
      const levelUpResult = this.levelUp();
      levelUps.push(levelUpResult);
    }
    
    return levelUps.length > 0 ? levelUps : null;
  }
  
  levelUp() {
    this.experience -= this.experienceToNext;
    this.level++;
    
    // Get stat gains based on class
    const statGains = this.getStatGainsForClass();
    
    // Apply stat increases
    this.maxHp += statGains.hp;
    this.maxMp += statGains.mp;
    this.baseAttack += statGains.attack;
    this.baseDefense += statGains.defense;
    this.baseSpeed += statGains.speed;
    
    // Heal to full on level up
    this.hp = this.maxHp;
    this.mp = this.maxMp;
    
    // Calculate next level requirement (exponential growth)
    this.experienceToNext = Math.floor(100 * Math.pow(1.2, this.level - 1));
    
    console.log(`🆙 ${this.name} reached level ${this.level}!`);
    
    return {
      newLevel: this.level,
      statGains: statGains,
      message: `${this.name} reached level ${this.level}!`,
      newStats: {
        hp: this.maxHp,
        mp: this.maxMp,
        attack: this.getAttack(),
        defense: this.getDefense(),
        speed: this.getSpeed()
      }
    };
  }
  
  getStatGainsForClass() {
    const classGains = {
      Warrior: { hp: 8, mp: 2, attack: 3, defense: 2, speed: 1 },
      Mage: { hp: 4, mp: 6, attack: 1, defense: 1, speed: 2 },
      Ranger: { hp: 6, mp: 3, attack: 2, defense: 1, speed: 3 },
      Rogue: { hp: 5, mp: 2, attack: 2, defense: 1, speed: 4 },
      Cleric: { hp: 6, mp: 5, attack: 1, defense: 2, speed: 1 },
      Paladin: { hp: 7, mp: 3, attack: 2, defense: 3, speed: 1 }
    };
    
    return classGains[this.class] || { hp: 5, mp: 3, attack: 2, defense: 1, speed: 2 };
  }

  // Character status methods
  getExpPercentage() {
    return this.experienceToNext > 0 ? this.experience / this.experienceToNext : 1;
  }

  isMaxLevel() {
    return this.level >= 50; // Set max level as desired
  }

  getCharacterSummary() {
    return {
      id: this.id,
      name: this.name,
      class: this.class,
      level: this.level,
      hp: this.hp,
      maxHp: this.maxHp,
      mp: this.mp,
      maxMp: this.maxMp,
      attack: this.getAttack(),
      defense: this.getDefense(),
      speed: this.getSpeed(),
      portrait: this.portrait
    };
  }

  // Equipment methods
  hasWeapon() {
    if (!this.inventory || !this.inventory.items) return false;
    return this.inventory.items.some(item => 
      item.type === "weapon" && item.isPlaced && item.isPlaced()
    );
  }

  hasArmor() {
    if (!this.inventory || !this.inventory.items) return false;
    return this.inventory.items.some(item => 
      item.type === "armor" && item.isPlaced && item.isPlaced()
    );
  }

  getEquippedItems() {
    if (!this.inventory || !this.inventory.items) return [];
    return this.inventory.items.filter(item => item.isPlaced && item.isPlaced());
  }

  // Combat utility methods
  canAct() {
    return this.isAlive() && this.mp > 0;
  }

  getAffordableSkills() {
    const allSkills = this.getAvailableSkills();
    return allSkills.filter(skill => this.canUseSkill(skill));
  }

  // Status effect methods (for future expansion)
  addStatusEffect(effect) {
    if (!this.statusEffects) this.statusEffects = [];
    this.statusEffects.push(effect);
  }

  removeStatusEffect(effectName) {
    if (!this.statusEffects) return;
    this.statusEffects = this.statusEffects.filter(effect => effect.name !== effectName);
  }

  hasStatusEffect(effectName) {
    if (!this.statusEffects) return false;
    return this.statusEffects.some(effect => effect.name === effectName);
  }

  // Full restoration (for rest/level up)
  fullRestore() {
    this.hp = this.maxHp;
    this.mp = this.maxMp;
    if (this.statusEffects) this.statusEffects = [];
    console.log(`✨ ${this.name} fully restored!`);
  }

  debugCharacterState() {
    console.group(`🎭 ${this.name} Debug Info`);
    console.log(`Class: ${this.class} | Level: ${this.level}`);
    console.log(`HP: ${this.hp}/${this.maxHp} | MP: ${this.mp}/${this.maxMp}`);
    console.log(`EXP: ${this.experience}/${this.experienceToNext} (${Math.round(this.getExpPercentage() * 100)}%)`);
    console.log(`Stats - ATK: ${this.getAttack()} | DEF: ${this.getDefense()} | SPD: ${this.getSpeed()}`);
    console.log(`Base Stats - ATK: ${this.baseAttack} | DEF: ${this.baseDefense} | SPD: ${this.baseSpeed}`);
    console.log(`Equipment: ${this.getEquippedItems().length} items equipped`);
    console.log(`Skills: ${this.getAvailableSkills().length} available`);
    if (this.inventory) {
      console.log(`Inventory: ${this.inventory.items.length} total items`);
    }
    console.groupEnd();
  }
}
