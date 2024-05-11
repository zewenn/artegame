from scenenum import SCENES

from saves import Loader
from events import *
from entities import Items

@SCENES.DEFAULT.spawn
def _spw():
    Loader.load(False)