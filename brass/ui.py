from classes import *
from pgapi import *
from enums import *

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




@dataclass
class StyleSheet:
    position: str = POSITION.ABSOLUTE

    bottom: str = "0x"
    right: str = "0x"
    left: str = "0x"
    top: str = "0x"

    width: str = "0x"
    height: str = "0x"

    bg_color: Tuple[int, int, int, float] = (0, 0, 0, 0)
    bg_image: str = None
    bg_size: Tuple[float, float] = (0, 0)

    color: Tuple[int, int, int, float] = (0, 0, 0, 1)
    font: str = "press_play.ttf"
    font_size: str = FONT_SIZE.EXTRA_SMALL


class Element:
    def __init__(
        self, *children: type["Element"] | str, style: Optional[StyleSheet] = None
    ) -> None:
        self.children = children
        self.style = style if style else StyleSheet()


DOM_El: Optional[Element] = Element()


def DOM(*children: Element | str, style: Optional[StyleSheet] = None) -> None:
    global DOM_El
    DOM_El.children = children
    DOM_El.style = style if style else StyleSheet()
