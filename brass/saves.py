from .base import *

from copy import deepcopy
from result import *
import zenyx
from . import (
    pgapi,
    items,
    gui
)
import os

def path(pth_string: str) -> str:
    pth: list[str] = pth_string.split("/")

    for index, pth_part in enumerate(pth):
        if pth_part == "~":
            pth[index] = os.path.expanduser(pth_part)

    return os.path.realpath(os.path.join(*pth))


SAVES_DIR: Optional[str] = None
SLOTS: list[dict[str, Any]] = []
SLOT: int = 0


def create_save_dir() -> Result[None, Mishap]:
    global SAVES_DIR

    try:
        if SAVES_DIR is None:
            SAVES_DIR = (
                path(pgapi.SETTINGS.demo_save_path)
                if pgapi.SETTINGS.is_demo
                else path(pgapi.SETTINGS.save_path)
            )

        if os.path.isdir(SAVES_DIR):
            return Err(Mishap(f"{SAVES_DIR} already exists!"))
        os.mkdir(SAVES_DIR)

        for slot_num in range(4):
            pth = path(f"{SAVES_DIR}/slot_{slot_num}")

            if os.path.isdir(pth):
                return Err(Mishap(f"{pth} already exists!"))

            os.mkdir(pth)

        return Ok(None)
    except Exception as e:
        print(f"An exception occured while creating the save directories: {e}")
        return Err(Mishap(f"An error occured: {e}", True))


def select_slot(num: Literal[0, 1, 2, 3]) -> None:
    global SLOT
    SLOT = num


def load() -> Result[None, Mishap]:
    create_res = create_save_dir()

    if create_res.is_err():
        res = create_res.err()
        if res.is_fatal():
            return Err(Mishap("Couldn't create the save dir!", True))

    item_file = os.path.join(SAVES_DIR, f"slot_{SLOT}", "items.json")
    # gui_file = os.path.join(SAVES_DIR, f"slot_{SLOT}", "gui.json")

    items_loaded: Result[list[Item], Mishap] = attempt(
        zenyx.pyon.load, (item_file,)
    )
    # gui_loaded: Result[list[GUIElement], Mishap] = attempt(
    #     zenyx.pyon.load, (gui_file,)
    # )

    if items_loaded.is_err():
        return Err(Mishap("Couldn't load save files!", True))
    
    items.rendering = items_loaded.ok()
    # IF YOU ENABLE THIS IT WON'T HELP
        # The gui cannot be saved, max recursion depth will be exceeded
        # Also it kinda has no point since we override this anyway
    # gui.DOM(*(gui_loaded.ok()))

    return Ok(None)


def delete_files_in_directory(directory_path):
    try:
        files = os.listdir(directory_path)
        for filename in files:
            file_path = os.path.join(directory_path, filename)

            if os.path.isfile(file_path):
                os.remove(file_path)
            
    except OSError as e:
        print("Error occurred while deleting files: \n", e)


def delete_save() -> None:
    create_res = create_save_dir()
    if create_res.is_err():
        res = create_res.err()
        if res.is_fatal():
            return

    del_dir = os.path.join(SAVES_DIR, f"slot_{SLOT}")
    delete_files_in_directory(del_dir)


def save() -> Result[None, Mishap]:
    create_res = create_save_dir()

    if create_res.is_err():
        res = create_res.err()
        if res.is_fatal():
            return Err(Mishap("Couldn't create the save dir!", True))

    item_file = os.path.join(SAVES_DIR, f"slot_{SLOT}", "items.json")
    # gui_file = os.path.join(SAVES_DIR, f"slot_{SLOT}", "gui.json")

    zenyx.pyon.dump(deepcopy(items.rendering), item_file)
    # IF YOU ENABLE THIS IT WON'T HELP
        # The gui cannot be saved, max recursion depth will be exceeded
        # Also it kinda has no point since we override this anyway
    # zenyx.pyon.dump(deepcopy(gui.DOM_El.children), gui_file)

    return Ok(None)
