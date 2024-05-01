
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
                "leg_right": Bone(
                    transform=Transform(
                        Vector2(32, 32),
                        Vector3(0, 0, -20),
                        Vector2(32, 32)
                    ),
                    anchor=Vector2(0, 0),
                    sprite="test.png"
                )
            }
        )
    )
