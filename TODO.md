# Artegame Tasks

## Backlog

## Work in Progress


## Done

### [17#UIB] Standardize UI button ratios and integer scaling for pixel-art sprites

  - tags: [ui, scaling, buttons]
  - priority: medium
  - workload: Normal
  - steps:
      - [x] Add calculateUiScale in HUD.zig with integer floor scaling and unit tests
      - [x] Standardize menu item buttons to 6:1 ratio with 48px base height (288x48) in MainMenu, PauseMenu, and GameOverMenu
      - [x] Standardize compact/utility buttons to 4:1 ratio with dynamic base height in OptionsMenu and BoonMenu
      - [x] Remove borders and corner radiuses from buttons and apply sprites from src/assets/ui/HUD/buttons
      - [x] Support normal and hovered sprite variants (large_button1/2, small_button1/2)
      - [x] Verify test suite and build verification



### [16#OPS] Multi-platform release GitHub Actions workflow

  - tags: [ci, github-actions, release]
  - priority: medium
  - workload: Normal
  - steps:
      - [x] Add GitHub Actions workflow triggered on push to release branch
      - [x] Extract version tag from build.zig.zon
      - [x] Cross-compile / matrix build for Windows, macOS (ARM64 & x86_64), and Linux
      - [x] Package release archives with binary and assets
      - [x] Configure application icon for macOS bundle (.icns) and Windows executable (.ico/.rc)
      - [x] Create GitHub release and upload release assets

### [15#DOC] Complete project README documentation

  - tags: [docs, readme]
  - priority: low
  - workload: Easy
  - steps:
      - [x] Fill in About the game, Download, and Build from source sections in README.md


### [14#AST] Remove unused assets from assets directory

  - tags: [assets, cleanup]
  - priority: low
  - workload: Easy
  - steps:
      - [x] Remove obsolete background, font, character, card, HUD, and effect files (28 files)
      - [x] Verify build and tests pass with zero missing asset errors



### [10#INP] Dynamic button prompt overlays (keyboard vs controller)

  - tags: [input, ui]
  - priority: low
  - workload: Easy
  - steps:
      - [x] Implement InputHelper state machine detecting active input device (KBM vs Gamepad)
      - [x] Create PromptBadge component for styled keycaps and Xbox-colored controller pills
      - [x] Update InteractionPrompt and PlayerStats HUD to dynamically render active device prompts
      - [x] Update MainMenu, PauseMenu, GameOverMenu, BoonMenu, and OptionsMenu with dynamic footers and button prompts
      - [x] Add unit tests for InputHelper device switching, prompt resolution, and run build verification

### [13#AST] Rename/re-categorise assets into subdirectory trees.

  - tags: [Assets, Categorisation]
  - priority: medium
  - workload: Normal
  - defaultExpanded: false
  - steps:
      - [x] Create subdir-tree for assets/audio and re-categorise
      - [x] Create subdir-tree for assets/characters and re-categorise
      - [x] Create subdir-tree for assets/projectiles and re-categorise
      - [x] Create subdir-tree for assets/ui and re-categorise
      - [x] Create subdir-tree for assets/weapons and re-categorise
    ```md
    Currently assets like [audio__ambient.mp3](./src/assets/audio/audio__ambient.mp3) are clutterring up the workspace, and would be better named/placed like: "src/assets/audio/music/ambient.mp3".
    ```

### [8#SYS] Save system and session persistence

  - tags: [system, save]
  - priority: low
  - workload: Hard
  - steps:
      - [x] Define serialization schema for settings, all-time scores, and current run data (full Weapon structs, spells, stats, round state)
      - [x] Implement file I/O reader and writer with error recovery and default fallbacks at exe-relative path (./save.json)
      - [x] Hook settings persistence (audio volume) into game startup and options menu
      - [x] Implement run auto-saving on round start, boon purchase, quit to main menu, and player death
      - [x] Support run resumption from Main Menu (Continue / New Run) and record lifetime statistics
      - [x] Add unit tests for schema serialization, Weapon roundtrip, and save/load lifecycle

### [7#UIS] Game Over screen with run statistics, restart, and main menu

  - tags: [ui, game-over, summary]
  - priority: medium
  - workload: Normal
  - steps:
      - [x] Detect player defeat when player's health <= 0 and trigger game over modal sequence
      - [x] Freeze gameplay world updates (lm.time.pause()) while keeping UI modal rendering active
      - [x] Build GameOver UI component rendered on top of the game with dimmed backdrop overlay and suppress in-game HUD
      - [x] Display run statistics summary (rounds survived, enemies defeated, and experience collected)
      - [x] Implement "Restart" action (reloads demo_map scene) and "Main Menu" action (returns to main_menu scene)
      - [x] Support Mouse, Keyboard, and Gamepad navigation with audio feedback
      - [x] Add unit tests for defeat trigger condition, state machine, and action handlers

### [13#UIB] Replace purchased boon cards with non-clickable dummy cards

  - tags: [ui, boons]
  - priority: medium
  - workload: Normal
  - steps:
      - [x] Retain purchased card slots in BoonMenu using dummy placeholders
      - [x] Render visually distinct disabled/purchased styling for dummy cards
      - [x] Adjust keyboard and gamepad navigation to skip dummy cards
      - [x] Replace SKIP button with CLOSE by default and remove empty all-claimed screen
      - [x] Add unit tests for dummy card state, navigation skipping, and purchase lifecycle

