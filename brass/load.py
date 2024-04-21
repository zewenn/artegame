
from entities import *

def default_load():
    Entities.create(
        Entity(
            id="player",
            tags=["player", "entity"],
            transform=Transform(
                Vector2(-32, -32),
                Vector3(0, 0, 0),
                Vector2(64, 64)
            ),
            # fill_color=[20, 20, 20],
            sprite="test.png",
            can_move=True, 
            movement_speed=300,
            bones={
                "leg_left": Bone(
                    transform=Transform(
                        Vector2(-48, 48),
                        Vector3(0, 0, 20),
                        Vector2(32, 32)
                    ),
                    anchor=Vector2(0, 0),
                    # fill_color=[255, 255, 255]
                    sprite="test.png"
                ),
                "leg_right": Bone(
                    transform=Transform(
                        Vector2(48, 48),
                        Vector3(0, 0, -20),
                        Vector2(32, 32)
                    ),
                    anchor=Vector2(0, 0),
                    sprite="test.png"
                )
            }
        )
    )

    Entities.create(
        Entity(
            id="ground",
            tags=["ground"],
            transform=Transform(
                Vector2(-800, 250),
                Vector3(0, 0, 0),
                Vector2(1600, 200)
            ),
            # fallback_sprite="test.png"
            fill_color=(255, 255, 255)
        )
    )

    Entities.create(
        Entity(
            id="100mark",
            tags=["ground"],
            transform=Transform(
                Vector2(-700, 230),
                Vector3(0, 0, 0),
                Vector2(2, 20)
            ),
            # fallback_sprite="test.png"
            fill_color=(255, 0, 0)
        )
    )
