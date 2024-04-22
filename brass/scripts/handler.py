from events import Events, init, update
from classes import Item, Vector2, Vector3
from entities import Items, Transformer
from pgapi import TIME

from input import Input

player: Item


@init
def start():
    global player

    query_res = Items.get("player")
    if query_res:
        player = query_res


@update
def update():
    if Input.get_button("w"):
        player.transform.rotation.z -= 500 * TIME.deltatime
    if Input.get_button("s"):
        player.transform.rotation.z += 500 * TIME.deltatime
