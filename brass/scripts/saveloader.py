
from saves import Loader
from events import awake, init, update

@awake
def awake():
    Loader.load()


