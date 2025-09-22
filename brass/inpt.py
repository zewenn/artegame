from .base import *

from . import vectormath, pgapi, enums


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
        if bool(value) is True and key in keys_down:
            return value

        if bool(value) is True:
            keys_down.append(key)
            return value

        if key in keys_down:
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

        r = controller.get_axis(event)
        ar = abs(r)

        if ar > pgapi.SETTINGS.axis_rounding or (
            key in ["right-trigger@ctrl#0", "left-trigger@ctrl#0"]
            and ar > pgapi.SETTINGS.axis_rounding * 0.3
        ):
            return resolve(controller.get_axis(event))
        return resolve(False)


def get_button_down(key: str) -> bool:
    """Checks for button press

    Args:
        key (str)

    Returns:
        bool
    """

    in_list = key in keys_down
    is_down = get_button(key)

    if typeof(is_down) == "int":
        is_down = is_down > pgapi.SETTINGS.axis_rounding

    if not is_down or in_list:
        return False

    return True


def get_button_up(key: str) -> bool:
    """Checks for button release

    Args:
        key (str)

    Returns:
        bool
    """

    in_list = key in keys_down
    is_down = get_button(key)

    if typeof(is_down) == "int":
        is_down = is_down > pgapi.SETTINGS.axis_rounding

    if in_list or is_down:
        return True

    return False


def any_button() -> bool:
    """
    ## `[UNDOCUMENTED]`
    This function has not been documented yet!
    Be careful using it!

    Returns:
        bool: _description_
    """

    if len(keys_down) > 0:
        return True
    return False


def any_button_down() -> bool:
    """
    ## `[UNDOCUMENTED]`
    This function has not been documented yet!
    Be careful using it!

    Returns:
        bool: _description_
    """

    global last_keys_down_len

    if len(keys_down) > last_keys_down_len:
        last_keys_down_len = len(keys_down)
        return True
    elif len(keys_down) < last_keys_down_len:
        last_keys_down_len = len(keys_down)
    return False


def any_button_up() -> bool:
    """
    ## `[UNDOCUMENTED]`
    This function has not been documented yet!
    Be careful using it!

    Returns:
        bool: _description_
    """

    global last_keys_down_len

    if len(keys_down) != last_keys_down_len:
        last_keys_down_len = len(keys_down)
        return True
    
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
    T_type: Optional[Literal["down", "up"]] = None,
) -> None:
    if bind_cache.get(name):
        # print(f"[Warn] Couldn't overwrite bind: {name}")
        return

    def bindf():
        getfn: Callable[[str], bool]
        if T_type is None:
            getfn = get_button
        elif T_type == "down":
            getfn = get_button_down
        elif T_type == "up":
            getfn = get_button_up

        all_down_any = False

        # pylint: disable=consider-using-enumerate
        for i in range(len(key_set_list)):
            if isinstance(key_set_list[i], str):
                key_set_list[i] = set([key_set_list[i]])
        # pylint: enable=consider-using-enumerate

        for _set in key_set_list:
            set_good = 0
            for key in _set:
                r = getfn(key)
                if typeof(r) == "int":
                    r = r > pgapi.SETTINGS.axis_rounding
                if r:
                    set_good += 1
            if set_good == len(_set):
                all_down_any = True
                break

        return all_down_any

    bind_cache[name] = bindf


def active_bind(name: str):
    return bind_cache[name]()


def get_mouse_position() -> Vec2:
    mp = pygame.mouse.get_pos()
    return Vec2(mp[0], mp[1])


def system_udpate() -> None:

    pgapi.LAST_MOUSE_POSITION, pgapi.MOUSE_POSITION = (
        pgapi.MOUSE_POSITION,
        get_mouse_position(),
    )

    if len(pgapi.CONTROLLERS) == 0:
        return

    distance = vectormath.get_Vec2_distcance(
        pgapi.MOUSE_POSITION, pgapi.LAST_MOUSE_POSITION
    )

    if distance >= 15:
        pgapi.SETTINGS.input_mode = enums.input_modes.MOUSE_AND_KEYBOARD
        return

    if (
        abs(get_button("left-x@ctrl#0")) > pgapi.SETTINGS.axis_rounding
        or abs(get_button("left-y@ctrl#0")) > pgapi.SETTINGS.axis_rounding
        or abs(get_button("right-x@ctrl#0")) > pgapi.SETTINGS.axis_rounding
        or abs(get_button("right-y@ctrl#0")) > pgapi.SETTINGS.axis_rounding
    ):
        pgapi.SETTINGS.input_mode = enums.input_modes.CONTROLLER
        return

    if len(keys_down) == 0:
        return

    # key = keys_down[0]

    for key in keys_down:

        if any(
            [
                "mouse" in key,
                "ms" in key,
                "cursor" in key,
                "crs" in key,
                "keyboard" in key,
                "kb" in key,
                "kybrd" in key,
            ]
        ):
            pgapi.SETTINGS.input_mode = enums.input_modes.MOUSE_AND_KEYBOARD
            return

        if any(
            ["controller" in key, "ctrl" in key, "joystick" in key, "jstick" in key]
        ):
            if key in [
                "left-x@ctrl#0",
                "right-x@ctrl#0",
                "left-y@ctrl#0",
                "right-y@ctrl#0",
            ]:
                continue
            # print(key)
            pgapi.SETTINGS.input_mode = enums.input_modes.CONTROLLER
            return
