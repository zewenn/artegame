# Artegame - Zig Reimagined vs Python Main Feature Parity

This document tracks the progress of porting **Artegame** from the original Python implementation (`main` branch) to the Zig reimplementation (`reimagined` branch using the `loom` engine).

---

## 🎯 Accomplished Goals (`reimagined` branch)

### 🏗️ 1. Core Engine & Architecture
- [x] Engine migration to Zig using the **Loom** framework ([main.zig](file:///C:/Users/yemenn/Projects/artegame/src/main.zig), [setup.zig](file:///C:/Users/yemenn/Projects/artegame/src/global/setup.zig)).
- [x] Multi-scene structure (`default` and `demo_map` scenes).
- [x] Entity Component System (ECS) architecture for players, enemies, projectiles, and UI.

### 🏃 2. Player Systems
- [x] **Player Prefab** ([Player.zig](file:///C:/Users/yemenn/Projects/artegame/src/prefabs/Player.zig)) with movement controller ([Movement.zig](file:///C:/Users/yemenn/Projects/artegame/src/components/player/Movement.zig)).
- [x] **Walk Animations**: Directional walking animation state machine (`player_left_0.png`, `player_right_0.png`).
- [x] **Mouse Aiming**: Smooth hand holder rotation following cursor position (`player_hand_holder`).
- [x] **Dashing Mechanism**: Stamina-based dash controller ([Dashing.zig](file:///C:/Users/yemenn/Projects/artegame/src/components/Dashing.zig)).
- [x] **Attack Controller**: Light, heavy, dash attacks, and spell casting slot management ([Attack.zig](file:///C:/Users/yemenn/Projects/artegame/src/components/player/Attack.zig)).
- [x] **Objectives Tracking**: Flexible quest/objective tracking component ([Objectives.zig](file:///C:/Users/yemenn/Projects/artegame/src/components/player/Objectives.zig)).

### ⚔️ 3. Combat & Weapons
- [x] **Unified Stats Component**: Health, mana, stamina, armour, movement speed, and aggro range with `Stats.init` helper ([Stats.zig](file:///C:/Users/yemenn/Projects/artegame/src/components/Stats.zig)).
- [x] **Weapon System**: Extensible weapon structure supporting custom attack profiles ([Weapon.zig](file:///C:/Users/yemenn/Projects/artegame/src/components/Weapons/Weapon.zig), [weapons.zig](file:///C:/Users/yemenn/Projects/artegame/src/components/Weapons/weapons.zig)).
- [x] **Animated Punching**: Keyframe-animated fist/glove combat ([Hands.zig](file:///C:/Users/yemenn/Projects/artegame/src/components/Weapons/Hands.zig)).
- [x] **Projectile System**: Unified projectile entity ([Projectile.zig](file:///C:/Users/yemenn/Projects/artegame/src/prefabs/Projectile.zig)) and movement behavior ([ProjectileMovement.zig](file:///C:/Users/yemenn/Projects/artegame/src/components/ProjectileMovement.zig)) with lifetime, speed, damage, crits, and team filters.

### 👾 4. Enemy Mechanics
- [x] **Basic Melee Enemy**: Basic enemy prefab ([Basic.zig](file:///C:/Users/yemenn/Projects/artegame/src/prefabs/enemies/Basic.zig)).
- [x] **Enemy AI**: Aggro range checking and movement towards player ([Movement.zig](file:///C:/Users/yemenn/Projects/artegame/src/components/enemy/Movement.zig)).
- [x] **Enemy Attack**: Melee attack execution ([Attack.zig](file:///C:/Users/yemenn/Projects/artegame/src/components/enemy/Attack.zig)).
- [x] **Death & Cleanup**: Entity destruction on 0 HP ([Death.zig](file:///C:/Users/yemenn/Projects/artegame/src/components/enemy/Death.zig)).
- [x] **Overhead Health Bar**: Enemy floating UI component ([OverheadUI.zig](file:///C:/Users/yemenn/Projects/artegame/src/components/enemy/OverheadUI.zig)).

### 🖥️ 5. UI & Environment
- [x] **Responsive HUD**: Floating health, mana, and stamina progress bars ([HUD.zig](file:///C:/Users/yemenn/Projects/artegame/src/global/HUD.zig)).
- [x] **Spell Indicators**: Slot display for equipped left & right spells on HUD.
- [x] **Objective Overlay**: Screen UI rendering active objective name and description.
- [x] **Tiled Map & Bounds**: Background renderer with arena wall collision colliders ([Background.zig](file:///C:/Users/yemenn/Projects/artegame/src/prefabs/Background.zig)).
- [x] **Round Manager**: State machine managing `replenish` and `combat` round transitions ([DemoMap.zig](file:///C:/Users/yemenn/Projects/artegame/src/global/DemoMap.zig)).

---

## 📋 Feature Parity TODO (Original Python `main` Branch)

### 🪄 1. Spells & Abilities
- [ ] **Haste ("Pre workout")**: Temporary movement speed and attack speed boost (`haste_icon.png`).
- [ ] **Goliath ("Kreatin")**: Temporary size increase and max HP multiplier (`goliath_icon.png`).
- [ ] **Ashwaganda / Sleep ("Zzzz")**: AoE spell placing sleep puddles (`sleep_icon.png`, `sleep_puddle_0..2.png`).
- [ ] **Heal ("Vitamin-mix") Expansion**: Over-time health regeneration ticks & level scaling.

### 🌀 2. Crowd Control (CC) & Status Effects
- [ ] **CC State Engine**: Port `crowd_control.py` state management for `sleep`, `stun`, `root`, and `slow`.
- [ ] **Status Visual Effects**: Port visual particle/icon overlays (`sleep_effect.png`, `stun_effect_1..4.png`, `heal_effect_0..1.png`).

### 🍎 3. Boon & Fruit Upgrade System ("Alapanyagok kiválasztása")
- [ ] **Fruit Inventory**: Collectible fruit inventory counters (Banana, Strawberry, Blueberry).
- [ ] **Fruit Drops & Pickups**: Enemy death item drops (`banana.png`, `strawberry.png`, `blueberry.png`) with collision pickup detection.
- [ ] **Boon Ingredient Menu (`BoonMenu`)**: Ingredient slider UI for allocating fruits.
- [ ] **Boon Selection Menu (`BoonSelectionMenu`)**: Card selection UI offering Normal, Rare, and Epic tier upgrades.
- [ ] **Boon Upgrade Logic**: Tiered stat boosts and spell effectiveness modifications.

### 🏹 4. Enemy Variety & Spawning
- [ ] **Ranged Enemy Prefab**: Ranged enemy variant (`enemy_ranged_left.png`, `enemy_ranged_right.png`) with projectile attack patterns.
- [ ] **Dynamic Round Spawner**: Round-scaling enemy spawn formulas balancing melee and ranged unit ratios.

### 🎵 5. Audio & Sound System
- [ ] **Ambient Music**: Background soundtrack with fade-in/fade-out transitions (`audio__ambient.mp3`).
- [ ] **Combat Music Manager**: Round start/end combat music rotation (`audio__fight_0.mp3` .. `audio__fight_3.mp3`).
- [ ] **Sound Effects**: Punch impact (`punch.mp3`), fruit pickup (`pickup.mp3`), and movement footsteps (`walking.mp3`).

### 📑 6. Menus, Game Scenes & State Persistence
- [ ] **Main Menu Scene**: Title screen UI (`DEFAULT` scene: Play, Options, Quit).
- [ ] **Pause Menu (`GameMenu`)**: In-game pause menu overlay (Resume, Reload, Main Menu).
- [ ] **Defeat Screen**: Game over screen (`DEFEAT` scene on player HP <= 0).
- [ ] **Save System**: Round progress and inventory persistence between sessions (`saves.py` equivalent).

### 🎮 7. Input & Interaction Parity
- [ ] **World Interaction Prompt**: Floating `[F]` (Keyboard) / `[B]` (Controller) interaction shower (`InteractionShower`).
- [ ] **Controller Parity**: Full gamepad analog stick aiming & dynamic controller button prompt overlays.
