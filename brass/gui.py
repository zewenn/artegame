from enums.gui import *
from base import *
import collision
import pgapi
import copy
import inpt


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

    num_res: float

    try:
        num_res = attempt(float, (u[:-1],))
    except:
        unreachable(
            f"Cannot parse float from incorrect unit type!"
            + "\n | Expected:\tstr"
            + f"\n | Type Given:\t{type(u).__name__}"
            + (f"\nTry using \"{u}x\" instead of {u}!" if type(u) in [int, float] else "")
        )

    if num_res.is_err():
        print(num_res.err().msg)
        return 0

    num: float = num_res.ok()

    match u[-1]:
        case "x":
            return num

        case "h":
            return pgapi.get_screen_size().y * (num / 100)

        case "w":
            return pgapi.get_screen_size().x * (num / 100)

        case "u":
            return num * 16


query_available: list[GUIElement] = []
mouse_transform: Transform = Transform(Vector2(), Vector3(), Vector2(1, 1))
hovering: Optional[GUIElement] = None


def get_element(id: str) -> Result[GUIElement, None]:
    for el in query_available:
        if el.id == id:
            return Ok(el)
    return Err(None)


def add_parent(to: GUIElement, prnt: GUIElement) -> GUIElement:
    if isinstance(to, str):
        return to

    to.parent = prnt
    return copy.deepcopy(to)


def Element(
    id: str,
    *children: GUIElement,
    style: Optional[StyleSheet] = None,
    onclick: Optional[Callable[[], None]] = None,
) -> GUIElement:
    this = GUIElement(
        id=id,
        children=list(children),
        style=style if style else StyleSheet(),
        onclick=onclick,
        transform=Transform(Vector2(), Vector3(), Vector2()),
    )

    this.children = [add_parent(x, this) for x in this.children]
    query_available.append(this)
    return this


DOM_El: Optional[GUIElement] = Element("DOM")


def Text(t: str) -> str:
    return t


def DOM(*children: GUIElement | str, style: Optional[StyleSheet] = None) -> None:
    global DOM_El
    DOM_El.children = children
    DOM_El.style = style if style else StyleSheet()


def system_update() -> None:
    global hovering

    mouse_transform.position = inpt.get_mouse_position()
    hovering = None

    for el in query_available[::-1]:
        if isinstance(el, str):
            continue

        elstl = el.style

        x, y = 0, 0
        w = unit(elstl.width) if elstl.width != None else 0
        h = unit(elstl.height) if elstl.height != None else 0

        match elstl.position:
            case POSITION.ABSOLUTE:
                x = (
                    unit(elstl.left)
                    if unit(elstl.left) != None
                    else unit(elstl.right) if unit(elstl.right) != None else 0
                )
                y = (
                    unit(elstl.top)
                    if unit(elstl.top) != None
                    else unit(elstl.bottom) if unit(elstl.bottom) != None else 0
                )

            case POSITION.RELATIVE:
                x = (
                    unit(elstl.left) + unit(el.parent.style.left)
                    if unit(elstl.left) != None and unit(el.parent.style.left) != None
                    else (
                        unit(elstl.right) + unit(el.parent.style.right)
                        if unit(elstl.right) != None
                        and unit(el.parent.style.right) != None
                        else 0
                    )
                )
                y = (
                    unit(elstl.top) + unit(el.parent.style.top)
                    if unit(elstl.top) != None and unit(el.parent.style.top) != None
                    else (
                        unit(elstl.bottom) + unit(el.parent.style.bottom)
                        if unit(elstl.bottom) != None
                        and unit(el.parent.style.bottom) != None
                        else 0
                    )
                )

        el.transform.position.x = x
        el.transform.position.y = y
        el.transform.scale.x = w
        el.transform.scale.y = h

        if collision.collides(mouse_transform, el.transform):
            hovering = el
            break

    if inpt.get_button_down("left@mouse") and hovering != None:
        hovering.onclick()
