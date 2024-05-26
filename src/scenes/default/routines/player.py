from brass.base import *

from global_routines import item_funcs

# fmt: off
from brass import (
    vectormath, 
    animator,
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

dash_display: Optional[GUIElement] = None
walk_sound: Optional[Audio] = None


def init() -> None:
    global player
    global player_hand_holder
    global dash_display
    global walk_sound
    global player_light_attack_anim

    player_query = items.get("player")
    player_hand_holder_query = items.get("player_hand_holder")
    dash_gui_query = gui.get_element("PlayerDashCounter")

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

    # Walking audio
    walk_sound = assets.use("walking.mp3")
    audio.set_volume(walk_sound, 0.1)

    player_light_attack_anim_query = animator.store.get("hit")

    if player_light_attack_anim_query.is_err():
        unreachable('"hit" animation does not exist')

    player_light_attack_anim = player_light_attack_anim_query.ok()

    player.movement_speed = player.base_movement_speed
    player.dashes_remaining = player.dash_count
    player.last_dash_charge_refill = pgapi.TIME.current


def update() -> None:
    global player_light_attack_anim

    move_player()
    pgapi.move_camera(player.transform.position)

    if inpt.active_bind(enums.keybinds.PLAYER_LIGHT_ATTACK):
        animator.play(player_light_attack_anim)


def move_player() -> None:
    global dash_display, player_hand_holder

    if not player.can_move:
        return

    # print(player.dashes_remaining)

    dash_display.children[0] = (
        " ".join(["[×]" for _ in range(player.dashes_remaining)])
        + (" " if player.dashes_remaining != 0 else "")
        + " ".join(["[ ]" for _ in range(player.dash_count - player.dashes_remaining)])
    )

    if player.dashes_remaining < player.dash_count:
        if (
            player.dash_charge_refill_time + player.last_dash_charge_refill
            <= pgapi.TIME.current
        ):
            player.dashes_remaining = player.dash_count
            player.last_dash_charge_refill = pgapi.TIME.current

    move_math_vec = vectormath.normalise(
        vectormath.new(Vector2(inpt.horizontal(), inpt.vertical()))
    )

    if move_math_vec.end.x != 0 or move_math_vec.end.y != 0:
        audio.fade_in(walk_sound, 100, 1)
    else:
        audio.fade_out(walk_sound, 100)

    if (
        inpt.active_bind(enums.keybinds.PLAYER_DASH)
        and player.dashes_remaining > 0
        and (move_math_vec.end.x != 0 or move_math_vec.end.y != 0)
    ):
        # if player.dashes_remaining == player.dash_count:
        player.last_dash_charge_refill = pgapi.TIME.current
        player.dashes_remaining -= 1
        item_funcs.apply_dash_effect(
            player, move_math_vec, player.dash_movement_multiplier, 80
        )

    player.transform.position.y += (
        player.movement_speed * pgapi.TIME.deltatime * move_math_vec.end.y
    )
    player.transform.position.x += (
        player.movement_speed * pgapi.TIME.deltatime * move_math_vec.end.x
    )

    player_hand_holder.transform.position = player.transform.position
    if move_math_vec.end.x != 0 or move_math_vec.end.y != 0:
        player_hand_holder.transform.rotation.z = -move_math_vec.direction + 90
