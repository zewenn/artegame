from brass.base import *

# fmt: off
from global_routines import projectiles, dash, crowd_control
from brass import (
    items, 
    pgapi, 
    scene,
    enums, 
    vectormath,
    collision,
    timeout,
    animator
)
# fmt: on


def summon(at: Item, sprites: list[string], length: Number) -> None:
    uid = "effect:" + uuid()
    effect = Item(
        id=uid, tags=["effect_display"], transform=at.transform, sprite=sprites[0]
    )
    items.add(effect)

    sprites = [sprites[0]] + sprites

    num_of_keyframes = len(sprites)
    kf_increment = 100 / num_of_keyframes

    print("kfi:", kf_increment)

    keyframes: dict[int, Keyframe] = {}

    for i in range(num_of_keyframes):
        keyframes[round(kf_increment * i)] = Keyframe(sprite=sprites[i])

    animator.play(
        animator.create(
            duration_seconds=uid,
            mode=enums.animations.MODES.NORMAL,
            timing_function=enums.animations.TIMING.LINEAR,
            animations=[Animation(effect.id, keyframes)],
        )
    )

    def deL_obj():
        items.remove(effect)
        # del effect

    timeout.set(length, deL_obj, ())
