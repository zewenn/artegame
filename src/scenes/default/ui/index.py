from brass.base import *
from brass.gui import *

from brass import pgapi

def test_component(id: str, pos: Vec2):
    left = str(pos.x) + "u"
    top = str(pos.y) + "u"

    return Element(
        id,

        Text("Hello World!"),

        style=StyleSheet(
            position=POSITION.ABSOLUTE,
            color=COLOURS.WHITE,
            width="10u",
            height="1.5u",
            left=left,
            top=top,
            font_family=FONTS.PRESS_PLAY,
        ),
        hover=StyleSheet(
            color=COLOURS.LIGHTBLUE,
            bg_color=(30, 30, 30, .5),
            font_variant=["bold", "italic"],
        ),
        is_button=True
    )


def awake() -> None:
    pgapi.as_menu()
    DOM(
        test_component("HelloWorld", Vec2(2, 5)),
        test_component("HelloWorld2", Vec2(2, 7)),
        test_component("HelloWorld3", Vec2(2, 9)),
        Element(
            "PlayerDashCounter",
            
            Text("[×] [×] "),
            
            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                top="3.5u",
                left=".5u",
                font_size=FONT_SIZE.MEDIUM,
                font_family=FONTS.PRESS_PLAY,
                color=COLOURS.WHITE,
            ),
        ),
        Element(
            "TestBarBackground",

            Element(
                "TestBarInnerContainer",

                Element(
                    "PlayerHitpointBar",
                    
                    style=StyleSheet(
                        position=POSITION.RELATIVE,
                        left="0u",
                        top="0u",
                        width="75%",
                        height="100%",
                        bg_color=(255, 80, 50, 1)
                    )
                ),

                style=StyleSheet(
                    position=POSITION.RELATIVE,
                    top=".25u",
                    left=".25u",
                    width="9.5u",
                    height="1.5u",
                )
            ),

            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                top="1u",
                left="1u",
                width="10u",
                height="2u",
                bg_color=(50, 50, 50, 1)
            )
        )
    )
