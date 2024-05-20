from classes import *
from events import Events
import pgapi

dashers: list[Dasher] = []


@Events.update
def upd_dash():
    global dashers
    for e in dashers:
        pass


def apply_dash_effect(
    this: Item, move_vec: CompleteMathVector, speed_multiplier: float, timeMS: int
) -> None:
    this.can_move = False
    this.movement_speed = this.base_movement_speed * speed_multiplier

    start_t = pgapi.TIME.current

    def dash():
        this.transform.position.y += (
            this.movement_speed * pgapi.TIME.deltatime * move_vec.end.y
        )
        this.transform.position.x += (
            this.movement_speed * pgapi.TIME.deltatime * move_vec.end.x
        )
        if not start_t + timeMS < pgapi.TIME.current:
            this.can_move = True
            return
