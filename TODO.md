# Artegame Tasks

## Backlog

### [5#UIM] Main menu scene (Play, Options, Quit)

  - tags: [ui, menu]
  - priority: medium
  - workload: Normal

### [6#UIM] In-game pause menu (Resume, Restart, Main Menu)

  - tags: [ui, menu]
  - priority: high
  - workload: Normal

### [7#UIS] Defeat and victory screens with run summary

  - tags: [ui, summary]
  - priority: medium
  - workload: Normal

### [8#SYS] Save system and session persistence

  - tags: [system, save]
  - priority: low
  - workload: Hard
  - steps:
      - [ ] Define serialization schema for settings, high scores, and run statistics
      - [ ] Implement file I/O reader and writer with error recovery and default fallbacks
      - [ ] Hook settings persistence (audio volume, controls) into game startup
      - [ ] Add run summary recording to high score / stats history

### [9#INP] Controller aiming polish and configurable stick deadzones

  - tags: [input, controller]
  - priority: medium
  - workload: Easy

### [10#INP] Dynamic button prompt overlays (keyboard vs controller)

  - tags: [input, ui]
  - priority: low
  - workload: Easy

## Work in Progress

## Done

### [3#SPW] Dynamic round spawner with scaling enemy waves

  - tags: [spawner, gameplay]
  - priority: high
  - workload: Hard
  - steps:
      - [x] Design wave budget and enemy cost scaling formula based on round number
      - [x] Implement spawn queue system with randomized spawn positions around arena bounds
      - [x] Connect spawner lifecycle with RoundManager combat and replenish phases
      - [x] Add wave progress tracking to HUD/ObjectiveUI


### [11#FIX] Fix Clay UI element ID exhaustion causing unclickable Boon Menu and frozen UI

  - tags: [ui, bugfix]
  - priority: high
  - workload: Easy
  - steps:
      - [x] Stabilize progress bar element IDs in PlayerStats
      - [x] Implement recyclable enemy UI ID pool in OverheadUI
      - [x] Add keyboard navigation support to BoonMenu


### [2#ENE] Universal enemy system with attack ranges, conditional projectiles, and spells

  - tags: [enemies, combat, ai]
  - priority: high
  - workload: Hard
  - steps:
      - [x] Design universal enemy attack configuration with range thresholds, conditional rules, and fallback attack
      - [x] Implement conditional projectile firing supporting multiple projectile profiles and trigger criteria
      - [x] Implement enemy spell-casting support with conditions (e.g. self-buffs, crowd control)
      - [x] Build variant prefabs (melee, ranged, elite/champion with distinctive tints) using universal system
      - [x] Update Enemy AI pursuit, strafing, and attack execution to evaluate conditional attacks dynamically
      - [x] Implement conditional animations (idle, locomotion, windup, attack, winddown, reaction)


### [4#AUD] Comprehensive audio system (Loom audio backend, dynamic phase BGM, and gameplay SFX)

  - tags: [audio, engine, music, sfx]
  - priority: high
  - workload: Hard
  - steps:
      - [x] Build AudioManager service with volume buses (Master, Music, SFX) and mute state atop Loom's audio backend
      - [x] Implement dynamic BGM manager with track cross-fading and looping between combat (action) and replenish (ambient)
      - [x] Connect phase-based BGM transitions to DemoMap combat start and round clear events
      - [x] Implement spatial audio helper (stereo pan and distance attenuation) wrapping lm.audio.playAdvanced
      - [x] Wire combat SFX: weapon swings, punch/projectile impacts, enemy hurt, and defeat sounds
      - [x] Wire movement & action SFX: dash swoosh, footsteps, and spell cast sounds
      - [x] Wire world & UI SFX: shrine activation, round start gong/horn, and boon selection feedback

