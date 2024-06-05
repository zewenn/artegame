from brass.base import *
from brass.gui import *

from brass import items, timeout, scene, enums, gui
from global_routines import effect_display, menus, round_manager

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
                left=f"200x",
                top=f"160x",
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
    rarity: Literal["generic", "rare", "epic"] = "generic",
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
                left="250x",
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
            bg_image=f"menu_option_{rarity}_bg.png",
        ),
        # add_query_selectable=False,
        hover=StyleSheet(bg_image=f"menu_option_{rarity}_bg_active.png"),
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

    NEXT_BOON_OPTIONS = Inventory(2, 1, 5)
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



def close_boon_menu() -> None:
    menus.toggle("BoonMenu")
    
    player.inventory.banana -= NEXT_BOON_OPTIONS.banana
    player.inventory.strawberry -= NEXT_BOON_OPTIONS.strawberry
    player.inventory.blueberry -= NEXT_BOON_OPTIONS.blueberry
    
    show_boon_selection_menu()



def show_boon_selection_menu() -> None:
    set_string_map()
    id = "BoonSelectionMenu"

    print(player.spells)

    rarity_tag = "generic"
    rarity = (
        NEXT_BOON_OPTIONS.banana * 3
        + NEXT_BOON_OPTIONS.blueberry * 2
        + NEXT_BOON_OPTIONS.strawberry
    )

    boons_list_elem = gui.get_element("BoonSelectionList")

    if boons_list_elem.is_err():
        unreachable("BoonSelectionList does not exits!")

    boons_list_elem = boons_list_elem.ok()

    for bn_el in boons_list_elem.children:
        gui.Delete(bn_el)

    boons_list_elem.children = []

    bns = []

    if rarity <= 15:
        bns = structured_clone(BOONS.normal)
    elif rarity <= 35:
        bns = structured_clone(BOONS.rare)
        rarity_tag = "rare"
    else:
        bns = structured_clone(BOONS.epic)
        rarity_tag = "epic"

    # print(rarity_tag, [x.name for x in bns])

    available: list[Boon] = []

    for bn in bns:
        if bn.change == None:
            available.append(bn)
            continue

        if bn.change.startswith("g") and (
            bn.change.endswith(player.spells[0].name)
            or bn.change.endswith(player.spells[1].name)
        ):
            # bns.remove(bn)
            # print(f"Removed {bn.name}")
            continue

        if (bn.change == "u:s0" and player.spells[0].name == "Üres") or (
            bn.change == "u:s1" and player.spells[1].name == "Üres"
        ):
            # bns.remove(bn)
            # print(f"Removed {bn.name}")
            continue

        available.append(bn)

    if len(available) == 0:
        unreachable("Not enough boons to create boon menu")

    bns = [available.pop(random.randint(0, len(available) - 1)) for _ in range(3)]

    def grant_fn(bn: Boon) -> None:
        bn.grant_fn(),
        menus.toggle(id)
        round_manager.ROUND_STATE = "Wait"

    for index, bn in enumerate(bns):
        descr: list[string] = structured_clone(bn.description)

        title = bn.name

        for k, v in STRING_MAP.items():
            title = title.replace(k, v)
            for i, x in enumerate(descr):
                descr[i] = x.replace(k, v)

        el = new_boon_element(
            fruit=bn.fruit,
            boon_icon=bn.icon,
            boon_fn=caller(grant_fn, (bn,)),
            title=title,
            description=descr,
            child_num=index,
            rarity=rarity_tag,
        )
        el.parent = boons_list_elem

        boons_list_elem.children.append(el)

    menus.toggle(id)


# Boon defs


@mk_boon(
    "normal",
    "banana",
    "Ashwaganda",
    [
        "A körülötted lévő ellenfelek",
        "elaltatása 2 másodperc után.",
        "Ezt cseréli: %p.s1 (1)",
    ],
    "banana.png",
    "g:s1:" + enums.spells.Zzzz.name,
)
def _() -> None:
    enums.spells.Zzzz.effectiveness = 1
    player.spells[1] = enums.spells.Zzzz


