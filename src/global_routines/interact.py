from brass.base import *

from brass import items, timeout, scene, enums, gui, pgapi
from global_routines import effect_display, menus


element_id = "InteractionShower"
text_element_id = "InteractionShower:Text"

element: Optional[GUIElement] = None
text_element: Optional[GUIElement] = None


@scene.awake(enums.scenes.GAME)
def awake() -> None:
    global element
    global text_element

    element = gui.get_element(element_id)
    text_element = gui.get_element(text_element_id)

    if element.is_err():
        unreachable("Interaction shower does not exist!")

    element = element.ok()

    if text_element.is_err():
        unreachable("Interaction shower text element does not exist!")

    text_element = text_element.ok()


@scene.update(enums.scenes.GAME)
def update() -> None:
    element.children[0].children[0].children[0] = (
        "B" if pgapi.SETTINGS.input_mode == "Controller" else "F"
    )


def show(text: string) -> None:
    global element
    global text_element

    if len(text_element.children) > 0:
        text_element.children[0] = text
    else:
        text_element.children = [text]

    element.style.display = "block"


def hide() -> None:
    element.style.display = "none"
