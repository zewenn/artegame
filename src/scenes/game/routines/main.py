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
    menus,
    enemies,
    sounds,
    round_manager
)
# fmt: on



# def issnit() -> None:
#     round_manager.ROUND_STATE = "Wait"


# Runs every frame
def update() -> None:
    if inpt.active_bind(enums.keybinds.SHOW_PAUSE_MENU) or (
        menus.is_showing("GameMenu") and inpt.active_bind(enums.keybinds.BACK)
    ):
        menus.toggle("GameMenu")

    print("FPS:", round(1 / pgapi.TIME.deltatime), end="\r")