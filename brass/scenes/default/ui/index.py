from ui import *
from pgapi import SCENES


@SCENES.default.awake
def awk():
    DOM(
        Element(
            "TestElement",
            
            Element(
                "fasz",

                style=StyleSheet(
                    position=POSITION.RELATIVE,
                    top="1u",
                    left="-2u",
                    width="3u",
                    height="3u",
                    bg_color=(20, 120, 220, 1)
                )
            ),
            

            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                top="50h",
                left="50w",
                width="5u",
                height="5u",
                bg_color=(245, 0, 0, 0),
                # bg_image="neunyx32x32.png",
                font_size=FONT_SIZE.SMALL,
                color=(255, 255, 255, 1),
            ),
        ),
    )
