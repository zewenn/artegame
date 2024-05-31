# Import the base lib
from brass.base import *

# Import generic utilities
# fmt: off
from brass import (
    vectormath,
    enums, 
    items, 
    pgapi, 
    audio,
    assets,
    inpt, 
    gui
)
from global_routines import (
    menu,
    enemies,
    sounds
)
# fmt: on


# Runs at the normal start after spawn() and awake()
def init() -> None:
    menu_gui = gui.get_element("GameMenu")
    if menu_gui.is_err():
        return

    menu.set_menu(menu_gui.ok())



# Runs every frame
def update() -> None:
    if inpt.active_bind(enums.keybinds.SHOW_MENU):
        menu.show_menu()

    if menu.SHOWING and inpt.active_bind(enums.keybinds.BACK):
        menu.hide_menu()

    print("FPS:", round(1 / pgapi.TIME.deltatime), end="\r")

    if len(enemies.ENEMIES) == 0:
        enemies.new(
            Item(
                id="enemy1",
                tags=["enemy", "item"],
                transform=Transform(Vec2(-512, -32), Vec3(0, 0, 0), Vec2(64, 64)),
                # fill_color=[20, 20, 20],
                sprite="test.png",
                can_move=True,
                can_collide=True,
                can_repulse=True,
                lightness=1,
                base_movement_speed=300,
                dash_count=2,
                dash_movement_multiplier=10,
                dash_charge_refill_time=0.25,
                max_hitpoints=100,
                effective_range=600,
                hitpoints=100,
                max_mana=100,
                base_attack_speed=4,
                team="Enemy"
            )
        )
        enemies.new(
            Item(
                id="enemy2",
                tags=["enemy", "item"],
                transform=Transform(Vec2(512, 128), Vec3(0, 0, 0), Vec2(64, 64)),
                # fill_color=[20, 20, 20],
                sprite="test.png",
                can_move=True,
                can_collide=True,
                can_repulse=True,
                lightness=1,
                base_movement_speed=300,
                dash_count=2,
                dash_movement_multiplier=10,
                dash_charge_refill_time=0.25,
                max_hitpoints=100,
                effective_range=800,
                hitpoints=100,
                max_mana=100,
                base_attack_speed=4,
                team="Enemy"
            )
        )
