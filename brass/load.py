
from entities import *

def load_game_scene():
    # Items.create(
    #     Item(
    #         id="displ",
    #         tags=["displ", "item"],
    #         transform=Transform(
    #             Vector2(-32, -32),
    #             Vector3(0, 0, 0),
    #             Vector2(64, 64)
    #         ),
    #         fill_color=[20, 20, 20],
    #         # sprite="test.png",
    #         can_move=False
    #     )
    # )
    Items.create(
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
            can_move=False, 
            can_collide=True,
            can_repulse=True,
            lightness=1,
            movement_speed=300,
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

    Items.create(
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

    Items.create(
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

    # print(Items.rendering)