@mk_boon(
    "normal",
    "banana",
    "Vitamin-mix",
    [
        "Másodpercenként visszatölti",
        "at életerőd egy részét.",
        "Ezt cseréli: %p.s0 (0)",
    ],
    "banana.png",
    "g:s0:" + enums.spells.HEALING.name,
)
def _() -> None:
    enums.spells.HEALING.effectiveness = 5
    player.spells[0] = enums.spells.HEALING


@mk_boon(
    "normal",
    "banana",
    "Kreatin",
    ["Nagyobb méret és több életerő", "15 másodpercig.", "Ezt cseréli: %p.s0 (0)"],
    "banana.png",
    "g:s0:" + enums.spells.GOLIATH.name,
)
def grant_goliath() -> None:
    enums.spells.GOLIATH.effectiveness = 1.25
    player.spells[0] = enums.spells.GOLIATH


@mk_boon(
    "normal", "banana", "%p.s0 fejlesztése", ["+1 hatékonyság"], "banana.png", "u:s0"
)
def _() -> None:
    player.spells[0].effectiveness += 1


@mk_boon(
    "normal", "banana", "%p.s1 fejlesztése", ["+1 hatékonyság"], "banana.png", "u:s1"
)
def _() -> None:
    player.spells[1].effectiveness += 1


# |> Rare


@mk_boon(
    "rare",
    "banana",
    "Pre workout",
    [
        "Bónusz mozgási- és támadási",
        "sebesség 5 másodpercig.",
        "Ezt cseréli: %p.s1 (1)",
        # "Alapvető hatékonyság: 6"
    ],
    "banana.png",
    "g:s1:" + enums.spells.HASTE.name,
)
def _() -> None:
    enums.spells.HASTE.effectiveness = 6
    player.spells[1] = enums.spells.HASTE


@mk_boon(
    "rare",
    "banana",
    "Ashwaganda x2",
    [
        "A körülötted lévő ellenfelek",
        "elaltatása 2 másodperc után.",
        "Ezt cseréli: %p.s1 (1)",
    ],
    "banana.png",
    "g:s1:" + enums.spells.Zzzz.name,
)
def _() -> None:
    enums.spells.Zzzz.effectiveness = 2
    player.spells[1] = enums.spells.Zzzz


@mk_boon(
    "rare",
    "banana",
    "Vitamin-mix x2",
    [
        "Másodpercenként visszatölti",
        "at életerőd egy részét.",
        "Ezt cseréli: %p.s0 (0)",
    ],
    "banana.png",
    "g:s0:" + enums.spells.HEALING.name,
)
def _() -> None:
    enums.spells.HEALING.effectiveness = 10
    player.spells[0] = enums.spells.HEALING


@mk_boon(
    "rare",
    "banana",
    "Kreatin x2",
    ["Nagyobb méret és több életerő", "15 másodpercig.", "Ezt cseréli: %p.s0 (0)"],
    "banana.png",
    "g:s0:" + enums.spells.GOLIATH.name,
)
def grant_goliath() -> None:
    enums.spells.GOLIATH.effectiveness = 2.5
    player.spells[0] = enums.spells.GOLIATH


@mk_boon(
    "rare", "banana", "%p.s0 fejlesztése", ["+2.5 hatékonyság"], "banana.png", "u:s0"
)
def _() -> None:
    player.spells[0].effectiveness += 2.5


@mk_boon(
    "rare", "banana", "%p.s1 fejlesztése", ["+2.5 hatékonyság"], "banana.png", "u:s1"
)
def _() -> None:
    player.spells[1].effectiveness += 2.5


@mk_boon(
    "rare", "banana", "%p.s0 fejlesztése", ["+3.25 hatékonyság"], "banana.png", "u:s0"
)
def _() -> None:
    player.spells[0].effectiveness += 3.25


@mk_boon(
    "rare", "banana", "%p.s1 fejlesztése", ["+3.25 hatékonyság"], "banana.png", "u:s1"
)
def _() -> None:
    player.spells[1].effectiveness += 3.25


# |> Epic


@mk_boon(
    "epic",
    "banana",
    "Pre workout + monster",
    [
        "Bónusz mozgási- és támadási",
        "sebesség 5 másodpercig.",
        "Ezt cseréli: %p.s1 (1)",
        # "Alapvető hatékonyság: 6"
    ],
    "banana.png",
    "g:s1:" + enums.spells.HASTE.name,
)
def _() -> None:
    enums.spells.HASTE.effectiveness = 9
    player.spells[1] = enums.spells.HASTE


