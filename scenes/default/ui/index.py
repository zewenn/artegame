from brass.base import *
from brass.gui import *


def awake() -> None:
    DOM(
        Element(
            "PlayerVitals",

            Text("Helth: 100"),
            Text("Mana: 50"),
            
            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                top=".5u",
                left=".5u",
                width="3u",
                height="3u",
                # bg_color=(100, 100, 100, .2),
                font_size=FONT_SIZE.MEDIUM,
                gap="2x",
                color=(255, 80, 50, 1)
            ),
            hover=StyleSheet(
                color=(255, 255, 255, 1)
            )
        ),
        Element(
            "PlayerDashCounter",

            Text("[×] [×] "),

            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                top="3.5u",
                left=".5u",
                font_size=FONT_SIZE.MEDIUM,
                font=FONTS.PRESS_PLAY,
                color=COLOURS.WHITE
            )
        )
    )
