from brass.base import *

# fmt: off
from brass import (
    animator,
    timeout,
    items, 
    enums
)
# fmt: on


def summon(at: Transform, sprites: list[string], length: Number, anim_len: Number) -> None:
    uid = "effect:" + uuid()
    effect = Item(
        id=uid, tags=["effect_display"], transform=at, sprite=sprites[0]
    )
    items.add(effect)

    sprites = sprites * math.ceil(length / anim_len)

    num_of_keyframes = len(sprites)
    kf_increment = 100 / num_of_keyframes

    keyframes: dict[int, Keyframe] = {}

    for i in range(num_of_keyframes):
        k = round(kf_increment * i)
        keyframes[k if k > 0 else 1] = Keyframe(sprite=sprites[i])

    anim = animator.create(
        duration_seconds=length,
        mode=enums.animations.MODES.FORWARD,
        timing_function=enums.animations.TIMING.LINEAR,
        animations=[Animation(uid, keyframes)],
    )

    animator.play(anim)

    def del_obj():
        items.remove(effect)
        # del effect

    timeout.new(length, del_obj, ())

    