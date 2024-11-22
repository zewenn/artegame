# Diff Details

Date : 2024-11-22 08:18:40

Directory /Users/zoltantakacs/_code/py/artegame

Total : 122 files,  38 codes, 0 comments, 0 blanks, all 38 lines

[Summary](results.md) / [Details](details.md) / [Diff Summary](diff.md) / Diff Details

## Files
| filename | language | code | comment | blank | total |
| :--- | :--- | ---: | ---: | ---: | ---: |
| [.pylintrc](/.pylintrc) | Ini | 29 | 0 | 5 | 34 |
| [README.md](/README.md) | Markdown | 53 | 0 | 10 | 63 |
| [architect/__config__.py](/architect/__config__.py) | Python | 34 | 6 | 12 | 52 |
| [architect/__main__.py](/architect/__main__.py) | Python | 23 | 0 | 9 | 32 |
| [architect/b64encoder.py](/architect/b64encoder.py) | Python | 36 | 3 | 18 | 57 |
| [architect/cli.py](/architect/cli.py) | Python | 178 | 19 | 63 | 260 |
| [architect/deps.py](/architect/deps.py) | Python | 158 | 11 | 62 | 231 |
| [architect/import_generator.py](/architect/import_generator.py) | Python | 286 | 19 | 79 | 384 |
| [brass/__init__.py](/brass/__init__.py) | Python | 74 | 22 | 19 | 115 |
| [brass/animator/__init__.py](/brass/animator/__init__.py) | Python | 138 | 48 | 65 | 251 |
| [brass/animator/interpolation.py](/brass/animator/interpolation.py) | Python | 51 | 2 | 16 | 69 |
| [brass/animator/play_objects.py](/brass/animator/play_objects.py) | Python | 25 | 0 | 11 | 36 |
| [brass/animator/store.py](/brass/animator/store.py) | Python | 9 | 0 | 6 | 15 |
| [brass/assets.py](/brass/assets.py) | Python | 50 | 18 | 28 | 96 |
| [brass/audio.py](/brass/audio.py) | Python | 41 | 1 | 28 | 70 |
| [brass/base.py](/brass/base.py) | Python | 115 | 1 | 55 | 171 |
| [brass/collision.py](/brass/collision.py) | Python | 127 | 3 | 34 | 164 |
| [brass/display.py](/brass/display.py) | Python | 243 | 35 | 69 | 347 |
| [brass/enums/__init__.py](/brass/enums/__init__.py) | Python | 7 | 1 | 1 | 9 |
| [brass/enums/animations.py](/brass/enums/animations.py) | Python | 9 | 0 | 5 | 14 |
| [brass/enums/base_keybinds.py](/brass/enums/base_keybinds.py) | Python | 3 | 0 | 1 | 4 |
| [brass/enums/gui.py](/brass/enums/gui.py) | Python | 30 | 0 | 8 | 38 |
| [brass/enums/input_modes.py](/brass/enums/input_modes.py) | Python | 2 | 0 | 2 | 4 |
| [brass/enums/scenes.py](/brass/enums/scenes.py) | Python | 3 | 1 | 2 | 6 |
| [brass/events.py](/brass/events.py) | Python | 30 | 0 | 20 | 50 |
| [brass/gui.py](/brass/gui.py) | Python | 252 | 8 | 70 | 330 |
| [brass/inpt.py](/brass/inpt.py) | Python | 296 | 21 | 106 | 423 |
| [brass/items.py](/brass/items.py) | Python | 86 | 10 | 46 | 142 |
| [brass/pgapi.py](/brass/pgapi.py) | Python | 77 | 0 | 46 | 123 |
| [brass/saves.py](/brass/saves.py) | Python | 68 | 17 | 35 | 120 |
| [brass/scene.py](/brass/scene.py) | Python | 47 | 6 | 30 | 83 |
| [brass/structures.py](/brass/structures.py) | Python | 331 | 30 | 112 | 473 |
| [brass/timeout.py](/brass/timeout.py) | Python | 16 | 2 | 8 | 26 |
| [brass/vectormath.py](/brass/vectormath.py) | Python | 214 | 4 | 72 | 290 |
| [pyproject.toml](/pyproject.toml) | TOML | 9 | 0 | 1 | 10 |
| [src/__init__.py](/src/__init__.py) | Python | 4 | 0 | 1 | 5 |
| [src/enums/__init__.py](/src/enums/__init__.py) | Python | 4 | 0 | 1 | 5 |
| [src/enums/keybinds.py](/src/enums/keybinds.py) | Python | 9 | 0 | 6 | 15 |
| [src/enums/spell_enum.py](/src/enums/spell_enum.py) | Python | 37 | 0 | 4 | 41 |
| [src/global_routines/__init__.py](/src/global_routines/__init__.py) | Python | 13 | 0 | 1 | 14 |
| [src/global_routines/boons.py](/src/global_routines/boons.py) | Python | 797 | 106 | 202 | 1,105 |
| [src/global_routines/crowd_control.py](/src/global_routines/crowd_control.py) | Python | 70 | 3 | 20 | 93 |
| [src/global_routines/dash.py](/src/global_routines/dash.py) | Python | 31 | 2 | 13 | 46 |
| [src/global_routines/effect_display.py](/src/global_routines/effect_display.py) | Python | 30 | 3 | 13 | 46 |
| [src/global_routines/enemies.py](/src/global_routines/enemies.py) | Python | 214 | 11 | 46 | 271 |
| [src/global_routines/interact.py](/src/global_routines/interact.py) | Python | 40 | 0 | 26 | 66 |
| [src/global_routines/menus.py](/src/global_routines/menus.py) | Python | 57 | 2 | 27 | 86 |
| [src/global_routines/projectiles.py](/src/global_routines/projectiles.py) | Python | 160 | 10 | 26 | 196 |
| [src/global_routines/round_manager.py](/src/global_routines/round_manager.py) | Python | 133 | 2 | 33 | 168 |
| [src/global_routines/sounds.py](/src/global_routines/sounds.py) | Python | 36 | 0 | 19 | 55 |
| [src/global_routines/spells.py](/src/global_routines/spells.py) | Python | 121 | 1 | 47 | 169 |
| [src/scenes/default/routines/conf.py](/src/scenes/default/routines/conf.py) | Python | 9 | 5 | 4 | 18 |
| [src/scenes/default/routines/main.py](/src/scenes/default/routines/main.py) | Python | 13 | 6 | 6 | 25 |
| [src/scenes/default/ui/index.py](/src/scenes/default/ui/index.py) | Python | 84 | 12 | 14 | 110 |
| [src/scenes/defeat/routines/conf.py](/src/scenes/defeat/routines/conf.py) | Python | 9 | 5 | 4 | 18 |
| [src/scenes/defeat/routines/main.py](/src/scenes/defeat/routines/main.py) | Python | 13 | 6 | 6 | 25 |
| [src/scenes/defeat/ui/index.py](/src/scenes/defeat/ui/index.py) | Python | 106 | 10 | 14 | 130 |
| [src/scenes/game/routines/conf.py](/src/scenes/game/routines/conf.py) | Python | 298 | 109 | 13 | 420 |
| [src/scenes/game/routines/main.py](/src/scenes/game/routines/main.py) | Python | 24 | 7 | 7 | 38 |
| [src/scenes/game/routines/player.py](/src/scenes/game/routines/player.py) | Python | 472 | 51 | 129 | 652 |
| [src/scenes/game/ui/index.py](/src/scenes/game/ui/index.py) | Python | 503 | 29 | 15 | 547 |
| [d:/_code/python/24 - Summer/artegame/.pylintrc](/d:/_code/python/24%20-%20Summer/artegame/.pylintrc) | Ini | -29 | 0 | -5 | -34 |
| [d:/_code/python/24 - Summer/artegame/README.md](/d:/_code/python/24%20-%20Summer/artegame/README.md) | Markdown | -23 | 0 | -14 | -37 |
| [d:/_code/python/24 - Summer/artegame/architect.bat](/d:/_code/python/24%20-%20Summer/artegame/architect.bat) | Batch | -1 | 0 | 0 | -1 |
| [d:/_code/python/24 - Summer/artegame/architect/__config__.py](/d:/_code/python/24%20-%20Summer/artegame/architect/__config__.py) | Python | -34 | -6 | -12 | -52 |
| [d:/_code/python/24 - Summer/artegame/architect/__main__.py](/d:/_code/python/24%20-%20Summer/artegame/architect/__main__.py) | Python | -19 | -2 | -8 | -29 |
| [d:/_code/python/24 - Summer/artegame/architect/b64encoder.py](/d:/_code/python/24%20-%20Summer/artegame/architect/b64encoder.py) | Python | -34 | -3 | -17 | -54 |
| [d:/_code/python/24 - Summer/artegame/architect/cli.py](/d:/_code/python/24%20-%20Summer/artegame/architect/cli.py) | Python | -176 | -19 | -63 | -258 |
| [d:/_code/python/24 - Summer/artegame/architect/deps.py](/d:/_code/python/24%20-%20Summer/artegame/architect/deps.py) | Python | -154 | -11 | -59 | -224 |
| [d:/_code/python/24 - Summer/artegame/architect/import_generator.py](/d:/_code/python/24%20-%20Summer/artegame/architect/import_generator.py) | Python | -285 | -25 | -82 | -392 |
| [d:/_code/python/24 - Summer/artegame/brass/__init__.py](/d:/_code/python/24%20-%20Summer/artegame/brass/__init__.py) | Python | -72 | -21 | -18 | -111 |
| [d:/_code/python/24 - Summer/artegame/brass/animator/__init__.py](/d:/_code/python/24%20-%20Summer/artegame/brass/animator/__init__.py) | Python | -138 | -48 | -65 | -251 |
| [d:/_code/python/24 - Summer/artegame/brass/animator/interpolation.py](/d:/_code/python/24%20-%20Summer/artegame/brass/animator/interpolation.py) | Python | -51 | -2 | -16 | -69 |
| [d:/_code/python/24 - Summer/artegame/brass/animator/play_objects.py](/d:/_code/python/24%20-%20Summer/artegame/brass/animator/play_objects.py) | Python | -25 | 0 | -11 | -36 |
| [d:/_code/python/24 - Summer/artegame/brass/animator/store.py](/d:/_code/python/24%20-%20Summer/artegame/brass/animator/store.py) | Python | -9 | 0 | -6 | -15 |
| [d:/_code/python/24 - Summer/artegame/brass/assets.py](/d:/_code/python/24%20-%20Summer/artegame/brass/assets.py) | Python | -50 | -18 | -28 | -96 |
| [d:/_code/python/24 - Summer/artegame/brass/audio.py](/d:/_code/python/24%20-%20Summer/artegame/brass/audio.py) | Python | -41 | -1 | -28 | -70 |
| [d:/_code/python/24 - Summer/artegame/brass/base.py](/d:/_code/python/24%20-%20Summer/artegame/brass/base.py) | Python | -115 | -1 | -55 | -171 |
| [d:/_code/python/24 - Summer/artegame/brass/collision.py](/d:/_code/python/24%20-%20Summer/artegame/brass/collision.py) | Python | -127 | -3 | -34 | -164 |
| [d:/_code/python/24 - Summer/artegame/brass/display.py](/d:/_code/python/24%20-%20Summer/artegame/brass/display.py) | Python | -241 | -35 | -68 | -344 |
| [d:/_code/python/24 - Summer/artegame/brass/enums/__init__.py](/d:/_code/python/24%20-%20Summer/artegame/brass/enums/__init__.py) | Python | -7 | -1 | -1 | -9 |
| [d:/_code/python/24 - Summer/artegame/brass/enums/animations.py](/d:/_code/python/24%20-%20Summer/artegame/brass/enums/animations.py) | Python | -9 | 0 | -5 | -14 |
| [d:/_code/python/24 - Summer/artegame/brass/enums/base_keybinds.py](/d:/_code/python/24%20-%20Summer/artegame/brass/enums/base_keybinds.py) | Python | -3 | 0 | -1 | -4 |
| [d:/_code/python/24 - Summer/artegame/brass/enums/gui.py](/d:/_code/python/24%20-%20Summer/artegame/brass/enums/gui.py) | Python | -30 | 0 | -8 | -38 |
| [d:/_code/python/24 - Summer/artegame/brass/enums/input_modes.py](/d:/_code/python/24%20-%20Summer/artegame/brass/enums/input_modes.py) | Python | -2 | 0 | -2 | -4 |
| [d:/_code/python/24 - Summer/artegame/brass/enums/scenes.py](/d:/_code/python/24%20-%20Summer/artegame/brass/enums/scenes.py) | Python | -3 | -1 | -2 | -6 |
| [d:/_code/python/24 - Summer/artegame/brass/events.py](/d:/_code/python/24%20-%20Summer/artegame/brass/events.py) | Python | -30 | 0 | -20 | -50 |
| [d:/_code/python/24 - Summer/artegame/brass/gui.py](/d:/_code/python/24%20-%20Summer/artegame/brass/gui.py) | Python | -252 | -8 | -70 | -330 |
| [d:/_code/python/24 - Summer/artegame/brass/inpt.py](/d:/_code/python/24%20-%20Summer/artegame/brass/inpt.py) | Python | -296 | -21 | -106 | -423 |
| [d:/_code/python/24 - Summer/artegame/brass/items.py](/d:/_code/python/24%20-%20Summer/artegame/brass/items.py) | Python | -86 | -10 | -46 | -142 |
| [d:/_code/python/24 - Summer/artegame/brass/pgapi.py](/d:/_code/python/24%20-%20Summer/artegame/brass/pgapi.py) | Python | -77 | 0 | -46 | -123 |
| [d:/_code/python/24 - Summer/artegame/brass/saves.py](/d:/_code/python/24%20-%20Summer/artegame/brass/saves.py) | Python | -83 | -13 | -38 | -134 |
| [d:/_code/python/24 - Summer/artegame/brass/scene.py](/d:/_code/python/24%20-%20Summer/artegame/brass/scene.py) | Python | -47 | -6 | -30 | -83 |
| [d:/_code/python/24 - Summer/artegame/brass/structures.py](/d:/_code/python/24%20-%20Summer/artegame/brass/structures.py) | Python | -330 | -30 | -112 | -472 |
| [d:/_code/python/24 - Summer/artegame/brass/timeout.py](/d:/_code/python/24%20-%20Summer/artegame/brass/timeout.py) | Python | -16 | -2 | -8 | -26 |
| [d:/_code/python/24 - Summer/artegame/brass/vectormath.py](/d:/_code/python/24%20-%20Summer/artegame/brass/vectormath.py) | Python | -214 | -4 | -72 | -290 |
| [d:/_code/python/24 - Summer/artegame/src/__init__.py](/d:/_code/python/24%20-%20Summer/artegame/src/__init__.py) | Python | -4 | 0 | -1 | -5 |
| [d:/_code/python/24 - Summer/artegame/src/enums/__init__.py](/d:/_code/python/24%20-%20Summer/artegame/src/enums/__init__.py) | Python | -4 | 0 | -1 | -5 |
| [d:/_code/python/24 - Summer/artegame/src/enums/keybinds.py](/d:/_code/python/24%20-%20Summer/artegame/src/enums/keybinds.py) | Python | -9 | 0 | -6 | -15 |
| [d:/_code/python/24 - Summer/artegame/src/enums/spell_enum.py](/d:/_code/python/24%20-%20Summer/artegame/src/enums/spell_enum.py) | Python | -37 | 0 | -4 | -41 |
| [d:/_code/python/24 - Summer/artegame/src/global_routines/__init__.py](/d:/_code/python/24%20-%20Summer/artegame/src/global_routines/__init__.py) | Python | -13 | 0 | -1 | -14 |
| [d:/_code/python/24 - Summer/artegame/src/global_routines/boons.py](/d:/_code/python/24%20-%20Summer/artegame/src/global_routines/boons.py) | Python | -797 | -106 | -202 | -1,105 |
| [d:/_code/python/24 - Summer/artegame/src/global_routines/crowd_control.py](/d:/_code/python/24%20-%20Summer/artegame/src/global_routines/crowd_control.py) | Python | -70 | -3 | -20 | -93 |
| [d:/_code/python/24 - Summer/artegame/src/global_routines/dash.py](/d:/_code/python/24%20-%20Summer/artegame/src/global_routines/dash.py) | Python | -31 | -2 | -13 | -46 |
| [d:/_code/python/24 - Summer/artegame/src/global_routines/effect_display.py](/d:/_code/python/24%20-%20Summer/artegame/src/global_routines/effect_display.py) | Python | -30 | -3 | -13 | -46 |
| [d:/_code/python/24 - Summer/artegame/src/global_routines/enemies.py](/d:/_code/python/24%20-%20Summer/artegame/src/global_routines/enemies.py) | Python | -214 | -11 | -46 | -271 |
| [d:/_code/python/24 - Summer/artegame/src/global_routines/interact.py](/d:/_code/python/24%20-%20Summer/artegame/src/global_routines/interact.py) | Python | -40 | 0 | -26 | -66 |
| [d:/_code/python/24 - Summer/artegame/src/global_routines/menus.py](/d:/_code/python/24%20-%20Summer/artegame/src/global_routines/menus.py) | Python | -57 | -2 | -27 | -86 |
| [d:/_code/python/24 - Summer/artegame/src/global_routines/projectiles.py](/d:/_code/python/24%20-%20Summer/artegame/src/global_routines/projectiles.py) | Python | -160 | -10 | -26 | -196 |
| [d:/_code/python/24 - Summer/artegame/src/global_routines/round_manager.py](/d:/_code/python/24%20-%20Summer/artegame/src/global_routines/round_manager.py) | Python | -131 | -2 | -33 | -166 |
| [d:/_code/python/24 - Summer/artegame/src/global_routines/sounds.py](/d:/_code/python/24%20-%20Summer/artegame/src/global_routines/sounds.py) | Python | -36 | 0 | -19 | -55 |
| [d:/_code/python/24 - Summer/artegame/src/global_routines/spells.py](/d:/_code/python/24%20-%20Summer/artegame/src/global_routines/spells.py) | Python | -121 | -1 | -47 | -169 |
| [d:/_code/python/24 - Summer/artegame/src/scenes/default/routines/conf.py](/d:/_code/python/24%20-%20Summer/artegame/src/scenes/default/routines/conf.py) | Python | -9 | -5 | -4 | -18 |
| [d:/_code/python/24 - Summer/artegame/src/scenes/default/routines/main.py](/d:/_code/python/24%20-%20Summer/artegame/src/scenes/default/routines/main.py) | Python | -13 | -6 | -6 | -25 |
| [d:/_code/python/24 - Summer/artegame/src/scenes/default/ui/index.py](/d:/_code/python/24%20-%20Summer/artegame/src/scenes/default/ui/index.py) | Python | -91 | -11 | -14 | -116 |
| [d:/_code/python/24 - Summer/artegame/src/scenes/defeat/routines/conf.py](/d:/_code/python/24%20-%20Summer/artegame/src/scenes/defeat/routines/conf.py) | Python | -9 | -5 | -4 | -18 |
| [d:/_code/python/24 - Summer/artegame/src/scenes/defeat/routines/main.py](/d:/_code/python/24%20-%20Summer/artegame/src/scenes/defeat/routines/main.py) | Python | -13 | -6 | -6 | -25 |
| [d:/_code/python/24 - Summer/artegame/src/scenes/defeat/ui/index.py](/d:/_code/python/24%20-%20Summer/artegame/src/scenes/defeat/ui/index.py) | Python | -105 | -9 | -13 | -127 |
| [d:/_code/python/24 - Summer/artegame/src/scenes/game/routines/conf.py](/d:/_code/python/24%20-%20Summer/artegame/src/scenes/game/routines/conf.py) | Python | -298 | -109 | -13 | -420 |
| [d:/_code/python/24 - Summer/artegame/src/scenes/game/routines/main.py](/d:/_code/python/24%20-%20Summer/artegame/src/scenes/game/routines/main.py) | Python | -24 | -7 | -7 | -38 |
| [d:/_code/python/24 - Summer/artegame/src/scenes/game/routines/player.py](/d:/_code/python/24%20-%20Summer/artegame/src/scenes/game/routines/player.py) | Python | -472 | -51 | -129 | -652 |
| [d:/_code/python/24 - Summer/artegame/src/scenes/game/ui/index.py](/d:/_code/python/24%20-%20Summer/artegame/src/scenes/game/ui/index.py) | Python | -502 | -28 | -14 | -544 |

[Summary](results.md) / [Details](details.md) / [Diff Summary](diff.md) / Diff Details