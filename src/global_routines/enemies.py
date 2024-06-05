import random

from brass.base import *

# fmt: off
from global_routines import projectiles, dash, crowd_control, interact
from brass import (
    items, 
    pgapi, 
    scene,
    enums, 
    vectormath,
    collision,
    timeout,
    animator,
    inpt
)
# fmt: on

import random


ENEMIES: list[Item] = []
DROPPED_FRUITS: list[Item] = []
player: Optional[Item] = None
FRUIT_HUN_DICT = {
    "banana": "Banán",
    "strawberry": "Eper",
    "blueberry": "Áfonya"
}


def drop_fruit(at_item: Item) -> None:
    fruit = random.choice(["banana", "strawberry", "blueberry"])

    fruit_item = Item(
        id="fruit:" + uuid(),
        tags=[fruit, "fruit"],
        transform=Transform(
            Vec2(at_item.transform.position.x - 64, at_item.transform.position.y - 64),
            Vec3(),
            Vec2(128, 128),
        ),
        bones={
            "display_bone": Bone(
                transform=Transform(Vec2(), Vec3(), Vec2(64, 64)),
                sprite=f"{fruit}.png",
                anchor=Vec2(),
            )
        },
    )

    DROPPED_FRUITS.append(items.add(fruit_item))


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

    item.attack_speed = item.base_attack_speed
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


walk_anims: dict[string, bool] = {}


def reset_anim(anim: AnimationGroup, id: string) -> None:
    del anim
    del walk_anims[id]

def play(item: Item, dir: Literal["right", "left"]) -> None:
    if walk_anims.get(item.id):
        return
    
    walk_anims[item.id] = True
    dur = .5
    anim = animator.create(
        duration_seconds=dur,
        mode=enums.animations.MODES.NORMAL,
        timing_function=enums.animations.TIMING.EASE_IN_OUT,
        animations=[
            Animation(
                item.id,
                {
                    1: Keyframe(sprite=f"enemy_melee_{dir}_1.png"),
                    50: Keyframe(sprite=f"enemy_melee_{dir}_2.png"),
                    100: Keyframe(sprite=f"enemy_melee_{dir}_1.png"),
                },
            )
        ],
    )
    animator.play(anim)
    timeout.set(dur + 0.02, reset_anim, (anim, item.id))



@scene.update(enums.scenes.GAME)
def update() -> None:
    vec = None

    for enemy in ENEMIES:
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
            if enemy.tags.__contains__("ranged"):
                if x < 0:
                    enemy.sprite = "enemy_ranged_left.png"
                else:
                    enemy.sprite = "enemy_ranged_right.png"
            elif enemy.tags.__contains__("melee"):
                play(enemy, "left" if x < 0 else "right")

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

    for index, frt in enumerate(DROPPED_FRUITS):
        if collision.collides(frt.transform, player.transform):
            interact.show(f"Felvétel: {FRUIT_HUN_DICT.get(frt.tags[0])}", 100000 + index)
            if inpt.active_bind(enums.keybinds.INTERACT):
                if frt.tags[0] == "banana":
                    player.inventory.banana += 1

                if frt.tags[0] == "strawberry":
                    player.inventory.strawberry += 1

                if frt.tags[0] == "blueberry":
                    player.inventory.blueberry += 1

                items.remove(frt)
                DROPPED_FRUITS.remove(frt)
                interact.hide(200000)
        elif interact.current_priority >= 100000 + index:
             interact.hide(100000 + index)


def shoot_random_projectile(vector: CompleteMathVector, item: Item) -> None:
    if not item.attack_speed:
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
                item.base_movement_speed * 1.2,
                "Enemy",
                10,
            )
        )
        item.can_attack = False
        timeout.set(1 / item.attack_speed, remove_attack_cooldown, (item,))
        return

    # Heavy Attack

    projectiles.shoot(
        projectiles.new(
            "enemy_heavy_projectile.png",
            structured_clone(item.transform.position),
            Vec2(64, 64),
            -vector.direction + 90,
            2.5,
            item.base_movement_speed * 1.1,
            "Enemy",
            20,
            [Effect("stun", 0.75, 0, 0)],
        )
    )
    item.can_attack = False
    crowd_control.apply(item, "stun", 0.5)
    timeout.set((1 / item.attack_speed * 2), remove_attack_cooldown, (item,))
