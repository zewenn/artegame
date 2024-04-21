from events import Events, init, update
from classes import Entity, Vector2, Vector3
from entities import Entities, Transformer

from input import Input

player: Entity

@init
def start():
    global player

    query_res = Entities.get("player")
    if (query_res):
        player = query_res


@update
def update():
    if Input.get_button("w"):
        Transformer.set_rotation(player, Vector3(0, 0, player.transform.rotation.z - 1))
    if Input.get_button("s"):
        Transformer.set_rotation(player, Vector3(0, 0, player.transform.rotation.z + 1))