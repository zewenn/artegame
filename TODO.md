# Artegame Tasks

## Backlog

### [25#ARC] Projectile and combat stream extensions: pull forces, ally healing, fixed angles, and channeled barrages

  - tags: [architecture, combat, projectiles, abilities]
  - priority: high
  - workload: Normal
  - steps:
      - [ ] Add vector pull/drag on-hit mechanic in Projectile.zig pulling target toward caster (Magician "Where are you going?")
      - [ ] Add healing projectile mode in Projectile.zig allowing projectiles to restore HP to matching team members (Shaman Remote Healing)
      - [ ] Support absolute world angle firing in Ability.zig independent of player position (Angler & Bishop cardinal directions)
      - [ ] Implement channeled continuous barrage execution in Attack.zig with rotating heading (Bishop 4-way radial sweep over 5s)
      - [ ] Support staggered multi-wave projectile volleys in Ability.zig (Queen dash attack waves and Tank slow bursts)
      - [ ] Implement projectile on-hit callback hook for global reactions (Shaman Grieving Wounds team heal, Queen Bond of Life early cancel)
      - [ ] User confirmation that projectile extensions and channeled streams function as expected
    ```md
    Builds on existing Projectile.zig (which already supports passthrough piercing, lifetimes, on-hit slow/root/stun, and knockback) by implementing missing v4.0.0 combat capabilities: caster-directed pull forces (Magician), ally-targeted healing projectiles (Shaman), fixed-angle firing (Angler), channeled rotating continuous streams (Bishop/Queen), multi-wave bursts, and on-hit event hooks. Blocks Shaman, Magician, Angler, Bishop, and Queen abilities.
    ```

### [26#ARC] Universal enemy status effects and ability framework: stasis, proximity auras, and Bond of Life

  - tags: [architecture, enemies, status-effects, combat]
  - priority: high
  - workload: Hard
  - steps:
      - [ ] Implement Stasis state component (invulnerable to damage, stunned/unable to act)
      - [ ] Implement reactive damage aura framework (reactive root-on-hit and mark/rebound damage reflection)
      - [ ] Implement proximity/distance-based scaling auras (Knight parabolic Armor/MR and drain; Magician slow)
      - [ ] Implement ally-targeting and revive mechanics for support enemies (Shaman ally buffs, Lifeliner revive)
      - [ ] Implement Bond of Life mark lifecycle: true damage on hit, damage rebound to caster on miss/expiry
      - [ ] User confirmation that universal ability hooks and status effects trigger correctly
    ```md
    Extensible status effect and enemy ability framework. Introduces stasis invulnerability, proximity stat/damage scaling curves, ally targeted support abilities, and reactive damage mechanisms needed across new normal enemies, mini-bosses, and bosses.
    ```

### [27#ARC] Tile-based background engine, room layout serialization, and map editor

  - tags: [architecture, tilemap, map-editor, assets]
  - priority: high
  - workload: Extreme
  - steps:
      - [ ] Implement tilemap grid data structures supporting ground and wall/obstacle tile layers
      - [ ] Generate static boundary and obstacle Loom colliders dynamically from tilemap layout data
      - [ ] Design file serialization format (.map / JSON) for persistent room layout saving and loading
      - [ ] Modernize and integrate map editor tooling to design, edit, and export room layouts
      - [ ] Build runtime room loader to instantiate tilemap backgrounds based on active room type
      - [ ] User confirmation that tile-based maps load, render, and collide properly
    ```md
    Tile-based map engine replacing hardcoded single-texture arena backgrounds. Provides data-driven room layouts, serialization, and integrated editor tooling to author visually distinct regular rooms, boss arenas, and tutorial environments.
    ```

### [28#SPW] Dynamic wave spawner overhaul and 256 enemy cap scaling

  - tags: [spawner, scaling, performance, waves]
  - priority: high
  - workload: Normal
  - steps:
      - [ ] Expand active enemy entity pool capacity and tracking limits from 128 to 256 enemies per room
      - [ ] Decouple RoundSpawner from static arena coordinates to accept arbitrary room boundaries and spawn zones
      - [ ] Add room-type spawn profiles: Tutorial (Dummy), Normal (scaling mob waves), Mini-Boss (solo), Boss (solo + phases)
      - [ ] Scale enemy spawn quantities, composition, and stats dynamically based on current room number
      - [ ] Benchmark and optimize collision, movement, and tick performance under 256 active entities
      - [ ] User confirmation that spawner handles 256 enemies without frame drops or memory leaks
    ```md
    Overhauls RoundSpawner.zig to double enemy capacity to 256 per room, dynamically generate room-tailored encounter waves, scale mob difficulty with room index, and maintain 60 FPS under full capacity.
    ```

