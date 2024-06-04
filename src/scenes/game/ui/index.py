from brass.base import *
from brass.gui import *

from brass import pgapi, scene, saves, timeout
from global_routines import menus, boon_fruit_option, boons

FS = FONT_SIZE.MEDIUM
GAP = 40


def back_to_main_menu() -> None:
    menus.toggle("GameMenu")
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
            inherit_display=True,
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


def item_display(nth: Number, name: string) -> GUIElement:
    width = 48
    gap = 32
    FS = FONT_SIZE.SMALL
    return Element(
        "Inventory-Item-" + name,
        Element(
            "Inventory-Item-" + name + "-Counter",
            Text("0"),
            style=StyleSheet(
                position=POSITION.RELATIVE,
                top=f"{width - FS}x",
                left=f"{width - FS}x",
                font_size=FS,
                font_family=FONTS.PRESS_PLAY,
            ),
        ),
        style=StyleSheet(
            position=POSITION.RELATIVE,
            left=f"{width * nth - 1 + gap}x",
            top="0x",
            width=width,
            height=width,
            bg_image=f"{name}.png",
        ),
    )


def awake() -> None:
    DOM(
        Element(
            "InventoryDisplay",
            item_display(1, "banana"),
            item_display(2, "strawberry"),
            item_display(3, "blueberry"),
            style=StyleSheet(position=POSITION.ABSOLUTE, left="80w", top="90h"),
        ),
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
        menus.new(
            Element(
                "BoonMenu",
                # Element(
                #     "BoonMenuBackdropContainer",
                #     style=StyleSheet(
                #         display="block",
                #         inherit_display=True,
                #         position=POSITION.ABSOLUTE,
                #         top="40h",
                #         left="50w",
                #     ),
                # ),
                # Element(
                #     "CenterButtons",
                #     style=StyleSheet(
                #         position=POSITION.ABSOLUTE,
                #         inherit_display=True,
                #         top="40h",
                #         left="50w",
                #     ),
                # ),
                Element(
                    "CenterBoonMenu",
                    Element(
                        "BoonBackdrop",
                        style=StyleSheet(
                            display="block",
                            inherit_display=True,
                            position=POSITION.RELATIVE,
                            top=f"-350x",
                            left="-375x",
                            height="700x",
                            width="750x",
                            bg_color=(0, 0, 0, 1),
                        ),
                    ),
                    Element(
                        "BoonTitle",
                        "Alapanyagok kiválasztása",
                        style=StyleSheet(
                            inherit_display=True,
                            position=POSITION.RELATIVE,
                            top=f"-{400 + FONT_SIZE.LARGE}x",
                            left=f"-{len('Alapanyagok kiválasztása') * FONT_SIZE.LARGE / 2}x",
                            font_size=FONT_SIZE.LARGE,
                            font_family=FONTS.PRESS_PLAY,
                        ),
                    ),
                    boon_fruit_option.new_setting_adjuster("banana", 0),
                    boon_fruit_option.new_setting_adjuster("strawberry", 1),
                    boon_fruit_option.new_setting_adjuster("blueberry", 2),
                    Element(
                        "EndBoonSelectionNumberButtons",
                        title_button(
                            "confirm-boon-options-btn",
                            "Elfogadás",
                            0,
                            caller(menus.toggle, ("BoonMenu",)),
                        ),
                        title_button(
                            "confirm-boon-options-btn",
                            "Mégse",
                            FS + GAP,
                            caller(menus.toggle, ("BoonMenu",)),
                        ),
                        style=StyleSheet(
                            position=POSITION.RELATIVE,
                            inherit_display=True,
                            top="400x",
                            left="0x",
                        ),
                    ),
                    style=StyleSheet(
                        position=POSITION.ABSOLUTE,
                        inherit_display=True,
                        top="50h",
                        left="50w",
                    ),
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
            )
        ),
        menus.new(
            Element(
                "BoonSelectionMenu",
                Element(
                    "CenterBoonSelectionMenu",
                    Element(
                        "BoonBackdrop2",
                        style=StyleSheet(
                            display="block",
                            inherit_display=True,
                            position=POSITION.RELATIVE,
                            top=f"-350x",
                            left="-375x",
                            height="700x",
                            width="750x",
                            bg_color=(0, 0, 0, 1),
                        ),
                    ),
                    Element(
                        "BoonTitle",
                        "Fejlődés Kiválasztása",
                        style=StyleSheet(
                            inherit_display=True,
                            position=POSITION.RELATIVE,
                            top=f"-{400 + FONT_SIZE.LARGE}x",
                            left=f"-{len('Fejlődés Kiválasztása') * FONT_SIZE.LARGE / 2}x",
                            font_size=FONT_SIZE.LARGE,
                            font_family=FONTS.PRESS_PLAY,
                        ),
                    ),
                    boon_fruit_option.new_boon(
                        "banana",
                        "gyuri.png",
                        lambda: None,
                        "Haste",
                        [
                            "Lorem ipsum dolor sit amet.",
                            "Etiam luctus gravida tortor.",
                            "Sed eu nisi pellentesque.",
                        ],
                        0,
                    ),
                    boon_fruit_option.new_boon(
                        "banana",
                        "gyuri.png",
                        lambda: None,
                        "Not Haste",
                        [
                            "Lorem ipsum dolor sit amet.",
                            "Etiam luctus gravida tortor.",
                            "Sed eu nisi pellentesque.",
                        ],
                        1,
                    ),
                    boon_fruit_option.new_boon(
                        "banana",
                        "gyuri.png",
                        lambda: None,
                        "Yes Haste",
                        [
                            "Lorem ipsum dolor sit amet.",
                            "Etiam luctus gravida tortor.",
                            "Sed eu nisi pellentesque.",
                        ],
                        2,
                    ),
                    style=StyleSheet(
                        position=POSITION.ABSOLUTE,
                        inherit_display=True,
                        top="50h",
                        left="50w",
                    ),
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
            )
        ),
        menus.new(
            Element(
                "GameMenu",
                Element(
                    "CenterButtons",
                    title_button(
                        "continue-btn",
                        "Játék Folytatása",
                        0,
                        caller(menus.toggle, ("GameMenu",)),
                    ),
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
                    style=StyleSheet(
                        position=POSITION.ABSOLUTE,
                        inherit_display=True,
                        top="40h",
                        left="50w",
                    ),
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
            )
        ),
    )
    timeout.set(1, boons.show_boon_menu, ())

    # print(get_element("wrapper:banana").ok().transform)
