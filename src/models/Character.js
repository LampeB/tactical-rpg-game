class Character {
    constructor(name, maxHp = 100, maxMp = 50) {
        this.name = name;
        this.maxHp = maxHp;
        this.maxMp = maxMp;
        this.hp = maxHp;
        this.mp = maxMp;
        this.inventory = null; // Will be set to a Grid instance
    }
    
    getAvailableSkills() {
        return this.inventory ? this.inventory.generateSkills() : [];
    }
    
    canUseSkill(skill) {
        return this.mp >= skill.cost;
    }
    
    useSkill(skill, target) {
        if (!this.canUseSkill(skill)) return false;
        
        this.mp -= skill.cost;
        
        if (skill.type === 'healing') {
            this.heal(-skill.damage);
        } else {
            // Apply damage to target
            if (target && target.takeDamage) {
                target.takeDamage(skill.damage);
            }
        }
        
        return true;
    }
    
    takeDamage(damage) {
        this.hp = Math.max(0, this.hp - damage);
        return this.hp <= 0; // Return true if defeated
    }
    
    heal(amount) {
        this.hp = Math.min(this.maxHp, this.hp + amount);
    }
    
    restoreMp(amount) {
        this.mp = Math.min(this.maxMp, this.mp + amount);
    }
}