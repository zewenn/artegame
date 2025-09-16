import random

from brass.base import *

# fmt: off
from . import projectiles, dash, crowd_control, interact, sounds
from brass import (
    items, 
    pgapi, 
    scene,
    enums, 
    vectormath,
    collision,
    timeout,
    animator,
    audio,
    inpt
)
# fmt: on


ENEMIES: list[Item] = []
DROPPED_FRUITS: list[Item] = []
player: Optional[Item] = None
FRUIT_HUN_DICT = {"banana": "Banán", "strawberry": "Eper", "blueberry": "Áfonya"}


def drop_fruit(at_item: Item) -> None:
    if at_item.transform is None:
        return

    fruit = random.choice(["banana", "strawberry", "blueberry"])

    fruit_item = Item(
        id="fruit:" + uuid(),
        tags=[fruit, "fruit"],
        transform=Transform(
            Vec2(at_item.transform.position.x - 96, at_item.transform.position.y - 96),
            Vec3(),
            Vec2(192, 192),
        ),
        bones={
            "display_bone": Bone(
                transform=Transform(Vec2(96, 96), Vec3(), Vec2(64, 64)),
                sprite=f"{fruit}.png",
                anchor=Vec2(),
            )
        },
    )

    DROPPED_FRUITS.append(items.add(fruit_item))


@scene.awake(enums.scenes.GAME)
def awake() -> None:
    global ENEMIES, player, DROPPED_FRUITS

    ENEMIES = items.get_all("enemy")
    DROPPED_FRUITS = items.get_all("fruit")
    # print(ENEMIES)

    for item in ENEMIES:
        item.movement_speed = int(orelse(item.base_movement_speed, 335))
        item.hitpoints = item.max_hitpoints
        item.mana = item.max_mana
        item.team = "Enemy"
        item.can_attack = True
        item.slowed_by_percent = 0
        if item.effective_range is None:
            item.effective_range = 200

    player_q = items.get("player")
    if player_q.is_err():
        unreachable("Player does not exist in the game scene!")

    player = player_q.ok()  # type: ignore


def new(item: Item) -> Item:
    if item.tags is None:
        return item

    if not "enemy" in item.tags:
        item.tags.append("enemy")

    item.attack_speed = item.base_attack_speed
    item.movement_speed = int(orelse(item.base_movement_speed, 335))
    item.hitpoints = item.max_hitpoints
    item.mana = item.max_mana
    item.team = "Enemy"
    item.can_attack = True
    item.slowed_by_percent = 0

    items.add(item)
    timeout.new(0.25, ENEMIES.append, (item,))
    # ENEMIES.append(item)
    return item


def remove_attack_cooldown(item: Item) -> None:
    item.can_attack = True


walk_anims: dict[string, bool] = {}


def reset_anim(anim: AnimationGroup, name: string) -> None:
    del anim
    del walk_anims[name]


def play(item: Item, direction: Literal["right", "left"]) -> None:
    if walk_anims.get(item.id):
        return

    walk_anims[item.id] = True
    duration = 0.5
    anim = animator.create(
        duration_seconds=duration,
        mode=enums.animations.MODES.NORMAL,
        timing_function=enums.animations.TIMING.EASE_IN_OUT,
        animations=[
            Animation(
                item.id,
                {
                    1: Keyframe(sprite=f"enemy_melee_{direction}_1.png"),
                    50: Keyframe(sprite=f"enemy_melee_{direction}_2.png"),
                    100: Keyframe(sprite=f"enemy_melee_{direction}_1.png"),
                },
            )
        ],
    )
    animator.play(anim)
    timeout.new(duration + 0.02, reset_anim, (anim, item.id))


@scene.update(enums.scenes.GAME)
def update() -> None:
    vec = None

    for enemy in ENEMIES:
        if (
            enemy.hitpoints is None
            or player is None
            or player.mana is None
            or player.transform is None
            or enemy.movement_speed is None
            or enemy.slowed_by_percent is None
            or enemy.tags is None
            or enemy.effective_range is None
        ):
            continue

        if enemy.hitpoints <= 0:
            player.mana += 10
            drop_fruit(enemy)
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
            x = (
                enemy.movement_speed
                * (1 - (enemy.slowed_by_percent / 100))
                * pgapi.TIME.deltatime
                * vec.end.x
            )
            enemy.transform.position.x += x
            if "ranged" in enemy.tags:
                if x < 0:
                    enemy.sprite = "enemy_ranged_left.png"
                else:
                    enemy.sprite = "enemy_ranged_right.png"
            elif "melee" in enemy.tags:
                play(enemy, "left" if x < 0 else "right")

        if random.randint(0, 100) == 0 and enemy.can_move:
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

    for frt in DROPPED_FRUITS:
        if (
            not frt.tags
            or not player
            or not player.inventory
            or not player.transform
            or not frt.transform
        ):
            continue

        if collision.collides(frt.transform, player.transform):
            if sounds.PICKUP:
                audio.play(audio.clone(sounds.PICKUP))
            if frt.tags[0] == "banana":
                player.inventory.banana += 1

            if frt.tags[0] == "strawberry":
                player.inventory.strawberry += 1

            if frt.tags[0] == "blueberry":
                player.inventory.blueberry += 1

            items.remove(frt)
            DROPPED_FRUITS.remove(frt)


def shoot_random_projectile(vector: CompleteMathVector, item: Item) -> None:
    if not item.attack_speed or not item.transform:
        return

    rand = random.randint(0, 3)

    # Light Attack
    if not item.can_attack:
        return

    if rand in range(0, 3):
        projectiles.shoot(
            projectiles.new(
                "enemy_light_projectile.png",
                structured_clone(item.transform.position),
                Vec2(64, 64),
                -vector.direction + 90,
                1.5,
                orelse(item.base_movement_speed, 355) * 1.2,
                "Enemy",
                10,
            )
        )
        item.can_attack = False
        timeout.new(1 / item.attack_speed, remove_attack_cooldown, (item,))
        return

    # Heavy Attack

    projectiles.shoot(
        projectiles.new(
            "enemy_heavy_projectile.png",
            structured_clone(item.transform.position),
            Vec2(64, 64),
            -vector.direction + 90,
            2.5,
            orelse(item.base_movement_speed, 335) * 1.1,
            "Enemy",
            20,
            # [Effect("stun", 0.75, 0, 0)],
            [],
        )
    )
    item.can_attack = False
    crowd_control.apply(item, "stun", 0.5)
    timeout.new((1 / item.attack_speed * 2), remove_attack_cooldown, (item,))