### [6#UIM] In-game pause menu (Resume, Restart, Main Menu)

  - tags: [ui, menu]
  - priority: high
  - workload: Normal
  - steps:
      - [x] Create PauseMenu component with modal overlay, responsive scaling, and state machine (root vs options sub-view)
      - [x] Implement Resume, Restart, Options, and Main Menu action handlers
      - [x] Integrate pause trigger (Escape key / Gamepad Start) in HUD.Update with BoonMenu exclusivity
      - [x] Add if (lm.time.paused()) return; guard to DemoMap.Update to halt spawner and wave logic during pause
      - [x] Connect multi-modal navigation (Mouse, Keyboard, Gamepad) and audio feedback for pause actions
      - [x] Add unit tests for PauseMenu state transitions, action triggers, and visibility lifecycle

### [5#UIM] Main menu scene (Play, Options, Quit)

  - tags: [ui, menu]
  - priority: medium
  - workload: Normal
  - steps:
      - [x] Create MainMenu behaviour struct conforming to Loom behaviour conventions with responsive layout and state machine
      - [x] Build Main Menu screen with game logo, Play, Options, and Quit buttons
      - [x] Build Options screen with Master/Music/SFX volume sliders, Mute toggle, Fullscreen toggle, and Controls reference guide
      - [x] Support Mouse, Keyboard (WASD/Arrows/Enter/Esc), and Gamepad (D-pad/stick/A/B) navigation
      - [x] Connect hover/click SFX and background music streaming to AudioManager & MusicManager
      - [x] Wire main_menu scene into main.zig and update startup routing in Setup.zig
      - [x] Add unit tests for menu state transitions, volume controls, and navigation logic

### [12#ARC] Codebase architectural overhaul and critical bug remediation

  - tags: [architecture, bugfix, performance, refactor]
  - priority: high
  - workload: Hard
  - steps:
      - [x] Convert enemy ability arrays in Melee, Ranged, and Elite prefabs to immutable templates and store runtime cooldown state per-instance in Enemy.Attack
      - [x] Fix off-by-one out-of-bounds slice index check in Enemy.Attack.getActiveAbilityPtr (change `>` to `>=`)
      - [x] Fix magic damage mitigation formula in Stats.calculateDamage to use defender.current.magic_resist instead of magic_damage
      - [x] Clamp defense values in Stats.defenseToDamageReductionPercent to prevent negative log10 NaN and high-defense damage healing
      - [x] Fix gamepad 180-degree attack direction reversal in player.Attack and Weapon.doAttack to restore accurate stick aiming
      - [x] Fix footstep audio timer reset placement in player.Movement to allow walking audio to play
      - [x] Fix knockback stamina drain by setting reduce_stamina = false in Projectile.onCollisionDealDamage
      - [x] Restore attack cooldown timer on player heavy attack and remove self-inflicted stun in player.Attack
      - [x] Fix canOfferAshwaganda1 unlock condition in boons.zig so tier-1 spell can be offered
      - [x] Implement per-target hit tracking on passthrough projectiles to eliminate multi-hit audio distortion and status effect spam
      - [x] Enforce hard cap in RoundSpawner ensuring active enemy count never exceeds 128 concurrently (protecting OverheadUI ID pool)
      - [x] Replace O(N*M) spawner liveness polling in RoundSpawner.update with direct defeat notification from Death component
      - [x] Replace O(N) array shifts in RoundSpawner spawn queue with O(1) queue cursor index
      - [x] Decouple arena coordinates and obstacle exclusion box from RoundSpawner by accepting SpawnAreaConfig from DemoMap
      - [x] Migrate global singletons (DemoMap state, MusicManager) to Loom 0.10.0 scene.getGlobalBehaviour / pullGlobalBehaviour
      - [x] Decouple Interactable component from DemoMap.state and replace static 64-slot registry with proximity/trigger collision detection
      - [x] Decouple weapon boons from fixed slot indices (0/1) by implementing Attack.getWeaponById
      - [x] Add unique string ID to Boon struct, update Boon.eql, and disambiguate duplicate boon names
      - [x] Prevent unbounded Objectives list growth by clearing or updating active phase objectives
      - [x] Ensure Raylib music streams are cleanly stopped and unloaded in MusicManager.End()
      - [x] Refactor Enemy.Attack abilities from fixed-capacity array to lm.List(Ability)
      - [x] Refactor Interactable registry from std.ArrayListUnmanaged(*Self) to lm.List(*Self)
    ```md
    Comprehensive remediation addressing critical combat bugs, spawner performance bottlenecks, memory leaks, and global singleton anti-patterns identified in the architectural analysis, leveraging Loom 0.10.0 global behaviour querying.
    ```

### Architectural analysis and code audit

  - tags: [architecture, analysis, audit]
  - priority: high
  - workload: Normal
  - steps:
      - [x] Comprehensive codebase audit (architecture, bugs, performance, extensibility)
      - [x] Document findings and recommendations in architecture analysis artifact

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

