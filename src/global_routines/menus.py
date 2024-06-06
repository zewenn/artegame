from brass.base import *
from brass.gui import *

from brass import pgapi, scene, saves, enums

MENU: Optional[GUIElement] = None
SHOWING: bool = False


MENUS: dict[string, GUIElement] = {}


@deprecated
def set_menu(gui_el: GUIElement) -> None:
    global MENU
    MENU = gui_el


def new(gui_element: GUIElement) -> GUIElement:
    global MENUS
    MENUS[gui_element.id] = gui_element
    return gui_element


def toggle(
    id: string,
    to: Optional[Literal["block", "none"]] = None,
    scn: string = enums.scenes.GAME,
) -> None:
    element = MENUS.get(id)

    if not element:
        print(f'Menu by the id "{id}" does not exist!')
        return

    # Mode :: "block" -> "none"
    if element.style.display == "block" and to != "block":
        element.style.display = "none"
        pgapi.SETTINGS.menu_mode = False
        scene.resume(scn)
        return

    if to == "none":
        return

    # Mode :: "none" -> "block"
    element.style.display = "block"
    pgapi.as_menu()
    scene.pause()


def is_showing(id: string) -> bool:
    element = MENUS.get(id)

    if not element:
        print(f'Menu by the id "{id}" does not exist!')
        return False

    return element.style.display == "block"


@deprecated
def show_menu() -> None:
    global SHOWING, MENU

    if not MENU:
        return

    MENU.style.display = "block"
    SHOWING = True
    pgapi.as_menu()
    scene.pause()


@deprecated
def hide_menu() -> None:
    global SHOWING, MENU

    if not MENU:
        return

    MENU.style.display = "none"
    SHOWING = False
    if pgapi.SETTINGS:
        pgapi.SETTINGS.menu_mode = False
    scene.resume(enums.scenes.GAME)
