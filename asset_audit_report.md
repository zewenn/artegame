# Asset Audit Report: Missing and Reused Assets (v4.0.0)

This report details every missing asset (currently relying on placeholders like `empty.png` or `empty_icon.png`) and reused asset (repurposed from existing minions, weapons, or UI icons) identified across the codebase for tickets `38#AST` and `39#AST`, including their exact native pixel resolutions and in-game rendered scales.

> **Resolution Baseline**: Artegame uses a **16x16 pixel-art baseline**. Standard characters and minions use a **16x16** native sprite texture scaled 4x in-engine to **64x64**. Dual-grid tilemap sheets are **64x64** (4x4 grid of 16x16 sub-quad tiles).

---

## Quick Reference Resolution Matrix

| Category | Item | Native Size (Source PNG) | In-Game Render Scale |
| :--- | :--- | :--- | :--- |
| **Standard Characters** | Player, Melee, Ranged, Shaman, Magician, Dummy | **16 x 16** | 64 x 64 |
| **Compact Characters** | Lifeliner, Angler | **16 x 16** | 56 x 56 |
| **Large Characters** | Tank | **24 x 24** | 80 x 80 (slam: 96 x 80) |
| **Bosses** | King, Queen | **24 x 24** | 96 x 96 to 100 x 100 |
| **Mini-Bosses** | Knight, Bishop | **16 x 16** (or **20 x 20**) | 64 x 64 |
| **World Entities** | Exit Door (open / closed) | **24 x 24** | 96 x 96 |
| **World Drops** | Boon Drop, Anchor | **16 x 16** | 48 x 48 (drop), 64 x 64 (anchor) |
| **Pickups** | Experience Orb | **16 x 16** (8x8 crystal) | 32 x 32 |
| **Projectiles** | Healing shot, Pull orb, Darts, Barrages | **16 x 16** | 32 x 32 to 48 x 48 |
| **Status Overlays** | Stun, Sleep, Root, Regen, Stasis, Aura | **16 x 16** (Aura: **24 x 24**) | 64 x 64 to 80 x 80 |
| **UI Badges & Icons** | Door badges, Status icons, Boon icons | **16 x 16** | 16 x 16 to 20 x 20 |
| **Dual-Grid Tilesets** | Floor & Wall 16-quad sheets | **64 x 64** (16x16 quads) | 64 x 64 per tile |
| **Wall Trim Sprites** | Normal wall front, Short wall front | **16 x 16**, **16 x 12** | 64 x 64, 64 x 48 |
| **Menu Backgrounds** | Main Menu, Game Over illustrations | **640 x 360** (or **1280 x 720**) | Fullscreen 16:9 |

---

## 1. Character & Entity Sprites

### 1.1 New Enemies (Missing Sprites)
All 5 newly implemented enemies currently point to `empty.png` across their renderers, animations, and projectile definitions:
- **Shaman** (`src/prefabs/enemies/Shaman.zig`):
  - **Required Native Size**: **16 x 16** px
  - **In-Game Scale**: 64 x 64 px
  - **Missing Assets**: Base sprite (`idle-left`, `idle-right`), walk frames (`walk-left`, `walk-right`), windup (`windup-cast`), and cast release (`cast`).
- **Magician** (`src/prefabs/enemies/Magician.zig`):
  - **Required Native Size**: **16 x 16** px
  - **In-Game Scale**: 64 x 64 px
  - **Missing Assets**: Base sprite, directional idle/walk frames, blink animation frames, and cast frames.
- **Lifeliner** (`src/prefabs/enemies/Lifeliner.zig`):
  - **Required Native Size**: **16 x 16** px (compact 14x14 silhouette)
  - **In-Game Scale**: 56 x 56 px
  - **Missing Assets**: Base sprite, directional idle/walk frames, rescue cast frames, and revive cast frames.
- **Angler** (`src/prefabs/enemies/Angler.zig`):
  - **Required Native Size**: **16 x 16** px (compact 14x14 silhouette)
  - **In-Game Scale**: 56 x 56 px
  - **Missing Assets**: Base sprite, directional idle/walk frames, and cardinal firing animation frames (`fire-cardinal`).
