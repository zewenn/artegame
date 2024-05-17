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
                # bg_color=(20, 120, 220, 1),
                color=(255, 80, 50, 255)
            ),
        )
    )
