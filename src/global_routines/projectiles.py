from brass.base import *

from brass import (
    vectormath,
    collision,
    events,
    pgapi,
    items,
    animator,
    enums,
    timeout,
    scene
)
from global_routines import crowd_control

PROJECTILES: list[Item] = []


def rm_projectile(proj: Item) -> None:
    if proj in PROJECTILES:
        PROJECTILES.remove(proj)
    if proj in items.rendering:
        items.remove(proj)
    del proj


def play(
    item: Item, anim: Literal["get_hit", "get_stunned"], length: Number = 0.1
) -> None:
    if anim == "get_hit":
        anim = animator.create(
            duration_seconds=0.1,
            mode=enums.animations.MODES.NORMAL,
            timing_function=enums.animations.TIMING.EASE_IN_OUT,
            animations=[
                Animation(
                    item.id,
                    {
                        1: Keyframe(rotation_z=0),
                        30: Keyframe(rotation_z=20),
                        60: Keyframe(rotation_z=-20),
                    },
                )
            ],
        )
        animator.play(anim)
        timeout.set(0.12, delete, (anim,))
        return

    if anim == "get_stunned":
        original_h = item.transform.scale.y

        anim = animator.create(
            duration_seconds=length,
            mode=enums.animations.MODES.NORMAL,
            timing_function=enums.animations.TIMING.EASE_IN_OUT,
            animations=[
                Animation(
                    item.id,
                    {
                        # fmt: off
                        1: Keyframe(
                            height=original_h,
                        ),
                        30: Keyframe(
                            height=original_h // 1.1,
                        ),
                        60: Keyframe(
                            height=original_h // 1.5
                        ),
                        100: Keyframe(
                            height=original_h,
                        ),
                        # fmt: on
                    },
                )
            ],
        )
        animator.play(anim)
        timeout.set(0.12, delete, (anim,))
        return


@scene.update(enums.scenes.GAME)
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
                or item.invulnerable
                or not item.hitpoints
            ):
                continue

            if collision.collides(projectile.transform, item.transform):
                play_name: Optional[string] = None

                if not item.invulnerable:
                    item.hitpoints -= projectile.projectile_damage
                    play_name = "get_hit"

                if item.hitpoints > 0:
                    length = 0.1
                    for effect in projectile.projectile_effects:
                        if effect.T == "stun":
                            play_name = "get_stunned"
                        crowd_control.apply(
                            item,
                            effect.T,
                            effect.length,
                            effect.slow_strength,
                            effect.sleep_wait_time,
                            True
                        )
                    if play_name != None:
                        play(item, play_name, length)
                rm_projectile(projectile)

            # if item.hitpoints <= 0:
            #     match item.team:
            #         case "Player":
            #             return
            #         case "Enemy":
            #             items.rendering.remove(item)
            #             del item


def new(
    sprite: string,
    position: Vec2,
    scale: Vec2,
    direction: Number,
    lifetime_seconds: Number,
    speed: Number,
    team: Literal["Player", "Enemy"],
    damage: Number,
    effects: list[Effect] = None,
) -> Item:
    effects = [] if effects == None else effects
    return Item(
        id=f"Projectile-{uuid()}",
        tags=["projectile", "item"],
        transform=Transform(
            position=position, rotation=Vec3(0, 0, direction), scale=scale
        ),
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
        projectile_effects=effects,
    )


def shoot(projectile: Item) -> None:
    if not projectile.is_projectile:
        printf(f"Cannot shoot non-projectile Item: {projectile.id}")
        return

    items.add(projectile)
    PROJECTILES.append(projectile)
