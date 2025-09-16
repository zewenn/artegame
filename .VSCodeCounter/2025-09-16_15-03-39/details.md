# Details

Date : 2025-09-16 15:03:39

Directory /Users/zoltantakacs/Projects/artegame

Total : 62 files,  6323 codes, 873 comments, 1849 blanks, all 9045 lines

[Summary](results.md) / Details / [Diff Summary](diff.md) / [Diff Details](diff-details.md)

## Files
| filename | language | code | comment | blank | total |
| :--- | :--- | ---: | ---: | ---: | ---: |
| [.pylintrc](/.pylintrc) | Ini | 30 | 0 | 7 | 37 |
| [README.md](/README.md) | Markdown | 53 | 0 | 10 | 63 |
| [architect/\_\_config\_\_.py](/architect/__config__.py) | Python | 33 | 6 | 13 | 52 |
| [architect/\_\_main\_\_.py](/architect/__main__.py) | Python | 24 | 0 | 9 | 33 |
| [architect/b64encoder.py](/architect/b64encoder.py) | Python | 35 | 6 | 19 | 60 |
| [architect/cli.py](/architect/cli.py) | Python | 195 | 19 | 67 | 281 |
| [architect/deps.py](/architect/deps.py) | Python | 159 | 11 | 62 | 232 |
| [architect/import\_generator.py](/architect/import_generator.py) | Python | 277 | 16 | 82 | 375 |
| [brass/\_\_init\_\_.py](/brass/__init__.py) | Python | 87 | 7 | 22 | 116 |
| [brass/animator/\_\_init\_\_.py](/brass/animator/__init__.py) | Python | 138 | 48 | 65 | 251 |
| [brass/animator/interpolation.py](/brass/animator/interpolation.py) | Python | 41 | 12 | 16 | 69 |
| [brass/animator/play\_objects.py](/brass/animator/play_objects.py) | Python | 25 | 0 | 11 | 36 |
| [brass/animator/store.py](/brass/animator/store.py) | Python | 9 | 0 | 6 | 15 |
| [brass/assets.py](/brass/assets.py) | Python | 50 | 18 | 28 | 96 |
| [brass/audio.py](/brass/audio.py) | Python | 41 | 1 | 28 | 70 |
| [brass/base.py](/brass/base.py) | Python | 103 | 3 | 53 | 159 |
| [brass/collision.py](/brass/collision.py) | Python | 127 | 3 | 34 | 164 |
| [brass/display.py](/brass/display.py) | Python | 243 | 35 | 69 | 347 |
| [brass/enums/\_\_init\_\_.py](/brass/enums/__init__.py) | Python | 7 | 1 | 1 | 9 |
| [brass/enums/animations.py](/brass/enums/animations.py) | Python | 10 | 0 | 5 | 15 |
| [brass/enums/base\_keybinds.py](/brass/enums/base_keybinds.py) | Python | 3 | 0 | 1 | 4 |
| [brass/enums/gui.py](/brass/enums/gui.py) | Python | 30 | 0 | 8 | 38 |
| [brass/enums/input\_modes.py](/brass/enums/input_modes.py) | Python | 2 | 0 | 2 | 4 |
| [brass/enums/scenes.py](/brass/enums/scenes.py) | Python | 3 | 1 | 2 | 6 |
| [brass/events.py](/brass/events.py) | Python | 30 | 0 | 20 | 50 |
| [brass/gui.py](/brass/gui.py) | Python | 238 | 23 | 69 | 330 |
| [brass/inpt.py](/brass/inpt.py) | Python | 249 | 80 | 94 | 423 |
| [brass/items.py](/brass/items.py) | Python | 61 | 42 | 39 | 142 |
| [brass/pgapi.py](/brass/pgapi.py) | Python | 86 | 0 | 49 | 135 |
| [brass/saves.py](/brass/saves.py) | Python | 68 | 17 | 35 | 120 |
| [brass/scene.py](/brass/scene.py) | Python | 47 | 6 | 30 | 83 |
| [brass/structures.py](/brass/structures.py) | Python | 302 | 59 | 112 | 473 |
| [brass/timeout.py](/brass/timeout.py) | Python | 16 | 2 | 8 | 26 |
| [brass/vectormath.py](/brass/vectormath.py) | Python | 148 | 88 | 54 | 290 |
| [pyproject.toml](/pyproject.toml) | TOML | 10 | 0 | 2 | 12 |
| [pyrightconfig.json](/pyrightconfig.json) | JSON | 4 | 0 | 1 | 5 |
| [src/\_\_init\_\_.py](/src/__init__.py) | Python | 4 | 0 | 1 | 5 |
| [src/enums/\_\_init\_\_.py](/src/enums/__init__.py) | Python | 4 | 0 | 1 | 5 |
| [src/enums/keybinds.py](/src/enums/keybinds.py) | Python | 9 | 0 | 6 | 15 |
| [src/enums/spell\_enum.py](/src/enums/spell_enum.py) | Python | 37 | 0 | 4 | 41 |
| [src/global\_routines/\_\_init\_\_.py](/src/global_routines/__init__.py) | Python | 13 | 0 | 1 | 14 |
| [src/global\_routines/boons.py](/src/global_routines/boons.py) | Python | 797 | 106 | 202 | 1,105 |
| [src/global\_routines/crowd\_control.py](/src/global_routines/crowd_control.py) | Python | 72 | 0 | 21 | 93 |
| [src/global\_routines/dash.py](/src/global_routines/dash.py) | Python | 37 | 2 | 14 | 53 |
| [src/global\_routines/effect\_display.py](/src/global_routines/effect_display.py) | Python | 30 | 3 | 13 | 46 |
| [src/global\_routines/enemies.py](/src/global_routines/enemies.py) | Python | 234 | 7 | 51 | 292 |
| [src/global\_routines/interact.py](/src/global_routines/interact.py) | Python | 40 | 0 | 25 | 65 |
| [src/global\_routines/menus.py](/src/global_routines/menus.py) | Python | 57 | 2 | 27 | 86 |
| [src/global\_routines/projectiles.py](/src/global_routines/projectiles.py) | Python | 160 | 10 | 26 | 196 |
| [src/global\_routines/round\_manager.py](/src/global_routines/round_manager.py) | Python | 135 | 2 | 34 | 171 |
| [src/global\_routines/sounds.py](/src/global_routines/sounds.py) | Python | 65 | 0 | 33 | 98 |
| [src/global\_routines/spells.py](/src/global_routines/spells.py) | Python | 121 | 1 | 47 | 169 |
| [src/scenes/default/routines/conf.py](/src/scenes/default/routines/conf.py) | Python | 9 | 5 | 4 | 18 |
| [src/scenes/default/routines/main.py](/src/scenes/default/routines/main.py) | Python | 13 | 6 | 6 | 25 |
| [src/scenes/default/ui/index.py](/src/scenes/default/ui/index.py) | Python | 90 | 11 | 14 | 115 |
| [src/scenes/defeat/routines/conf.py](/src/scenes/defeat/routines/conf.py) | Python | 9 | 5 | 4 | 18 |
| [src/scenes/defeat/routines/main.py](/src/scenes/defeat/routines/main.py) | Python | 13 | 6 | 6 | 25 |
| [src/scenes/defeat/ui/index.py](/src/scenes/defeat/ui/index.py) | Python | 106 | 7 | 14 | 127 |
| [src/scenes/game/routines/conf.py](/src/scenes/game/routines/conf.py) | Python | 298 | 109 | 13 | 420 |
| [src/scenes/game/routines/main.py](/src/scenes/game/routines/main.py) | Python | 23 | 7 | 6 | 36 |
| [src/scenes/game/routines/player.py](/src/scenes/game/routines/player.py) | Python | 460 | 51 | 128 | 639 |
| [src/scenes/game/ui/index.py](/src/scenes/game/ui/index.py) | Python | 503 | 29 | 15 | 547 |

[Summary](results.md) / Details / [Diff Summary](diff.md) / [Diff Details](diff-details.md)