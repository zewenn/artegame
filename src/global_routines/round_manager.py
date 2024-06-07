from brass.base import *

from brass import items, timeout, scene, enums, gui, pgapi, saves
from global_routines import effect_display, menus, enemies

import random

round_saver_entity: Optional[Item] = None
player: Optional[Item] = None
ROUND_STATE: Literal["BoonSelection", "Wait", "Fight"]
ROUND: int = 0
MIXER_TRANSFORM: Transform = Transform(Vec2(-128, -196 - 128), Vec3(), Vec2(256, 256))
round_display_el: Optional[GUIElement] = None


def get_random_spawn_pos() -> Vec2:
    global player

    x = random.randint(
        -pgapi.SETTINGS.background_size.x / 2, pgapi.SETTINGS.background_size.x / 2
    )
    y = random.randint(
        -pgapi.SETTINGS.background_size.y / 2, pgapi.SETTINGS.background_size.y / 2
    )

    if (
        x > player.transform.position.x - 256
        and x < player.transform.position.x + (256 + 64)
    ) and (
        y > player.transform.position.y - 256
        and y < player.transform.position.y + (256 + 64)
    ):
        x = (
            player.transform.position.x - 256
            if player.transform.position.x > -pgapi.SETTINGS.background_size.x / 2
            else player.transform.position.x - (256 + 64)
        )
        y = (
            player.transform.position.y - 256
            if player.transform.position.y > -pgapi.SETTINGS.background_size.y / 2
            else player.transform.position.y - (256 + 64)
        )

    return Vec2(x, y)


def spawn_melee() -> None:
    global ROUND
    enemies.new(
        Item(
            id="enemy:" + uuid(),
            tags=["enemy", "item", "melee"],
            transform=Transform(get_random_spawn_pos(), Vec3(0, 0, 0), Vec2(64, 64)),
            # fill_color=[20, 20, 20],
            sprite="enemy_melee_left_1.png",
            can_move=True,
            can_collide=True,
            can_repulse=True,
            lightness=1,
            base_movement_speed=300 + 300 * 0.01 * ROUND,
            dash_movement_multiplier=5 + 0.1 * ROUND,
            dash_time=0.15,
            max_hitpoints=150 + 5 * ROUND,
            effective_range=random.randint(200, 500),
            hitpoints=100,
            max_mana=100,
            base_attack_speed=random.randint(3, 7),
            team="Enemy",
        )
    )


def spawn_ranged() -> None:
    global ROUND
    enemies.new(
        Item(
            id="enemy:" + uuid(),
            tags=["enemy", "item", "ranged"],
            transform=Transform(get_random_spawn_pos(), Vec3(0, 0, 0), Vec2(64, 64)),
            # fill_color=[20, 20, 20],
            sprite="enemy_ranged_left.png",
            can_move=True,
            can_collide=True,
            can_repulse=True,
            lightness=1,
            base_movement_speed=300 + 300 * 0.01 * ROUND,
            dash_movement_multiplier=5 + 0.1 * ROUND,
            dash_time=0.15,
            max_hitpoints=95 + 95 * 0.01 * ROUND,
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

    enemy_count = random.randint(ROUND, ROUND + 2)
    melee_count = range(round(enemy_count * 0.66))
    ranged_count = range(round(enemy_count * 0.33))

    for _ in melee_count:
        spawn_melee()

    for _ in ranged_count:
        spawn_ranged()


@scene.init(enums.scenes.GAME)
def init() -> None:
    global ROUND_STATE
    global ROUND
    global round_saver_entity
    global round_display_el
    global player

    ROUND_STATE = None
    ROUND = 0

    round_saver_entity_query = items.get("RoundSaver")
    if round_saver_entity_query.is_err():
        unreachable("RoundSaver entity does not exist!")

    round_saver_entity = round_saver_entity_query.ok()

    player_q = items.get("player")
    if player_q.is_err():
        unreachable("player entity does not exist!")

    player = player_q.ok()

    rdq = gui.get_element("RoundDisplay")
    if rdq.is_err():
        unreachable("RoundDisplay does not exist!")
    round_display_el = rdq.ok()

    try:
        ROUND_STATE = round_saver_entity.tags[0]
        ROUND = round_saver_entity.transform.position.x
    except:
        round_saver_entity.tags = ["Wait"]
        ROUND_STATE = "Wait"


@scene.update(enums.scenes.GAME)
def update() -> None:
    global ROUND_STATE, round_display_el

    if round_display_el.children[0] != f"{ROUND}. Kör":
        t = f"{ROUND}. Kör"
        round_display_el.children[0] = t
        round_display_el.style.left = f"-{len(t) / 2 * 16}x"

    if ROUND_STATE == "Fight" and len(enemies.ENEMIES) == 0:
        saves.save()
        ROUND_STATE = "BoonSelection"

    round_saver_entity.tags = [ROUND_STATE]
    round_saver_entity.transform.position.x = ROUND
