from .base import *
from .enums.gui import *

from . import (
    collision,
    pgapi,
    enums,
    inpt
)




def unit(u: str, in_relation_to: float = None) -> float:
    # print(GUI_SIZE)
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
        if typeof(u) in ["int", "float", "Number"]:
            num_res = Ok(u)
            u = str(u) + "x"
        else:
            unreachable(
                f"Cannot parse float from incorrect unit type!"
                + "\n | Expected:\tstr"
                + f"\n | Type Given:\t{type(u).__name__}"
                + (
                    f'\nTry using "{u}x" instead of {u}!'
                    if type(u) in [int, float]
                    else ""
                )
            )

    if num_res.is_err():
        print(num_res.err().msg)
        return 0

    num: float = num_res.ok()

    match u[-1]:
        case "x":
            return num * pgapi.GUI_PIXEL_RATIO

        case "h":
            return pgapi.get_screen_size().y * (num / 100)

        case "w":
            return pgapi.get_screen_size().x * (num / 100)

        case "u":
            return num * 16 * pgapi.GUI_PIXEL_RATIO

        case "%":
            return (
                (in_relation_to if in_relation_to is not None else 0)
                * num
                // 100
            )


query_available: list[GUIElement] = []
mouse_transform: Transform = Transform(Vec2(), Vec3(), Vec2(1, 1))
hovering: Optional[GUIElement] = None
buttons: list[GUIElement] = []
selected_button_index: Optional[int] = 0


def reset() -> None:
    global query_available, buttons, selected_button_index
    del query_available[::]
    del buttons[::]

    selected_button_index = 0
    query_available = []
    buttons = []


def get_element(name: string) -> Result[GUIElement, None]:
    for el in query_available:
        if el.id == name:
            return Ok(el)
    return Err(None)


def add_parent(to: GUIElement, prnt: GUIElement) -> GUIElement:
    if not isinstance(to, str):
        to.parent = prnt

    return to


def Element(
    name: string,
    *children: GUIElement,
    style: Optional[StyleSheet] = None,
    hover: Optional[StyleSheet] = None,
    onclick: Optional[Callable[[], None]] = None,
    is_button: bool = False,
) -> GUIElement:

    if typeof(onclick) not in ["NoneType", "function", "compiled_function"]:
        unreachable(
            f'"{name}": GUIElement\'s onclick is not of the required type!'
            + "\n | Expected:\t[None, Callable[[], None]]"
            + f"\n | Type Given:\t{typeof(onclick)}"
        )

    styl = style if style else StyleSheet()
    this = GUIElement(
        id=name,
        children=list(children),
        style=styl,
        current_style=styl,
        hover=hover,
        onclick=onclick,
        transform=None,
        button=is_button,
    )

    this.children = [add_parent(x, this) for x in this.children]
    query_available.append(this)
    if is_button:
        buttons.append(this)
    return this


def Delete(el: GUIElement) -> None:
    if len(el.children) > 0:
        # print("Deleting children:",  len(el.children))
        for x in el.children:
            if isinstance(x, str):
                continue
            # print("\tChild:", x.id)
            Delete(x)

    query_available.remove(el)
    if el.button:
        buttons.remove(el)
    # el.parent.children.remove(el)

    # print("Deleted", el.id)

    del el


DOM_El: Optional[GUIElement] = Element("DOM")



def DOM(*children: GUIElement | str, style: Optional[StyleSheet] = None) -> None:
    DOM_El.children = children
    DOM_El.style = (
        style
        if style
        else StyleSheet(
            position=POSITION.ABSOLUTE, width="100w", height="100h", top="0x", left="0x"
        )
    )


def system_update() -> None:
    global hovering, selected_button_index

    displaying_buttons = [x for x in buttons if x.current_style.display == "block"]

    if selected_button_index >= len(displaying_buttons):
        selected_button_index = 0

    if inpt.get_button_down("dpad-down@ctrl#0"):
        if selected_button_index + 1 < len(displaying_buttons):
            selected_button_index += 1

    if inpt.get_button_down("dpad-up@ctrl#0"):
        if selected_button_index - 1 >= 0:
            selected_button_index -= 1

    mouse_transform.position = inpt.get_mouse_position()
    hovering = None

    next_no_pos_y: int = 0

    for el in query_available[::-1]:
        if isinstance(el, str):
            continue

        if el.current_style != el.style:
            if hovering is None or hovering.id != el.id:
                el.current_style = structured_clone(el.style)

        elstl = el.current_style
        parent = el.parent if el.parent else DOM_El
        parent_style = el.parent.current_style if el.parent else DOM_El.current_style

        if el.style.inherit_display:
            el.current_style.display = parent_style.display
            # print(el.current_style.display)

        if el.transform is None:
            el.transform = Transform(Vec2(), Vec3(), Vec2())

        x, y = 0, 0
        w = unit(elstl.width, unit(parent_style.width)) if elstl.width is not None else 0
        h = unit(elstl.height, unit(parent_style.height)) if elstl.height is not None else 0

        if elstl.position is None:
            y = next_no_pos_y
            next_no_pos_y += h

        elif elstl.position == POSITION.ABSOLUTE:
            x = (
                unit(elstl.left, unit(parent_style.left))
                if elstl.left is not None
                else (
                    unit(elstl.right, unit(parent_style.right))
                    if elstl.right is not None
                    else 0
                )
            )
            y = (
                unit(elstl.top, unit(parent_style.top))
                if elstl.top is not None
                else (
                    unit(elstl.bottom, unit(parent_style.bottom))
                    if elstl.bottom is not None
                    else 0
                )
            )

        elif elstl.position == POSITION.RELATIVE:
            x = (
                (
                    unit(elstl.left, unit(parent_style.left))
                    + parent.transform.position.x
                )
                if elstl.left is not None and parent_style.left is not None
                else (
                    (
                        parent.transform.position.x
                        - unit(elstl.right, unit(parent_style.right))
                    )
                    if elstl.right is not None and parent_style.right is not None
                    else 0
                )
            )
            y = (
                (unit(elstl.top, unit(parent_style.top)) + parent.transform.position.y)
                if elstl.top is not None and parent_style.top is not None
                else (
                    (
                        parent.transform.position.y
                        - unit(elstl.bottom, unit(parent_style.bottom))
                    )
                    if elstl.bottom is not None and parent_style.bottom is not None
                    else 0
                )
            )

        el.transform.position.x = x
        el.transform.position.y = y
        el.transform.scale.x = w
        el.transform.scale.y = h

        if (
            collision.collides(mouse_transform, el.transform)
            and hovering is None
            and el.button
            and el.id != "DOM"
            and elstl.display != "none"
        ):
            hovering = el
            continue

    if hovering is None:
        if len(displaying_buttons) == 0 or selected_button_index >= len(
            displaying_buttons
        ):
            selected_button_index = 0
            return
        
        assert isinstance(selected_button_index, int)

        btn = displaying_buttons[selected_button_index]

        if (
            not btn.hover
            or not pgapi.SETTINGS.menu_mode
            or pgapi.SETTINGS.input_mode == enums.input_modes.MOUSE_AND_KEYBOARD
        ):
            return

        merge_res = merge(btn.style, btn.hover)
        if merge_res.is_ok():
            btn.current_style = merge_res.ok()

        if btn.onclick is not None and inpt.active_bind(enums.keybinds.ACCEPT_MENU):
            btn.onclick()

        return

    if hovering.hover:
        merge_res = merge(hovering.style, hovering.hover)
        if merge_res.is_ok():
            hovering.current_style = merge_res.ok()

    if inpt.get_button_down("left@mouse"):
        hovering.onclick()
