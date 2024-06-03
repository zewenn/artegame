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


def new(
    fruit: Literal["banana", "strawberry", "blueberry"], child_num: int
) -> GUIElement:
    return Element(
        "boon_fruit_option:" + fruit,
        Element(
            "boon_fruit_icon:" + fruit,
            style=StyleSheet(
                inherit_display=True,
                position=POSITION.RELATIVE,
                left=f"{15 * .1}h",
                top=f"{15 * .0}h",
                height="80%",
                width=f"{15 * .8}h",
                bg_image=f"{fruit}.png",
            ),
        ),
        Element(
            "boon_fruit_num_display:" + fruit,
            Text("0"),
            style=StyleSheet(
                inherit_display=True,
                position=POSITION.RELATIVE,
                left=f"{15 * .8}h",
                top=f"{15 * .7}h",
                height=f"{FS}x",
                width=f"{FS}x",
                font_size=FS,
                font_family=FONTS.PRESS_PLAY
            ),
        ),
        Element(
            "boon_fruit_buttons:" + fruit,
            btn(fruit, "Add more (+1)", 0, caller(boons.update_setting, (fruit, 1))),
            btn(fruit, "Remove (-1)", 1, caller(boons.update_setting, (fruit, -1))),
            style=StyleSheet(
                inherit_display=True,
                position=POSITION.RELATIVE,
                left="30h",
                top="0x",
            ),
        ),
        style=StyleSheet(
            display="block",
            inherit_display=True,
            position=POSITION.RELATIVE,
            top=f"{(child_num - 1) * 16.25 - 7.5}h",
            left="-22.5h",
            width="45h",
            height="15h",
            # bg_color=COLOURS.RED,
        ),
    )
