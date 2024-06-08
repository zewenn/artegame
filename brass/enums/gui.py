from ..base import *

class FONT_SIZE:
    EXTRA_SMALL = 8
    SMALL = 12
    MEDIUM = 16
    BIG = 20
    LARGE = 32
    EXTRA_LARGE = 64


class FONTS:
    DEFAULT: str = "inter.ttf"
    INTER: str = "inter.ttf"
    PRESS_PLAY: str = "press_play.ttf"
    JETBRAINSMONO: str = "JetBrainsMono.ttf"


class COLOURS:
    WHITE: Colour = (255, 255, 255, 1)
    BLACK: Colour = (0, 0, 0, 1)
    RED: Colour = (225, 40, 40, 1)
    CUSTOM_RED: Colour = (154, 3, 20, 1)
    YELLOW: Colour = (251, 139, 36, 1)
    GREEN: Colour = (0, 255, 0, 1)
    BLUE: Colour = (0, 0, 255, 1)
    LIGHTBLUE: Colour = (20, 120, 220, 1)
    NIGHT_BLUE: Colour = (34, 34, 59, 1)
    MENUS_BACKDROP: Colour = (0, 0, 0, .8) 


class POSITION:
    ABSOLUTE = "absolute"
    RELATIVE = "relative"

class DISPLAY:
    NONE = "none"
    BLOCK = "block"