import os
from classes import *
from entities import *


class Events:
    class ids:
        awake: str = "evn::awake"
        initalise: str = "evn::initalise"
        update: str = "evn::update"
    
    current_scene: Optional[any] = None
    update_name: Optional[str] = "NONE"
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
    def system_update(this) -> None:
        this.call(this.ids.update)
        
        if this.update_name != "NONE":
            this.call(this.update_name)

    @classmethod
    def set_update_name(this, to: str) -> None:
        this.update_name = to

    @classmethod
    def awake(this, func: Callable) -> None:
        Events.subscribe(this.ids.awake, func)

    @classmethod
    def init(this, func: Callable) -> None:
        Events.subscribe(this.ids.initalise, func)

    @classmethod
    def update(this, func: Callable) -> None:
        Events.subscribe(this.ids.update, func)


class Scene:
    def __init__(self, name: str) -> None:
        self.id: str = name
        self.items: list[Item] = []

    def spawn(self, fn: Callable) -> None:
        Events.subscribe(f"{self.id}::spawn", fn)

    def awake(self, fn: Callable) -> None:
        Events.subscribe(f"{self.id}::awake", fn)
    
    def initalise(self, fn: Callable) -> None:
        Events.subscribe(f"{self.id}::initalise", fn)
    
    def update(self, fn: Callable) -> None:
        Events.subscribe(f"{self.id}::update", fn)

    def quit(self, fn: Callable) -> None:
        Events.subscribe(f"{self.id}::quit", fn)

    def load(self):
        if Events.current_scene:
            Events.current_scene.close()
        Events.current_scene = self

        Events.call(f"{self.id}::spawn")
        Events.call(f"{self.id}::awake")
        Events.call(f"{self.id}::initalise")

        Events.set_update_name(f"{self.id}::update")
    
    def close(self):
        self.items = Items.rendering
        Items.rendering = []

        Events.call(f"{self.id}::quit")