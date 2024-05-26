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
                color=(255, 80, 50, 1),
            ),
            hover=StyleSheet(color=(255, 255, 255, 1)),
        ),
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
    )