### [1#VIS] Status visual effect sprite overlays (sleep, stun, heal particles)

  - tags: [visuals, status]
  - priority: medium
  - workload: Normal
  - steps:
      - [x] Create or configure sprite frames/assets for status effect overlays (sleep Zzz, stun stars, heal sparkles, root vines)
      - [x] Implement animated visual overlay component attached to entity transforms
      - [x] Connect overlay rendering to Stats active effect queries (stun, root, slow, regen)
      - [x] Replace text status labels in enemy OverheadUI with animated icon overlays
      - [x] Test overlay lifecycle and positioning on both Player and Enemy entities

### Effect on_tick callback for periodic spells like regen

  - tags: [effects, spells]

### Timed buff lifecycle in Stats (temporary haste and goliath expiration)

  - tags: [stats, spells]

### Spell mana depletion checks and cooldown indicators on HUD

  - tags: [spells, hud]

### Boon pool filtering and randomizer (draw 3 valid boons)

  - tags: [boons, gameplay]

### Natural boon triggers on round completion or level up

  - tags: [boons, progression]

### World interaction prompts for shrines and activators

  - tags: [world, ui]

### Add categories to tasks in TODO.md using markdown-kanban skill

  - tags: [meta, task-board]

### Physical experience drops / orbs spawned on enemy defeat

  - tags: [xp, gameplay]

### Experience orb pickup magnetism and pickup audio

  - tags: [xp, sfx]

### Engine migration to Zig using Loom framework

  - tags: [engine, zig]

### Multi-scene structure (default and demo_map scenes)

  - tags: [scenes, engine]

### Entity Component System (ECS) architecture

  - tags: [ecs, engine]

### Player prefab with movement controller

  - tags: [player, input]

### Directional walking animation state machine

  - tags: [player, animation]

### Aiming and hand orientation following cursor or gamepad stick

  - tags: [player, input]

### Stamina-based dashing mechanism

  - tags: [player, combat]

### Multi-slot attack controller (light, heavy, dash attacks, weapon switching)

  - tags: [player, combat]

### Dual spell-casting slots on player

  - tags: [player, spells]

### Objective and quest tracking component

  - tags: [quest, engine]

### Unified Stats component (health, mana, stamina, armor, speed, attack speed, crits, CC timers)

  - tags: [stats, engine]

### Extensible weapon system with Fists and Goliath profiles

  - tags: [weapons, combat]

### Keyframe-animated fist combat

  - tags: [weapons, animation]

### Unified projectile entity and movement behavior

  - tags: [projectiles, combat]

### Baseline core spells (Heal, Root, Goliath, Haste)

  - tags: [spells, combat]

### Basic melee enemy prefab

  - tags: [enemies, combat]

### Enemy AI with aggro range, CC awareness, and player pursuit

  - tags: [enemies, ai]

### Enemy melee attack execution with range validation

  - tags: [enemies, combat]

### Enemy death and cleanup awarding player experience

  - tags: [enemies, xp]

### Enemy overhead health bar and floating status UI

  - tags: [enemies, ui]

### Enemy CC enforcement (stun disables movement/attacks, root stops movement, slow scales speed)

  - tags: [enemies, cc]

### Modular HUD component architecture

  - tags: [hud, ui]

### Player stats HUD with health, mana, stamina bars, and equipped spells

  - tags: [hud, ui]

### Live experience counter with per-frame arena allocation

  - tags: [hud, xp]

### Screen objective overlay

  - tags: [hud, ui]

### Responsive Boon selection modal with scaling cards and skip button

  - tags: [boons, ui]

### Mouse and Gamepad 0 navigation for Boon selection

  - tags: [boons, input]

### 50 defined boons across spells, stats, and weapons

  - tags: [boons, content]

### Experience-based boon economy replacing fruit inventory

  - tags: [boons, xp]

### Tiled map background renderer with wall collision bounds

  - tags: [map, visuals]

### Round manager state machine with replenish and combat phases

  - tags: [round, gameplay]

