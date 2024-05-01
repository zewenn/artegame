import os
from classes import *


class events:
    class ids:
        awake: str = "evn::awake"
        initalise: str = "evn::initalise"
        update: str = "evn::update"
    
    event_map: dict[str, list[Event]] = {}

    @classmethod
    def subscribe(this, event_name: str, callback: Callable) -> None:
        if not this.event_map.get(event_name):
            this.event_map[event_name] = []
        this.event_map[event_name].append(Event(callable.__name__, callback))

    @classmethod
    def call(this, event_name: str):
        if not this.event_map.get(event_name):
            return
        for event in this.event_map.get(event_name):
            event.callback()

    @classmethod
    def awake(this, func: Callable) -> None:
        events.subscribe(this.ids.awake, func)

    @classmethod
    def init(this, func: Callable) -> None:
        events.subscribe(this.ids.initalise, func)

    @classmethod
    def update(this, func: Callable) -> None:
        events.subscribe(this.ids.update, func)