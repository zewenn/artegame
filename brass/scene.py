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

    events.set_update_name(f"{scene}::update")


def close(scene: str) -> None:
    pgapi.SETTINGS.menu_mode = False
    items.rendering = []
    gui.buttons = []
    gui.selected_button_index = 0
    gui.query_available = []
    gui.DOM_El.children = []

    events.call(f"{scene}::quit")