@mk_boon(
    "epic",
    "banana",
    "Ashwaganda x3",
    [
        "A körülötted lévő ellenfelek",
        "elaltatása 2 másodperc után.",
        "Ezt cseréli: %p.s1 (1)",
    ],
    "banana.png",
    "g:s1:" + enums.spells.Zzzz.name,
)
def _() -> None:
    enums.spells.Zzzz.effectiveness = 4
    player.spells[1] = enums.spells.Zzzz


@mk_boon(
    "epic",
    "banana",
    "Vitamin mix x3",
    [
        "Másodpercenként visszatölti",
        "at életerőd egy részét.",
        "Ezt cseréli: %p.s0 (0)",
    ],
    "banana.png",
    "g:s0:" + enums.spells.HEALING.name,
)
def _() -> None:
    enums.spells.HEALING.effectiveness = 25
    player.spells[0] = enums.spells.HEALING


@mk_boon(
    "epic",
    "banana",
    "Kreatin x3",
    ["Nagyobb méret és több életerő", "15 másodpercig.", "Ezt cseréli: %p.s0 (0)"],
    "banana.png",
    "g:s0:" + enums.spells.GOLIATH.name,
)
def grant_goliath() -> None:
    enums.spells.GOLIATH.effectiveness = 5
    player.spells[0] = enums.spells.GOLIATH


@mk_boon(
    "epic", "banana", "%p.s0 fejlesztése", ["+5 hatékonyság"], "banana.png", "u:s0"
)
def _() -> None:
    player.spells[0].effectiveness += 5


@mk_boon(
    "epic", "banana", "%p.s1 fejlesztése", ["+5 hatékonyság"], "banana.png", "u:s1"
)
def _() -> None:
    player.spells[1].effectiveness += 5


@mk_boon(
    "epic", "banana", "%p.s0 fejlesztése", ["+7.5 hatékonyság"], "banana.png", "u:s0"
)
def _() -> None:
    player.spells[0].effectiveness += 7.5


@mk_boon(
    "epic", "banana", "%p.s1 fejlesztése", ["+7.5 hatékonyság"], "banana.png", "u:s1"
)
def _() -> None:
    player.spells[1].effectiveness += 7.5


# --- Strawberry ---


@mk_boon(
    "normal",
    "strawberry",
    "Aluljárós gyros",
    ["Megnöveli a mozgási sebességet.", "+20 mozgási sebesség"],
    "strawberry.png",
)
def _() -> None:
    player.base_movement_speed += 20
    player.movement_speed = player.base_movement_speed


@mk_boon(
    "normal",
    "strawberry",
    "Hústorony",
    ["+20 sebzés"],
    "strawberry.png",
)
def _() -> None:
    player.base_damage += 20


@mk_boon(
    "normal",
    "strawberry",
    "Anabolyc Tren",
    ["+25 maximum életerő."],
    "strawberry.png",
)
def _() -> None:
    player.max_hitpoints += 25
    player.hitpoints += 25


@mk_boon("normal", "strawberry", "Több mana", ["+10 maximum mana."], "strawberry.png")
def _() -> None:
    player.max_mana += 10
    player.mana += 10


# |> Rare


@mk_boon(
    "rare",
    "strawberry",
    "Steroid shot",
    ["+50 maximum életerő."],
    "strawberry.png",
)
def _() -> None:
    player.max_hitpoints += 50
    player.hitpoints += 50


@mk_boon(
    "rare",
    "strawberry",
    "Csábító Hústorony",
    ["+35 sebzés"],
    "strawberry.png",
)
def _() -> None:
    player.base_damage += 35


@mk_boon(
    "rare",
    "strawberry",
    "Nike Blazer",
    ["+1 ugrás"],
    "strawberry.png",
)
def _() -> None:
    player.dash_count += 1


@mk_boon(
    "rare",
    "strawberry",
    "Asszonyverő atléta",
    ["+1 támadási sebesség"],
    "strawberry.png",
)
def _() -> None:
    player.base_attack_speed += 1


