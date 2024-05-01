
from saves import Loader
from events import events

@events.awake
def awake():
    Loader.load(False)
    # Loader.load()


