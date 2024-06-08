from brass.base import *
from brass.gui import *

from brass import pgapi, scene, saves, timeout
from src.global_routines import menus, boons

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
    width = 64
    gap = 10
    FS = FONT_SIZE.SMALL
    return Element(
        "Inventory-Item-" + name,
        Element(
            "Inventory-Item-" + name + "-Counter",
            Text("0"),
            style=StyleSheet(
                position=POSITION.RELATIVE,
                top=f"{width + gap}x",
                left=f"{width / 2 - FS / 2}x",
                font_size=FS,
                font_family=FONTS.PRESS_PLAY,
            ),
        ),
        style=StyleSheet(
            position=POSITION.RELATIVE,
            left=f"{(width + gap) * (nth - 1)}x",
            top="0x",
            width=width,
            height=width,
            bg_image=f"{name}.png",
        ),
    )


def awake() -> None:
    DOM(
        Element(
            "InteractionShower",
            # "B",
            Element(
                "InteractionShower:Picture",
                Element(
                    "InteractionShower:Picture:Letter",
                    Text("B"),
                    style=StyleSheet(
                        inherit_display=True,
                        position=POSITION.RELATIVE,
                        top="24x",
                        left="24x",
                        width=f"{FS}x",
                        height=f"{FS}x",
                        # bg_image="interaction_shower.png",
                        color=COLOURS.RED,
                        font_family=FONTS.PRESS_PLAY,
                    ),
                ),
                style=StyleSheet(
                    inherit_display=True,
                    position=POSITION.RELATIVE,
                    top="-32x",
                    left="32x",
                    width="64x",
                    height="64x",
                    bg_image="interaction_shower.png",
                ),
            ),
            Element(
                "InteractionShower:Text",
                Text("Interakció: Mixer"),
                style=StyleSheet(
                    inherit_display=True,
                    position=POSITION.RELATIVE,
                    top=f"-{FS/2}x",
                    left="96x",
                    width=f"{FS}x",
                    height=f"{FS}x",
                    # bg_image="interaction_shower.png",
                    color=COLOURS.WHITE,
                    font_family=FONTS.PRESS_PLAY,
                ),
            ),
            style=StyleSheet(
                display="block",
                position=POSITION.ABSOLUTE,
                top="50h",
                left="50w",
            ),
        ),
        Element(
            "HudContainer",
            Element(
                "Hud",
                Element(
                    "HitpointBarBackground",
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
                            top=f"{15 - FONT_SIZE.MEDIUM / 2}x",
                            left="4.75u",
                            font_size=FONT_SIZE.MEDIUM,
                            font_family=FONTS.PRESS_PLAY,
                            color=COLOURS.WHITE,
                        ),
                    ),
                    style=StyleSheet(
                        position=POSITION.RELATIVE,
                        top="20x",
                        left="20x",
                        width="600x",
                        height="30x",
                        bg_color=COLOURS.NIGHT_BLUE,
                    ),
                ),
                Element(
                    "ManaBarBackground",
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
                        top="60x",
                        left="20x",
                        width="600x",
                        height="20x",
                        bg_color=COLOURS.NIGHT_BLUE,
                    ),
                ),
                Element(
                    "DashBarBackground",
                    Element(
                        "DashBar",
                        style=StyleSheet(
                            position=POSITION.RELATIVE,
                            left="0u",
                            top="0u",
                            width="100%",
                            height="100%",
                            bg_color=COLOURS.WHITE,
                        ),
                    ),
                    style=StyleSheet(
                        position=POSITION.RELATIVE,
                        top="90x",
                        left="20x",
                        width="600x",
                        height="5x",
                        bg_color=COLOURS.NIGHT_BLUE,
                    ),
                ),
                Element(
                    "Hud:Icons-Abilities:Container",
                    Element(
                        "WeaponSwapDisplay",
                        Element(
                            "WeaponSwapDisplay:Keybind",
                            Text("Tab"),
                            style=StyleSheet(
                                position=POSITION.RELATIVE,
                                inherit_display=True,
                                top="74x",
                                # left=f"{32 - 1.5 * FS}x",
                                left="8x",
                                width=f"{3 * FS}x",
                                height=f"{FS}x",
                                font_size=FS,
                                font_family=FONTS.PRESS_PLAY,
                            ),
                        ),
                        style=StyleSheet(
                            position=POSITION.RELATIVE,
                            inherit_display=True,
                            top="0x",
                            left="-600x",
                            width="64x",
                            height="64x",
                            bg_image="weapon_switch_plates.png",
                        ),
                    ),
                    Element(
                        "Spell0Display",
                        Element(
                            "Spell0Display:Keybind",
                            Text("Q"),
                            style=StyleSheet(
                                position=POSITION.RELATIVE,
                                inherit_display=True,
                                top="74x",
                                left=f"{32 - .5 * FS}x",
                                width=f"{3 * FS}x",
                                height=f"{FS}x",
                                font_size=FS,
                                font_family=FONTS.PRESS_PLAY,
                            ),
                        ),
                        style=StyleSheet(
                            position=POSITION.RELATIVE,
                            inherit_display=True,
                            top="0x",
                            left="-96x",
                            width="64x",
                            height="64x",
                            bg_image="empty_icon.png",
                        ),
                    ),
                    Element(
                        "Spell1Display",
                        Element(
                            "Spell1Display:Keybind",
                            Text("E"),
                            style=StyleSheet(
                                position=POSITION.RELATIVE,
                                inherit_display=True,
                                top="74x",
                                left=f"{32 - .5 * FS}x",
                                width=f"{3 * FS}x",
                                height=f"{FS}x",
                                font_size=FS,
                                font_family=FONTS.PRESS_PLAY,
                            ),
                        ),
                        style=StyleSheet(
                            position=POSITION.RELATIVE,
                            inherit_display=True,
                            top="0x",
                            left=f"{640 + 32}x",
                            width="64x",
                            height="64x",
                            bg_image="empty_icon.png",
                        ),
                    ),
                    style=StyleSheet(
                        position=POSITION.RELATIVE,
                        inherit_display=True,
                        top="12x",
                        left="0x",
                    ),
                ),
                Element(
                    "Hud:Fruits:Container",
                    item_display(1, "banana"),
                    item_display(2, "strawberry"),
                    item_display(3, "blueberry"),
                    style=StyleSheet(
                        position=POSITION.RELATIVE,
                        # inherit_display=True,
                        top="12x",
                        left=f"{640 + 600 - 222}x",
                    ),
                ),
                style=StyleSheet(
                    position=POSITION.RELATIVE,
                    inherit_display=True,
                    left="-320x",
                    width="640x",
                    top="-115x",
                    height="115x",
                    # bg_color=(10, 9, 8, 1),
                    bg_image="hud_bg.png",
                ),
            ),
            style=StyleSheet(
                display="block",
                position=POSITION.ABSOLUTE,
                top="100h",
                left="50w",
            ),
        ),
        Element(
            "RoundDisplay:Container",
            Element(
                "RoundDisplay",
                "1. Kör",
                style=StyleSheet(
                    position=POSITION.RELATIVE,
                    font_family=FONTS.PRESS_PLAY,
                    font_size=FONT_SIZE.MEDIUM,
                    left=f"-{3 * FONT_SIZE.MEDIUM}x",
                    top="0x"
                )
            ),
            style=StyleSheet(
                display="block",
                position=POSITION.ABSOLUTE,
                top="32x",
                left="50w",
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
                    boons.new_setting_adjuster_element("banana", 0),
                    boons.new_setting_adjuster_element("strawberry", 1),
                    boons.new_setting_adjuster_element("blueberry", 2),
                    Element(
                        "EndBoonSelectionNumberButtons",
                        title_button(
                            "confirm-boon-options-btn",
                            "Elfogadás",
                            0,
                            caller(boons.close_boon_menu, ()),
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
                    bg_color=COLOURS.MENUS_BACKDROP,
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
                    Element(
                        "BoonSelectionList",
                        style=StyleSheet(
                            position=POSITION.ABSOLUTE,
                            inherit_display=True,
                            top="50h",
                            left="50w",
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
                    bg_color=COLOURS.MENUS_BACKDROP,
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
                    bg_color=COLOURS.MENUS_BACKDROP,
                ),
            )
        ),
    )
    # timeout.new(1, boons.show_boon_menu, ())

    # print(get_element("wrapper:banana").ok().transform)

