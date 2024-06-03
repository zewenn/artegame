from brass.base import *

from brass import items, timeout, scene, enums, gui
from global_routines import effect_display, menus


NEXT_BOON_OPTIONS: Optional[Inventory] = None
player: Optional[Item] = None


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

def show_boon_selection_menu() -> None:
    id = "BoonSelectionMenu"

    menus.toggle(id)