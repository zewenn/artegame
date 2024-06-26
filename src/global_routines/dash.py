from brass.base import *

from brass import events, pgapi, timeout, scene, enums

DASH_OBJECTS: list[Dasher] = []


def remove_invulnerable(item: Item) -> None:
    item.invulnerable = False


@scene.update(enums.scenes.GAME)
def upd_dash():
    for dsh_obj in copy.copy(DASH_OBJECTS):
        if pgapi.TIME.current > dsh_obj.start_time + dsh_obj.time:
            DASH_OBJECTS.remove(dsh_obj)
            dsh_obj.this.can_move = True
            dsh_obj.this.movement_speed = dsh_obj.this.base_movement_speed
            # dsh_obj.this.invulnerable = False
            timeout.new(.1, remove_invulnerable, (dsh_obj.this,))
            dsh_obj.this.dashing = False
            continue

        dsh_obj.this.transform.position.y += (
            dsh_obj.this.movement_speed * pgapi.TIME.deltatime * dsh_obj.towards.end.y
        )
        dsh_obj.this.transform.position.x += (
            dsh_obj.this.movement_speed * pgapi.TIME.deltatime * dsh_obj.towards.end.x
        )


def apply_dash_effect(
    this: Item, move_vec: CompleteMathVector, speed_multiplier: float, timeMS: int
) -> None:
    # print(this.dashes_remaining)

    this.can_move = False
    this.dashing = True
    this.movement_speed = this.base_movement_speed * speed_multiplier

    start_t = pgapi.TIME.current

    DASH_OBJECTS.append(
        Dasher(this, move_vec, speed_multiplier, timeMS / 1000, start_t)
    )