- **Tank** (`src/prefabs/enemies/Tank.zig`):
  - **Required Native Size**: **24 x 24** px (brute profile)
  - **In-Game Scale**: 80 x 80 px (slam attack expands to 96 x 80 px)
  - **Missing Assets**: Heavy brute base sprite, idle/walk frames, root shield stance, and heavy attack slam frames.

### 1.2 Bosses & Mini-Bosses (Reused Sprites)
All bosses and mini-bosses currently borrow minion sprites with scale/tint adjustments:
- **Knight Mini-Boss** (`src/prefabs/enemies/Knight.zig`):
  - **Required Native Size**: **16 x 16** px (or **20 x 20** for armored bulk)
  - **In-Game Scale**: 64 x 64 px
  - **Current Fallback**: Reuses `characters/enemies/melee/left_1.png` (16x16).
- **Bishop Mini-Boss** (`src/prefabs/enemies/Bishop.zig`):
  - **Required Native Size**: **16 x 16** px (or **20 x 20** with mitre/staff)
  - **In-Game Scale**: 64 x 64 px
  - **Current Fallback**: Reuses `characters/enemies/ranged/left_1.png` (16x16).
- **King Boss** (`src/prefabs/enemies/King.zig`):
  - **Required Native Size**: **24 x 24** px (regal armor & crown)
  - **In-Game Scale**: 100 x 100 px
  - **Current Fallback**: Reuses `characters/enemies/melee/left_1.png` scaled up 1.56x and tinted gold.
- **Queen Boss** (`src/prefabs/enemies/Queen.zig`):
  - **Required Native Size**: **24 x 24** px (royal robe & floating orbs)
  - **In-Game Scale**: 96 x 96 px
  - **Current Fallback**: Reuses `characters/enemies/ranged/left_1.png` scaled up 1.5x and tinted magenta.
- **Elite Enemy** (`src/prefabs/enemies/Elite.zig`):
  - **Required Native Size**: **16 x 16** px (distinct elite armor/spikes)
  - **In-Game Scale**: 64 x 64 px
  - **Current Fallback**: Reuses `characters/enemies/melee/left_1.png` tinted red.
- **Training Dummy** (`src/prefabs/enemies/TrainingDummy.zig`):
  - **Required Native Size**: **16 x 16** px
  - **In-Game Scale**: 64 x 64 px
  - **Current Fallback**: Reuses static `characters/enemies/dummy.png`.

### 1.3 World Entities & Item Drops
- **Exit Door** (`src/prefabs/ExitDoor.zig`):
  - **Required Native Size**: **24 x 24** px (door archway frame)
  - **In-Game Scale**: 96 x 96 px
  - **Current Fallback**: Renders `ui/icons/empty_icon.png` (16x16) tinted dynamically.
  - **Required Variations**: Closed door frame, open active portal, boss gate arch.
- **Boon Drop** (`src/prefabs/items/BoonDrop.zig`):
  - **Required Native Size**: **16 x 16** px (pedestal / floating gift orb)
  - **In-Game Scale**: 48 x 48 px
  - **Current Fallback**: Renders `ui/icons/empty_icon.png`.
- **Experience Orb** (`src/prefabs/items/ExperienceOrb.zig`):
  - **Required Native Size**: **16 x 16** px (centered 8x8 glowing xp gem)
  - **In-Game Scale**: 32 x 32 px
  - **Current Fallback**: Reuses `ui/icons/sleep_icon.png` (16x16).
- **Anchor** (`src/prefabs/Anchor.zig`):
  - **Required Native Size**: **16 x 16** px
  - **In-Game Scale**: 64 x 64 px
  - **Current Fallback**: Renders `ui/icons/empty_icon.png`.

---

## 2. Projectiles & Visual Effects (VFX)

### 2.1 Projectiles (Native Size: 16 x 16 px)
- **Shaman Healing Projectile** (`src/prefabs/enemies/Shaman.zig:130`):
  - **Required Native Size**: **16 x 16** px (in-game scale: 40 x 40 px)
  - **Current Fallback**: `empty.png`. Needs green/gold holy healing orb.
- **Shaman Grieving Wounds Projectile** (`src/prefabs/enemies/Shaman.zig:167`):
  - **Required Native Size**: **16 x 16** px (in-game scale: 32 x 32 px)
  - **Current Fallback**: `empty.png`. Needs cursed skull/bolt.
