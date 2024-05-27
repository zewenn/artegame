# Import the base lib
from brass.base import *

# Import generic utilities
# fmt: off
from brass import (
    vectormath,
    enums, 
    items, 
    pgapi, 
    inpt, 
    gui
)
from global_routines import (
    menu
)
# fmt: on


# Runs at the normal start after spawn() and awake()
def init() -> None:
    menu_gui = gui.get_element("GameMenu")
    if (menu_gui.is_err()):
        return
    
    menu.set_menu(menu_gui.ok())


# Runs every frame
def update() -> None:
    if inpt.active_bind(enums.keybinds.SHOW_MENU):
        menu.show_menu()
    
    if menu.SHOWING and inpt.active_bind(enums.keybinds.BACK):
        menu.hide_menu()
    
