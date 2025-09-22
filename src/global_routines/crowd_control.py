from brass.base import *

from brass import items, timeout
from . import effect_display


EFFECT_TYPES = Literal["slow", "root", "stun", "sleep", "all"]


def cleanse(item: Item, effect: EFFECT_TYPES) -> None:
    if effect == "all":
        item.slowed_by_percent = 0
        item.rooted = False
        item.stunned = False
        item.sleeping = False
        return

    if effect == "slow":
        item.slowed_by_percent = 0
        return

    if effect == "root":
        item.rooted = False
        return

    if effect == "stun":
        item.stunned = False
        return

    if effect == "sleep":
        item.sleeping = False
        return


def apply_sleep(to: Item, length: Number) -> None:
    to.sleeping = True

    if to.transform is None:
        return

    timeout.new(length, cleanse, (to, "sleep"))
    effect_display.summon(
        to.transform,
        [
            "sleep_effect.png",
        ],
        length,
        length,
    )


def apply(
    to: Item,
    T_type: EFFECT_TYPES,
    length: Number,
    slow_pecent: Number = 50,
    sleep_countdown: Number = 1,
    show_effect: bool = False,
) -> None:
    if T_type == "all":
        print("Cannot apply all effects!")
        return

    if T_type == "sleep":
        timeout.new(sleep_countdown, apply_sleep, (to, length))
        return

    timeout.new(length, cleanse, (to, T_type))

    if T_type == "slow":
        to.slowed_by_percent = float(slow_pecent)
        return

    if T_type == "root":
        to.rooted = True
        return

    if T_type == "stun":
        to.stunned = True
        if show_effect and to.transform is not None:
            effect_display.summon(
                to.transform,
                [
                    "stun_effect_1.png",
                    "stun_effect_2.png",
                    "stun_effect_3.png",
                    "stun_effect_4.png",
                ],
                1,
                0.3,
            )
        return
