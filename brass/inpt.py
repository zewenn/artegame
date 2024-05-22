from base import *

import pygame._sdl2.controller as pycontroller
import pygame
import pgapi


controller_codes: dict[str, int] = {
    # normals
    "x": pygame.CONTROLLER_BUTTON_X,
    "y": pygame.CONTROLLER_BUTTON_Y,
    "a": pygame.CONTROLLER_BUTTON_A,
    "b": pygame.CONTROLLER_BUTTON_B,
    # dpad
    "dpad-down": pygame.CONTROLLER_BUTTON_DPAD_DOWN,
    "dpad-up": pygame.CONTROLLER_BUTTON_DPAD_UP,
    "dpad-left": pygame.CONTROLLER_BUTTON_DPAD_LEFT,
    "dpad-right": pygame.CONTROLLER_BUTTON_DPAD_RIGHT,
    # shoulders
    "shoulder-left": pygame.CONTROLLER_BUTTON_LEFTSHOULDER,
    "shoulder-right": pygame.CONTROLLER_BUTTON_RIGHTSHOULDER,
    # sticks
    "stick-left": pygame.CONTROLLER_BUTTON_LEFTSTICK,
    "stick-right": pygame.CONTROLLER_BUTTON_RIGHTSTICK,
    # back & guide @ start
    "back": pygame.CONTROLLER_BUTTON_BACK,
    "guide": pygame.CONTROLLER_BUTTON_GUIDE,
    "start": pygame.CONTROLLER_BUTTON_START,
}

controller_axis_codes: dict[str, int] = {
    # axis
    "left-x": pygame.CONTROLLER_AXIS_LEFTX,
    "left-y": pygame.CONTROLLER_AXIS_LEFTY,
    "right-x": pygame.CONTROLLER_AXIS_RIGHTX,
    "right-y": pygame.CONTROLLER_AXIS_RIGHTY,
    # axis-trigger
    "left-trigger": pygame.CONTROLLER_AXIS_TRIGGERLEFT,
    "right-trigger": pygame.CONTROLLER_AXIS_TRIGGERRIGHT,
}

mouse_codes: dict[str, int] = {
    "left": 0,
    "middle": 1,
    "right": 2,
    "mb4": 3,
    "mb5": 4,
}

key_cache: dict[str, tuple[float, int]] = {}
bind_cache: dict[str, callable] = {}

keys_down: list[str] = []
last_keys_down_len: int = 0


def init_controllers():
    pgapi.CONTROLLERS = []
    for i in range(pycontroller.get_count()):
        pgapi.CONTROLLERS.append(pycontroller.Controller(i))


def __inner_get__(key: str) -> Tuple[float, int]:
    """x@controller#0
    x@keyboard - default
    left@mouse

    Args:
        key (str): _description_

    Raises:
        ValueError: _description_
        ValueError: _description_

    Returns:
        tuple[float, int]: _description_
    """

    if key_cache.get(key):
        return key_cache.get(key)

    filter_list: list[str] = key.split("@")
    query = filter_list[0].lower()

    if len(filter_list) == 1:
        filter_list.append("keyboard")

    event: int = -1
    device: int = -1

    # mouse->left
    if filter_list[1] in ["mouse", "ms", "cursor", "crs"]:
        device = 0
        event = mouse_codes[query]

    # keyboard->a
    elif filter_list[1] in ["keyboard", "kb", "kybrd"]:
        device = 1
        event = pygame.key.key_code(query)

    # controller|0->dpad-left
    elif filter_list[1].split("#")[0] in [
        "controller",
        "ctrl",
        "joystick",
        "jstick",
    ]:
        controller_index: int = int(filter_list[1].split("#")[1])
        if controller_index < 0 or controller_index >= len(pgapi.CONTROLLERS):
            device = 5
            event = 0

        elif query in controller_codes:
            # 2.1 -> 2.33 -> 2.330321123
            device = 2 + (controller_index * 0.1)
            event = controller_codes[query]

        elif query in controller_axis_codes:
            device = 3 + (controller_index * 0.1)
            event = controller_axis_codes[query]

    if device == -1 or event == -1:
        raise ValueError(
            "Button type must be one of the following: mouse, keyboard, controller"
        )

    res = (device, event)
    key_cache[key] = res

    return res


