from events import Events
from classes import Item, Vector2, Vector3
from entities import *
from pgapi import TIME, Debugger
from vectormath import MathVectorToolkit, CompleteMathVector

from input import Input

player: Item
hand: Bone

move_vec: Vector2 = Vector2()
move_math_vec: CompleteMathVector


@Events.init
def start():
    global player, hand

    query_res = Items.get("player")
    hand_res = Items.get("player->left_hand")
    if query_res:
        player = query_res
    if hand_res:
        hand = hand_res

    # Debugger.print("player.transform:", player.transform)


@Events.update
def update():
    move_vec.y = Input.vertical()
    move_vec.x = Input.horizontal()

    move_math_vec = MathVectorToolkit.normalise(
        MathVectorToolkit.new(move_vec)
    )

    player.transform.position.y += 500 * TIME.deltatime * move_math_vec.end.y
    player.transform.position.x += 500 * TIME.deltatime * move_math_vec.end.x
