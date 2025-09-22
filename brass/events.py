from .base import *


class IDS:
    awake: str = "evn::awake"
    init: str = "evn::init"
    update: str = "evn::update"


current_scene: str = None
update_name: Optional[str] = "NONE"
event_map: dict[str, list[Event]] = {}


def on(event_name: str, callback: Callable) -> None:
    if not event_map.get(event_name):
        event_map[event_name] = []
    event_map[event_name].append(Event(callable.__name__, callback))


def call(event_name: str):
    if not event_map.get(event_name):
        return
    for event in event_map.get(event_name):
        event.callback()


def system_update() -> None:
    call(IDS.update)

    if update_name != "NONE":
        call(update_name)


def set_update_name(to: str) -> None:
    global update_name
    update_name = to


def awake(func: Callable) -> None:
    on(IDS.awake, func)


def init(func: Callable) -> None:
    on(IDS.init, func)


def update(func: Callable) -> None:
    on(IDS.update, func)
