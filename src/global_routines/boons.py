from brass.base import *
from brass.gui import *

from brass import items, timeout, scene, enums, gui
from global_routines import effect_display, menus

import random


FS = FONT_SIZE.MEDIUM


def btn_element(
    id: str, content: string, top: Literal[0, 1] = 0, fn: Callable[..., None] = None
):
    top = f"{top * FS * 2 + 76}x"

    return Element(
        id,
        # Element(
        #     "wrapper:" + id,
        #     style=StyleSheet(
        #         position=POSITION.RELATIVE,
        #         inherit_display=True,
        #         top=f"-{FS}x",
        #         left="0x",
        #         font_size=FS,
        #         font_family=FONTS.PRESS_PLAY,
        #     ),
        # ),
        Text(content),
        style=StyleSheet(
            position=POSITION.RELATIVE,
            inherit_display=True,
            color=COLOURS.WHITE,
            width=f"{len(content) * FS}x",
            height=f"{FS * 1.25}x",
            left=f"-{len(content) * FS / 2}x",
            # left="0x",
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


def new_setting_adjuster_element(
    fruit: Literal["banana", "strawberry", "blueberry"], child_num: int
) -> GUIElement:
    return Element(
        "boon_fruit_option:" + fruit,
        Element(
            "boon_fruit_icon:" + fruit,
            style=StyleSheet(
                inherit_display=True,
                position=POSITION.RELATIVE,
                left=f"60x",
                top=f"20x",
                height="160x",
                width=f"160x",
                bg_image=f"{fruit}.png",
                # bg_color=COLOURS.BLUE,
            ),
        ),
        Element(
            "boon_fruit_num_display:" + fruit,
            Text("0"),
            style=StyleSheet(
                inherit_display=True,
                position=POSITION.RELATIVE,
                left=f"220x",
                top=f"180x",
                height=f"{FS}x",
                width=f"{FS}x",
                font_size=FS,
                font_family=FONTS.PRESS_PLAY,
            ),
        ),
        Element(
            "boon_fruit_buttons:" + fruit,
            btn_element(fruit, "Hozzáadás (+1)", 0, caller(update_setting, (fruit, 1))),
            btn_element(
                fruit, "Eltávolítás (-1)", 1, caller(update_setting, (fruit, -1))
            ),
            style=StyleSheet(
                inherit_display=True,
                position=POSITION.RELATIVE,
                left="480x",
                top="0x",
            ),
        ),
        style=StyleSheet(
            display="block",
            inherit_display=True,
            position=POSITION.RELATIVE,
            top=f"{(child_num - 1) * 225 - 100}x",
            left="-350x",
            width="700x",
            height="200x",
            # bg_color=COLOURS.RED
            bg_image="menu_option_generic_bg.png",
        ),
    )


def new_boon_element(
    fruit: Literal["banana", "strawberry", "blueberry"],
    boon_icon: string,
    boon_fn: Callable[..., None],
    title: string,
    description: list[string],
    child_num: int,
) -> GUIElement:
    return Element(
        "boon:" + fruit + ":" + title,
        Element(
            "boon_icon:" + fruit + ":" + title,
            style=StyleSheet(
                inherit_display=True,
                position=POSITION.RELATIVE,
                left=f"60x",
                top=f"20x",
                height="160x",
                width=f"160x",
                bg_image=boon_icon,
            ),
        ),
        # Element(
        #     "boon_num_display:" + fruit + ":" + title,
        #     Text("0"),
        #     style=StyleSheet(
        #         inherit_display=True,
        #         position=POSITION.RELATIVE,
        #         left=f"{15 * .8}h",
        #         top=f"{15 * .7}h",
        #         height=f"{FS}x",
        #         width=f"{FS}x",
        #         font_size=FS,
        #         font_family=FONTS.PRESS_PLAY,
        #     ),
        # ),
        Element(
            "boon_details:" + fruit + ":" + title,
            Element(
                "boon_title:" + fruit + ":" + title,
                Text(title),
                style=StyleSheet(
                    position=POSITION.RELATIVE,
                    inherit_display=True,
                    color=COLOURS.WHITE,
                    width=f"{len(title) * FS}x",
                    height=f"{FS * 1.25}x",
                    # left=f"-{len(title) * FS / 2}x",
                    left="0x",
                    top="40x",
                    font_size=FONT_SIZE.MEDIUM,
                    font_family=FONTS.PRESS_PLAY,
                    # bg_color=COLOURS.RED
                ),
            ),
            Element(
                "boon_description:" + fruit + ":" + "description",
                *description,
                style=StyleSheet(
                    position=POSITION.RELATIVE,
                    inherit_display=True,
                    color=COLOURS.WHITE,
                    width=f"{len(description) * FS}x",
                    height=f"{FS * 1.25}x",
                    # left=f"-{len(description) * FS / 2}x",
                    left="0x",
                    top=f"{FONT_SIZE.MEDIUM + 40 + 20}x",
                    font_size=FONT_SIZE.SMALL,
                    font_family=FONTS.PRESS_PLAY,
                    gap="20x",
                    # bg_color=COLOURS.RED
                ),
            ),
            style=StyleSheet(
                inherit_display=True,
                position=POSITION.RELATIVE,
                left="260x",
                top="0x",
            ),
        ),
        style=StyleSheet(
            display="block",
            inherit_display=True,
            position=POSITION.RELATIVE,
            top=f"{(child_num - 1) * 225 - 100}x",
            left="-350x",
            width="700x",
            height="200x",
            # bg_color=COLOURS.RED,
            bg_image="menu_option_generic_bg.png",
        ),
        # add_query_selectable=False,
        hover=StyleSheet(bg_image="menu_option_generic_bg_active.png"),
        is_button=True,
        onclick=boon_fn,
    )


NEXT_BOON_OPTIONS: Optional[Inventory] = None
player: Optional[Item] = None

BOONS = BoonCollection([], [], [])


STRING_MAP: dict[string, Any] = {}


def set_string_map() -> None:
    global STRING_MAP

    if player == None:
        unreachable("Set string map called before player is loaded!")

    # STRING_MAP["%p"] = player.id

    # # %b - base
    # STRING_MAP["%b.dmg"] = player.base_damage
    # STRING_MAP["%b.as"] = player.base_attack_speed
    # STRING_MAP["%b.ms"] = player.base_movement_speed

    # # %m - max
    # STRING_MAP["%m.hp"] = player.max_hitpoints
    # STRING_MAP["%m.mana"] = player.max_mana

    # # %c - current
    # STRING_MAP["%c.hp"] = player.hitpoints
    # STRING_MAP["%c.mana"] = player.mana

    # # %w - weapon
    # # |> %w0 - weapons[0]
    # #       -> light
    # STRING_MAP["%w0.l.dm"] = player.weapons[0].light_damage_multiplier
    # STRING_MAP["%w0.l.ms"] = player.weapons[0].light_speed
    # STRING_MAP["%w0.l.size"] = player.weapons[0].light_size
    # STRING_MAP["%w0.l.lt"] = player.weapons[0].light_lifetime
    # #       -> heavy
    # STRING_MAP["%w0.h.dm"] = player.weapons[0].heavy_damage_multiplier
    # STRING_MAP["%w0.h.ms"] = player.weapons[0].heavy_speed
    # STRING_MAP["%w0.h.size"] = player.weapons[0].heavy_sizee
    # STRING_MAP["%w0.h.lt"] = player.weapons[0].heavy_lifetime
    # #       -> dash
    # STRING_MAP["%w0.d.dm"] = player.weapons[0].dash_damage_multiplier
    # STRING_MAP["%w0.d.ms"] = player.weapons[0].dash_speed
    # STRING_MAP["%w0.d.size"] = player.weapons[0].dash_size
    # STRING_MAP["%w0.d.lt"] = player.weapons[0].dash_lifetime
    # # |> %w1 - weapons[0]
    # #       -> light
    # STRING_MAP["%w1.l.dm"] = player.weapons[1].light_damage_multiplier
    # STRING_MAP["%w1.l.ms"] = player.weapons[1].light_speed
    # STRING_MAP["%w1.l.size"] = player.weapons[1].light_size
    # STRING_MAP["%w1.l.lt"] = player.weapons[1].light_lifetime
    # #       -> heavy
    # STRING_MAP["%w1.h.dm"] = player.weapons[1].heavy_damage_multiplier
    # STRING_MAP["%w1.h.ms"] = player.weapons[1].heavy_speed
    # STRING_MAP["%w1.h.size"] = player.weapons[1].heavy_sizee
    # STRING_MAP["%w1.h.lt"] = player.weapons[1].heavy_lifetime
    # #       -> dash
    # STRING_MAP["%w1.d.dm"] = player.weapons[1].dash_damage_multiplier
    # STRING_MAP["%w1.d.ms"] = player.weapons[1].dash_speed
    # STRING_MAP["%w1.d.size"] = player.weapons[1].dash_size
    # STRING_MAP["%w1.d.lt"] = player.weapons[1].dash_lifetime

    STRING_MAP["%p.s0"] = player.spells[0].name
    STRING_MAP["%p.s1"] = player.spells[1].name

    # %s - Spell Level
    # STRING_MAP["%s.lvl.haste"] = enums.spells.HASTE.effectiveness
    # STRING_MAP["%s.lvl.healing"] = enums.spells.HEALING.effectiveness
    # STRING_MAP["%s.lvl.goliath"] = enums.spells.GOLIATH.effectiveness
    # STRING_MAP["%s.lvl.zzzz"] = enums.spells.Zzzz.effectiveness
    # # |> Spell id
    # STRING_MAP["%s.id.haste"] = enums.spells.HASTE.name
    # STRING_MAP["%s.id.healing"] = enums.spells.HEALING.name
    # STRING_MAP["%s.id.goliath"] = enums.spells.GOLIATH.name
    # STRING_MAP["%s.id.zzzz"] = enums.spells.Zzzz.name


@scene.awake(enums.scenes.GAME)
def awake() -> None:
    global NEXT_BOON_OPTIONS
    global player

    NEXT_BOON_OPTIONS = Inventory()
    player_query = items.get("player")

    # Player
    if player_query.is_err():
        unreachable("Player Item does not exist!")

    player = player_query.ok()


def update_display_numer(fruit: string, FS: int, to: int) -> None:
    element = gui.get_element(f"boon_fruit_num_display:{fruit}")

    if element.is_err():
        return

    element = element.ok()

    element.children[0] = str(to)
    element.style.width = f"{FS * len(str(to))}x"


def mk_boon(
    rarity: Literal["normal", "rare", "epic"],
    fruit: Literal["banana", "strawberry", "blueberry"],
    name: string,
    description: list[string],
    icon: string,
    change: string = None,
) -> None:
    global BOONS

    bn = Boon(
        fruit=fruit,
        name=name,
        description=description,
        icon=icon,
        grant_fn=None,
        change=change,
    )

    def decorator(fn: Callable[[], None]) -> None:
        nonlocal bn
        bn.grant_fn = fn

    match rarity:
        case "normal":
            BOONS.normal.append(bn)
        case "rare":
            BOONS.rare.append(bn)
        case "epic":
            BOONS.epic.append(bn)

    return decorator


def update_setting(
    fruit: Literal["banana", "strawberry", "blueberry"], adjust: Literal[1, -1]
) -> None:
    global NEXT_BOON_OPTIONS

    if fruit == "banana":
        if (
            NEXT_BOON_OPTIONS.banana + adjust > player.inventory.banana
            or NEXT_BOON_OPTIONS.banana + adjust < 0
        ):
            return

        NEXT_BOON_OPTIONS.banana += adjust
        update_display_numer(fruit, gui.FONT_SIZE.SMALL, NEXT_BOON_OPTIONS.banana)
        return

    if fruit == "strawberry":
        if (
            NEXT_BOON_OPTIONS.strawberry + adjust > player.inventory.strawberry
            or NEXT_BOON_OPTIONS.strawberry + adjust < 0
        ):
            return

        NEXT_BOON_OPTIONS.strawberry += adjust
        update_display_numer(fruit, gui.FONT_SIZE.SMALL, NEXT_BOON_OPTIONS.strawberry)
        return

    if fruit == "blueberry":
        if (
            NEXT_BOON_OPTIONS.blueberry + adjust > player.inventory.blueberry
            or NEXT_BOON_OPTIONS.blueberry + adjust < 0
        ):
            return

        NEXT_BOON_OPTIONS.blueberry += adjust
        update_display_numer(fruit, gui.FONT_SIZE.SMALL, NEXT_BOON_OPTIONS.blueberry)
        return


def show_boon_menu() -> None:
    global NEXT_BOON_OPTIONS

    NEXT_BOON_OPTIONS.banana = 0
    NEXT_BOON_OPTIONS.strawberry = 0
    NEXT_BOON_OPTIONS.blueberry = 0

    update_setting("banana", 0)
    update_setting("strawberry", 0)
    update_setting("blueberry", 0)

    menus.toggle("BoonMenu")

    BOONS.normal[0].grant_fn()


def show_boon_selection_menu() -> None:
    set_string_map()
    id = "BoonSelectionMenu"

    rarity = 0

    boons_list_elem = gui.get_element("BoonSelectionList")

    if boons_list_elem.is_err():
        unreachable("BoonSelectionList does not exits!")

    boons_list_elem = boons_list_elem.ok()

    for bn_el in boons_list_elem.children:
        gui.Delete(bn_el)

    boons_list_elem.children = []

    printf.full_line(f"{len(gui.query_available)}")

    bns = structured_clone(BOONS.normal)

    for bn in bns:
        if not bn.change or bn.change.startswith("g"):
            continue

        if (bn.change == "u:s0" and player.spells[0].name == "Üres") or (
            bn.change == "u:s1" and player.spells[1].name == "Üres"
        ):
            bns.remove(bn)

    bns = [bns.pop(random.randint(0, len(bns) - 1)) for _ in range(3)]

    for index, bn in enumerate(bns):

        def grant_fn() -> None:
            bn.grant_fn(),
            menus.toggle(id)

        descr: list[string] = structured_clone(bn.description)

        title = bn.name

        for k, v in STRING_MAP.items():
            title = title.replace(k, v)
            for i, x in enumerate(descr):
                descr[i] = x.replace(k, v)

        el = new_boon_element(
            bn.fruit,
            bn.icon,
            grant_fn,
            title,
            descr,
            index,
        )
        el.parent = boons_list_elem

        boons_list_elem.children.append(el)

    menus.toggle(id)


# Boon defs


@mk_boon(
    "normal",
    "banana",
    "Gyorsulás Képesség",
    [
        "Bónusz mozgási- és támadási",
        "sebesség 5 másodpercig.",
        "Ezt cseréli: %p.s1 (1)",
    ],
    "banana.png",
    "g:s1",
)
def grant_haste() -> None:
    enums.spells.HASTE.effectiveness = 3
    player.spells[1] = enums.spells.HASTE


@mk_boon(
    "normal",
    "banana",
    "ZzZz...",
    [
        "A körülötted lévő ellenfelek",
        "elaltatása 2 másodperc után.",
        "Ezt cseréli: %p.s1 (1)",
    ],
    "banana.png",
    "g:s1",
)
def grant_zzzz() -> None:
    enums.spells.Zzzz.effectiveness = 1
    player.spells[1] = enums.spells.Zzzz


@mk_boon(
    "normal",
    "banana",
    "Gyógyulás",
    [
        "Másodpercenként visszatölti",
        "at életerőd egy részét.",
        "Ezt cseréli: %p.s0 (0)",
    ],
    "banana.png",
    "g:s0",
)
def grant_healing() -> None:
    enums.spells.HEALING.effectiveness = 5
    player.spells[0] = enums.spells.HEALING


@mk_boon(
    "normal",
    "banana",
    "Góliát",
    ["Nagyobb méret és több életerő", "15 másodpercig.", "Ezt cseréli: %p.s0 (0)"],
    "banana.png",
    "g:s0",
)
def grant_goliath() -> None:
    enums.spells.GOLIATH.effectiveness = 1.25
    player.spells[0] = enums.spells.GOLIATH


@mk_boon(
    "normal", "banana", "%p.s0 fejlesztése", ["+1 hatékonyság"], "banana.png", "u:s0"
)
def grant_healing() -> None:
    player.spells[0].effectiveness += 1


@mk_boon(
    "normal",
    "strawberry",
    "Gyors mozgás",
    ["Megnöveli a mozgási sebességet."],
    "strawberry.png",
)
def movement_speed() -> None:
    player.base_movement_speed += 20


@mk_boon(
    "normal",
    "strawberry",
    "Nagyobb életerő",
    ["+25 maximum életerő."],
    "strawberry.png",
)
def grant_healing() -> None:
    player.max_hitpoints += 25
    player.hitpoints += 25


@mk_boon("normal", "strawberry", "Több mana", ["+10 maximum mana."], "strawberry.png")
def grant_healing() -> None:
    player.max_mana += 10
    player.mana += 10