- **Magician Pull Orb** (`src/prefabs/enemies/Magician.zig:95`):
  - **Required Native Size**: **16 x 16** px (in-game scale: 48 x 48 px)
  - **Current Fallback**: `empty.png`. Needs swirling purple gravity vortex.
- **Magician Covered Attack Darts** (`src/prefabs/enemies/Magician.zig:118`):
  - **Required Native Size**: **16 x 16** px (in-game scale: 32 x 32 px)
  - **Current Fallback**: `empty.png`.
- **Lifeliner Rapid Dart** (`src/prefabs/enemies/Lifeliner.zig:127`):
  - **Required Native Size**: **16 x 16** px (in-game scale: 32 x 32 px)
  - **Current Fallback**: `empty.png`. Needs needle/siphon dart.
- **Angler Cardinal Darts** (`src/prefabs/enemies/Angler.zig:78`):
  - **Required Native Size**: **16 x 16** px (in-game scale: 32 x 32 px)
  - **Current Fallback**: `empty.png`. Needs directional arrow/cross bolts.
- **Tank Slow Barrage & Knockback** (`src/prefabs/enemies/Tank.zig:93`):
  - **Required Native Size**: **16 x 16** px (in-game scale: 44 x 44 px)
  - **Current Fallback**: `empty.png`. Needs heavy mud/stone boulder.

### 2.2 Visual Effects & Overlays (`src/components/effects/EffectVisual.zig`)
- **Bond of Life Tether**:
  - **Required Native Size**: **16 x 8** px (horizontal tileable chain/tether segment)
  - **Current Fallback**: Missing completely (no rendering).
- **Bond of Life Status Overlay**:
  - **Required Native Size**: **16 x 16** px (in-game scale: 64 x 64 px)
  - **Current Fallback**: Returns `null`. Needs blood link / curse icon above target.
- **Stasis Barrier**:
  - **Required Native Size**: **24 x 24** px or **32 x 32** px (in-game scale: 72 x 72 px)
  - **Current Fallback**: Returns `null`. Needs golden stasis crystal/invulnerability dome.
- **Slow Effect Overlay**:
  - **Required Native Size**: **16 x 16** px (in-game scale: 64 x 64 px)
  - **Current Fallback**: Returns `null`. Needs ice crystals / sluggish sludge particles.
- **Reactive Root Aura**:
  - **Required Native Size**: **24 x 24** px or **32 x 32** px (in-game scale: 80 x 80 px)
  - **Current Fallback**: Missing. Needs thorny ground roots / wooden shield perimeter.
- **Distance Drain Beam**:
  - **Required Native Size**: **16 x 8** px (tileable siphon beam animation)
  - **Current Fallback**: Missing. Needs pulsing cyan energy beam.
- **Heal Pulse Animation**:
  - **Required Native Size**: **16 x 16** to **32 x 32** px (3-4 frame expanding ring)
  - **Current Fallback**: Missing.

---

## 3. Audio (Sound Effects & Music)

### 3.1 Reused Sound Effects
- **Healing SFX & Ally Heal Chime** (`Shaman.zig:72`, `SupportMechanics.zig:134`): Reuses `audio/sfx/pickup.mp3`. Needs holy chime / warm pulse SFX.
- **Caster Pull Force SFX** (`Magician.zig:104`): Reuses `audio/sfx/punch.mp3`. Needs whoosh / gravitational pull SFX.
- **Magician Blink & Queen Dash** (`Magician.zig:72`, `QueenMechanics.zig:81`): Reuses player `audio/sfx/dash.wav`. Needs arcane teleport pop / warp SFX.
- **Knight Shield Slam / Charge** (`KnightMechanics.zig:133`): Reuses `audio/sfx/coin.wav`. Needs metallic shield bash / gallop SFX.
- **Knight Leap Buff** (`KnightMechanics.zig:139`): Reuses `audio/sfx/pickup.mp3`. Needs warhorn / battle shout SFX.
- **Tank Root Shield Activation** (`Tank.zig:70`): Reuses generic explosion `audio/sfx/boom.wav`. Needs earthen thud / stone cracking SFX.
- **Door Transition SFX** (`Door.zig:156`): Reuses UI button click `audio/sfx/click.wav`. Needs heavy stone gate creak / portal hum SFX.
- **Boon Drop Interaction** (`BoonDrop.zig:15`): Reuses `audio/sfx/coin.wav`. Needs ethereal boon unseal chime.

