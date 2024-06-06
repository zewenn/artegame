from brass.base import *

from brass import items, timeout
from global_routines import effect_display


EFFECT_TYPES = Literal["slow", "root", "stun", "sleep", "all"]


def cleanse(item: Item, effect: EFFECT_TYPES) -> None:
    # print(f"Removing \"{effect}\" from \"{item.id}\" item")
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
    # print("Sleeping", to.id, to.sleeping)
    timeout.set(length, cleanse, (to, "sleep"))
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
    T: EFFECT_TYPES,
    length: Number,
    slow_pecent: Number = 50,
    sleep_countdown: Number = 1,
    show_effect: bool = False,
) -> None:
    if T == "all":
        print("Cannot apply all effects!")
        return

    # print(T, to.id, to.uuid)

    if T == "sleep":
        timeout.set(sleep_countdown, apply_sleep, (to, length))
        return

    timeout.set(length, cleanse, (to, T))

    if T == "slow":
        to.slowed_by_percent = slow_pecent
        return

    if T == "root":
        to.rooted = True
        return

    if T == "stun":
        to.stunned = True
        if show_effect:
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