### [29#SYS] Save system reset and schema updates for room progression and tutorial persistence

  - tags: [save, persistence, schema, tutorial]
  - priority: high
  - workload: Easy
  - steps:
      - [ ] Bump save version in SaveData.zig and automatically reset legacy saves to defaults on mismatch
      - [ ] Add tutorial_completed boolean flag to persistent profile save data
      - [ ] Extend active run save schema to persist current_room_index, rooms_cleared, and room category
      - [ ] Update SaveSystem.zig to save and restore mid-run room progression state during replenish phase
      - [ ] Add unit tests verifying legacy save reset on version mismatch and clean room/tutorial serialization
      - [ ] User confirmation that save reset on v4.0.0 and room/tutorial persistence work as expected
    ```md
    Updates SaveData.zig and SaveSystem.zig to support room progression, active room state, and persistent tutorial completion. Bumps the save file version so incompatible legacy saves are cleanly reset to fresh defaults rather than migrated.
    ```

### [30#ARC] Boon category data structures and categorized reward pools

  - tags: [architecture, boons, progression, rng]
  - priority: high
  - workload: Normal
  - steps:
      - [ ] Define BoonCategory struct with name, icon identifier, and boon collection slice
      - [ ] Categorize all existing and planned boons into thematic category pools
      - [ ] Update BoonPool.zig to support category-scoped boon rolling and candidate filtering
      - [ ] Implement category selection logic to assign random BoonCategory items to room exit doors
      - [ ] Enforce category restriction in BoonMenu so offered 3-card choices draw only from room category
      - [ ] User confirmation that boon rewards accurately filter to the room's designated category
    ```md
    Implements BoonCategory data structures and pool filtering. Allows room doors to offer category-specific rewards (e.g. Plate Upgrades), giving players deterministic control over build progression while retaining the 3-card selection UI.
    ```

### [31#UIB] Interactive room exit doors with reward category icon overlays

  - tags: [ui, doors, interaction, prefabs]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Create Door prefab entity with physical collider, interaction prompt, and open/closed visuals
      - [ ] Render overhead reward icon badges on doors indicating upcoming room reward (Boon category, Mini-Boss, Boss)
      - [ ] Implement door spawner generating 1 to 3 doors during replenish phase based on room rules
      - [ ] Randomize door rewards after each round completion to prevent static progression routes
      - [ ] Connect door interaction to RoomManager to trigger room transition and load selected room
      - [ ] User confirmation that doors spawn with correct reward icons and transition rooms on interaction
    ```md
    Implements interactive exit doors appearing during the replenish phase. Displays reward category icons overhead and lets the player choose which room path to venture into next.
    ```

### [32#UIS] Dedicated top-of-screen boss health bar HUD component

  - tags: [ui, hud, boss-bar, encounters]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Design top-of-screen boss health bar HUD layout in HUD.zig with boss name and stylized health bar
      - [ ] Implement entity binding API to link boss bar to active Mini-Boss or Boss entity Stats component
      - [ ] Hide default overhead health bar on entities currently bound to the top boss bar
      - [ ] Add smooth health bar animation, damage lag gauge, and defeat fade-out transition
      - [ ] User confirmation that top-of-screen boss health bar renders cleanly during boss fights
    ```md
    UI component for mini-boss and boss encounters. Replaces floating overhead health bars with a prominent screen-top boss health bar displaying boss name and current health percentage.
    ```

### [33#ENE] New normal enemy archetypes: Shaman, Magician, Lifeliner, Angler, and Tank

  - tags: [enemies, ai, combat, archetypes]
  - priority: medium
  - workload: Hard
  - steps:
      - [ ] Implement Shaman prefab & AI: pass-through heal burst, ally speed buff, grieving projectile, stasis backup call, on-death HP drain/buff
      - [ ] Implement Magician prefab & AI: blink teleport, pull projectile, proximity slow aura, close-range stun burst
      - [ ] Implement Lifeliner prefab & AI: low-HP ally rescue teleport and fallen enemy resurrection
      - [ ] Implement Angler prefab & AI: 4-way rapid cardinal fire (0°, 90°, -90°, 180°) with scaling attack speed
      - [ ] Implement Tank prefab & AI: reactive root-on-hit aura, stacking slow shots, knockback projectile, 8-way stun burst
      - [ ] User confirmation that all 5 normal enemy archetypes display intended behaviors and abilities
    ```md
    Implements 5 new standard enemy archetypes specified in v4.0.0: Shaman (support/summoner), Magician (mobility/pull), Lifeliner (medic/reviver), Angler (rapid cardinal suppression), and Tank (crowd control/reactive defense).
    ```