### 3.2 Music & BGM (`src/global/audio/MusicManager.zig`)
- **Boss Encounter BGM**: Missing. Needs high-tempo orchestral/chiptune boss theme.
- **Mini-Boss Encounter BGM**: Missing. Needs driving battle theme.

---

## 4. UI Elements & Icons

### 4.1 Exit Door Category Badges (Native Size: 16 x 16 px, Rendered at 20 x 20 px)
- **Boss Door Badge**: Reuses `ui/icons/goliath_icon.png`. Needs gold skull / royal crest icon (**16 x 16**).
- **Mini-Boss Door Badge**: Reuses `ui/icons/goliath_icon.png`. Needs purple crossed swords / shield icon (**16 x 16**).
- **Room 1 Door Badge**: Reuses `ui/icons/empty_icon.png`. Needs stone doorway / entrance badge (**16 x 16**).
- **Tutorial Door Badge**: Reuses `ui/icons/empty_icon.png`. Needs scroll / graduation cap icon (**16 x 16**).
- **Vitality Category Badge**: Reuses `items/strawberry.png`. Needs heart / vitality flask badge (**16 x 16**).
- **New Supplements Badge**: Reuses `ui/icons/heal_icon.png`. Needs blender / smoothie potion badge (**16 x 16**).
- **Supplement Upgrades Badge**: Reuses `ui/icons/haste_icon.png`. Needs upward upgrade chevron badge (**16 x 16**).

### 4.2 Status Effect Icons (Native Size: 16 x 16 px)
- **Stun Icon**: Reuses `ui/icons/empty_icon.png`. Needs yellow spiral / dazed stars (**16 x 16**).
- **Root Icon**: Reuses `ui/icons/sleep_icon.png`. Needs vines / tangled roots (**16 x 16**).
- **Slow Icon**: Returns `null`. Needs blue snowflake / snail weight (**16 x 16**).
- **Bond of Life Icon**: Returns `null`. Needs broken heart / tether chain (**16 x 16**).

### 4.3 Boon Card Artwork (`src/global/boons/boons.zig`)
- **Passive Boons (36+ entries)**: Reuses `items/blueberry.png` (**16 x 16**). Needs category-specific badges.
- **Spell Boons (25+ entries)**: Reuses `items/banana.png` (**16 x 16**). Needs spell-specific flasks / fruits.
- **Boon Selection Fallback Icon**: Reuses `ui/icons/sleep_icon.png`. Needs mystery chest / question token (**16 x 16**).

---

## 5. Backgrounds & Environment Art

### 5.1 Menu & Screen Backgrounds
- **Main Menu** (`src/global/ui/MainMenu.zig:139`):
  - **Required Resolution**: **640 x 360** px (upscaled 2x to 1280x720) or native **1280 x 720** px (16:9).
  - **Current State**: Plain solid dark color `#0a0c10`. Needs pixel-art gym/dungeon arena panoramic illustration.
- **Game Over Screen** (`src/global/ui/GameOverMenu.zig`):
  - **Required Resolution**: **640 x 360** px or **1280 x 720** px.
  - **Current State**: Semi-transparent dark overlay `#080a0e`. Needs defeat vignette / cracked gym floor artwork.

### 5.2 Environment & Tilesets (`src/global/map/MapRenderer.zig`, `MapTypes.zig`)
- **Dual-Grid Tileset Sheets**:
  - **Required Native Size**: **64 x 64** px texture sheet (4x4 arrangement of 16x16 sub-quad tiles).
  - **Current State**: All arenas share generic `stone.png`, `carpet.png`, and `wall_top.png`.
  - **Missing Themed Tilesets**:
    - Royal Arena (King / Queen): Polished marble floor, royal red carpet, gold-accented brick walls (**64 x 64** dual-grid sheets).
    - Sanctuary Arena (Knight / Bishop): Mosaic flagstones, stained glass floor reflections, vaulted stone walls (**64 x 64** dual-grid sheets).
    - Wall Trims: Normal wall front (**16 x 16**), Short wall front (**16 x 12**).
- **Asset Typo**: `src/assets/backgrounds/bakcground_tile_2_32x32.png` contains a typo in the asset filename.
