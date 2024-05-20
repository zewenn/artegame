from classes import *
from pgapi import *
from enums.gui import *


def unit(u: str) -> float:
    """
    ## Units
    x   - pixel\n
    h   - screen height\n
    w   - screen width\n
    u   - 16px \n

    ## Example
    ```
    el(
        style=style(
            x="12u",
            y="14w"
        )
    )
    ```
    """

    if u is None:
        return None

    num_res = attempt(float, (u[:-1],))

    if num_res.is_err():
        print(num_res.err())
        return 0

    num: float = num_res.ok()

    match u[-1]:
        case "x":
            return num

        case "h":
            return get_screen_size().y * (num / 100)

        case "w":
            return get_screen_size().x * (num / 100)

        case "u":
            return num * 16


query_available: list[GUIElement] = []


def get_element(id: str) -> "Element":
    for el in query_available:
        if el.id == id:
            return el

def Element(
        id: str,
        *children: GUIElement,
        style: Optional[StyleSheet] = None,
    ) -> GUIElement:
        this = GUIElement(
            id, 
            children,
            style if style else StyleSheet()
        )
        query_available.append(this)
        return this


DOM_El: Optional[GUIElement] = Element("DOM")


def Text(t: str) -> str:
    return t


def DOM(*children: GUIElement | str, style: Optional[StyleSheet] = None) -> None:
    global DOM_El
    DOM_El.children = children
    DOM_El.style = style if style else StyleSheet()