# |> Epic


@mk_boon(
    "epic",
    "strawberry",
    "Anabolyc Tren",
    ["+100 maximum életerő."],
    "strawberry.png",
)
def _() -> None:
    player.max_hitpoints += 100
    player.hitpoints += 100


@mk_boon(
    "epic",
    "strawberry",
    "Nike ow blazer",
    ["+1 ugrás", "+100 mozgási sebesség"],
    "strawberry.png",
)
def _() -> None:
    player.dash_count += 1
    if player.base_movement_speed < 600:
        player.base_movement_speed += 100
        return
    player.base_movement_speed += 50
    player.movement_speed = player.base_movement_speed


@mk_boon(
    "epic",
    "strawberry",
    "Ellenállhatatlan Hústorony",
    ["+50 sebzés"],
    "strawberry.png",
)
def _() -> None:
    player.base_damage += 50


# --- Blueberry ---


@mk_boon(
    "normal",
    "blueberry",
    "Új pr",
    ["+10% sebzés künnyű támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[0].light_damage_multiplier += 0.1


@mk_boon(
    "normal",
    "blueberry",
    "Új pr",
    ["+10% sebzés nehéz támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[0].heavy_damage_multiplier += 0.1


@mk_boon(
    "normal",
    "blueberry",
    "Új pr",
    ["+10% sebzés ugró támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[0].dash_damage_multiplier += 0.1


@mk_boon(
    "normal",
    "blueberry",
    "Boxkesztyű Fejlesztés",
    ["+10% sebzés künnyű támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[1].light_damage_multiplier += 0.1


@mk_boon(
    "normal",
    "blueberry",
    "Boxkesztyű Fejlesztés",
    ["+10% sebzés nehéz támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[1].heavy_damage_multiplier += 0.1


@mk_boon(
    "normal",
    "blueberry",
    "Boxkesztyű Fejlesztés",
    ["+10% sebzés ugró támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[1].dash_damage_multiplier += 0.1


# |> Rare


@mk_boon(
    "rare",
    "blueberry",
    "Széles Súlylemez",
    ["+25% szélesség könnyű támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[0].light_size.x *= 1.25


@mk_boon(
    "rare",
    "blueberry",
    "Széles Boxkesztyű",
    ["+25% szélesség könnyű támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[0].light_size.x *= 1.25


@mk_boon(
    "rare",
    "blueberry",
    "Széles Súlylemez",
    ["+15% szélesség nehéz támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[0].heavy_size.x *= 1.15


@mk_boon(
    "rare",
    "blueberry",
    "Széles Boxkesztyű",
    ["+15% szélesség nehéz támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[1].heavy_size.x *= 1.15


@mk_boon(
    "rare",
    "blueberry",
    "Széles Súlylemez",
    ["+10% szélesség ugró támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[0].dash_size.x *= 1.1


@mk_boon(
    "rare",
    "blueberry",
    "Széles Boxkesztyű",
    ["+10% szélesség nehéz támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[1].dash_size.x *= 1.1


# |> Epic


@mk_boon(
    "epic",
    "blueberry",
    "Széles Súlylemez",
    ["+50% szélesség könnyű támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[0].light_size.x *= 1.5


@mk_boon(
    "epic",
    "blueberry",
    "Széles Boxkesztyű",
    ["+50% szélesség könnyű támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[1].light_size.x *= 1.5


@mk_boon(
    "epic",
    "blueberry",
    "Széles Súlylemez",
    ["+35% szélesség nehéz támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[0].heavy_size.x *= 1.35


@mk_boon(
    "epic",
    "blueberry",
    "Széles Boxkesztyű",
    ["+35% szélesség nehéz támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[1].heavy_size.x *= 1.35


@mk_boon(
    "epic",
    "blueberry",
    "Széles Súlylemez",
    ["+25% szélesség ugró támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[0].dash_size.x *= 1.25


@mk_boon(
    "rare",
    "blueberry",
    "Széles Boxkesztyű",
    ["+25% szélesség nehéz támadáskor"],
    "blueberry.png",
)
def _() -> None:
    player.weapons[1].dash_size.x *= 1.25