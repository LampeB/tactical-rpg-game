export class Skill {
    constructor(name, description, damage, cost, type = 'attack') {
        this.name = name;
        this.description = description;
        this.damage = damage;
        this.cost = cost; // MP/AP cost
        this.type = type; // attack, magic, defensive, healing, ranged
        this.sourceItems = []; // Items that contribute to this skill
    }
    
    clone() {
        const cloned = new Skill(this.name, this.description, this.damage, this.cost, this.type);
        cloned.sourceItems = [...this.sourceItems];
        return cloned;
    }
    
    addSourceItem(item) {
        if (!this.sourceItems.includes(item)) {
            this.sourceItems.push(item);
        }
    }
    
    getSourceItemNames() {
        return this.sourceItems.map(item => item.name).join(' + ');
    }
}