import os
from classes import *


class Events:
    __events_dict: dict[str, list[Event]] = {}

    @classmethod
    def script(this, init: Optional[Callable] = None, update: Optional[Callable] = None):
        if init is not None:
            this.subscribe("init", init)
        if update is not None:
            this.subscribe("update", update)

    @classmethod
    def subscribe(this, event_name: str, callback: Callable) -> None:
        if not this.__events_dict.get(event_name):
            this.__events_dict[event_name] = []
        this.__events_dict[event_name].append(Event(callable.__name__, callback))

    @classmethod
    def call(this, event_name: str):
        if not this.__events_dict.get(event_name):
            return
        for event in this.__events_dict.get(event_name):
            event.callback()

    @classmethod
    def awake(this):
        this.call("awake")

    @classmethod
    def init(this):
        this.call("init")

    @classmethod
    def update(this):
        this.call("update")


def awake(func: Callable) -> None:
    Events.subscribe("awake", func)

def init(func: Callable) -> None:
    Events.subscribe("init", func)

def update(func: Callable) -> None:
    Events.subscribe("update", func)