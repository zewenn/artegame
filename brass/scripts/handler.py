from events import Events, init, update
from classes import Entity, Vector2
from entities import Entities, Transformer

from input import Input

player: Entity

@init
def start():
    global player

    query_res = Entities.get("test_card");
    if (query_res):
        player = query_res


@update
def update():    
    if Input.get_button("d@kb"):
        Transformer.set_position(player, Vector2(0, 1))