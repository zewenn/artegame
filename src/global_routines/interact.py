from brass.base import *

from brass import items, timeout, scene, enums, gui, pgapi
from . import effect_display, menus


element_id = "InteractionShower"
text_element_id = "InteractionShower:Text"

element: Optional[GUIElement] = None
text_element: Optional[GUIElement] = None


current_priority: int = 0


@scene.init(enums.scenes.GAME)
def awake() -> None:
    global element
    global text_element

    query_element: Result[GUIElement, None] = gui.get_element(element_id)
    query_text_element: Result[GUIElement, None] = gui.get_element(text_element_id)

    if query_element.is_err():
        unreachable("Interaction shower does not exist!")

    element = query_element.ok()

    if query_text_element.is_err():
        unreachable("Interaction shower text element does not exist!")

    text_element = query_text_element.ok()


@scene.update(enums.scenes.GAME)
def update() -> None:
    ensure(element).children[0].children[0].children[0] = (  # type: ignore
        "B" if ensure(pgapi.SETTINGS).input_mode == "Controller" else "F"
    )


def show(text: string, prio: int = 0) -> None:
    global current_priority

    if prio < current_priority or text_element is None:
        return

    if len(text_element.children) > 0:
        text_element.children[0] = text  # type: ignore
    else:
        text_element.children = [text]  # type: ignore

    ensure(element).style.display = "block"

    current_priority = prio


def hide(prio: int = 0) -> None:
    global current_priority

    if prio >= current_priority:
        ensure(element).style.display = "none"
        current_priority = 0
