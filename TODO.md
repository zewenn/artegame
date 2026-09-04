# Artegame Tasks

## Backlog

- [ ] Natural boon triggers on round completion or level up
- [ ] Boon pool filtering and randomizer (draw 3 valid boons)
- [ ] Skip or reroll rewards for boons
- [ ] Spell visuals and particle effects (sleep puddles, goliath scale, haste trail, heal sparkles)
- [ ] Spell mana depletion checks and cooldown indicators on HUD
- [ ] Timed buff lifecycle in Stats (temporary haste and goliath expiration)
- [ ] Status visual effect sprite overlays (sleep, stun, heal particles)
- [ ] Ranged enemy prefab with strafing and projectile attacks
- [ ] Dynamic round spawner with scaling enemy waves
- [ ] Elite and champion enemy variants with distinctive tints
- [ ] Audio engine integration with Loom audio backend
- [ ] Dynamic background music for combat and replenish phases
- [ ] Sound effects for combat, movement, and pickups
- [ ] Main menu scene (Play, Options, Quit)
- [ ] In-game pause menu (Resume, Restart, Main Menu)
- [ ] Defeat and victory screens with run summary
- [ ] Save system and session persistence
- [ ] World interaction prompts for shrines and activators
- [ ] Controller aiming polish and configurable stick deadzones
- [ ] Dynamic button prompt overlays (keyboard vs controller)

## Work in Progress

## Done

- [x] Physical experience drops / orbs spawned on enemy defeat
- [x] Experience orb pickup magnetism and pickup audio
- [x] Engine migration to Zig using Loom framework
- [x] Multi-scene structure (default and demo_map scenes)
- [x] Entity Component System (ECS) architecture
- [x] Player prefab with movement controller
- [x] Directional walking animation state machine
- [x] Aiming and hand orientation following cursor or gamepad stick
- [x] Stamina-based dashing mechanism
- [x] Multi-slot attack controller (light, heavy, dash attacks, weapon switching)
- [x] Dual spell-casting slots on player
- [x] Objective and quest tracking component
- [x] Unified Stats component (health, mana, stamina, armor, speed, attack speed, crits, CC timers)
- [x] Extensible weapon system with Fists and Goliath profiles
- [x] Keyframe-animated fist combat
- [x] Unified projectile entity and movement behavior
- [x] Baseline core spells (Heal, Root, Goliath, Haste)
- [x] Basic melee enemy prefab
- [x] Enemy AI with aggro range, CC awareness, and player pursuit
- [x] Enemy melee attack execution with range validation
- [x] Enemy death and cleanup awarding player experience
- [x] Enemy overhead health bar and floating status UI
- [x] Enemy CC enforcement (stun disables movement/attacks, root stops movement, slow scales speed)
- [x] Modular HUD component architecture
- [x] Player stats HUD with health, mana, stamina bars, and equipped spells
- [x] Live experience counter with per-frame arena allocation
- [x] Screen objective overlay
- [x] Responsive Boon selection modal with scaling cards and skip button
- [x] Mouse and Gamepad 0 navigation for Boon selection
- [x] 50 defined boons across spells, stats, and weapons
- [x] Experience-based boon economy replacing fruit inventory
- [x] Tiled map background renderer with wall collision bounds
- [x] Round manager state machine with replenish and combat phases
