from enums import *
from gui import *
from events import *

@awake
def _awake():
    DOM(
        Element(
            "PlayerVitals",

            Text("Helth: 100"),
            Text("Mana: 50"),
            
            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                top=".5u",
                left=".5u",
                # width="3u",
                # height="3u",
                # bg_color=(100, 100, 100, .2),
                font_size=FONT_SIZE.MEDIUM,
                gap="2x",
                color=(255, 80, 50, 1)
            ),
        ),
        Element(
            "PlayerDashCounter",

            Text("[×] [×] "),

            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                top="3.5u",
                left=".5u",
                font_size=FONT_SIZE.MEDIUM,
                color=(255, 255, 255, 1)
            )
        )
    )
