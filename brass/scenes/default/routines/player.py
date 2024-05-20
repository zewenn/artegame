from vectormath import MathVectorToolkit
from audio_helper import Audio
from input_handler import Input
from enums import keybinds
from classes import *
from events import *
import item_funcs
import items
import pgapi


player: Optional[Item] = None
dash_display: Optional[GUIElement] = None


@init
def _init():
    global player, dash_display

    player_query = items.get("player")
    dash_gui_query = gui.get_element("PlayerDashCounter")

    if player_query.is_err():
        raise Exception("Player item couldn't be found!")

    player = player_query.ok()

    if dash_gui_query.is_err():
        raise Exception("Critical player dash GUIElement is missing!")

    dash_display = dash_gui_query.ok()

    player.movement_speed = player.base_movement_speed
    player.dashes_remaining = player.dash_count
    player.last_dash_charge_refill = pgapi.TIME.current


@update
def _update():
    move_player()


def move_player():
    global dash_display

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

    move_math_vec = MathVectorToolkit.normalise(
        MathVectorToolkit.new(Vector2(Input.horizontal(), Input.vertical()))
    )

    if (
        Input.active_bind(keybinds.PLAYER_DASH)
        and player.dashes_remaining > 0
        and (move_math_vec.end.x != 0 or move_math_vec.end.y != 0)
    ):
        # if player.dashes_remaining == player.dash_count:
        player.last_dash_charge_refill = pgapi.TIME.current
        player.dashes_remaining -= 1
        item_funcs.apply_dash_effect(player, move_math_vec, 12.5, 80)

    player.transform.position.y += (
        player.movement_speed * pgapi.TIME.deltatime * move_math_vec.end.y
    )
    player.transform.position.x += (
        player.movement_speed * pgapi.TIME.deltatime * move_math_vec.end.x
    )
