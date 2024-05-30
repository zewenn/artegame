from brass.base import *


# fmt: off
from global_routines import (
    projectiles,
    dash,
    crowd_control,
    spells
)

from brass import (
    vectormath, 
    animator,
    timeout,
    assets,
    audio,
    enums, 
    items, 
    pgapi, 
    inpt, 
    gui
)
# fmt: on


player: Optional[Item] = None
player_hand_holder: Optional[Item] = None
player_light_attack_anim: Optional[AnimationGroup] = None
player_can_move_save = True

dash_display: Optional[GUIElement] = None
hp_amount_display: Optional[GUIElement] = None
hitpoint_display: Optional[GUIElement] = None
mana_display: Optional[GUIElement] = None
walk_sound: Optional[Audio] = None

can_attack: bool = True
can_dash: bool = False


def init() -> None:
    global player
    global player_hand_holder
    global dash_display
    global hitpoint_display
    global mana_display
    global walk_sound
    global player_light_attack_anim
    global hp_amount_display

    player_query = items.get("player")
    player_hand_holder_query = items.get("player_hand_holder")
    dash_gui_query = gui.get_element("PlayerDashCounter")
    hitpoint_bar_query = gui.get_element("PlayerHitpointBar")
    mana_bar_query = gui.get_element("ManaBar")
    hp_amount_query = gui.get_element("HpAmountDispaly")

    # Player
    if player_query.is_err():
        unreachable("Player Item does not exist!")

    player = player_query.ok()

    # Player Hand Holder
    if player_hand_holder_query.is_err():
        unreachable("Player Item does not exist!")

    player_hand_holder = player_hand_holder_query.ok()

    # Dash Display GUIElement
    if dash_gui_query.is_err():
        unreachable("Dash display GUIElement does not exist!")

    dash_display = dash_gui_query.ok()

    # Hitpoint Display GUIElement
    if hitpoint_bar_query.is_err():
        unreachable("Hitpoint display GUIElement does not exist!")

    hitpoint_display = hitpoint_bar_query.ok()

    # Mana Bar GUIElement
    if mana_bar_query.is_err():
        unreachable("Hitpoint display GUIElement does not exist!")

    mana_display = mana_bar_query.ok()

    # HP Amount Display GUIElement
    if hp_amount_query.is_err():
        unreachable("Hitpoint display GUIElement does not exist!")

    hp_amount_display = hp_amount_query.ok()

    # Walking audio
    walk_sound = assets.use("walking.mp3", T=Audio)
    audio.set_volume(walk_sound, 0.1)

    player_light_attack_anim_query = animator.store.get("hit")

    if player_light_attack_anim_query.is_err():
        unreachable('"hit" animation does not exist')

    player_light_attack_anim = player_light_attack_anim_query.ok()

    player.movement_speed = player.base_movement_speed
    player.attack_speed = player.base_attack_speed

    player.dashes_remaining = player.dash_count
    player.last_dash_charge_refill = pgapi.TIME.current

    player.hitpoints = player.max_hitpoints
    player.mana = player.max_mana

    player.slowed_by_percent = 0

    if not player.spells:
        player.spells = [enums.spells.HEALING, enums.spells.GOLIATH]

    if not player.dash_time:
        player.dash_time = 150

    # hitpoint_display.style.bg_color = (20, 120, 220, 1)


def update() -> None:
    global player_light_attack_anim
    global hitpoint_display
    global player_can_move_save
    global mana_display
    global hp_amount_display

    if inpt.get_button_down("e"):
        # crowd_control.apply(player, "root", 2)
        spells.cast(player.spells[1], player)

    if inpt.get_button_down("q"):
        # crowd_control.apply(player, "root", 2)
        spells.cast(player.spells[0], player)

    if (player.rooted or player.stunned or player.sleeping) and player.can_move:
        player.can_move = False
    elif (
        not (player.rooted or player.stunned or player.sleeping)
    ) and not player.can_move:
        player.can_move = True

    move_player()
    pgapi.CAMERA.position = player.transform.position

    # print(items.rendering)
    handle_combat()

    if player.hitpoints < 0:
        player.hitpoints = 0

    if player.mana < 0:
        player.mana = 0

    if player.hitpoints > player.max_hitpoints:
        player.hitpoints = player.max_hitpoints

    if player.mana > player.max_mana:
        player.mana = player.max_mana

    hitpoint_display.style.width = f"{player.hitpoints / player.max_hitpoints * 100}%"
    mana_display.style.width = f"{player.mana / player.max_mana * 100}%"

    hp_amount_text = f"{int(player.hitpoints)}/{int(player.max_hitpoints)}"
    hp_amount_display.style.left = (
        f"{4.75 * 16 - len(hp_amount_text) * hp_amount_display.style.font_size / 2}x"
    )
    hp_amount_display.children[0] = hp_amount_text


def allow_attack() -> None:
    global can_attack
    can_attack = True


