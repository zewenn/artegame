
from saves import Loader
from events import *
from entities import Items

@spawn
def _spw():
    Loader.load(False)