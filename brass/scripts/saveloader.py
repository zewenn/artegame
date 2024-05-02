
from saves import Loader
from events import Events
from pgapi import SCENES

@SCENES.default.spawn
def spawn():
    Loader.load()

@Events.awake
def awake():
    SCENES.default.load()




