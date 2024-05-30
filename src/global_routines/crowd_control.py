from brass.base import *

from brass import items, timeout
from threading import Timer


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


def apply(
    to: Item,
    T: EFFECT_TYPES,
    length: Number,
    slow_pecent: Number = 50,
    sleep_countdown: Number = 1,
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
        return
