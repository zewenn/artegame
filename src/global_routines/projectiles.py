from brass.base import *

from brass import (
    vectormath,
    collision,
    events,
    pgapi,
    items
)


PROJECTILES: list[Item] = []


@events.update
def system_update() -> None:
    global PROJECTILES

    for projectile in PROJECTILES:
        if pgapi.TIME.current > projectile.life_start + projectile.lifetime_seconds:
            PROJECTILES.remove(projectile)
            items.rendering.remove(projectile)
            continue
        
        move_vec = vectormath.new(start=Vec2(), magnitude=1, direction=(-projectile.facing + 90))

        projectile.transform.position.y += (
            projectile.movement_speed * pgapi.TIME.deltatime * move_vec.end.y
        )
        projectile.transform.position.x += (
            projectile.movement_speed * pgapi.TIME.deltatime * move_vec.end.x
        )


def new(
    sprite: string,
    pos: Vec2,
    scale: Vec2,
    direction: Number,
    lifetime_seconds: Number,
    speed: Number,
    team: Literal["Player", "Enemy"]
) -> Item:
    return Item(
        id=f"Projectile-{uuid()}",
        tags=["projectile", "item"],
        transform=Transform(position=pos, rotation=Vec3(0, 0, direction), scale=scale),
        facing=direction,
        sprite=sprite,
        base_movement_speed=speed,
        movement_speed=speed,
        is_projectile=True,
        lifetime_seconds=lifetime_seconds,
        life_start=pgapi.TIME.current,
        team=team
    )


def shoot(projectile: Item) -> None:
    if not projectile.is_projectile:
        printf(f"Cannot shoot non-projectile Item: {projectile.id}")
        return

    items.add_to_scene(projectile)
    PROJECTILES.append(projectile)
