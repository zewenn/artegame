
from saves import Loader
from events import Events
from pgapi import SCENES
from entities import Items

@SCENES.default.spawn
def game_scene_spawn():
    Loader.load(False)

@Events.awake
def awake():
    SCENES.default.load()




