# Import the base lib
from brass.base import *

# Import generic utilities
from brass.gui import *
from brass import (
    pgapi,
    saves,
    scene
)

FS = FONT_SIZE.MEDIUM


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
            height=f"{FS}x",
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


def load_game_scene() -> None:
    saves.select_slot(0)
    scene.load(enums.scenes.GAME)


# Runs after spawn()
def awake() -> None:
    gap = 40

    title_card_len = len("| | | | |  | ||  __/ (_| | (_| | | | | | |  __/")

    pgapi.as_menu()
    # DOM creates a new document object model
    DOM(
        Element(
            "TitleCard",
            Element(
                "TitleCard Text",
                Text("  ___       _"),
                Text(" / _ \     | |"),
                Text("/ /_\ \_ __| |_ ___  __ _  __ _ _ __ ___   ___ "),
                Text("|  _  | '__| __/ _ \/ _` |/ _` | '_ ` _ \ / _ \\"),
                Text("| | | | |  | ||  __/ (_| | (_| | | | | | |  __/"),
                Text("\_| |_/_|   \__\___|\__, |\__,_|_| |_| |_|\___|"),
                Text("                     __/ |   "),
                Text("                    |___/   "),
                style=StyleSheet(
                    font_family=FONTS.PRESS_PLAY,
                    position=POSITION.RELATIVE,
                    width=f"{title_card_len * FS}x",
                    left=f"-{title_card_len * FS / 2}x",
                    height=f"{FS * 8}x",
                    top="0x",
                    font_size=FS,
                    # bg_color=COLOURS.RED
                ),
            ),
            style=StyleSheet(position=POSITION.ABSOLUTE, left="50w", top="25h"),
        ),
        Element(
            "CenterButtons",
            title_button("StartGame", "Start Game", 0, load_game_scene),
            title_button("StartGame", "Options", FS + gap),
            title_button("StartGame", "Exit", (FS + gap) * 2, lambda: exit()),
            style=StyleSheet(position=POSITION.ABSOLUTE, top="60h", left="50w"),
        ),
    )
