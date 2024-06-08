# Import the base lib
from brass.base import *

# Import generic utilities
from brass.gui import *
from brass import pgapi, saves, scene
from src.global_routines import round_manager

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


def load_game_scene() -> None:
    saves.select_slot(0)
    scene.load(enums.scenes.GAME)


# Runs after spawn()
def awake() -> None:
    saves.delete_save()
    gap = 40

    title_card_len = len("| | __ / _` | '_ ` _ \ / _ \ | | | \ \ / / _ \ '__|")
    rounds_survived = f"{round_manager.ROUND} Túlélt kör"

    # DOM creates a new document object model
    DOM(
        Element(
            "GameOver",
            Element(
                "Background:GameOver",
                style=StyleSheet(
                    position=POSITION.ABSOLUTE,
                    left="0x",
                    top="0x",
                    width="100w",
                    height="100h",
                    bg_image="background.png",
                ),
                is_button=False,
            ),
            Element(
                "BackgroundShade:GameOver",
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
                "TitleCard:Defeat",
                Element(
                    "TitleCard Text",
                    " _____                        _____                ",
                    "|  __ \                      |  _  |               ",
                    "| |  \/ __ _ _ __ ___   ___  | | | |_   _____ _ __ ",
                    "| | __ / _` | '_ ` _ \ / _ \ | | | \ \ / / _ \ '__|",
                    "| |_\ \ (_| | | | | | |  __/ \ \_/ /\ V /  __/ |   ",
                    " \____/\__,_|_| |_| |_|\___|  \___/  \_/ \___|_|   ",
                    Text(""),
                    Text(
                        f"{' ' * round(title_card_len / 2 - len(rounds_survived) / 2)}{rounds_survived}"
                    ),
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
                is_button=False,
            ),
            Element(
                "CenterButtons",
                title_button("StartGame-Btn", "Új Játék", 0, load_game_scene),
                title_button(
                    "Menu-Btn",
                    "Főmenu",
                    (FS + gap) * 1,
                    caller(scene.load, (enums.scenes.DEFAULT,)),
                ),
                style=StyleSheet(position=POSITION.ABSOLUTE, top="60h", left="50w"),
            ),
        ),
    )

    # if pgapi.SETTINGS.skip_title_screen:
    #     load_game_scene()
    # else:
    pgapi.as_menu()