def handle_combat() -> None:
    global can_attack, can_dash
    if player.stunned or player.sleeping:
        return

    light_attacking = inpt.active_bind(enums.keybinds.PLAYER_LIGHT_ATTACK)
    heavy_attacking = inpt.active_bind(enums.keybinds.PLAYER_HEAVY_ATTACK)

    if light_attacking and player.dashing:
        animator.play(player_light_attack_anim)
        projectiles.shoot(
            projectiles.new(
                sprite="dash_attack_projectile.png",
                position=structured_clone(player.transform.position),
                scale=Vec2(128, 64),
                direction=player_hand_holder.transform.rotation.z,
                lifetime_seconds=1,
                speed=player.base_movement_speed
                * 1.5
                * player.dash_movement_multiplier,
                team="Player",
                damage=20,
            ),
        ),
        # timeout.set(
        #     (player.dash_time * 1.1) / 1000,
        #     ()
        # )

    elif light_attacking and can_attack:
        animator.play(player_light_attack_anim)
        projectiles.shoot(
            projectiles.new(
                sprite="light_attack_projectile.png",
                position=structured_clone(player.transform.position),
                scale=Vec2(64, 64),
                direction=player_hand_holder.transform.rotation.z,
                lifetime_seconds=0.5,
                speed=player.base_movement_speed * 1.125,
                team="Player",
                damage=10,
            )
        )
        can_attack = False
        # timeout.set()

        if not player.rooted and not can_dash:
            can_dash = True

        crowd_control.apply(player, "root", 0.1)
        timeout.set((1 / player.attack_speed), allow_attack, ())

    elif heavy_attacking and can_attack and not player.dashing:
        animator.play(player_light_attack_anim)
        projectiles.shoot(
            projectiles.new(
                sprite="heavy_attack_projectile.png",
                position=structured_clone(player.transform.position),
                scale=Vec2(64, 64),
                direction=player_hand_holder.transform.rotation.z,
                lifetime_seconds=1.25,
                speed=player.base_movement_speed * 0.75,
                team="Player",
                damage=25,
                effects=[Effect("stun", 1)],
            )
        )
        crowd_control.apply(player, "root", 0.25)
        can_attack = False
        timeout.set((1 / player.attack_speed) * 2, allow_attack, ())


def move_player() -> None:
    global can_dash
    # global dash_display
    # global player_hand_holder

    # if not player.can_move:
    #     return

    # print(player.dashes_remaining)

    dash_display.children[0] = (
        " ".join(["[×]" for _ in range(player.dashes_remaining)])
        + (" " if player.dashes_remaining != 0 else "")
        + " ".join(["[ ]" for _ in range(player.dash_count - player.dashes_remaining)])
    )

    if player.dashes_remaining < player.dash_count and player.can_move:
        if (
            player.dash_charge_refill_time + player.last_dash_charge_refill
            <= pgapi.TIME.current
        ):
            player.dashes_remaining = player.dash_count
            player.last_dash_charge_refill = pgapi.TIME.current

    move_math_vec = vectormath.normalise(
        vectormath.new(Vec2(inpt.horizontal(), inpt.vertical()))
    )

    if move_math_vec.end.x != 0 or move_math_vec.end.y != 0:
        audio.fade_in(walk_sound, 100, 1)
    else:
        audio.fade_out(walk_sound, 100)

    if (
        inpt.active_bind(enums.keybinds.PLAYER_DASH)
        and player.dashes_remaining > 0
        and (move_math_vec.end.x != 0 or move_math_vec.end.y != 0)
        and (player.can_move or can_dash)
    ):
        # if player.dashes_remaining == player.dash_count:
        player.last_dash_charge_refill = pgapi.TIME.current
        player.dashes_remaining -= 1
        dash.apply_dash_effect(
            player, move_math_vec, player.dash_movement_multiplier, player.dash_time
        )
        player.invulnerable = True
        if can_dash:
            can_dash = False

    if player.can_move:
        player.transform.position.y += (
            player.movement_speed
            * (1 - (player.slowed_by_percent / 100))
            * pgapi.TIME.deltatime
            * move_math_vec.end.y
        )
        player.transform.position.x += (
            player.movement_speed
            * (1 - (player.slowed_by_percent / 100))
            * pgapi.TIME.deltatime
            * move_math_vec.end.x
        )

    player_hand_holder.transform.position = player.transform.position
    match pgapi.SETTINGS.input_mode:
        case enums.input_modes.CONTROLLER:
            if move_math_vec.end.x != 0 or move_math_vec.end.y != 0:
                player_hand_holder.transform.rotation.z = -move_math_vec.direction + 90

        case enums.input_modes.MOUSE_AND_KEYBOARD:
            center = Vec2(pgapi.SCREEN.size.x / 2, pgapi.SCREEN.size.y / 2)
            mouse_relative_pos = Vec2(
                pgapi.MOUSE_POSITION.x - center.x, pgapi.MOUSE_POSITION.y - center.y
            )

            rotation = math.degrees(
                math.atan2(mouse_relative_pos.x, mouse_relative_pos.y)
            )
            player_hand_holder.transform.rotation.z = rotation
