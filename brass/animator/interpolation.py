"""
`interpolation_factor` or `t`:  represents how far we are in the 
                                interpolation process. In other words 
                                it's like a percentage: .5 is 50%.
"""

from ..base import *



def lerp(start: Number, end: Number, interpolation_factor: Number) -> Number:
    """Linear interpolation function."""
    return start + interpolation_factor * (end - start)


def ease_in(start: Number, end: Number, interpolation_factor: Number) -> Number:
    """Ease-in timing function."""
    return lerp(start, end, interpolation_factor * interpolation_factor)


def ease_out(start: Number, end: Number, interpolation_factor: Number) -> Number:
    """Ease-out timing function."""
    return lerp(
        start, end, (1 - (1 - interpolation_factor) * (1 - interpolation_factor))
    )


def ease_in_out(start: Number, end: Number, interpolation_factor: Number) -> Number:
    """Ease-in-out timing function."""
    return lerp(
        start,
        end,
        (
            interpolation_factor * interpolation_factor * (3 - 2 * interpolation_factor)
            if interpolation_factor < 0.5
            else 1
            - (1 - interpolation_factor)
            * (1 - interpolation_factor)
            * (3 - 2 * (1 - interpolation_factor))
        ),
    )


def interpolate_keyframes(
    timing_fn: Callable[[Number, Number, Number], Number],
    keyframe_a,
    keyframe_b,
    interpolation_factor,
) -> Keyframe:
    """Interpolate between two KeyframeT objects."""
    interpolated_keyframe = Keyframe()

    for field in keyframe_a.__annotations__:
        value1 = getattr(keyframe_a, field)
        value2 = getattr(keyframe_b, field)

        if isinstance(value1, (int, float)) and isinstance(value2, (int, float)):
            # Linear interpolation for numerical values
            interpolated_value = timing_fn(value1, value2, interpolation_factor)
            setattr(interpolated_keyframe, field, interpolated_value)
        else:
            if interpolation_factor == 1:
                # Handle non-numeric values (e.g., colors, sprites)
                setattr(interpolated_keyframe, field, value2)
            else:
                setattr(interpolated_keyframe, field, value1)

    return interpolated_keyframe
