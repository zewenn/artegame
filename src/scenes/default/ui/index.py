# Import the base lib
from brass.base import *

# Import generic utilities
from brass.gui import *  # type: ignore
from brass import pgapi, saves, scene, items

FS = FONT_SIZE.MEDIUM
continue_game: bool = False


def title_button(
    name: str, content: string, top: Number = 0, fn: Callable[..., None] = None
):

    content = " " + content + " "

    return Element(
        name,
        Text(content),
        style=StyleSheet(
            position=POSITION.RELATIVE,
            color=COLOURS.WHITE,
            width=f"{len(content) * FS}x",
            height=f"{FS * 1.25}x",
            left=f"-{len(content) * FS / 2}x",
            top=f"{top}x",
            font_size=FS,
            font_family=FONTS.PRESS_PLAY,
            # bg_color=COLOURS.RED
        ),
        hover=StyleSheet(
            # color=COLOURS.LIGHTBLUE,
            font_variant=["bold", "italic"],
            color=COLOURS.BLACK,
            bg_color=COLOURS.WHITE,
        ),
        is_button=True,
        onclick=fn,
    )


def load_game_scene() -> None:
    # saves.select_slot(0)
    scene.load(enums.scenes.GAME)


# Runs after spawn()
def awake() -> None:
    global continue_game
    gap = 40

    load_res = saves.load()
    if load_res.is_ok():
        continue_game = True
        items.reset()

    # DOM creates a new document object model
    DOM(
        Element(
            "Background",
            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                left="0x",
                top="0x",
                width="100w",
                height="100h",
                bg_image="background4_576x384.png",
            ),
            is_button=False,
        ),
        Element(
            "BackgroundShade",
            style=StyleSheet(
                position=POSITION.ABSOLUTE,
                left="0x",
                top="0x",
                width="100w",
                height="100h",
                bg_color=(0, 0, 0, 0.8),
            ),
            is_button=False,
        ),
        Element(
            "TitleCard",
            Element(
                "TitleCard Text",
                style=StyleSheet(
                    font_family=FONTS.PRESS_PLAY,
                    position=POSITION.RELATIVE,
                    width=f"1024x",
                    left=f"-512x",
                    height=f"256x",
                    top="0x",
                    font_size=FS,
                    bg_image="artegame_logo.png",
                    # bg_color=COLOURS.RED
                ),
            ),
            style=StyleSheet(position=POSITION.ABSOLUTE, left="50w", top="25h"),
            is_button=False,
        ),
        Element(
            "CenterButtons",
            title_button("StartGame-Btn", "Új Játék" if not continue_game else "Folytatás", 0, load_game_scene),
            title_button("Exit-Btn", "Kilépés", (FS + gap) * 1, pgapi.end),
            style=StyleSheet(position=POSITION.ABSOLUTE, top="60h", left="50w"),
        ),
    )

    # if pgapi.SETTINGS.skip_title_screen:
    #     load_game_scene()
    # else:
    pgapi.as_menu()
