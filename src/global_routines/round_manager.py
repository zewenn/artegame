from brass.base import *

from brass import items, timeout, scene, enums, gui, pgapi
from global_routines import effect_display, menus, enemies

import random

round_saver_entity: Optional[Item] = None
ROUND_STATE: Literal["BoonSelection", "Wait", "Fight"]
ROUND: int = 0
MIXER_TRANSFORM: Transform = Transform(Vec2(-128, -196 - 128), Vec3(), Vec2(256, 256))


def get_random_spawn_pos() -> Vec2:
    x = random.randint(
        -pgapi.SETTINGS.background_size.x / 2, pgapi.SETTINGS.background_size.x / 2
    )
    y = random.randint(
        -pgapi.SETTINGS.background_size.y / 2, pgapi.SETTINGS.background_size.y / 2
    )
    return Vec2(x, y)


def spawn_melee() -> None:
    enemies.new(
        Item(
            id="enemy:" + uuid(),
            tags=["enemy", "item", "melee"],
            transform=Transform(get_random_spawn_pos(), Vec3(0, 0, 0), Vec2(64, 64)),
            # fill_color=[20, 20, 20],
            sprite="test.png",
            can_move=True,
            can_collide=True,
            can_repulse=True,
            lightness=1,
            base_movement_speed=300,
            dash_movement_multiplier=10,
            dash_charge_refill_time=0.25,
            max_hitpoints=100,
            effective_range=random.randint(200, 500),
            hitpoints=100,
            max_mana=100,
            base_attack_speed=random.randint(3, 7),
            team="Enemy",
        )
    )


def spawn_ranged() -> None:
    enemies.new(
        Item(
            id="enemy:" + uuid(),
            tags=["enemy", "item", "ranged"],
            transform=Transform(get_random_spawn_pos(), Vec3(0, 0, 0), Vec2(64, 64)),
            # fill_color=[20, 20, 20],
            sprite="test.png",
            can_move=True,
            can_collide=True,
            can_repulse=True,
            lightness=1,
            base_movement_speed=300,
            dash_movement_multiplier=10,
            dash_charge_refill_time=0.25,
            max_hitpoints=100,
            effective_range=random.randint(600, 1000),
            hitpoints=100,
            max_mana=100,
            base_attack_speed=random.randint(2, 4),
            team="Enemy",
        )
    )


def start_round() -> None:
    global ROUND_STATE
    global ROUND

    ROUND_STATE = "Fight"
    ROUND += 1

    enemy_count = random.randint(2, 2 + ROUND)
    melee_count = range(round(enemy_count * 0.66))
    ranged_count = range(round(enemy_count * 0.66))

    for _ in melee_count:
        spawn_melee()

    for _ in ranged_count:
        spawn_ranged()


@scene.awake(enums.scenes.GAME)
def awake() -> None:
    global ROUND_STATE
    global ROUND
    global round_saver_entity

    ROUND_STATE = None
    ROUND = 0

    round_saver_entity_query = items.get("RoundSaver")
    if round_saver_entity_query.is_err():
        unreachable("RoundSaver entity does not exist!")
    
    round_saver_entity = round_saver_entity_query.ok()

    try:
        ROUND_STATE = round_saver_entity.tags[0]
    except:
        round_saver_entity.tags = ["Wait"]
        ROUND_STATE = "Wait"


@scene.update(enums.scenes.GAME)
def update() -> None:
    global ROUND_STATE

    round_saver_entity.tags = [ROUND_STATE]

    if ROUND_STATE == "Fight" and len(enemies.ENEMIES) == 0:
        ROUND_STATE = "BoonSelection"
        print("Boon Selection Phase")