### [34#ENE] Mini-boss encounters: Knight and Bishop with scaled clear rewards

  - tags: [enemies, mini-boss, encounters, ai]
  - priority: medium
  - workload: Hard
  - steps:
      - [ ] Implement Knight prefab & AI: close-range brawler, parabolic distance Armor/MR scaling, distance drain aura, beheading strike, Weaken vulnerability, low-HP heal channel
      - [ ] Implement Bishop prefab & AI: sweeping 360° rotating cross barrages (Knockback, Slow, Root, Stun variants) with 5s duration and 750 projectile speed
      - [ ] Trigger mini-boss room encounter automatically every 5th room after clearing 4 regular rooms
      - [ ] Grant mini-boss clear rewards on defeat: full HP restore and permanent +10% max HP increase
      - [ ] User confirmation that mini-boss encounters function correctly with distinct phases and rewards
    ```md
    Implements the two v4.0.0 mini-boss encounters appearing every 5 rooms. Defeating a mini-boss restores HP to max and permanently boosts max HP by 10%.
    ```

### [35#ENE] End-game boss encounters: The King and The Queen

  - tags: [enemies, bosses, encounters, ai]
  - priority: medium
  - workload: Extreme
  - steps:
      - [ ] Implement The King prefab & AI: wide melee attacks, stasis minion summoning (2 mini-bosses or 40+ normal enemies followed by Weaken), sub-50% HP root and slow spells
      - [ ] Implement The Queen prefab & AI: Bond of Life application (10% max HP true damage / rebound on miss), radial sweep, dash attack waves, and sniper stun projectile
      - [ ] Trigger boss room encounter automatically every 15th room after clearing 14 rooms
      - [ ] Grant boss clear rewards on defeat: full HP restore, permanent +15% max HP, +15 physical damage, and +10 magic damage
      - [ ] User confirmation that King and Queen boss fights operate with proper multi-phase mechanics and rewards
    ```md
    Implements full boss encounters for The King and The Queen appearing every 15 rooms. Features complex phase shifts, summon phases, Bond of Life mechanics, and major permanent stat upgrade rewards on clear.
    ```

### [36#UIS] First-launch tutorial room, Training Dummy prefab, and objective sequence

  - tags: [tutorial, hud, objectives, onboarding]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Create TrainingDummy prefab with infinite health, hit impact audio/visual feedback, and no offensive attacks
      - [ ] Implement sequential tutorial objective HUD tracker: WASD move, Space dash, light/heavy/dash attacks, boon interact, door interact
      - [ ] Spawn guaranteed starter boon selection and single exit door in tutorial room
      - [ ] Persist tutorial completion in save data upon exiting the tutorial room and bypass on future runs
      - [ ] User confirmation that tutorial room guides player through all core actions and saves completion
    ```md
    Implements the first-room onboarding tutorial. Features a non-hostile Training Dummy and sequential objective prompts teaching movement, dashes, attacks, boon collection, and door transitions.
    ```

### [37#UIM] Main menu dynamic "Tutorial" replay button

  - tags: [ui, main-menu, buttons, tutorial]
  - priority: low
  - workload: Easy
  - steps:
      - [ ] Add query to SaveSystem to check if tutorial has been completed previously
      - [ ] Dynamically render a standardized 6:1 "Tutorial" menu button in MainMenu.zig when tutorial_completed is true
      - [ ] Connect button click to launch standalone practice tutorial room without altering active run stats
      - [ ] Return cleanly to Main Menu upon exiting the practice tutorial room
      - [ ] User confirmation that Tutorial button displays and launches practice room as expected
    ```md
    Adds a dynamic "Tutorial" button to the Main Menu when the player has previously completed the tutorial, allowing players to replay the tutorial / practice room anytime from the menu.
    ```

### [38#AST] Sprite, particle, and audio asset integration for v4.0.0 content

  - tags: [assets, sprites, audio, vfx]
  - priority: low
  - workload: Normal
  - steps:
      - [ ] Source or generate pixel-art sprites for new enemies (Shaman, Magician, Lifeliner, Angler, Tank) and bosses (Knight, Bishop, King, Queen, Training Dummy)
      - [ ] Create visual effect textures and particle animations: Bond of Life tether, stasis barrier, reactive root aura, distance drain beam, radial bullets
      - [ ] Create door sprites (open, closed, category icon badges) and modular tilemap tilesets
      - [ ] Integrate sound effects for new abilities (blink, bullet sweep, drain, stasis) and boss encounter BGM
      - [ ] User confirmation that all v4.0.0 visual and audio assets load and render without glitches
    ```md
    Encompasses visual and audio assets required for v4.0.0: new enemy spritesheets, VFX overlays (Bond of Life, shields, beams), door/icon tiles, and audio sound effects/music tracks.
    ```

