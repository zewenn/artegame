from enums import *
from gui import *
from events import *


@awake
def awk():
    DOM(
        Element(
            "PlayerVitals",

            Text("Helth: 100"),
            Text("Mana: 50"),
            
            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                top="0.5u",
                left="0.5u",
                # width="3u",
                # height="3u",
                # bg_color=(20, 120, 220, 1),
                color=(255, 80, 50, 255)
            ),
        )
    )
