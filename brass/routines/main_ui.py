from ui import *
from pgapi import SCENES


@SCENES.default.awake
def awk():
    DOM(
        Element(
            "TestElement",
            Text("HELLO MOTHERF*CKER!!!"),
            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                top="50h",
                left="10w",
                width="150x",
                height="50x",
                # bg_color=(245, 255, 255, 0),
                bg_image="neunyx32x32.png",
                font_size=FONT_SIZE.EXTRA_LARGE,
                color=(255, 0, 0, 1),
            ),
        ),
    )
