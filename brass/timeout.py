from .base import *

from . import (
    events,
    pgapi
)


TIMEOUTS: list[Timeout] = []


@events.update
def update() -> None:
    for to in TIMEOUTS:
        if to.interval + to.start_time < pgapi.TIME.current:
            to.fn(*to.args)
            # pylint: disable = modified-iterating-list
            TIMEOUTS.remove(to)
            # pylint: enable = modified-iterating-list


def new(interval: Number, fn: Callable[..., None], args: Tuple) -> None:
    TIMEOUTS.append(
        Timeout(interval=interval, fn=fn, args=args, start_time=pgapi.TIME.current)
    )
