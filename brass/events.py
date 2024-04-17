import os
from classes import Event


class Events:
    __events_dict: dict[str, list[Event]] = {}

    @classmethod
    def script(this, init: callable or None = None, update: callable or None = None):
        if init is not None:
            this.subscribe("init", init)
        if update is not None:
            this.subscribe("update", update)

    @classmethod
    def subscribe(this, event_name: str, callback: callable) -> None:
        if not this.__events_dict.get(event_name):
            this.__events_dict[event_name] = []
        this.__events_dict[event_name].append(Event(callable.__name__, callback))

    @classmethod
    def trigger(this, event_name: str):
        for event in this.__events_dict.get(event_name):
            event.callback()

    @classmethod
    def init(this):
        this.trigger("init")

    @classmethod
    def update(this):
        this.trigger("update")


def init(func: callable) -> callable:
    Events.subscribe("init", func)

def update(func: callable) -> callable:
    Events.subscribe("update", func)