from events import *
from classes import *
from enums import *
from result import *
from typing import *
import items
import saves



@spawn
def spawn_scene():
    saves.select_slot(0)
    # res_loaded: Result[None, Mishap] = saves.load()
    
    # if res_loaded.is_ok():
    #     return


    # if loaded.is_ok():
    items.create(
        Item(
            id="player",
            tags=["player", "item"],
            transform=Transform(
                Vector2(-32, -32),
                Vector3(0, 0, 0),
                Vector2(64, 64)
            ),
            # fill_color=[20, 20, 20],
            sprite="test.png",
            can_move=True, 
            can_collide=True,
            can_repulse=True,
            lightness=1,
            base_movement_speed=300,
            bones={
                "left_hand": Bone(
                    transform=Transform(
                        Vector2(-32, 32),
                        Vector3(0, 0, 20),
                        Vector2(32, 32)
                    ),
                    anchor=Vector2(0, 0),
                    # fill_color=[255, 255, 255]
                    sprite="test.png"
                ),
                "right_hand": Bone(
                    transform=Transform(
                        Vector2(32, 32),
                        Vector3(0, 0, -20),
                        Vector2(32, 32)
                    ),
                    anchor=Vector2(0, 0),
                    sprite="test.png"
                )
            },
            inventory={
                "box_gloves": Weapon(
                    damage=3,
                    damage_area=Vector2(
                        50,
                        150
                    )
                ),
                "weight_plate": Weapon(
                    damage=10,
                    damage_area=Vector2(
                        100,
                        50
                    )
                ),
                "banana": 0,
                "strawberry": 0,
                "blueberry": 0
            }
        )
    )

    items.create(
        Item(
            id="box",
            tags=["box", "item"],
            transform=Transform(
                position=Vector2(64, 0),
                rotation=Vector3(),
                scale=Vector2(64, 64)
            ),
            can_collide=True,
            can_repulse=True,
            lightness=2,
            fill_color=[20, 20, 20]
        )
    )

    items.create(
        Item(
            id="asd",
            tags=["asd", "item"],
            transform=Transform(
                position=Vector2(200, 0),
                rotation=Vector3(),
                scale=Vector2(64, 64)
            ),
            sprite="test.png",
            render=True,
            can_collide=True,
            can_repulse=False,
            lightness=10,
        )
    )