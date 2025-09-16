from ..animator import interpolation
from typing import *  # type: ignore


class MODES:
    NORMAL = "Normal"
    FORWARD = "Forwards"


class TIMING:
    LINEAR: Callable[[float, float, float], float] = interpolation.lerp
    EASE_IN: Callable[[float, float, float], float] = interpolation.ease_in
    EASE_OUT: Callable[[float, float, float], float] = interpolation.ease_out
    EASE_IN_OUT: Callable[[float, float, float], float] = interpolation.ease_in_out
