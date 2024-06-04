# Import the base lib
from brass.base import *

# Import generic utilities
from global_routines import boons

from brass.gui import *
from brass import pgapi


FS = FONT_SIZE.MEDIUM


def btn(
    id: str, content: string, top: Literal[0, 1] = 0, fn: Callable[..., None] = None
):
    top = f"{top * FS * 2 + 76}x"

    return Element(
        id,
        # Element(
        #     "wrapper:" + id,
        #     style=StyleSheet(
        #         position=POSITION.RELATIVE,
        #         inherit_display=True,
        #         top=f"-{FS}x",
        #         left="0x",
        #         font_size=FS,
        #         font_family=FONTS.PRESS_PLAY,
        #     ),
        # ),
        Text(content),
        style=StyleSheet(
            position=POSITION.RELATIVE,
            inherit_display=True,
            color=COLOURS.WHITE,
            width=f"{len(content) * FS}x",
            height=f"{FS * 1.25}x",
            left=f"-{len(content) * FS / 2}x",
            # left="0x",
            top=top,
            font_size=FS,
            font_family=FONTS.PRESS_PLAY,
            # bg_color=COLOURS.RED
        ),
        hover=StyleSheet(
            color=COLOURS.LIGHTBLUE,
            font_variant=["bold", "italic"],
        ),
        is_button=True,
        onclick=fn,
    )


def new_setting_adjuster(
    fruit: Literal["banana", "strawberry", "blueberry"], child_num: int
) -> GUIElement:
    return Element(
        "boon_fruit_option:" + fruit,
        Element(
            "boon_fruit_icon:" + fruit,
            style=StyleSheet(
                inherit_display=True,
                position=POSITION.RELATIVE,
                left=f"60x",
                top=f"20x",
                height="160x",
                width=f"160x",
                bg_image=f"{fruit}.png",
                # bg_color=COLOURS.BLUE,
            ),
        ),
        Element(
            "boon_fruit_num_display:" + fruit,
            Text("0"),
            style=StyleSheet(
                inherit_display=True,
                position=POSITION.RELATIVE,
                left=f"220x",
                top=f"180x",
                height=f"{FS}x",
                width=f"{FS}x",
                font_size=FS,
                font_family=FONTS.PRESS_PLAY,
            ),
        ),
        Element(
            "boon_fruit_buttons:" + fruit,
            btn(fruit, "Hozzáadás (+1)", 0, caller(boons.update_setting, (fruit, 1))),
            btn(
                fruit, "Eltávolítás (-1)", 1, caller(boons.update_setting, (fruit, -1))
            ),
            style=StyleSheet(
                inherit_display=True,
                position=POSITION.RELATIVE,
                left="480x",
                top="0x",
            ),
        ),
        style=StyleSheet(
            display="block",
            inherit_display=True,
            position=POSITION.RELATIVE,
            top=f"{(child_num - 1) * 225 - 100}x",
            left="-350x",
            width="700x",
            height="200x",
            # bg_color=COLOURS.RED
            bg_image="menu_option_generic_bg.png",
        ),
    )


def new_boon(
    fruit: Literal["banana", "strawberry", "blueberry"],
    boon_icon: string,
    boon_fn: Callable[..., None],
    title: string,
    description: list[string],
    child_num: int,
) -> GUIElement:
    return Element(
        "boon:" + fruit + ":" + title,
        Element(
            "boon_icon:" + fruit + ":" + title,
            style=StyleSheet(
                inherit_display=True,
                position=POSITION.RELATIVE,
                left=f"60x",
                top=f"20x",
                height="160x",
                width=f"160x",
                bg_image=boon_icon,
            ),
        ),
        # Element(
        #     "boon_num_display:" + fruit + ":" + title,
        #     Text("0"),
        #     style=StyleSheet(
        #         inherit_display=True,
        #         position=POSITION.RELATIVE,
        #         left=f"{15 * .8}h",
        #         top=f"{15 * .7}h",
        #         height=f"{FS}x",
        #         width=f"{FS}x",
        #         font_size=FS,
        #         font_family=FONTS.PRESS_PLAY,
        #     ),
        # ),
        Element(
            "boon_details:" + fruit + ":" + title,
            Element(
                "boon_title:" + fruit + ":" + title,
                Text(title),
                style=StyleSheet(
                    position=POSITION.RELATIVE,
                    inherit_display=True,
                    color=COLOURS.WHITE,
                    width=f"{len(title) * FS}x",
                    height=f"{FS * 1.25}x",
                    # left=f"-{len(title) * FS / 2}x",
                    left="0x",
                    top="40x",
                    font_size=FONT_SIZE.MEDIUM,
                    font_family=FONTS.PRESS_PLAY,
                    # bg_color=COLOURS.RED
                ),
            ),
            Element(
                "boon_description:" + fruit + ":" + "description",
                *description,
                style=StyleSheet(
                    position=POSITION.RELATIVE,
                    inherit_display=True,
                    color=COLOURS.WHITE,
                    width=f"{len(description) * FS}x",
                    height=f"{FS * 1.25}x",
                    # left=f"-{len(description) * FS / 2}x",
                    left="0x",
                    top=f"{FONT_SIZE.MEDIUM + 40 + 20}x",
                    font_size=FONT_SIZE.SMALL,
                    font_family=FONTS.PRESS_PLAY,
                    gap="20x",
                    # bg_color=COLOURS.RED
                ),
            ),
            style=StyleSheet(
                inherit_display=True,
                position=POSITION.RELATIVE,
                left="260x",
                top="0x",
            ),
        ),
        style=StyleSheet(
            display="block",
            inherit_display=True,
            position=POSITION.RELATIVE,
            top=f"{(child_num - 1) * 225 - 100}x",
            left="-350x",
            width="700x",
            height="200x",
            # bg_color=COLOURS.RED,
            bg_image="menu_option_generic_bg.png",
        ),
        hover=StyleSheet(bg_image="menu_option_generic_bg_active.png"),
        is_button=True,
        onclick=boon_fn,
    )
