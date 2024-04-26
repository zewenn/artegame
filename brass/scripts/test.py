from events import Events, init, update
from classes import Item, Vector2, Vector3
from entities import Items
from pgapi import TIME, Debugger
from vectormath import MathVectorToolkit, CompleteMathVector

from input import Input

player: Item


@init
def start():
    global player

    query_res = Items.get("player")
    if query_res:
        player = query_res

    Debugger.print(player.transform)


@update
def update():

    move_vec: Vector2 = Vector2()

    if Input.get_button("w@kb"):
        move_vec.y = -1
    if Input.get_button("s@kb"):
        move_vec.y = 1
    if Input.get_button("a@kb"):
        move_vec.x = -1
    if Input.get_button("d@kb"):
        move_vec.x = 1

    if Input.get_button("q@kb"):
        player.transform.rotation.z -= 500 * TIME.deltatime
    if Input.get_button("e@kb"):
        player.transform.rotation.z += 500 * TIME.deltatime


    move_math_vec: CompleteMathVector = MathVectorToolkit.new(move_vec)
    normalised: CompleteMathVector = MathVectorToolkit.normalise(move_math_vec)

    player.transform.position.y += 500 * TIME.deltatime * normalised.end.y
    player.transform.position.x += 500 * TIME.deltatime * normalised.end.x