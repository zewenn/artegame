from vectormath import MathVectorToolkit
from audio_helper import Audio
from input_handler import Input
from classes import *
from events import *
import items
import pgapi

player: Optional[Item] = None


@init
def _init():
    global player

    player_query = items.get("player")

    if player_query.is_err():
        raise Exception("Player item couldn't be found!")

    player = player_query.ok()

    player.movement_speed = player.base_movement_speed


@update
def _update():
    move_player()


def move_player():
    if not player.can_move:
        return
    
    move_math_vec = MathVectorToolkit.normalise(
        MathVectorToolkit.new(Vector2(Input.horizontal(), Input.vertical()))
    )

    if Input.get_button_down("space"):
        items.apply_dash_effect(player, move_math_vec, 3, .1)

    player.transform.position.y += (
        player.movement_speed * pgapi.TIME.deltatime * move_math_vec.end.y
    )
    player.transform.position.x += (
        player.movement_speed * pgapi.TIME.deltatime * move_math_vec.end.x
    )