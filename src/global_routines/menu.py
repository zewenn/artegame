from brass.base import *
from brass.gui import *

from brass import pgapi, scene, saves

MENU: Optional[GUIElement] = None
SHOWING: bool = False


def set_menu(gui_el: GUIElement) -> None:
    global MENU
    MENU = gui_el


def show_menu() -> None:
    global SHOWING, MENU

    if not MENU:
        return

    MENU.style.display = "block"
    SHOWING = True
    pgapi.as_menu()


def hide_menu() -> None:
    global SHOWING, MENU

    if not MENU:
        return

    MENU.style.display = "none"
    SHOWING = False
    if pgapi.SETTINGS:
        pgapi.SETTINGS.menu_mode = False
