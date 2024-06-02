from brass.base import *

from brass import items, timeout, scene, enums
from global_routines import effect_display


NEXT_BOON_OPTIONS: Optional[Inventory] = None


@scene.awake(enums.scenes.GAME)
def awake() -> None:
    global NEXT_BOON_OPTIONS
    
    NEXT_BOON_OPTIONS = Inventory()