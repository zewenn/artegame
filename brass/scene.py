from .base import *

from . import (
    animator,
    pgapi,
    items,
    events,
    gui
)

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


def scene_quit(scene: str) -> None:
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
    pgapi.SETTINGS.background_image = None
    # items.rendering = []

    # item_list = copy.copy(items.rendering)
    # del item_list[::]
    animator.reset()
    items.reset()

    # print("Items rendering: ", items.rendering, item_list)
    # gui.buttons = []
    gui.reset()

    events.call(f"{scene}::quit")


def pause() -> None:
    events.set_update_name("NONE")


def resume(scene: string) -> None:
    events.set_update_name(f"{scene}::update")
