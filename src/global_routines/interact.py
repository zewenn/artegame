from brass.base import *

from brass import items, timeout, scene, enums, gui, pgapi
from global_routines import effect_display, menus


element_id = "InteractionShower"
text_element_id = "InteractionShower:Text"

element: Optional[GUIElement] = None
text_element: Optional[GUIElement] = None


current_priority: int = 0


@scene.init(enums.scenes.GAME)
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


def show(text: string, prio: int = 0) -> None:
    global element
    global text_element
    global current_priority

    if prio < current_priority:
        return

    if len(text_element.children) > 0:
        text_element.children[0] = text
    else:
        text_element.children = [text]

    element.style.display = "block"

    current_priority = prio


def hide(prio: int = 0) -> None:
    global current_priority
    
    if prio >= current_priority:
        element.style.display = "none"
        current_priority = 0

