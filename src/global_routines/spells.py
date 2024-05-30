from brass.base import *

from brass import scene, enums, assets, events, timeout, pgapi, items, collision
from global_routines import crowd_control, projectiles


SPELL_DICT: Dict[string, Callable[[Spell, Item, Number], None]] = {}


def spell(name: string | Spell):
    def decorator(fn) -> None:
        if isinstance(name, str):
            SPELL_DICT[name] = fn
            return
        SPELL_DICT[name.name] = fn

    return decorator


def cast(spell: Spell, item: Item) -> None:
    global SPELL_DICT
    spell_fn = SPELL_DICT.get(spell.name)

    if not spell_fn:
        return

    if item.mana < spell.mana_cost:
        return

    if (
        spell.cooldown_start == None
        or spell.cooldown_start + spell.cooldown < pgapi.TIME.current
    ):
        spell.cooldown_start = pgapi.TIME.current
    else:
        return

    item.mana -= spell.mana_cost

    spell_fn(spell, item, spell.effectiveness)


@spell(enums.spells.HEALING)
def __spell_fn_heal(this: Spell, item: Item, effectiveness: Number) -> None:
    if not item.hitpoints:
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

        timeout.set(1, heal, ())

    heal()


@spell(enums.spells.HASTE)
def __spell_fn_haste(this: Spell, item: Item, effectiveness: Number) -> None:
    if not item.movement_speed or not item.attack_speed:
        return

    def reset() -> None:
        item.movement_speed = item.base_movement_speed
        item.attack_speed = item.base_attack_speed

    item.movement_speed *= effectiveness
    item.attack_speed *= effectiveness

    timeout.set(5, reset, ())


@spell(enums.spells.GOLIATH)
def __spell_fn_goliath(this: Spell, item: Item, effectiveness: Number) -> None:
    if not item.transform or not item.max_hitpoints:
        return

    original_max_hp = item.max_hitpoints
    original_scale = structured_clone(item.transform.scale)

    def reset() -> None:
        item.transform.scale = original_scale
        item.max_hitpoints = original_max_hp

    item.transform.scale.x *= effectiveness
    item.transform.scale.y *= effectiveness

    item.max_hitpoints *= effectiveness * 1.5
    item.hitpoints *= effectiveness * 1.5

    timeout.set(15, reset, ())


@spell(enums.spells.Zzzz)
def __spell_fn_Zzzz(this: Spell, item: Item, effectiveness: Number) -> None:
    trs: Transform = structured_clone(item.transform)

    trs.position.x -= trs.scale.x
    trs.position.y -= trs.scale.x

    trs.scale.x *= 3
    trs.scale.y = trs.scale.x

    projectiles.shoot(
        projectiles.new(
            "gyuri.png",
            trs.position,
            trs.scale,
            0,
            1,
            0,
            item.team,
            0,
            [Effect("sleep", 2, 0, 2)]
        )
    )
