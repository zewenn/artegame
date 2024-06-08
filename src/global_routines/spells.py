from brass.base import *

from src import enums

from brass import scene, assets, events, timeout, pgapi, items, collision, animator
from . import crowd_control, projectiles, effect_display


SPELL_DICT: Dict[string, Callable[[Spell, Item, Number], None]] = {}


def spell(name: string | Spell):
    def decorator(fn) -> None:
        if isinstance(name, str):
            SPELL_DICT[name] = fn
            return
        SPELL_DICT[name.name] = fn

    return decorator


def fire(spell_object: Spell, item: Item) -> None:
    spell_fn = SPELL_DICT.get(spell_object.name)

    if not spell_fn:
        return

    if item.mana < spell_object.mana_cost:
        return

    if (
        spell_object.cooldown_start is None
        or spell_object.cooldown_start + spell_object.cooldown < pgapi.TIME.current
    ):
        spell_object.cooldown_start = pgapi.TIME.current
    else:
        return

    item.mana -= spell_object.mana_cost

    def clear_cd_start():
        spell_object.cooldown_start = None

    spell_fn(spell_object, item, spell_object.effectiveness)
    timeout.new(spell_object.cooldown, clear_cd_start, ())


@spell(enums.spell_enum.HEALING)
def __spell_fn_heal(_: Spell, item: Item, effectiveness: Number) -> None:
    if item.hitpoints is None:
        return

    last_hp = item.hitpoints
    times = 0

    def heal():
        nonlocal last_hp, times

        if item.hitpoints < last_hp:
            return

        if times < 10:
            times += 1

        last_hp = item.hitpoints
        item.hitpoints += item.max_hitpoints * 0.01 * effectiveness

        if item.hitpoints > item.max_hitpoints:
            item.hitpoints = item.max_hitpoints
            return

        timeout.new(1, heal, ())
        effect_display.summon(
            item.transform,
            [
                "heal_effect_0.png",
                "heal_effect_1.png",
                "heal_effect_0.png",
                # "heal_effect_2.png",
            ],
            1,
            0.5,
        )

    heal()


@spell(enums.spell_enum.HASTE)
def __spell_fn_haste(_: Spell, item: Item, effectiveness: Number) -> None:
    if not item.movement_speed or not item.attack_speed:
        return

    def reset() -> None:
        item.movement_speed = item.base_movement_speed
        item.attack_speed = item.base_attack_speed

    item.movement_speed *= effectiveness
    item.attack_speed *= effectiveness

    timeout.new(5, reset, ())


@spell(enums.spell_enum.GOLIATH)
def __spell_fn_goliath(_: Spell, item: Item, effectiveness: Number) -> None:
    if not item.transform or not item.max_hitpoints:
        return

    original_max_hp = item.max_hitpoints
    original_scale = structured_clone(item.transform.scale)

    def reset() -> None:
        item.transform.scale = original_scale
        item.max_hitpoints = original_max_hp

    item.transform.scale.x *= 1 + (effectiveness / 5)
    item.transform.scale.y *= 1 + (effectiveness / 5)

    item.max_hitpoints *= effectiveness * 1.5
    item.hitpoints *= effectiveness * 1.5

    timeout.new(15, reset, ())


@spell(enums.spell_enum.Zzzz)
def __spell_fn_Zzzz(_: Spell, item: Item, _2: Number) -> None:
    trs: Transform = structured_clone(item.transform)

    trs.position.x -= trs.scale.x
    trs.position.y -= trs.scale.x

    trs.scale.x *= 3
    trs.scale.y = trs.scale.x

    duration = 1

    proj = projectiles.new(
        "sleep_puddle_0.png",
        trs.position,
        trs.scale,
        0,
        duration,
        0,
        item.team,
        0,
        [Effect("sleep", 2, 0, 2)],
    )

    anim: AnimationGroup = animator.create(
        duration,
        enums.animations.MODES.NORMAL,
        enums.animations.TIMING.LINEAR,
        [
            Animation(
                proj.id,
                {
                    0: Keyframe(sprite="sleep_puddle_0.png"),
                    33: Keyframe(sprite="sleep_puddle_1.png"),
                    66: Keyframe(sprite="sleep_puddle_2.png"),
                    100: Keyframe(sprite="sleep_puddle_0.png"),
                },
            )
        ],
    )

    projectiles.shoot(proj)
    animator.play(anim)

    timeout.new(duration + 0.02, delete, (anim,))
