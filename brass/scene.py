from base import *

import events
import pgapi
import items
import gui


def spawn(scene: str) -> None:
    def wrap(fn: Callable):
        events.on(f"{scene}::spawn", fn)

    return wrap


def awake(scene: str) -> None:
    def wrap(fn: Callable):
        events.on(f"{scene}::awake", fn)

    return wrap


def init(scene: str) -> None:
    def wrap(fn: Callable):
        events.on(f"{scene}::init", fn)

    return wrap


def update(scene: str) -> None:
    def wrap(fn: Callable):
        events.on(f"{scene}::update", fn)

    return wrap


def quit(scene: str) -> None:
    def wrap(fn: Callable):
        events.on(f"{scene}::quit", fn)

    return wrap


def load(scene: str) -> None:
    if events.current_scene:
        close(events.current_scene)
    events.current_scene = scene

    events.call(f"{scene}::spawn")
    events.call(f"{scene}::awake")
    events.call(f"{scene}::init")

    # print(items.rendering)

    events.set_update_name(f"{scene}::update")


def close(scene: str) -> None:
    pgapi.SETTINGS.menu_mode = False
    # items.rendering = []

    # item_list = copy.copy(items.rendering)
    # del item_list[::]
    items.reset()
    
    # print("Items rendering: ", items.rendering, item_list)
    # gui.buttons = []
    for x in gui.buttons:
        gui.buttons.remove(x)
    gui.selected_button_index = 0
    # gui.query_available = []
    for x in gui.query_available:
        gui.query_available.remove(x)
    gui.DOM_El.children = []

    events.call(f"{scene}::quit")
