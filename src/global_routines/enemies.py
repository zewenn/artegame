import random

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
    timeout
)
# fmt: on

ENEMIES: list[Item] = []
player: Optional[Item] = None


@scene.awake(enums.scenes.GAME)
def awake() -> None:
    global ENEMIES, player

    ENEMIES = items.get_all("enemy")
    # print(ENEMIES)

    for item in ENEMIES:
        item.movement_speed = item.base_movement_speed
        item.hitpoints = item.max_hitpoints
        item.mana = item.max_mana
        item.team = "Enemy"
        item.can_attack = True
        item.slowed_by_percent = 0
        if item.effective_range == None:
            item.effective_range = 200

    player_q = items.get("player")
    if player_q.is_err():
        unreachable("Player does not exist in the game scene!")

    player = player_q.ok()


def new(item: Item) -> Item:
    global ENEMIES
    if not item.tags.__contains__("enemy"):
        item.tags.append("enemy")

    
    item.movement_speed = item.base_movement_speed
    item.hitpoints = item.max_hitpoints
    item.mana = item.max_mana
    item.team = "Enemy"
    item.can_attack = True
    item.slowed_by_percent = 0

    ENEMIES.append(item)
    items.add(item)
    return item


def remove_attack_cooldown(item: Item) -> None:
    item.can_attack = True


@scene.update(enums.scenes.GAME)
def update() -> None:
    vec = None

    for enemy in ENEMIES:
        if enemy.hitpoints <= 0:
            player.mana += 10
            items.remove(enemy)
            ENEMIES.remove(enemy)
            del enemy
            continue
        if not enemy.transform:
            print(f'"{enemy.id}" does not qualify being an enemy: no transform')
            ENEMIES.remove(enemy)
            continue

        if enemy.stunned or enemy.rooted or enemy.sleeping:
            enemy.can_move = False
        elif not enemy.can_move:
            enemy.can_move = True

        or_vec = vectormath.new(
            end=vectormath.sub_Vec2(player.transform.position, enemy.transform.position)
        )

        if enemy.can_move and or_vec.magnitude >= enemy.transform.scale.x * 1.5:
            vec = vectormath.normalise(or_vec)
            enemy.transform.position.y += (
                enemy.movement_speed
                * (1 - (enemy.slowed_by_percent / 100))
                * pgapi.TIME.deltatime
                * vec.end.y
            )
            enemy.transform.position.x += (
                enemy.movement_speed
                * (1 - (enemy.slowed_by_percent / 100))
                * pgapi.TIME.deltatime
                * vec.end.x
            )

        if random.randint(0, 400) == 0 and enemy.can_move:
            dash.apply_dash_effect(
                enemy,
                vectormath.new(
                    start=Vec2(0, 0),
                    magnitude=1,
                    direction=random.choice(
                        [or_vec.direction - 90, or_vec.direction + 90, or_vec.direction]
                    ),
                ),
                3,
                150,
            )

        if (
            or_vec.magnitude <= enemy.effective_range
            and enemy.can_attack
            and not enemy.sleeping
            and not enemy.stunned
        ):
            shoot_random_projectile(or_vec, enemy)


def shoot_random_projectile(vector: CompleteMathVector, item: Item) -> None:
    rand = random.randint(0, 1)

    # Light Attack

    if rand == 0:
        projectiles.shoot(
            projectiles.new(
                "light_attack_projectile.png",
                structured_clone(item.transform.position),
                Vec2(64, 64),
                -vector.direction + 90,
                1,
                item.base_movement_speed * 1.2,
                "Enemy",
                10,
            )
        )
        item.can_attack = False
        timeout.set(.5, remove_attack_cooldown, (item,))
        return
    
    # Heavy Attack

    projectiles.shoot(
        projectiles.new(
            "heavy_attack_projectile.png",
            structured_clone(item.transform.position),
            Vec2(64, 64),
            -vector.direction + 90,
            1.5,
            item.base_movement_speed * 1.1,
            "Enemy",
            20,
        )
    )
    item.can_attack = False
    crowd_control.apply(item, "stun", .5)
    timeout.set(.75, remove_attack_cooldown, (item,))
