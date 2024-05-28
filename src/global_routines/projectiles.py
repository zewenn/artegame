from brass.base import *

from brass import vectormath, collision, events, pgapi, items


PROJECTILES: list[Item] = []


def rm_projectile(proj: Item) -> None:
    PROJECTILES.remove(proj)
    items.remove(proj)


@events.update
def system_update() -> None:
    global PROJECTILES

    for projectile in PROJECTILES:
        if pgapi.TIME.current > projectile.life_start + projectile.lifetime_seconds:
            rm_projectile(projectile)
            continue

        move_vec = vectormath.new(
            start=Vec2(), magnitude=1, direction=(-projectile.facing + 90)
        )

        projectile.transform.position.y += (
            projectile.movement_speed * pgapi.TIME.deltatime * move_vec.end.y
        )
        projectile.transform.position.x += (
            projectile.movement_speed * pgapi.TIME.deltatime * move_vec.end.x
        )

        for item in items.rendering:
            if (
                not item.can_collide
                or item.team == projectile.team
                or not item.hitpoints
            ):
                continue

            if collision.collides(projectile.transform, item.transform):
                item.hitpoints -= projectile.projectile_damage
                rm_projectile(projectile)
            
            if item.hitpoints <= 0:
                match item.team:
                    case "Player":
                        return
                    case "Enemy":
                        items.rendering.remove(item)
                        del item

def new(
    sprite: string,
    position: Vec2,
    scale: Vec2,
    direction: Number,
    lifetime_seconds: Number,
    speed: Number,
    team: Literal["Player", "Enemy"],
    damage: Number,
) -> Item:
    return Item(
        id=f"Projectile-{uuid()}",
        tags=["projectile", "item"],
        transform=Transform(position=position, rotation=Vec3(0, 0, direction), scale=scale),
        facing=direction,
        sprite=sprite,
        base_movement_speed=speed,
        # can_collide=True,
        movement_speed=speed,
        is_projectile=True,
        lifetime_seconds=lifetime_seconds,
        life_start=pgapi.TIME.current,
        team=team,
        projectile_damage=damage,
    )


def shoot(projectile: Item) -> None:
    if not projectile.is_projectile:
        printf(f"Cannot shoot non-projectile Item: {projectile.id}")
        return

    items.add(projectile)
    PROJECTILES.append(projectile)
