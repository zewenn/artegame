from ..animator import interpolation


class MODES:
    NORMAL = "Normal"
    FORWARD = "Forwards"


class TIMING:
    LINEAR = interpolation.lerp
    EASE_IN = interpolation.ease_in
    EASE_OUT = interpolation.ease_out
    EASE_IN_OUT = interpolation.ease_in_out
