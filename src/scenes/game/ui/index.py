from brass.base import *
from brass.gui import *

from brass import pgapi, scene, saves
from global_routines import menu

FS = FONT_SIZE.MEDIUM
GAP = 40


def back_to_main_menu() -> None:
    menu.hide_menu()
    err = saves.save()
    if err.is_err():
        print(err.err().msg)
    scene.load(enums.scenes.DEFAULT)


def title_button(
    id: str, content: string, top: Number = 0, fn: Callable[..., None] = None
):
    top = f"{top}x"

    return Element(
        id,
        Text(content),
        style=StyleSheet(
            position=POSITION.RELATIVE,
            color=COLOURS.WHITE,
            width=f"{len(content) * FS}x",
            height=f"{FS * 1.25}x",
            left=f"-{len(content) * FS / 2}x",
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


def awake() -> None:
    DOM(
        Element(
            "PlayerDashCounter",
            Text("[×] [×] "),
            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                top="5.5u",
                left="1u",
                font_size=FONT_SIZE.MEDIUM,
                font_family=FONTS.PRESS_PLAY,
                color=COLOURS.WHITE,
            ),
        ),
        Element(
            "HitpointBarBackground",
            Element(
                "HitpointBarInnerContainer",
                Element(
                    "PlayerHitpointBar",
                    style=StyleSheet(
                        position=POSITION.RELATIVE,
                        left="0u",
                        top="0u",
                        width="75%",
                        height="100%",
                        bg_color=(255, 80, 50, 1),
                    ),
                ),
                Element(
                    "HpAmountDispaly",
                    Text("100/100"),
                    style=StyleSheet(
                        position=POSITION.RELATIVE,
                        top=f"{(1.5 - (FONT_SIZE.SMALL / 16)) / 2}u",
                        left="4.75u",
                        font_size=FONT_SIZE.SMALL,
                        font_family=FONTS.PRESS_PLAY,
                        color=COLOURS.WHITE,
                    ),
                ),
                style=StyleSheet(
                    position=POSITION.RELATIVE,
                    top=".25u",
                    left=".25u",
                    width="9.5u",
                    height="1.5u",
                ),
            ),
            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                top="1u",
                left="1u",
                width="10u",
                height="2u",
                bg_color=(50, 50, 50, 1),
            ),
        ),
        Element(
            "ManaBarBackground",
            Element(
                "ManaBarInnerContainer",
                Element(
                    "ManaBar",
                    style=StyleSheet(
                        position=POSITION.RELATIVE,
                        left="0u",
                        top="0u",
                        width="100%",
                        height="100%",
                        bg_color=(20, 120, 220, 1),
                    ),
                ),
                style=StyleSheet(
                    position=POSITION.RELATIVE,
                    top=".25u",
                    left=".25u",
                    width="7u",
                    height="1u",
                ),
            ),
            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                top="3.5u",
                left="1u",
                width="7.5u",
                height="1.5u",
                bg_color=(50, 50, 50, 1),
            ),
        ),
        Element(
            "GameMenu",
            Element(
                "CenterButtons",
                title_button("continue-btn", "Játék Folytatása", 0, menu.hide_menu),
                title_button(
                    "reload-btn",
                    "Újratöltés",
                    FS + GAP,
                    lambda: scene.load(enums.scenes.GAME),
                ),
                title_button(
                    "exit-btn",
                    "Főmenü",
                    (FS + GAP) * 2,
                    back_to_main_menu,
                ),
                style=StyleSheet(position=POSITION.ABSOLUTE, top="40h", left="50w"),
            ),
            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                display="none",
                top="0x",
                left="0x",
                width="100w",
                height="100h",
                bg_color=(0, 0, 0, 0.6),
            ),
        ),
    )
