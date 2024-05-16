
from saves import Loader
from events import *
import items

@spawn
def _spw():
    Loader.load(False)