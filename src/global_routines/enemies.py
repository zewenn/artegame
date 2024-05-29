import random

from brass.base import *

# fmt: off
from global_routines import projectiles, dash
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

    for enemy in ENEMIES:
        enemy.movement_speed = enemy.base_movement_speed
        enemy.hitpoints = enemy.max_hitpoints
        enemy.mana = enemy.max_mana
        enemy.team = "Enemy"
        enemy.can_attack = True
        enemy.slowed_by_percent = 0
        if enemy.effective_range == None:
            enemy.effective_range = 200

    player_q = items.get("player")
    if player_q.is_err():
        unreachable("Player does not exist in the game scene!")

    player = player_q.ok()


def new(item: Item) -> Item:
    global ENEMIES
    if not item.tags.__contains__("enemy"):
        item.tags.append("enemy")

    ENEMIES.append(item)
    return item


def remove_attack_cooldown(item: Item) -> None:
    item.can_attack = True


@scene.update(enums.scenes.GAME)
def update() -> None:
    vec = None

    for enemy in ENEMIES:
        if enemy.hitpoints <= 0:
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

        or_vec = vectormath.new(
            end=vectormath.sub_Vec2(player.transform.position, enemy.transform.position)
        )

        if enemy.can_move and or_vec.magnitude >= enemy.effective_range:
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

        if random.randint(0, 400) == 0:
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

        if or_vec.magnitude <= enemy.effective_range and enemy.can_attack:
            projectiles.shoot(
                projectiles.new(
                    "light_attack_projectile.png",
                    structured_clone(enemy.transform.position),
                    Vec2(64, 64),
                    -or_vec.direction + 90,
                    0.5,
                    enemy.base_movement_speed,
                    "Enemy",
                    20,
                )
            )
            enemy.can_attack = False
            timeout.set(1.5, remove_attack_cooldown, (enemy,))
