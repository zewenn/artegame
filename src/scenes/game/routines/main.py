# Import the base lib
from brass.base import *

# Import generic utilities
# fmt: off
from brass import (
    vectormath,
    items, 
    pgapi, 
    audio,
    assets,
    enums,
    inpt, 
    gui
)
from src.global_routines import (
    menus,
    enemies,
    sounds,
    round_manager
)
from src.enums import keybinds
# fmt: on



# def issnit() -> None:
#     round_manager.ROUND_STATE = "Wait"


# Runs every frame
def update() -> None:
    if inpt.active_bind(enums.base_keybinds.SHOW_PAUSE_MENU) or (
        menus.is_showing("GameMenu") and inpt.active_bind(enums.base_keybinds.BACK)
    ):
        menus.toggle("GameMenu")

    print("FPS:", round(1 / pgapi.TIME.deltatime), end="\r")