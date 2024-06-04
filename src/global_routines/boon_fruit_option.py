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
    top = f"{top * 2.5 + 6}h"

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
                left=f"12.5x",
                top=f"12.5x",
                height="175x",
                width=f"175x",
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
                left=f"175x",
                top=f"175x",
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
                left="450x",
                top="0x",
            ),
        ),
        style=StyleSheet(
            display="block",
            inherit_display=True,
            position=POSITION.RELATIVE,
            top=f"{(child_num - 1) * 200 - 100}x",
            left="-350x",
            width="700x",
            height="200x",
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
                left=f"{15 * .1}h",
                top=f"{15 * .1}h",
                height="80%",
                width=f"{15 * .8}h",
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
                    top="1.25h",
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
                    top=f"{FONT_SIZE.MEDIUM + 40}x",
                    font_size=FONT_SIZE.SMALL,
                    font_family=FONTS.PRESS_PLAY,
                    gap="20x",
                    # bg_color=COLOURS.RED
                ),
            ),
            style=StyleSheet(
                inherit_display=True,
                position=POSITION.RELATIVE,
                left="15h",
                top="0x",
            ),
        ),
        style=StyleSheet(
            display="block",
            inherit_display=True,
            position=POSITION.RELATIVE,
            top=f"{(child_num - 1) * 16.25 - 7.5}h",
            left="-30h",
            width="60h",
            height="15h",
            # bg_color=COLOURS.RED,
        ),
        hover=StyleSheet(bg_color=(20, 120, 220, 1)),
        is_button=True,
        onclick=boon_fn,
    )