### [19#OPS] Linux release build and packaging workflow

  - tags: [ci, release, linux]
  - priority: medium
  - workload: Normal
  - steps:
      - [ ] Resolve Linux build dependencies and headless CI compatibility (X11, GL, libc)
      - [ ] Re-add linux-x86_64 target to matrix in .github/workflows/release.yml
      - [ ] Package standalone Linux archive (.tar.gz) or AppImage with bundled assets
      - [ ] Validate runtime execution across common Linux distributions

## Work in Progress

### [24#ARC] Room progression architecture and dynamic room lifecycle

  - tags: [architecture, room, progression, lifecycle]
  - priority: high
  - workload: Hard
  - steps:
      - [x] Refactor DemoMap.zig into a modular RoomManager and room lifecycle state machine
      - [x] Automatically initialize round state to .combat on room entry
      - [x] Transition round state to .replenish and grant rewards when all room enemies are defeated
      - [x] Track total rooms cleared, room counters, and triggers for mini-boss (every 5) and boss (every 15) rooms
      - [x] Implement entity cleanup (projectiles, remnants, drops) and player repositioning between rooms
      - [ ] User confirmation that room lifecycle and state transitions function as expected
    ```md
    Foundation architecture for v4.0.0 room-based progression. Replaces the single static arena loop with a dynamic RoomManager handling room entry, combat triggers, replenishment transitions, and room cleanup. Blocks mini-boss, boss, and tutorial room implementations.
    ```

## Done

### [21#OPS] Fix macOS release Gatekeeper damaged error via ad-hoc bundle signing

  - tags: [ci, release, macos, codesign, gatekeeper]
  - priority: high
  - workload: Normal
  - steps:
      - [x] Add ad-hoc bundle codesigning (`codesign --force --deep --sign -`) in packaging/macos/create_dmg.py
      - [x] Add `zig build sign` step and enrich Info.plist metadata in build.zig
      - [x] Ensure binary executable permissions (0755) in staged .app bundle
      - [x] Document Gatekeeper first-launch instructions (right-click / xattr) in README.md
      - [ ] User confirmation that release package launches properly

### [23#DOC] Proofread and polish v4.0.0 specification

  - tags: [docs, specs, v4]
  - priority: low
  - workload: Easy
  - steps:
      - [x] Review spelling, grammar, punctuation, and formatting in specs/v4.0.0.md
      - [x] Correct logical and copy-paste errors (Magician vs Shaman, Bishop diagonal vs radial, King peasant minions)
      - [x] Update specs/v4.0.0.md with polished documentation
      - [x] User confirmation that proofread specification meets expectations

### [22#WFX] Windows release fixes (terminal suppression, Play crash, ReleaseSafe build)

  - tags: [release, windows, bugfix, build]
  - priority: high
  - workload: Normal
  - steps:
      - [x] Configure Windows GUI subsystem (`exe.subsystem = .windows`) in build.zig to suppress terminal window
      - [x] Decouple hand sprite setting and guard child animators until initialized in Hands.zig, Attack.zig, and DemoMap.zig
      - [x] Add `_FORTIFY_SOURCE = 0` macro on Windows targets in build.zig to fix ReleaseSafe MinGW fortify build errors
      - [x] Dynamically read app_version from build.zig.zon in build.zig
      - [x] User confirmation that Windows release runs properly

### [20#OPS] macOS DMG installer packaging

  - tags: [ci, release, macos, installer, dmg]
  - priority: medium
  - workload: Normal
  - steps:
      - [x] Create packaging/macos/create_dmg.py script with Applications symlink and hdiutil
      - [x] Add `zig build dmg` step in build.zig for macOS targets
      - [x] Update .github/workflows/release.yml to package and publish .dmg files for macos-arm64 and macos-x86_64
      - [x] Update README.md documentation for .dmg downloads
      - [x] Verify local DMG build and test execution

### [18#OPS] Automated Windows Installer (NSIS)

  - tags: [ci, release, windows, installer]
  - priority: medium
  - workload: Normal
  - steps:
      - [x] Create packaging/windows/installer.nsi template with branding, shortcuts, and uninstaller
      - [x] Add `zig build installer` step in build.zig with makensis detection
      - [x] Update .github/workflows/release.yml to build and publish Windows installer executable
      - [x] Verify local build and test execution

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

