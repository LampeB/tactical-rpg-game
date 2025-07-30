# JRPG Game Design Document & Technical Architecture

## Table of Contents
1. [Game Overview](#game-overview)
2. [Core Systems Overview](#core-systems-overview)
3. [Technical Architecture](#technical-architecture)
4. [Data Structures](#data-structures)
5. [System Implementation Details](#system-implementation-details)
6. [Content Creation Workflows](#content-creation-workflows)
7. [User Interface & Accessibility](#user-interface--accessibility)
8. [Audio & Visual Systems](#audio--visual-systems)
9. [Balance & Testing Framework](#balance--testing-framework)
10. [Quality of Life Features](#quality-of-life-features)
11. [Error Handling & Edge Cases](#error-handling--edge-cases)
12. [Development Phases](#development-phases)
13. [Performance Considerations](#performance-considerations)

---

## Game Overview

### Core Concept
A traditional JRPG inspired by Final Fantasy VI and Dragon Quest, featuring:
- **Exploration:** Overworld map with explorable locations and progressive transportation unlocks
- **Combat:** Turn-based battles with speed-based turn order and dynamic camera
- **Character Building:** Grid-based inventory system with item combinations and passive skill trees
- **Story:** Linear narrative with side quests, no player choice branching

### Target Platform
- Single-player, offline experience
- Initially developed for PC (expandable to other platforms)
- Voxel aesthetic (starting with simple shapes)

### Technical Scope
- Unity 3D engine
- C# scripting
- Modular, data-driven architecture
- Multiple save system
- Video playback integration
- Dynamic music system

---

## Core Systems Overview

### 1. World Navigation System
- **Overworld Map:** Top-down view showing entire world with visible but inaccessible areas
- **Transportation:** Progressive unlocks (walking → boat → airship, etc.)
- **Locations:** Fixed explorable areas accessible from overworld
- **Multiple Worlds:** Support for 2-3 different overworld maps (dimensions)

### 2. Combat System
- **Turn Order:** Speed-based initiative with dynamic recalculation when speed changes
- **Actions:** Attack, Magic (MP cost), Items, Defend, Flee
- **Encounters:** Visible enemies on overworld, fixed compositions
- **Camera:** Dynamic movement during turns and attacks
- **Status Integration:** Status effects can modify turn order mid-combat

### 3. Inventory & Equipment System
- **Character Grids:** Unique shaped inventories per character (upgradeable)
- **Item Shapes:** Tetris-like pieces with rotation support
- **Modifiers:** Gems and enhancers that affect adjacent items
- **Party Storage:** Infinite list-based storage accessible at specific locations
- **Item Tiers:** 6-tier rarity system with color coding and stat scaling
- **Upgrade System:** Combine identical items to create higher tier versions
- **Crafting System:** Blueprint-based creation of unique items and combinations
- **Preview System:** Live stat calculations, modifier highlighting, tabbed information display
- **Environmental Usage:** Items enable exploration mechanics (keys, torches, ice creation)

### 4. Character Progression System
- **Stats:** HP, MP, Speed, Luck, Physical/Special Attack/Defense
- **Resistances:** Type-based damage reduction (Fire, Ice, Thunder, etc.)
- **Equipment Progression:** All character development through inventory items
- **Passive Equipment:** Unmodifiable items providing permanent effects (armor, accessories)
- **Active Equipment:** Modifiable weapons and tools affected by gems and enhancers

### 5. Loot & Economy System
- **Sources:** NPCs, Chests, Combat rewards, Shops
- **Combat Loot:** Choose up to 2 from 0-5 items with flexible selection until confirmation
- **Shop System:** Purchase consumables, basic equipment, and common-rare blueprints
- **Reorganization:** Full inventory management during loot phases
- **Economy:** Gold-based progression for grid upgrades, shop purchases, and blueprint acquisition

---

## Technical Architecture

### Core Managers (Singleton Pattern)
```
GameManager
├── SaveSystem
├── SceneManager
├── AudioManager
├── UIManager
└── InputManager
```

### World Systems
```
OverworldManager
├── Multiple world map support
├── Transportation state tracking
├── Location accessibility logic
└── Player position persistence

LocationManager
├── Scene loading for explorable areas
├── Encounter spawn management
├── NPC and chest placement
└── Exit/entrance connections

TransportationSystem
├── Available transport methods
├── Path accessibility calculation
├── Movement mode switching
└── Story flag integration
```

### Character & Combat Systems
```
PartyManager
├── Active party composition
├── Character availability tracking
├── Party-wide state management
└── Inn/composition change handling

CharacterSystem
├── Base stats and calculations
├── Equipment stat modifications
├── Passive equipment effect application
├── Resistance calculations
└── Character-item compatibility checks

CombatManager
├── Turn order calculation
├── Action resolution
├── Damage calculations
├── Item skill execution
└── Victory/defeat handling

InventorySystem
├── Grid-based placement logic
├── Item rotation and validation
├── Modifier effect calculations
├── Drag-and-drop interface
└── Item tier visual management

CraftingSystem
├── Blueprint database management
├── Recipe validation and execution
├── Item upgrade combinations
└── Crafting UI integration

ItemSkillSystem
├── Skill availability calculation
├── Character restriction validation
├── MP cost and effect resolution
└── Combat and menu skill execution
```

### Data Management
```
ItemDatabase
├── All item definitions
├── Shape and modifier data
├── Loot pool configurations
└── Scriptable Object architecture

ShopSystem
├── Shop inventory management
├── Dynamic pricing calculation
├── Blueprint rarity distribution
└── Location-based shop availability

StoryFlagManager
├── Quest completion tracking
├── Area unlock conditions
├── NPC availability states
├── Shop unlock progression
└── Transportation prerequisites

SaveSystem
├── Multiple save slots
├── Automatic save naming
├── Complete game state serialization
├── Shop inventory persistence
└── Save file management
```

---

## Data Structures

### Core Data Classes

#### Character Data
```csharp
[System.Serializable]
public class Character
{
    public string id;
    public string displayName;
    public string characterType; // "Berserker", "Healer", "Mage", etc.
    public BaseStats baseStats;
    public GridInventory inventory;
    public List<StatusEffect> activeEffects;
    public CharacterResistances resistances;
    public List<ItemCategory> allowedItemCategories;
    public List<string> itemSkillRestrictions; // Skills this character can't use
}

[System.Serializable]
public class BaseStats
{
    public int maxHP;
    public int maxMP;
    public int speed;
    public int luck;
    public int physicalAttack;
    public int physicalDefense;
    public int specialAttack;
    public int specialDefense;
}
```

#### Item System
```csharp
public enum ItemTier
{
    Common,    // White
    Uncommon,  // Blue
    Rare,      // Yellow
    Elite,     // Orange
    Legendary, // Red
    Unique     // Gold - Only through specific loot or crafting
}

public enum ItemCategory
{
    // Active Equipment (Modifiable)
    Sword, Mace, Bow, Staff, Dagger, Shield,
    
    // Passive Equipment (Unmodifiable)
    Armor, Helmet, Pants, Shirt, Shoes, 
    Ring, Necklace,
    
    // Consumables and Materials
    Consumable, Gem, Material
}

public enum ItemType
{
    Consumable,     // Single-use items
    ActiveTool,     // Weapons/tools that can be modified
    PassiveGear,    // Equipment that provides passive effects
    Modifier        // Gems and enhancers
}

[CreateAssetMenu(fileName = "New Item", menuName = "Game/Item")]
public class Item : ScriptableObject
{
    public string itemId;
    public string displayName;
    public ItemType type; // Consumable, ActiveTool, PassiveGear, Modifier
    public ItemCategory category;
    public ItemTier tier;
    public ItemShape shape;
    public List<ItemEffect> effects;
    public List<StatModifier> statModifiers;
    public List<PassiveEffect> passiveEffects; // For PassiveGear items
    public List<ItemSkill> itemSkills; // Available from Uncommon+
    public List<string> allowedCharacterTypes; // Restriction system
    public ModifierPattern modifierZones; // For modifier items only
    public bool canBeModified; // False for PassiveGear, True for ActiveTools
    public Color tierColor; // Auto-assigned based on tier
    public Sprite icon;
    public GameObject worldModel;
    public bool canBeUpgraded;
    public Item upgradeResult; // What this becomes when upgraded
}

[System.Serializable]
public class PassiveEffect
{
    public string effectId;
    public string displayName;
    public PassiveEffectType type; // StatBonus, Resistance, SpecialAbility
    public List<StatModifier> statModifiers;
    public List<ResistanceModifier> resistanceModifiers;
    public string description;
}

[System.Serializable]
public class ItemSkill
{
    public string skillId;
    public string displayName;
    public string description;
    public int mpCost;
    public SkillTarget targetType; // Self, Ally, Enemy, All
    public SkillUsageContext usageContext; // Combat, Menu, Both
    public List<string> restrictedToCharacterTypes;
    public List<SkillEffect> effects;
    public bool requiresCombat;
}

[CreateAssetMenu(fileName = "New Blueprint", menuName = "Game/Crafting Blueprint")]
public class CraftingBlueprint : ScriptableObject
{
    public string blueprintId;
    public string displayName;
    public Item resultItem;
    public List<CraftingIngredient> requiredIngredients;
    public bool isUpgradeRecipe; // True for tier upgrades
    public string description;
}

[System.Serializable]
public class CraftingIngredient
{
    public Item requiredItem;
    public ItemTier minimumTier;
    public int quantity;
    public bool exactTierRequired; // For upgrade recipes
}
```

[System.Serializable]
public class ItemShape
{
    public Vector2Int[] occupiedCells;
    public Vector2Int pivotPoint;
    public int rotationStates; // 1, 2, or 4 possible rotations
}
```

#### Interactive Status Effects System
```csharp
public enum StatusEffectType
{
    // Damage Over Time (decreases by 1 each turn)
    Poison, Burn, Bleed,
    
    // Defensive/Offensive States (decreases by 1 each turn)  
    ArmorPoints, Spikes,
    
    // Modified Freeze (decreases by 1 each turn)
    Freeze, // Now reduces speed AND increases damage taken
    
    // Vulnerability States
    Wet, Oiled, Charged, Brittle, Exposed,
    
    // Stat Modifications
    StrengthUp, StrengthDown, SpeedUp, SpeedDown,
    DefenseUp, DefenseDown, MagicUp, MagicDown,
    
    // Action Restrictions
    Sleep, Silence, Charm, Paralysis,
    Stun, // NEW: Forces character to skip next turn
    
    // Special States
    Regeneration, Shield, Invisibility,
    FireImmunity, IceImmunity, PoisonImmunity
}

public enum StatusCategory
{
    DamageOverTime,     // Ongoing damage effects
    Vulnerability,      // Makes target susceptible to certain damage types
    StatModification,   // Changes character stats
    ActionRestriction,  // Limits available actions
    Protection,         // Defensive or beneficial effects
    Immunity           // Prevents certain effects
}

public enum DamageType
{
    Physical, Fire, Ice, Electric, Poison, 
    Spirit, Thunder, Water, Earth, Wind
}

[System.Serializable]
public class StatusEffect
{
    public StatusEffectType type;
    public StatusCategory category;
    public string displayName;
    public string description;
    public Sprite icon;
    public StatusDuration durationType;
    public int remainingTurns;
    public float intensity;
    public bool isBeneficial;
    public List<StatModifier> statModifiers;
    public List<StatusInteraction> interactions; // How this status interacts with others
    public List<DamageVulnerability> vulnerabilities; // Damage type modifications
    public string sourceId;
}

[System.Serializable]
public class StatusInteraction
{
    public StatusEffectType triggerStatus;     // Status that triggers this interaction
    public InteractionType interactionType;   // What happens when they meet
    public StatusEffectType resultStatus;     // Optional: new status to apply
    public float damageMultiplier;            // Damage modification
    public float applicationChance;           // Chance for special effects
    public bool removesTriggerStatus;         // Does interaction consume the trigger?
    public bool removesThisStatus;           // Does interaction consume this status?
}

public enum InteractionType
{
    Cancel,           // One status removes the other (freeze cancels burn)
    Amplify,          // One status makes damage stronger (oil + fire)
    Transform,        // Both statuses become something new
    Trigger,          // One status triggers an immediate effect
    Immunity         // One status prevents the other
}

[System.Serializable]
public class DamageVulnerability
{
    public DamageType damageType;
    public float damageMultiplier;     // 2.0 = double damage
    public StatusEffectType guaranteedEffect; // Effect applied on hit
    public float guaranteedChance;     // Chance for guaranteed effect (usually 1.0)
}

[System.Serializable]
public class StatusEffectApplication
{
    public StatusEffectType effectType;
    public int duration;
    public float intensity;
    public float applicationChance;
    public bool canStack;
    public bool overwritesSameType;
    public DamageType triggerDamageType; // Optional: only applies with certain damage
}
```

#### Environmental Interaction System
```csharp
public enum EnvironmentalTrigger
{
    HasSpecificItem,     // Player has key, torch, etc.
    HasItemCategory,     // Any fire gem, ice gem, etc.
    HasItemWithEffect,   // Any item that provides fire damage
    CharacterStat,       // Character has enough strength, etc.
    StoryFlag           // Story progression requirement
}

[System.Serializable]
public class EnvironmentalInteraction
{
    public string interactionId;
    public string displayPrompt; // "Light torch", "Freeze pond", "Unlock door"
    public EnvironmentalTrigger triggerType;
    public string requiredItemId;
    public ItemCategory requiredCategory;
    public string requiredEffect;
    public int requiredStatValue;
    public string requiredFlag;
    public GameObject resultPrefab; // What changes in the world
    public bool consumesItem; // Does using the key destroy it?
}
```csharp
[System.Serializable]
public class GridInventory
{
    public Vector2Int gridSize;
    public List<Vector2Int> availableCells;
    public List<PlacedItem> placedItems;
    
    public bool CanPlaceItem(Item item, Vector2Int position, int rotation);
    public bool PlaceItem(Item item, Vector2Int position, int rotation);
    public void RemoveItem(PlacedItem item);
    public List<ItemEffect> GetActiveEffects();
    public List<PassiveEffect> GetPassiveEffects(); // From PassiveGear
    public List<StatModifier> GetTotalStatModifiers(); // Combined active + passive
}

[System.Serializable]
public class PlacedItem
{
    public Item item;
    public Vector2Int position;
    public int rotation;
    public List<Vector2Int> occupiedCells;
    public List<ModifierApplication> appliedModifiers; // Only for ActiveTools
}

[System.Serializable]
public class ModifierApplication
{
    public Item modifierItem; // The gem/enhancer providing the effect
    public Vector2Int modifierPosition;
    public List<ItemEffect> appliedEffects;
}
```

### Save Data Structure
```csharp
[System.Serializable]
public class GameSaveData
{
    public string saveName;
    public DateTime saveTime;
    public string currentScene;
    public Vector3 playerPosition;
    public List<Character> partyMembers;
    public List<Character> availableCharacters;
    public Dictionary<string, bool> storyFlags;
    public List<string> unlockedTransportation;
    public PartyStorage partyStorage;
    public Dictionary<string, bool> visitedLocations;
    public Dictionary<string, ShopInventoryState> shopStates;
    public int playerGold;
    public float playtime;
}
```

### Shop System Data
```csharp
public enum ShopType
{
    GeneralGoods,    // Potions, basic consumables
    Equipment,       // Weapons, armor, accessories
    Blueprints,      // Common to Rare crafting recipes
    GridUpgrades,    // Inventory expansion
    Special          // Unique/story-specific shops
}

[CreateAssetMenu(fileName = "New Shop", menuName = "Game/Shop")]
public class Shop : ScriptableObject
{
    public string shopId;
    public string shopName;
    public ShopType shopType;
    public string shopkeeperName;
    public List<ShopItem> inventory;
    public List<string> requiredStoryFlags; // Unlock conditions
    public bool restocksItems;
    public float restockInterval; // In-game days
    public int gridUpgradeBaseCost;
    public float gridUpgradeCostMultiplier;
}

[System.Serializable]
public class ShopItem
{
    public Item item;
    public int basePrice;
    public PricingType pricingType; // Fixed, TierBased, Dynamic
    public int maxStock; // -1 for infinite
    public List<string> requiredFlags; // Item-specific unlock conditions
    public bool restockable;
}

[System.Serializable]
public class ShopInventoryState
{
    public string shopId;
    public Dictionary<string, int> currentStock; // itemId -> quantity
    public DateTime lastRestock;
    public List<string> purchasedBlueprints; // Track one-time purchases
}

public enum PricingType
{
    Fixed,        // Set price never changes
    TierBased,    // Price based on item tier
    Dynamic,      // Price varies based on story progression
    Negotiable    // Future: haggling system
}

public enum BlueprintRarity
{
    Purchasable,  // Common to Rare - available in shops
    Findable,     // Elite+ - found in world/combat/quests only
    Unique        // Story-specific acquisition
}
```

## Equipment-Focused Design Philosophy

### Core Benefits:
- **Unified Progression:** All character development flows through inventory management
- **Meaningful Choices:** Every grid slot matters for both storage and power
- **Clear Distinctions:** ActiveTools can be enhanced, PassiveGear provides reliable effects
- **Strategic Depth:** Grid shapes force players to prioritize what equipment to carry
- **Immediate Feedback:** Equipment changes instantly affect character capabilities

---

## System Implementation Details

### 2. Grid Inventory & Modifier System

#### Key Classes:
- **GridInventoryUI:** Handles drag-and-drop interface
- **InventoryValidator:** Checks placement legality
- **ModifierCalculator:** Applies item combination effects (ActiveTools only)

#### Core Logic:
```csharp
public bool ValidatePlacement(Item item, Vector2Int position, int rotation)
{
    // Get rotated shape
    Vector2Int[] rotatedShape = RotateShape(item.shape.occupiedCells, rotation);
    
    // Check bounds
    foreach (Vector2Int cell in rotatedShape)
    {
        Vector2Int finalPos = position + cell;
        if (!IsValidCell(finalPos)) return false;
        if (IsCellOccupied(finalPos)) return false;
    }
    
    return true;
}

public void CalculateModifierEffects(PlacedItem activeItem)
{
    // Only ActiveTools can be modified
    if (activeItem.item.type != ItemType.ActiveTool) return;
    
    activeItem.appliedModifiers.Clear();
    
    // Find all modifier items affecting this active tool
    foreach (PlacedItem modifier in placedItems)
    {
        if (modifier.item.type == ItemType.Modifier)
        {
            if (ModifierAffectsItem(modifier, activeItem))
            {
                ApplyModifierToItem(modifier, activeItem);
            }
        }
#### Strategic Implications of Dynamic Turn Order:

**Speed Buff Tactics:**
- Apply speed buffs to allies before big attacks to potentially act again sooner
- Very fast characters (2x+ base speed) get multiple actions per round
- Speed buffs can "steal turns" by moving characters ahead in the queue

**Speed Debuff Control:**
- Slow down enemy spellcasters to delay their dangerous abilities
- Speed debuffs can push enemies later in the turn order
- Strategic timing: apply speed debuffs right before enemy turns for maximum delay

**Turn Order Manipulation:**
- Players can see upcoming turn order and plan speed modifications accordingly
- Equipment swaps during combat can affect speed (if allowed by game rules)
- Status effect timing becomes crucial - when to apply buffs/debuffs for optimal positioning

**Example Combat Scenarios:**

**Scenario 1 - Speed Buff Combo:**
1. Turn 1: Support character casts "Haste" on damage dealer (+50 speed)
2. Turn order recalculates: Damage dealer moves from position 4 to position 2
3. Damage dealer gets their turn much sooner than expected
4. Enemy strategy disrupted by unexpected turn order change

**Scenario 2 - Speed Control:**
1. Enemy mage is about to cast powerful spell (next in turn queue)
2. Player casts "Slow" on mage (-30 speed)
3. Turn order recalculates: Mage drops to last position
4. Player team gets multiple actions before mage can complete their spell

**Scenario 3 - Multi-Action Speed Demon:**
1. Character has base speed 120 (above 2x threshold of 100)
2. Gets 2 actions per round automatically
3. Speed buff increases speed to 180
4. Now gets 3 actions per round - massive advantage

#### Visual Feedback Systems:
- **Turn Queue UI:** Shows next 5-6 upcoming turns with character portraits
- **Speed Change Indicators:** Flash/glow effects when turn order changes
- **Recalculation Notification:** Brief message "Turn order updated!" when speed changes
- **Multiple Action Indicators:** Special markers for characters with multiple actions per round
```

#### Implementation:
- **Base Stats:** Defined per character type, never change
- **Equipment Stats:** All stat modifications come from inventory items
- **Active Tools:** Weapons and tools that can be enhanced by modifier items
- **Passive Gear:** Armor and accessories providing effects regardless of grid position

```csharp
public class CharacterStatsCalculator
{
    public CharacterStats CalculateFinalStats(Character character)
    {
        CharacterStats finalStats = character.baseStats.Clone();
        
        // Apply passive gear effects (unmodifiable)
        foreach (PlacedItem item in character.inventory.placedItems)
        {
            if (item.item.type == ItemType.PassiveGear)
            {
                ApplyPassiveEffects(finalStats, item.item.passiveEffects);
            }
            else if (item.item.type == ItemType.ActiveTool)
            {
                // Apply base tool effects + any modifier enhancements
                ApplyActiveToolEffects(finalStats, item);
            }
        }
        
        return finalStats;
    }
    
    private void ApplyPassiveEffects(CharacterStats stats, List<PassiveEffect> effects)
    {
        // PassiveGear effects are always active regardless of grid position
        foreach (PassiveEffect effect in effects)
        {
            stats.ApplyStatModifiers(effect.statModifiers);
            stats.ApplyResistanceModifiers(effect.resistanceModifiers);
#### New Tactical Mechanics Examples:

**Armor Points System:**
- **Shield Usage:** Equipping shield grants 15 armor points that absorb damage until next turn
- **Layered Defense:** Multiple armor sources can stack (shield + armor spell)
- **Smart Timing:** Apply armor right before expected big attacks
- **Turn Management:** Armor refreshes each turn, encouraging active shield usage

**Spikes Reflection:**
- **Defensive Strategy:** Character with 10 spikes reflects 10 damage to each attacker
- **Multi-Hit Punishment:** Each individual attack triggers spikes separately
- **Strategic Positioning:** Place spikes character where enemies will focus fire
- **Decay Balance:** Spikes decrease by 1 each turn, preventing permanent advantage

**Enhanced Freeze Effect:**
- **Speed Reduction:** -20 speed affects turn order positioning
- **Damage Vulnerability:** +50% physical damage taken
- **Turn Decay:** Effect intensity decreases by 1 each turn
- **Strategic Application:** Use freeze to slow down fast enemies and make them more vulnerable

**Stun Mechanics:**
- **Turn Skip:** Stunned characters lose their entire turn
- **One-Turn Duration:** Effect automatically ends after skipping one turn
- **Interrupt Potential:** Apply stun right before enemy's powerful ability
- **No Stacking:** Can't chain-stun the same target continuously

#### Combat Flow with New Mechanics:

**Example Combat Round:**
1. **Turn 1 - Ally Tank:** Uses shield, gains 15 armor points, casts spikes (10 damage reflection)
2. **Turn 2 - Enemy 1:** Attacks tank → hits for 8 damage, absorbed by armor, takes 10 spike reflection damage
3. **Turn 3 - Ally Mage:** Casts freeze on fast enemy → reduces enemy speed by 20, increases damage taken
4. **Turn 4 - Fast Enemy:** Speed reduced, moves later in turn order due to freeze
5. **Turn 5 - Ally DPS:** Attacks frozen enemy → deals +50% damage due to freeze vulnerability
6. **Next Round:** Tank's armor refreshes, all turn-decaying effects decrease by 1

**Strategic Considerations:**
- **Timing Armor:** Shield use right before big enemy attacks for maximum absorption
- **Spikes Placement:** Put spikes on characters who will be focused by multiple enemies
- **Freeze Control:** Use freeze to manipulate turn order and set up vulnerability combos
- **Stun Interrupts:** Save stun effects to interrupt critical enemy abilities
- **Effect Decay Management:** Plan around effects wearing off over time
}

#### Key Classes:
- **GridInventoryUI:** Handles drag-and-drop interface
- **InventoryValidator:** Checks placement legality
- **ModifierCalculator:** Applies item combination effects

#### Core Logic:
```csharp
public bool ValidatePlacement(Item item, Vector2Int position, int rotation)
{
    // Get rotated shape
    Vector2Int[] rotatedShape = RotateShape(item.shape.occupiedCells, rotation);
    
    // Check bounds
    foreach (Vector2Int cell in rotatedShape)
    {
        Vector2Int finalPos = position + cell;
        if (!IsValidCell(finalPos)) return false;
        if (IsCellOccupied(finalPos)) return false;
    }
    
    return true;
}
```

### 3. Dynamic Combat Turn Order System

#### Implementation Approach:
- **Initial Calculation:** Speed-based initiative at combat start
- **Dynamic Recalculation:** Update turn queue when speed stats change
- **Queue Preservation:** Maintain current turn position during recalculation
- **Visual Updates:** Turn queue UI updates immediately when order changes

```csharp
public class DynamicTurnOrderManager
{
    private List<CombatEntity> allCombatants;
    private Queue<CombatEntity> currentTurnQueue;
    private CombatEntity currentActor;
    private int currentRound;
    
    public void InitializeCombat(List<CombatEntity> combatants)
    {
        allCombatants = combatants.ToList();
        currentRound = 1;
        RecalculateTurnOrder();
    }
    
    public void RecalculateTurnOrder()
    {
        // Get all active (non-defeated) combatants
        List<CombatEntity> activeCombatants = allCombatants
            .Where(c => !c.IsDefeated())
            .ToList();
        
        // Sort by current speed (including all modifiers)
        activeCombatants.Sort((a, b) => b.GetCurrentSpeed().CompareTo(a.GetCurrentSpeed()));
        
        // Handle multiple entries for very fast characters
        List<CombatEntity> newQueue = new List<CombatEntity>();
        foreach (CombatEntity combatant in activeCombatants)
        {
            int actions = CalculateActionsPerRound(combatant);
            for (int i = 0; i < actions; i++)
            {
                newQueue.Add(combatant);
            }
        }
        
        // Preserve current actor if mid-turn
        if (currentActor != null && !currentActor.IsDefeated())
        {
            // Current actor keeps their turn, but future turns are recalculated
            List<CombatEntity> futureQueue = newQueue.Where(c => c != currentActor).ToList();
            currentTurnQueue = new Queue<CombatEntity>(futureQueue);
        }
        else
        {
            currentTurnQueue = new Queue<CombatEntity>(newQueue);
        }
        
        UpdateTurnOrderUI();
    }
    
    public void OnSpeedChanged(CombatEntity entity)
    {
        // Speed changed due to status effect, equipment change, etc.
        RecalculateTurnOrder();
        
        // Log for feedback
        Debug.Log($"{entity.name}'s speed changed. Turn order recalculated.");
    }
    
    public CombatEntity GetNextActor()
    {
        if (currentTurnQueue.Count == 0)
        {
            // Round ended, start new round
            currentRound++;
            RecalculateTurnOrder();
        }
        
        if (currentTurnQueue.Count > 0)
        {
            currentActor = currentTurnQueue.Dequeue();
            
            // Skip defeated characters
            while (currentActor.IsDefeated() && currentTurnQueue.Count > 0)
            {
                currentActor = currentTurnQueue.Dequeue();
            }
            
            return currentActor.IsDefeated() ? null : currentActor;
        }
        
        return null;
    }
    
    private int CalculateActionsPerRound(CombatEntity entity)
    {
        int speed = entity.GetCurrentSpeed();
        int baseSpeed = 100; // Average speed reference point
        
        // Very fast characters get multiple actions per round
        if (speed >= baseSpeed * 2) return 2;
        if (speed >= baseSpeed * 3) return 3;
        return 1;
    }
    
    public List<CombatEntity> GetUpcomingTurnOrder(int lookahead = 5)
    {
        // For UI display - show next few actors in queue
        return currentTurnQueue.Take(lookahead).ToList();
    }
}

public class CombatEntity : MonoBehaviour
{
    [SerializeField] private int baseSpeed;
    private List<StatusEffect> activeStatusEffects;
    private List<StatModifier> equipmentModifiers;
    
    public int GetCurrentSpeed()
    {
        int currentSpeed = baseSpeed;
        
        // Apply equipment modifiers
        foreach (StatModifier modifier in equipmentModifiers)
        {
            if (modifier.statType == StatType.Speed)
            {
                currentSpeed += modifier.value;
            }
        }
        
        // Apply status effect modifiers
        foreach (StatusEffect effect in activeStatusEffects)
        {
            foreach (StatModifier modifier in effect.statModifiers)
            {
                if (modifier.statType == StatType.Speed)
                {
                    currentSpeed += modifier.value;
                }
            }
        }
        
        return Math.Max(1, currentSpeed); // Minimum speed of 1
    }
    
    public void OnStatusEffectApplied(StatusEffect effect)
    {
        activeStatusEffects.Add(effect);
        
        // Check if this effect modifies speed
        bool affectsSpeed = effect.statModifiers.Any(m => m.statType == StatType.Speed);
        if (affectsSpeed)
        {
            CombatManager.Instance.turnOrderManager.OnSpeedChanged(this);
        }
    }
    
    public void OnStatusEffectRemoved(StatusEffect effect)
    {
        activeStatusEffects.Remove(effect);
        
        // Check if this effect modified speed
        bool affectedSpeed = effect.statModifiers.Any(m => m.statType == StatType.Speed);
        if (affectedSpeed)
        {
            CombatManager.Instance.turnOrderManager.OnSpeedChanged(this);
        }
    }
    
    public void OnEquipmentChanged()
    {
        // Called when inventory changes affect stats
        RecalculateEquipmentModifiers();
        CombatManager.Instance.turnOrderManager.OnSpeedChanged(this);
    }
}

/// Turn Order UI Management
public class TurnOrderUI : MonoBehaviour
{
    [SerializeField] private Transform turnQueueParent;
    [SerializeField] private GameObject turnIndicatorPrefab;
    
    public void UpdateTurnOrder(List<CombatEntity> upcomingTurns)
    {
        // Clear existing indicators
        foreach (Transform child in turnQueueParent)
        {
            Destroy(child.gameObject);
        }
        
        // Create new indicators
        for (int i = 0; i < upcomingTurns.Count; i++)
        {
            GameObject indicator = Instantiate(turnIndicatorPrefab, turnQueueParent);
            TurnIndicator turnIndicator = indicator.GetComponent<TurnIndicator>();
            turnIndicator.SetCombatant(upcomingTurns[i], i == 0); // Highlight current turn
        }
    }
    
    public void HighlightSpeedChange(CombatEntity entity)
    {
        // Visual feedback when speed changes affect turn order
        // Could be a brief glow, color change, or animation
        StartCoroutine(FlashSpeedChangeIndicator(entity));
    }
}
```

### 3. Story Flag System

#### Implementation:
```csharp
public class StoryFlagManager : MonoBehaviour
{
    private Dictionary<string, bool> flags = new Dictionary<string, bool>();
    
    public void SetFlag(string flagName, bool value)
    {
        flags[flagName] = value;
        OnFlagChanged?.Invoke(flagName, value);
    }
    
    public bool GetFlag(string flagName)
    {
        return flags.ContainsKey(flagName) ? flags[flagName] : false;
    }
    
    // Transportation unlock example
    public bool CanUseBoat() => GetFlag("BOAT_UNLOCKED");
}
```

### 5. Item Upgrade & Crafting System

#### Implementation Approach:
```csharp
public class CraftingManager : MonoBehaviour
{
    private Dictionary<string, CraftingBlueprint> availableBlueprints;
    
    public bool CanUpgradeItem(Item item)
    {
        return item.canBeUpgraded && item.tier < ItemTier.Unique;
    }
    
    public Item UpgradeItem(List<Item> identicalItems)
    {
        // Verify all items are identical and meet requirements
        if (identicalItems.Count >= 2 && AllItemsIdentical(identicalItems))
        {
            return CreateUpgradedItem(identicalItems[0]);
        }
        return null;
    }
    
    public bool CanCraftItem(CraftingBlueprint blueprint, List<Item> availableItems)
    {
        foreach (CraftingIngredient ingredient in blueprint.requiredIngredients)
        {
            if (!HasSufficientIngredients(ingredient, availableItems))
                return false;
        }
        return true;
    }
}
```

### 8. Item Skill System

#### Skill Usage Contexts:
- **Combat Menu:** Skills accessible during battle through Magic menu
- **Character Menu:** Healing/utility skills usable outside combat
- **Automatic:** Passive effects that trigger without player input

#### Character Restrictions:
```csharp
public class ItemSkillValidator
{
    public bool CanCharacterUseSkill(Character character, ItemSkill skill)
    {
        // Check character type restrictions
        if (skill.restrictedToCharacterTypes.Contains(character.characterType))
            return false;
            
        // Check if character has restrictions for this specific skill
        if (character.itemSkillRestrictions.Contains(skill.skillId))
            return false;
            
        return true;
    }
    
    public List<ItemSkill> GetAvailableSkillsForCharacter(Character character)
    {
        List<ItemSkill> availableSkills = new List<ItemSkill>();
        
        // Get all skills from equipped items of Uncommon+ tier
        foreach (PlacedItem placedItem in character.inventory.placedItems)
        {
            if (placedItem.item.tier >= ItemTier.Uncommon)
            {
                foreach (ItemSkill skill in placedItem.item.itemSkills)
                {
                    if (CanCharacterUseSkill(character, skill))
                        availableSkills.Add(skill);
                }
            }
        }
        
        return availableSkills;
    }
}
```

### 9. Dynamic Camera System

#### Combat Camera Implementation:
```csharp
public class CombatCameraController : MonoBehaviour
{
    public void FocusOnCharacter(Character character, CameraFocusType focusType)
    {
        switch (focusType)
        {
            case CameraFocusType.TurnStart:
                // Rotate around character
                StartCoroutine(RotateAroundCharacter(character.transform));
                break;
            case CameraFocusType.MagicMenu:
                // Zoom to face
                StartCoroutine(ZoomToFace(character.transform));
                break;
            case CameraFocusType.AttackMenu:
                // Move behind shoulder
                StartCoroutine(MoveBehindShoulder(character.transform));
                break;
        }
    }
}
```

---

## Content Creation Workflows

### Adding New Items
1. Create Item ScriptableObject
2. Set tier, category, and character restrictions
3. Define shape in ItemShape component
4. Set up stat modifiers and effects
5. Configure item skills (Uncommon+ tier)
6. Create world model and icon with tier-appropriate coloring
7. Add to ItemDatabase
8. Configure loot pools if needed
9. Set up upgrade path if applicable

### Adding New Crafting Recipes
1. Create CraftingBlueprint ScriptableObject
2. Define required ingredients with tier requirements
3. Set result item and description
4. Add to CraftingManager database
5. Create blueprint loot item if needed
6. Test ingredient validation logic

### Adding New Shops
1. Create Shop ScriptableObject
2. Define shop type and inventory items
3. Set pricing strategy for each item type
4. Configure story flag requirements for access
5. Set up restock rules and intervals
6. Design shopkeeper character and dialogue
7. Place shop location in appropriate town/area
8. Test economic balance and progression flow

### Adding New Status Effects
1. Define effect type and category in StatusEffectType enum
2. Create visual icon and description
3. Set duration type and stacking rules
4. **Define vulnerability interactions** - what damage types trigger special effects
5. **Set up cancellation rules** - what status effects neutralize this one
6. **Configure amplification effects** - how this status enhances certain damage
7. Add to items that should apply the effect
8. Test interaction chains and balance
9. Ensure proper visual feedback in UI

### Adding Status Interactions
1. Identify the two status effects that should interact
2. Choose interaction type (Cancel, Amplify, Transform, Trigger)
3. Define damage multipliers and result effects
4. Set consumption rules (which effects are removed)
5. Add interaction rule to StatusEffectDatabase
6. Test interaction in various combat scenarios
7. Balance risk/reward of applying status effects in sequence

#### Example Interaction Chains:
- **Setup → Payoff:** Apply Oiled → Fire attack (double damage + guaranteed burn)
- **Cancellation:** Burning enemy → Ice attack (removes burn, applies freeze)
- **Defensive:** Wet ally → Electric immunity spell (prevents electric vulnerability)
- **Transformation:** Poison + Fire → Toxic Cloud (area effect)

### Adding Environmental Interactions
1. Create EnvironmentalInteraction ScriptableObject
2. Define trigger requirements and consumption rules
3. Create result prefab for world changes
4. Set up interaction prompt UI
5. Place interaction trigger in appropriate locations
6. Test with various item combinations
7. Verify story flag integration

### Adding Tutorial Steps
1. Define new TutorialStep enum value
2. Create progression logic in TutorialManager
3. Design appropriate item rewards for teaching
4. Create UI guidance and highlighting
5. Test tutorial flow and comprehension
6. Ensure tutorial can be skipped for experienced players

### Adding New Characters
1. Create Character ScriptableObject
2. Design unique grid inventory shape
3. Set up base stats and resistances
4. Create passive skill tree structure
5. Design character model and animations
6. Configure recruitment story flags

### Adding New Areas
1. Create Unity scene for exploration
2. Place encounters and NPCs
3. Configure exits to overworld
4. Set up accessibility story flags
5. Add to LocationManager database
6. Create overworld map icon

### Adding New Combat Encounters
1. Define enemy composition
2. Set up loot pools
3. Place encounter trigger on overworld/exploration
4. Configure story flag prerequisites
5. Test combat balance

---

## Development Phases

### Phase 1: Core Systems Foundation
1. **Data Architecture:** Item system with tiers and equipment types, Character system, Save system
2. **Basic UI:** Inventory grid, drag-and-drop, preview system with highlighting
3. **Equipment System:** Passive gear effects, active tool modifiers
4. **Status Effects:** Basic application and processing system
5. **Combat Framework:** Turn-based logic, basic animations
6. **Scene Management:** Overworld and location transitions

### Phase 2: Gameplay Systems
1. **Complete Inventory System:** Modifiers, rotations, storage, tier visualization, live previews
2. **Full Combat System:** All actions, camera movement, item skills, status effects
3. **Shop System:** Purchase interface, inventory management, pricing
4. **Upgrade & Crafting System:** Item combinations, blueprint management
5. **Character Progression:** Equipment-based stat calculation
6. **Environmental Interactions:** Key usage, torch lighting, ice creation
7. **Story Flag System:** Progression tracking
8. **Transportation System:** Progressive unlocks

### Phase 3: Content Integration
1. **Tutorial System:** Progressive learning area with controlled item introduction
2. **Audio System:** Music management, sound effects
3. **Save System:** Multiple saves, naming, persistence, shop states
4. **Character Restriction System:** Item compatibility validation
5. **Status Effect Polish:** Visual feedback, duration tracking, effect stacking
6. **Economy Balancing:** Shop prices, grid upgrade costs, gold distribution
7. **Polish Features:** Cinematics, advanced UI
8. **Content Creation Tools:** Editor utilities for easy addition

### Phase 4: Content & Polish
1. **Game Content:** Story, areas, encounters
2. **Art Integration:** Voxel models, animations
3. **Balancing:** Combat, progression, economy
4. **Bug Fixing & Optimization**

---

## Performance Considerations

### Optimization Strategies
- **Object Pooling:** For combat effects and UI elements
- **Lazy Loading:** Calculate stats only when needed
- **Caching:** Store complex calculations (modifier effects)
- **Scene Management:** Unload unused areas efficiently

### Memory Management
- **Asset Loading:** Load/unload area-specific assets
- **Save Data:** Compress large save files
- **UI Optimization:** Efficient inventory grid rendering

### Scalability Considerations
- **Modular Architecture:** Easy to add new content types
- **Data-Driven Design:** Most content in ScriptableObjects
- **Event System:** Loose coupling between systems
- **Editor Tools:** Streamline content creation workflow

---

## Development Guidelines

### Code Organization
```
Scripts/
├── Core/
│   ├── Managers/
│   ├── Systems/
│   └── Utilities/
├── Character/
├── Combat/
├── Inventory/
├── World/
├── UI/
└── Data/
    ├── ScriptableObjects/
    └── SaveData/
```

### Naming Conventions
- **Classes:** PascalCase (GridInventory)
- **Methods:** PascalCase (PlaceItem)
- **Variables:** camelCase (currentCharacter)
- **Constants:** UPPER_CASE (MAX_GRID_SIZE)
- **ScriptableObjects:** Descriptive names (FireSword_Item)

### Documentation Standards
- XML comments for all public methods
- README files for each major system
- Inline comments for complex algorithms
- Update this document with any architectural changes

---

---

## User Interface & Accessibility

### Input System Design

#### Dual Input Support:
- **Mouse & Keyboard:** Precise drag-and-drop inventory management
- **Controller Support:** Full Steam Deck compatibility with adapted controls
- **Hybrid Mode:** Allow seamless switching between input methods mid-game

#### Controller Adaptations:
```csharp
public class InputManager : MonoBehaviour
{
    public enum InputMode { MouseKeyboard, Controller, Hybrid }
    
    public void HandleInventoryNavigation()
    {
        if (Input.GetJoystickNames().Length > 0)
        {
            // Controller grid navigation
            HandleGridCursor();
            HandleItemSelection();
            HandleRotation(); // Shoulder buttons for rotation
        }
        else
        {
            // Mouse drag-and-drop
            HandleMouseDragDrop();
        }
    }
    
    private void HandleGridCursor()
    {
        // D-pad/left stick moves cursor through grid
        // A/X button picks up/places items
        // Y/Triangle button rotates selected item
        // B/Circle cancels current action
    }
}
```

### Inventory UI System

#### Tabbed Organization:
```csharp
public enum InventoryTab
{
    All,           // Show everything
    Weapons,       // ActiveTools only
    Armor,         // PassiveGear only  
    Consumables,   // Consumable items only
    Materials,     // Crafting materials and gems
    Storage        // Party storage access
}

public class InventoryTabSystem : MonoBehaviour
{
    private Dictionary<InventoryTab, List<ItemCategory>> tabFilters;
    
    private void InitializeTabFilters()
    {
        tabFilters = new Dictionary<InventoryTab, List<ItemCategory>>
        {
            { InventoryTab.Weapons, new List<ItemCategory> 
                { ItemCategory.Sword, ItemCategory.Mace, ItemCategory.Bow, ItemCategory.Staff, ItemCategory.Dagger } },
            { InventoryTab.Armor, new List<ItemCategory> 
                { ItemCategory.Armor, ItemCategory.Helmet, ItemCategory.Pants, ItemCategory.Shirt, ItemCategory.Shoes, 
                  ItemCategory.Ring, ItemCategory.Necklace } },
            // ... additional mappings
        };
    }
}
```

#### Filter System Implementation:
```csharp
public class InventoryFilterSystem : MonoBehaviour
{
    public enum FilterType
    {
        ItemTier,      // T1, T2, T3, T4, T5, T6
        ItemCategory,  // Sword, Armor, etc.
        StatusEffect,  // Items that apply specific effects
        StatModifier,  // Items that boost specific stats
        Usability     // Items current character can use
    }
    
    public List<Item> ApplyFilters(List<Item> items, List<FilterCriteria> filters)
    {
        List<Item> filteredItems = items;
        
        foreach (FilterCriteria filter in filters)
        {
            filteredItems = ApplyFilter(filteredItems, filter);
        }
        
        return filteredItems;
    }
    
    private List<Item> ApplyFilter(List<Item> items, FilterCriteria criteria)
    {
        switch (criteria.filterType)
        {
            case FilterType.ItemTier:
                return items.Where(i => i.tier == criteria.targetTier).ToList();
            case FilterType.ItemCategory:
                return items.Where(i => i.category == criteria.targetCategory).ToList();
            case FilterType.Usability:
                return items.Where(i => CanCurrentCharacterUse(i)).ToList();
            default:
                return items;
        }
    }
}
```

### Item Comparison System

#### Comparison UI:
```csharp
public class ItemComparisonUI : MonoBehaviour
{
    [SerializeField] private GameObject comparisonPanel;
    private Item selectedItem1;
    private Item selectedItem2;
    
    public void ShowComparison(Item item1, Item item2)
    {
        selectedItem1 = item1;
        selectedItem2 = item2;
        
        comparisonPanel.SetActive(true);
        UpdateComparisonDisplay();
    }
    
    private void UpdateComparisonDisplay()
    {
        // Side-by-side stat comparison
        DisplayItemStats(selectedItem1, leftPanel);
        DisplayItemStats(selectedItem2, rightPanel);
        
        // Highlight differences
        HighlightStatDifferences();
        
        // Show tier indicators
        ShowTierComparison();
    }
    
    public void ShowRewardComparison(List<Item> rewardItems)
    {
        // Special comparison mode for combat rewards
        // Click item to select for comparison, click another to compare
        EnableRewardComparisonMode(rewardItems);
    }
}
```

### Undo System

#### Action History:
```csharp
public class UndoSystem : MonoBehaviour
{
    private Stack<IUndoableAction> actionHistory;
    private const int MAX_UNDO_STEPS = 10;
    
    public interface IUndoableAction
    {
        void Execute();
        void Undo();
        string GetDescription();
    }
    
    public class ItemPlacementAction : IUndoableAction
    {
        private Character character;
        private Item item;
        private Vector2Int oldPosition;
        private Vector2Int newPosition;
        private int oldRotation;
        private int newRotation;
        
        public void Execute()
        {
            character.inventory.PlaceItem(item, newPosition, newRotation);
        }
        
        public void Undo()
        {
            character.inventory.RemoveItem(item);
            if (oldPosition != Vector2Int.zero)
            {
                character.inventory.PlaceItem(item, oldPosition, oldRotation);
            }
        }
        
        public string GetDescription()
        {
            return $"Moved {item.displayName}";
        }
    }
    
    public void ExecuteAction(IUndoableAction action)
    {
        action.Execute();
        actionHistory.Push(action);
        
        // Limit undo history
        if (actionHistory.Count > MAX_UNDO_STEPS)
        {
            var actionsToKeep = actionHistory.Take(MAX_UNDO_STEPS).ToList();
            actionHistory.Clear();
            foreach (var a in actionsToKeep.Reverse<IUndoableAction>())
            {
                actionHistory.Push(a);
            }
        }
    }
    
    public bool CanUndo() => actionHistory.Count > 0;
    
    public void UndoLastAction()
    {
        if (CanUndo())
        {
            IUndoableAction lastAction = actionHistory.Pop();
            lastAction.Undo();
            UIManager.ShowUndoFeedback(lastAction.GetDescription());
        }
    }
}
```

### Accessibility Features

#### Colorblind Support:
```csharp
public class AccessibilityManager : MonoBehaviour
{
    public void ApplyTierIndicators(Item item, Text itemText)
    {
        string tierIndicator = GetTierIndicator(item.tier);
        itemText.text = $"{item.displayName} {tierIndicator}";
    }
    
    private string GetTierIndicator(ItemTier tier)
    {
        return tier switch
        {
            ItemTier.Common => "T1",
            ItemTier.Uncommon => "T2", 
            ItemTier.Rare => "T3",
            ItemTier.Elite => "T4",
            ItemTier.Legendary => "T5",
            ItemTier.Unique => "T6",
            _ => ""
        };
    }
}
```

#### Controller UI Navigation:
- **Grid Cursor:** Visual indicator for controller navigation
- **Quick Actions:** Shoulder buttons for common operations (rotate, undo)
- **Context Menus:** Hold button for additional options
- **Audio Cues:** Sound feedback for navigation and actions

---

## Audio & Visual Systems

### Dynamic Music System

#### Music State Management:
```csharp
public class DynamicMusicManager : MonoBehaviour
{
    public enum MusicState
    {
        Exploration,    // Area-specific exploration music
        Combat,         // Battle music with intensity layers
        Victory,        // Post-combat victory stinger
        Shop,           // Town/shop ambient music
        Dramatic,       // Story moments and cinematics
        Silence         // For dramatic pauses
    }
    
    private Dictionary<string, AudioClip> explorationTracks;
    private Dictionary<CombatIntensity, AudioClip> combatLayers;
    
    public void TransitionToState(MusicState newState, string areaId = null)
    {
        switch (newState)
        {
            case MusicState.Exploration:
                PlayExplorationMusic(areaId);
                break;
            case MusicState.Combat:
                TransitionToCombat();
                break;
            case MusicState.Victory:
                PlayVictoryStinger();
                break;
        }
    }
    
    private void TransitionToCombat()
    {
        // Fade out exploration music
        StartCoroutine(FadeOutCurrentTrack(1.0f));
        
        // Start combat music with appropriate intensity
        CombatIntensity intensity = CalculateCombatIntensity();
        PlayCombatMusic(intensity);
    }
    
    public void UpdateCombatIntensity()
    {
        // Adjust music based on combat state
        // More intense as characters get low on HP
        // Dramatic shifts during status effect combinations
        CombatIntensity newIntensity = CalculateCombatIntensity();
        SmoothTransitionToCombatLayer(newIntensity);
    }
}

public enum CombatIntensity
{
    Low,        // Start of combat, everyone healthy
    Medium,     // Some damage taken, status effects active
    High,       // Low HP, dangerous situation
    Critical    // Near death, desperate situation
}
```

#### Area-Specific Audio:
```csharp
[CreateAssetMenu(fileName = "Area Audio Profile", menuName = "Game/Audio Profile")]
public class AreaAudioProfile : ScriptableObject
{
    [Header("Music")]
    public AudioClip explorationMusic;
    public AudioClip ambientLoop;
    public float musicVolume = 0.7f;
    
    [Header("Environmental Audio")]
    public List<AudioClip> ambientSounds; // Wind, water, etc.
    public AudioClip footstepOverride;     // Different surfaces
    public AudioClip environmentalLoop;    // Cave echoes, forest sounds
    
    [Header("Combat Overrides")]
    public AudioClip areaCombatMusic;      // Special combat music for this area
    public bool useGlobalCombat = true;    // Or use global combat music
}
```

### Audio Feedback Systems

#### Status Effect Audio:
```csharp
public class StatusEffectAudioManager : MonoBehaviour
{
    [System.Serializable]
    public class StatusAudioProfile
    {
        public StatusEffectType statusType;
        public AudioClip applicationSound;   // When effect is applied
        public AudioClip processSound;       // Each turn the effect triggers
        public AudioClip removalSound;      // When effect ends
        public bool loopWhileActive;        // For ongoing effects
    }
    
    public List<StatusAudioProfile> statusAudioProfiles;
    
    public void PlayStatusEffectAudio(StatusEffectType type, StatusAudioEvent eventType)
    {
        StatusAudioProfile profile = statusAudioProfiles.Find(p => p.statusType == type);
        if (profile != null)
        {
            AudioClip clipToPlay = eventType switch
            {
                StatusAudioEvent.Applied => profile.applicationSound,
                StatusAudioEvent.Processed => profile.processSound,
                StatusAudioEvent.Removed => profile.removalSound,
                _ => null
            };
            
            if (clipToPlay != null)
            {
                AudioSource.PlayClipAtPoint(clipToPlay, Camera.main.transform.position);
            }
        }
    }
}

public enum StatusAudioEvent { Applied, Processed, Removed }
```

#### Combat Audio Cues:
- **Turn Order Changes:** Distinct sound when speed effects alter turn queue
- **Damage Types:** Different audio for physical, fire, ice, electric damage
- **Armor Absorption:** Satisfying "clank" when armor blocks damage
- **Spikes Reflection:** Sharp "ping" when damage is reflected
- **Critical Hits:** Dramatic impact sound
- **Item Skills:** Unique audio signature for each skill type

### Visual Feedback Guidelines

#### Status Effect Visualization:
```csharp
public class StatusEffectVisualManager : MonoBehaviour
{
    [System.Serializable]
    public class StatusVisualProfile
    {
        public StatusEffectType statusType;
        public GameObject particleEffect;     // Ongoing visual effect
        public Color characterTint;           // Tint character while active
        public AnimationClip statusAnimation; // Character animation override
        public Sprite statusIcon;             // UI icon representation
        public bool pulseIcon;               // Should icon pulse/animate?
    }
    
    public void ApplyStatusVisuals(Character character, StatusEffect effect)
    {
        StatusVisualProfile profile = GetVisualProfile(effect.type);
        
        // Apply particle effect
        if (profile.particleEffect != null)
        {
            GameObject particles = Instantiate(profile.particleEffect, character.transform);
            particles.name = $"{effect.type}_particles";
        }
        
        // Apply character tint
        character.GetComponent<SpriteRenderer>().color = profile.characterTint;
        
        // Update UI icon
        character.statusIconUI.SetIcon(profile.statusIcon, profile.pulseIcon);
    }
}
```

#### Combat Feedback:
- **Damage Numbers:** Color-coded floating text (red physical, blue ice, etc.)
- **Screen Effects:** Subtle screen shake for heavy hits, freeze frame for critical hits
- **Turn Order UI:** Smooth animations when turn queue changes
- **Item Highlighting:** Glow effects for modifier interactions and comparisons
- **Grid Feedback:** Valid/invalid placement indicators, snap-to-grid animations

---

## Balance & Testing Framework

### Power Progression Curves

#### Character Power Growth:
```csharp
public class BalanceCalculator
{
    // Target power progression: exponential growth with plateau periods
    public static float CalculateTargetPower(int characterLevel, int storyProgress)
    {
        float basePower = 100f; // Starting power level
        float levelMultiplier = Mathf.Pow(1.15f, characterLevel); // 15% per "level"
        float storyMultiplier = 1f + (storyProgress * 0.1f); // 10% per major story beat
        
        return basePower * levelMultiplier * storyMultiplier;
    }
    
    // Item tier power scaling
    public static int GetTierStatBonus(ItemTier tier)
    {
        return tier switch
        {
            ItemTier.Common => 5,       // Base power
            ItemTier.Uncommon => 8,     // 60% increase
            ItemTier.Rare => 13,        // 62% increase  
            ItemTier.Elite => 21,       // 62% increase
            ItemTier.Legendary => 35,   // 67% increase
            ItemTier.Unique => 50,      // 43% increase (unique effects matter more)
            _ => 0
        };
    }
}
```

#### Enemy Scaling Guidelines:
- **Early Game (Story 0-25%):** Enemies slightly below player power, focus on teaching mechanics
- **Mid Game (Story 25-75%):** Enemies match player power, require tactical thinking
- **Late Game (Story 75-100%):** Enemies above player power, require optimization

### Economic Balance

#### Pricing Guidelines:
```csharp
public class EconomicBalance
{
    // Grid upgrade cost progression (exponential)
    public static int CalculateGridUpgradeCost(int currentSlots)
    {
        int baseSlots = 20; // Starting inventory size
        int additionalSlots = currentSlots - baseSlots;
        
        if (additionalSlots <= 0) return 0;
        
        int baseCost = 100;
        float multiplier = 1.5f;
        
        return Mathf.RoundToInt(baseCost * Mathf.Pow(multiplier, additionalSlots));
    }
    
    // Item pricing based on tier and type
    public static int CalculateItemPrice(Item item)
    {
        int basePriceByCategory = item.category switch
        {
            ItemCategory.Consumable => 10,
            ItemCategory.Gem => 25,
            ItemCategory.Sword => 50,
            ItemCategory.Armor => 75,
            _ => 30
        };
        
        float tierMultiplier = item.tier switch
        {
            ItemTier.Common => 1.0f,
            ItemTier.Uncommon => 2.5f,
            ItemTier.Rare => 6.0f,
            ItemTier.Elite => 15.0f,
            ItemTier.Legendary => 40.0f,
            ItemTier.Unique => 100.0f, // Rarely sold
            _ => 1.0f
        };
        
        return Mathf.RoundToInt(basePriceByCategory * tierMultiplier);
    }
}
```

#### Gold Income Balance:
- **Combat Rewards:** 10-50 gold per encounter (scaling with enemy difficulty)
- **Side Quest Rewards:** 100-500 gold (meaningful but not game-breaking)
- **Exploration Rewards:** 25-100 gold (treasure chests, hidden areas)
- **Target Economy:** Player should afford 1-2 grid upgrades per major story area

### Testing Framework

#### Automated Balance Testing:
```csharp
public class BalanceTestSuite : MonoBehaviour
{
    [System.Serializable]
    public class BalanceTest
    {
        public string testName;
        public Character testCharacter;
        public Enemy testEnemy;
        public float expectedWinRate; // 0.0 to 1.0
        public int testIterations = 100;
    }
    
    public List<BalanceTest> balanceTests;
    
    public void RunAllBalanceTests()
    {
        foreach (BalanceTest test in balanceTests)
        {
            RunBalanceTest(test);
        }
    }
    
    private void RunBalanceTest(BalanceTest test)
    {
        int wins = 0;
        
        for (int i = 0; i < test.testIterations; i++)
        {
            // Simulate combat
            bool playerWon = SimulateCombat(test.testCharacter, test.testEnemy);
            if (playerWon) wins++;
        }
        
        float actualWinRate = (float)wins / test.testIterations;
        float deviation = Mathf.Abs(actualWinRate - test.expectedWinRate);
        
        if (deviation > 0.1f) // 10% tolerance
        {
            Debug.LogWarning($"Balance Test '{test.testName}' failed: Expected {test.expectedWinRate:P}, Got {actualWinRate:P}");
        }
    }
}
```

#### Playtesting Metrics:
```csharp
public class PlaytestingMetrics : MonoBehaviour
{
    [System.Serializable]
    public class SessionMetrics
    {
        public float sessionDuration;
        public int combatsWon;
        public int combatsLost;
        public int itemsLooted;
        public int gridUpgradesPurchased;
        public int timesUndoUsed;
        public Dictionary<string, int> statusEffectUsage;
        public List<string> playerDeaths; // What killed the player
    }
    
    public void RecordMetric(string metricName, float value)
    {
        // Track player behavior and game balance
        // Export data for analysis
    }
    
    public void AnalyzeSessionData()
    {
        // Identify balance issues:
        // - Too many deaths to specific enemies
        // - Excessive undo usage (UI issues)
        // - Low status effect usage (mechanics not engaging)
        // - Rapid or slow progression (pacing issues)
    }
}
```

### Difficulty Validation

#### Encounter Testing:
- **Solo Testing:** Each encounter should be beatable with "average" gear for that story point
- **Tactical Testing:** Multiple valid strategies should exist for each encounter
- **Edge Case Testing:** Encounters should not become trivial with optimized builds
- **Accessibility Testing:** Encounters should be manageable with different playstyles

#### Item Balance Validation:
- **Power Level Consistency:** Items within same tier should offer roughly equivalent power
- **Meaningful Choices:** No item should be strictly superior to all others in its tier
- **Interaction Testing:** Item combinations should not break encounter balance
- **Economy Testing:** Purchasing power should match intended progression pace

### Smart Inventory Management

#### Auto-Organization Suggestions:
```csharp
public class InventoryOptimizer : MonoBehaviour
{
    public struct OptimizationSuggestion
    {
        public List<ItemPlacement> suggestedPlacements;
        public float efficiencyScore; // 0.0 to 1.0
        public string description;
    }
    
    public OptimizationSuggestion SuggestOptimalLayout(Character character)
    {
        List<Item> allItems = character.inventory.GetAllItems();
        List<ItemPlacement> bestPlacements = new List<ItemPlacement>();
        
        // Priority order: PassiveGear first, then ActiveTools, then Modifiers
        var prioritizedItems = allItems
            .OrderBy(item => GetPlacementPriority(item))
            .ThenByDescending(item => item.tier);
        
        foreach (Item item in prioritizedItems)
        {
            Vector2Int bestPosition = FindOptimalPosition(item, bestPlacements);
            if (bestPosition != Vector2Int.zero)
            {
                bestPlacements.Add(new ItemPlacement(item, bestPosition, 0));
            }
        }
        
        return new OptimizationSuggestion
        {
            suggestedPlacements = bestPlacements,
            efficiencyScore = CalculateEfficiencyScore(bestPlacements),
            description = "Optimized for maximum modifier coverage"
        };
    }
    
    private int GetPlacementPriority(Item item)
    {
        return item.type switch
        {
            ItemType.PassiveGear => 1,    // Highest priority
            ItemType.ActiveTool => 2,     // Second priority
            ItemType.Modifier => 3,       // Place last for optimal coverage
            ItemType.Consumable => 4,     // Lowest priority
            _ => 5
        };
    }
}
```

#### Quick Actions System:
```csharp
public class QuickActionManager : MonoBehaviour
{
    [System.Serializable]
    public class QuickAction
    {
        public KeyCode hotkey;
        public string actionName;
        public System.Action actionCallback;
        public bool requiresSelectedItem;
    }
    
    public List<QuickAction> quickActions = new List<QuickAction>
    {
        new QuickAction { hotkey = KeyCode.R, actionName = "Rotate Item", requiresSelectedItem = true },
        new QuickAction { hotkey = KeyCode.Z, actionName = "Undo", requiresSelectedItem = false },
        new QuickAction { hotkey = KeyCode.F5, actionName = "Quick Save", requiresSelectedItem = false },
        new QuickAction { hotkey = KeyCode.Space, actionName = "Auto-Sort Suggestions", requiresSelectedItem = false },
        new QuickAction { hotkey = KeyCode.C, actionName = "Compare Items", requiresSelectedItem = true }
    };
    
    private void Update()
    {
        foreach (QuickAction action in quickActions)
        {
            if (Input.GetKeyDown(action.hotkey))
            {
                if (!action.requiresSelectedItem || HasSelectedItem())
                {
                    action.actionCallback?.Invoke();
                }
            }
        }
    }
}
```

### Enhanced Tooltips & Information

#### Context-Aware Tooltips:
```csharp
public class AdvancedTooltipSystem : MonoBehaviour
{
    public void ShowItemTooltip(Item item, Vector3 position, TooltipContext context)
    {
        StringBuilder tooltipText = new StringBuilder();
        
        // Basic item info
        tooltipText.AppendLine($"{item.displayName} {GetTierIndicator(item.tier)}");
        tooltipText.AppendLine($"{item.description}");
        tooltipText.AppendLine();
        
        // Context-specific information
        switch (context)
        {
            case TooltipContext.Inventory:
                AddInventorySpecificInfo(tooltipText, item);
                break;
            case TooltipContext.Shop:
                AddShopSpecificInfo(tooltipText, item);
                break;
            case TooltipContext.Reward:
                AddRewardSpecificInfo(tooltipText, item);
                break;
            case TooltipContext.Comparison:
                AddComparisonInfo(tooltipText, item);
                break;
        }
        
        // Show modifier effects if applicable
        if (item.type == ItemType.Modifier)
        {
            AddModifierEffectInfo(tooltipText, item);
        }
        
        // Show compatibility warnings
        if (!CanCurrentCharacterUse(item))
        {
            tooltipText.AppendLine($"<color=red>⚠ {GetCurrentCharacter().characterType} cannot use this item</color>");
        }
        
        DisplayTooltip(tooltipText.ToString(), position);
    }
    
    private void AddInventorySpecificInfo(StringBuilder text, Item item)
    {
        // Show current stat contributions
        text.AppendLine("Current Effects:");
        foreach (StatModifier modifier in item.statModifiers)
        {
            text.AppendLine($"  {modifier.statType}: +{modifier.value}");
        }
        
        // Show active modifiers affecting this item
        List<Item> affectingModifiers = GetModifiersAffecting(item);
        if (affectingModifiers.Count > 0)
        {
            text.AppendLine("Enhanced by:");
            foreach (Item modifier in affectingModifiers)
            {
                text.AppendLine($"  • {modifier.displayName}");
            }
        }
    }
}

public enum TooltipContext
{
    Inventory,    // Hovering in character inventory
    Shop,         // Hovering in shop interface
    Reward,       // Hovering in combat rewards
    Comparison,   // Hovering during comparison mode
    Storage       // Hovering in party storage
}
```

### Progressive Tutorial System

#### Contextual Help:
```csharp
public class ContextualHelpManager : MonoBehaviour
{
    [System.Serializable]
    public class HelpTrigger
    {
        public string triggerName;
        public GameEvent triggerEvent;
        public string helpText;
        public Sprite helpImage;
        public bool showOnce;
        public bool hasBeenShown;
    }
    
    public List<HelpTrigger> helpTriggers;
    
    public void OnGameEvent(GameEvent eventType)
    {
        HelpTrigger trigger = helpTriggers.Find(h => h.triggerEvent == eventType);
        
        if (trigger != null && (!trigger.showOnce || !trigger.hasBeenShown))
        {
            ShowContextualHelp(trigger);
            trigger.hasBeenShown = true;
        }
    }
    
    private void ShowContextualHelp(HelpTrigger trigger)
    {
        // Non-intrusive help popup
        UIManager.ShowHelpPopup(trigger.helpText, trigger.helpImage, 3.0f); // Auto-dismiss after 3 seconds
    }
}

public enum GameEvent
{
    FirstItemPickup,
    FirstModifierPlacement,
    FirstItemRotation,
    FirstCombatReward,
    FirstShopVisit,
    FirstStatusEffect,
    FirstSpeedChange,
    InventoryFull,
    FirstComparison
}
```

### Advanced Shop System

#### Merchant-Specific Drag & Drop:
```csharp
public class MerchantDragDropSystem : MonoBehaviour
{
    private bool isDraggingFromShop = false;
    private Item originalShopItem;
    private int originalShopSlot;
    
    public void OnStartDragFromShop(Item item, int shopSlot)
    {
        isDraggingFromShop = true;
        originalShopItem = item;
        originalShopSlot = shopSlot;
        
        // Create visual copy for dragging
        CreateDragVisual(item);
        
        // Item remains in shop during drag
    }
    
    public void OnDropToInventory(Vector2Int gridPosition)
    {
        if (isDraggingFromShop)
        {
            bool canAfford = PlayerGold >= CalculateItemPrice(originalShopItem);
            bool canPlace = CurrentCharacter.inventory.CanPlaceItem(originalShopItem, gridPosition, 0);
            
            if (canAfford && canPlace)
            {
                // Complete purchase
                PlayerGold -= CalculateItemPrice(originalShopItem);
                CurrentCharacter.inventory.PlaceItem(originalShopItem, gridPosition, 0);
                
                // Update shop stock
                shopInventory.ReduceStock(originalShopSlot, 1);
            }
            else
            {
                // Show error message
                string error = !canAfford ? "Not enough gold!" : "Cannot place item here!";
                UIManager.ShowErrorMessage(error);
            }
            
            CleanupDragOperation();
        }
    }
    
    public void OnDropToStorage()
    {
        if (isDraggingFromShop)
        {
            // Direct purchase to party storage
            bool canAfford = PlayerGold >= CalculateItemPrice(originalShopItem);
            
            if (canAfford)
            {
                PlayerGold -= CalculateItemPrice(originalShopItem);
                PartyStorage.AddItem(originalShopItem);
                shopInventory.ReduceStock(originalShopSlot, 1);
            }
            
            CleanupDragOperation();
        }
    }
}
```

---

## Error Handling & Edge Cases

### Save System Resilience

#### Corrupted Save Recovery:
```csharp
public class RobustSaveSystem : MonoBehaviour
{
    private List<string> saveFilePaths;
    private const string SAVE_DIRECTORY = "Saves";
    private const string BACKUP_SUFFIX = "_backup";
    
    public bool LoadGame(string saveName)
    {
        string primaryPath = GetSavePath(saveName);
        string backupPath = GetSavePath(saveName + BACKUP_SUFFIX);
        
        // Try primary save first
        GameSaveData saveData = TryLoadSaveFile(primaryPath);
        if (saveData != null && ValidateSaveData(saveData))
        {
            ApplySaveData(saveData);
            return true;
        }
        
        // Primary failed, try backup
        Debug.LogWarning($"Primary save '{saveName}' corrupted or invalid. Trying backup...");
        saveData = TryLoadSaveFile(backupPath);
        if (saveData != null && ValidateSaveData(saveData))
        {
            ApplySaveData(saveData);
            UIManager.ShowMessage("Loaded from backup save due to corruption.");
            return true;
        }
        
        // Both failed, try previous save
        return TryLoadPreviousSave(saveName);
    }
    
    private bool TryLoadPreviousSave(string failedSaveName)
    {
        // Get all saves for this profile, sorted by date
        List<string> availableSaves = GetAllSaves()
            .Where(s => s != failedSaveName)
            .OrderByDescending(s => GetSaveTimestamp(s))
            .ToList();
        
        foreach (string saveName in availableSaves)
        {
            GameSaveData saveData = TryLoadSaveFile(GetSavePath(saveName));
            if (saveData != null && ValidateSaveData(saveData))
            {
                ApplySaveData(saveData);
                UIManager.ShowMessage($"Loaded previous save '{saveName}' due to corruption.");
                return true;
            }
        }
        
        // No valid saves found
        UIManager.ShowErrorMessage("No valid save files found. Starting new game.");
        return false;
    }
    
    private bool ValidateSaveData(GameSaveData saveData)
    {
        // Validate critical save data integrity
        if (saveData.partyMembers == null || saveData.partyMembers.Count == 0)
            return false;
        
        if (string.IsNullOrEmpty(saveData.currentScene))
            return false;
        
        if (saveData.playerGold < 0)
            return false;
        
        // Validate character data
        foreach (Character character in saveData.partyMembers)
        {
            if (!ValidateCharacterData(character))
                return false;
        }
        
        return true;
    }
    
    public void SaveGame(string saveName)
    {
        // Create backup of existing save first
        string primaryPath = GetSavePath(saveName);
        string backupPath = GetSavePath(saveName + BACKUP_SUFFIX);
        
        if (File.Exists(primaryPath))
        {
            File.Copy(primaryPath, backupPath, true);
        }
        
        // Save new data
        GameSaveData saveData = GatherSaveData();
        WriteSaveFile(primaryPath, saveData);
    }
}
```

### Inventory Edge Cases

#### Full Inventory Handling:
```csharp
public class InventoryOverflowManager : MonoBehaviour
{
    public void HandleLootWithFullInventory(List<Item> lootItems)
    {
        List<Item> placedItems = new List<Item>();
        List<Item> overflowItems = new List<Item>();
        
        // Try to place items in available inventory slots
        foreach (Item item in lootItems)
        {
            bool placed = false;
            
            // Try each character's inventory
            foreach (Character character in PartyManager.GetActiveParty())
            {
                if (character.inventory.CanPlaceAnywhereWithRotation(item))
                {
                    Vector2Int position = character.inventory.FindBestPosition(item);
                    character.inventory.PlaceItem(item, position, 0);
                    placedItems.Add(item);
                    placed = true;
                    break;
                }
            }
            
            if (!placed)
            {
                overflowItems.Add(item);
            }
        }
        
        // Handle overflow
        if (overflowItems.Count > 0)
        {
            ShowOverflowDialog(placedItems, overflowItems);
        }
        else
        {
            // All items placed successfully
            LootUIManager.ShowLootSummary(placedItems);
        }
    }
    
    private void ShowOverflowDialog(List<Item> placedItems, List<Item> overflowItems)
    {
        OverflowDialog dialog = UIManager.CreateOverflowDialog();
        dialog.SetItems(placedItems, overflowItems);
        
        dialog.OnSendToStorage += () =>
        {
            foreach (Item item in overflowItems)
            {
                PartyStorage.AddItem(item);
            }
            dialog.Close();
        };
        
        dialog.OnReorganize += () =>
        {
            // Open inventory management with overflow items highlighted
            InventoryManager.OpenWithOverflowItems(overflowItems);
            dialog.Close();
        };
        
        dialog.OnDiscard += (List<Item> discardedItems) =>
        {
            // Items are lost forever
            UIManager.ShowMessage($"Discarded {discardedItems.Count} items.");
            dialog.Close();
        };
    }
}
```

#### Combat Reward Edge Cases:
```csharp
public class CombatRewardEdgeCaseHandler : MonoBehaviour
{
    public void HandleFullInventoryRewards(List<Item> selectedRewards)
    {
        List<Item> canPlace = new List<Item>();
        List<Item> mustStore = new List<Item>();
        
        // Categorize selected rewards
        foreach (Item item in selectedRewards)
        {
            if (CanPlaceInAnyInventory(item))
            {
                canPlace.Add(item);
            }
            else
            {
                mustStore.Add(item);
            }
        }
        
        if (mustStore.Count > 0)
        {
            // Show forced storage dialog
            ForceStorageDialog dialog = UIManager.CreateForceStorageDialog();
            dialog.SetMessage($"{mustStore.Count} items will be sent to storage due to full inventories.");
            dialog.SetItems(canPlace, mustStore);
            
            dialog.OnConfirm += () =>
            {
                // Place what we can, store the rest
                foreach (Item item in canPlace)
                {
                    PlaceInBestInventory(item);
                }
                
                foreach (Item item in mustStore)
                {
                    PartyStorage.AddItem(item);
                }
                
                dialog.Close();
                OpenLootReorganization();
            };
        }
        else
        {
            // Normal loot flow
            OpenLootReorganization();
        }
    }
}
```

### Performance Safeguards

#### Inventory Size Limits:
```csharp
public class PerformanceManager : MonoBehaviour
{
    private const int MAX_GRID_DIMENSION = 12;
    private const int MAX_TOTAL_ITEMS_PER_CHARACTER = 50;
    private const int MAX_PARTY_STORAGE_ITEMS = 1000;
    
    public bool ValidateGridExpansion(Character character, Vector2Int newSize)
    {
        if (newSize.x > MAX_GRID_DIMENSION || newSize.y > MAX_GRID_DIMENSION)
        {
            UIManager.ShowErrorMessage($"Grid cannot exceed {MAX_GRID_DIMENSION}x{MAX_GRID_DIMENSION}");
            return false;
        }
        
        int totalSlots = newSize.x * newSize.y;
        if (totalSlots > MAX_GRID_DIMENSION * MAX_GRID_DIMENSION)
        {
            UIManager.ShowErrorMessage("Grid too large for optimal performance");
            return false;
        }
        
        return true;
    }
    
    public void MonitorPerformance()
    {
        // Track performance metrics
        float frameTime = Time.deltaTime;
        int totalItems = GetTotalItemCount();
        
        if (frameTime > 0.033f && totalItems > 200) // 30 FPS threshold
        {
            Debug.LogWarning("Performance degradation detected with high item count");
            SuggestOptimization();
        }
    }
    
    private void SuggestOptimization()
    {
        UIManager.ShowOptimizationSuggestion(
            "Large number of items detected. Consider storing unused items to improve performance."
        );
    }
}
```

### Data Integrity Validation

#### Item Database Validation:
```csharp
public class DataIntegrityValidator : MonoBehaviour
{
    [System.Serializable]
    public class ValidationResult
    {
        public bool isValid;
        public List<string> errors;
        public List<string> warnings;
    }
    
    public ValidationResult ValidateItemDatabase()
    {
        ValidationResult result = new ValidationResult
        {
            errors = new List<string>(),
            warnings = new List<string>()
        };
        
        List<Item> allItems = ItemDatabase.GetAllItems();
        
        foreach (Item item in allItems)
        {
            ValidateItem(item, result);
        }
        
        // Check for duplicate IDs
        var duplicateIds = allItems
            .GroupBy(i => i.itemId)
            .Where(g => g.Count() > 1)
            .Select(g => g.Key);
        
        foreach (string duplicateId in duplicateIds)
        {
            result.errors.Add($"Duplicate item ID found: {duplicateId}");
        }
        
        result.isValid = result.errors.Count == 0;
        return result;
    }
    
    private void ValidateItem(Item item, ValidationResult result)
    {
        // Required fields
        if (string.IsNullOrEmpty(item.itemId))
            result.errors.Add($"Item missing ID: {item.name}");
        
        if (string.IsNullOrEmpty(item.displayName))
            result.errors.Add($"Item missing display name: {item.itemId}");
        
        if (item.icon == null)
            result.warnings.Add($"Item missing icon: {item.itemId}");
        
        // Shape validation
        if (item.shape.occupiedCells == null || item.shape.occupiedCells.Length == 0)
            result.errors.Add($"Item has no shape defined: {item.itemId}");
        
        // Modifier validation
        if (item.type == ItemType.Modifier && item.modifierZones == null)
            result.warnings.Add($"Modifier item has no modifier zones: {item.itemId}");
        
        // Price validation
        int calculatedPrice = EconomicBalance.CalculateItemPrice(item);
        if (calculatedPrice <= 0)
            result.warnings.Add($"Item has invalid calculated price: {item.itemId}");
    }
}
```

---

## Development Phases

### Updated Phase Structure

#### Phase 1: Foundation & Core Systems (Weeks 1-8)
**Week 1-2: Project Setup**
- Unity project initialization with proper folder structure
- Input system setup (mouse/keyboard + controller)
- Basic scene management and transitions
- Core data structures (Item, Character, SaveData)

**Week 3-4: Basic Inventory System**
- Grid-based inventory implementation
- Drag-and-drop mechanics (mouse only initially)
- Item placement validation and rotation
- Basic undo system for item placement

**Week 5-6: Combat Framework**
- Turn-based combat structure
- Dynamic turn order calculation
- Basic status effect system
- Simple combat UI

**Week 7-8: Save System & Data Management**
- Save/load functionality with corruption handling
- Multiple save slots with automatic naming
- Basic item database structure
- Data validation systems

#### Phase 2: Advanced Gameplay Systems (Weeks 9-20)
**Week 9-10: Enhanced Inventory**
- Modifier system with item interactions
- Live stat calculation and preview
- Tab system and basic filtering
- Controller support for inventory navigation

**Week 11-12: Complete Combat System**
- All status effects with interactions
- Armor points and spikes reflection
- Turn-decaying effects
- Combat reward selection system

**Week 13-14: Shop & Economy**
- Basic shop system with pricing
- Grid upgrade purchases
- Economic balance implementation
- Merchant-specific drag-and-drop

**Week 15-16: Crafting & Progression**
- Item upgrade system (combine identical items)
- Blueprint-based crafting
- Item skill system
- Character restriction validation

**Week 17-18: Tutorial & Onboarding**
- Progressive tutorial area design
- Contextual help system
- Guided mechanic introduction
- Tutorial skip options

**Week 19-20: Quality of Life Features**
- Item comparison system
- Filter improvements and search alternatives
- Auto-organization suggestions
- Hotkey system and quick actions

#### Phase 3: Polish & Content Integration (Weeks 21-32)
**Week 21-22: Audio System**
- Dynamic music system with area transitions
- Status effect audio cues
- Combat feedback sounds
- Environmental audio profiles

**Week 23-24: Visual Polish**
- Status effect visual feedback
- UI animations and transitions
- Particle effects for combat
- Screen effects and camera shake

**Week 25-26: Balance Framework Implementation**
- Automated balance testing suite
- Economic balance validation
- Power progression curve implementation
- Playtesting metrics collection

**Week 27-28: Accessibility & Control Polish**
- Controller optimization for all systems
- Colorblind accessibility features
- Performance optimization
- Error handling robustness

**Week 29-30: Content Creation Tools**
- Editor utilities for easy item creation
- Template systems for rapid content development
- Batch creation tools
- Data integrity validation tools

**Week 31-32: Final Polish & Testing**
- Comprehensive playtesting
- Bug fixing and edge case handling
- Performance optimization
- Steam Deck compatibility validation

#### Phase 4: Content Creation & Launch Preparation (Weeks 33-40)
**Week 33-34: Core Game Content**
- Main story areas and encounters
- Character roster implementation
- Essential item database population
- Side quest design and implementation

**Week 35-36: Content Balance & Iteration**
- Encounter difficulty tuning
- Economic balance validation
- Progression pacing adjustments
- Content accessibility testing

**Week 37-38: Localization & Platform Preparation**
- Text localization framework
- Steam Deck optimization
- Platform-specific testing
- Achievement/progression system

**Week 39-40: Launch Preparation**
- Final bug fixes
- Performance optimization
- Marketing asset creation
- Steam store page preparation

### Milestone Deliverables

#### Phase 1 Milestones:
- **M1.1:** Basic inventory with drag-and-drop working
- **M1.2:** Simple combat with turn order
- **M1.3:** Save/load system functional
- **M1.4:** Core data structures complete

#### Phase 2 Milestones:
- **M2.1:** Complete inventory system with modifiers
- **M2.2:** Full combat with all status effects
- **M2.3:** Shop system operational
- **M2.4:** Tutorial system implemented

#### Phase 3 Milestones:
- **M3.1:** Audio system complete
- **M3.2:** Balance framework operational
- **M3.3:** All quality of life features implemented
- **M3.4:** Accessibility compliance achieved

#### Phase 4 Milestones:
- **M4.1:** Core content complete
- **M4.2:** Balance validated through testing
- **M4.3:** Platform compatibility confirmed
- **M4.4:** Launch-ready build achieved

---

## Performance Considerations

### Updated Performance Framework

#### Memory Management Strategy:
```csharp
public class MemoryManager : MonoBehaviour
{
    private const int MAX_INVENTORY_ITEMS = 144; // 12x12 grid maximum
    private const int MAX_PARTY_STORAGE = 1000;
    private const int MAX_CONCURRENT_PARTICLES = 50;
    
    private ObjectPool<GameObject> particlePool;
    private ObjectPool<UIElement> uiElementPool;
    
    public void ValidateMemoryUsage()
    {
        int totalItems = GetTotalItemCount();
        if (totalItems > MAX_INVENTORY_ITEMS * 4) // 4 party members max
        {
            Debug.LogWarning("High item count detected, performance may degrade");
            SuggestInventoryCleanup();
        }
        
        int particleCount = GetActiveParticleCount();
        if (particleCount > MAX_CONCURRENT_PARTICLES)
        {
            LimitParticleEffects();
        }
    }
    
    private void SuggestInventoryCleanup()
    {
        UIManager.ShowOptimizationTip(
            "Consider storing unused items to improve performance. " +
            "Large inventories may cause frame rate drops."
        );
    }
}
```

#### Scalability Considerations:
- **Grid Size Limits:** Maximum 12x12 per character for optimal performance
- **Item Database:** Lazy loading for large item databases
- **Save File Size:** Compression for saves with many items
- **UI Rendering:** Efficient inventory grid rendering with culling
- **Status Effect Processing:** Optimized calculation loops

#### Platform-Specific Optimizations:
- **Steam Deck:** Optimized for 800p resolution and battery life
- **Desktop:** Higher resolution support with optional visual enhancements
- **Controller Input:** Minimal input lag for inventory navigation
- **Memory Usage:** Conservative memory allocation for handheld devices

---

This document serves as the complete reference for the JRPG project architecture and should be updated as the project evolves. All systems are designed to work together cohesively while maintaining modularity for easy content creation and future enhancements.