def get_button(key: str) -> bool | int:
    """Checks if the `key` button is down

    Args:
        key (str)

    Returns:
        bool or int
    """

    def resolve(value):
        if bool(value) == True and key in keys_down:
            return value

        elif bool(value) == True:
            keys_down.append(key)

        elif key in keys_down:
            keys_down.remove(key)

        return value

    device, event = __inner_get__(key)
    device = str(device)

    if device == "0":
        return resolve(bool(pygame.mouse.get_pressed(5)[event]))

    # keyboard
    if device == "1":
        return resolve(bool(pygame.key.get_pressed()[event]))

    # controller
    if device[0] in ["2", "3"]:
        controller_id = int(device[2:])
        controller = pgapi.CONTROLLERS[controller_id]

        if device[0] == "2":
            return resolve(controller.get_button(event))
        return controller.get_axis(event)


def get_button_down(key: str) -> bool:
    """Checks for button press

    Args:
        key (str)

    Returns:
        bool
    """

    in_list = key in [x for x in keys_down]
    is_down = get_button(key)

    if not is_down:
        return False

    if in_list:
        return False

    return True


def get_button_up(key: str) -> bool:
    global last_keys_down_len
    """Checks for button release

    Args:
        key (str)

    Returns:
        bool
    """

    in_list = key in [x for x in keys_down]
    is_down = get_button(key)

    if is_down:
        return False

    if in_list:
        return True

    return False


def any_button() -> bool:
    global last_keys_down_len
    """_summary_

    Returns:
        bool: _description_
    """
    if len(keys_down) > 0:
        return True
    return False


def any_button_down() -> bool:
    global last_keys_down_len
    """_summary_

    Returns:
        bool: _description_
    """
    if len(keys_down) > last_keys_down_len:
        last_keys_down_len = len(keys_down)
        return True
    elif len(keys_down) < last_keys_down_len:
        last_keys_down_len = len(keys_down)
    return False


def any_button_up() -> bool:
    global last_keys_down_len
    """_summary_

    Returns:
        bool: _description_
    """
    if len(keys_down) < last_keys_down_len:
        last_keys_down_len = len(keys_down)
        return True
    elif len(keys_down) > last_keys_down_len:
        last_keys_down_len = len(keys_down)
    return False


def horizontal(controller: int = 0) -> Literal[1, 0, -1]:
    movement = 0
    ctrl_movement = get_button(f"left-x@ctrl#{controller}")

    if get_button(f"{pgapi.SETTINGS.move_keys[0][0]}@keyboard"):
        movement -= 1
    if get_button(f"{pgapi.SETTINGS.move_keys[0][1]}@keyboard"):
        movement += 1
    if ctrl_movement and abs(ctrl_movement) > pgapi.SETTINGS.axis_rounding:
        movement = ctrl_movement / 32768

    return movement


def vertical(controller: int = 0) -> Literal[1, 0, -1]:
    movement = 0
    ctrl_movement = get_button(f"left-y@ctrl#{controller}")

    if get_button(f"{pgapi.SETTINGS.move_keys[1][0]}@keyboard"):
        movement -= 1
    if get_button(f"{pgapi.SETTINGS.move_keys[1][1]}@keyboard"):
        movement += 1

    if ctrl_movement and abs(ctrl_movement) > pgapi.SETTINGS.axis_rounding:
        movement = ctrl_movement / 32768

    return movement


def bind_buttons(
    name: str,
    key_set_list: list[set[str]],
    T: Optional[Literal["down", "up"]] = None,
) -> None:
    if bind_cache.get(name):
        return

    getfn: Callable[[str], bool]
    match T:
        case None:
            getfn = get_button
        case "down":
            getfn = get_button_down
        case "up":
            getfn = get_button_up

    def bindf():
        all_down_any = False

        for i in range(len(key_set_list)):
            if type(key_set_list[i]) is str:
                key_set_list[i] = set([key_set_list[i]])

        for _set in key_set_list:
            set_good = 0
            for key in _set:
                if getfn(key):
                    set_good += 1
            if set_good == len(_set):
                all_down_any = True
                break

        return all_down_any

    bind_cache[name] = bindf


def active_bind(name: str):
    return bind_cache[name]()


def get_mouse_position() -> Vector2:
    mp = pygame.mouse.get_pos()
    return Vector2(mp[0], mp[1])