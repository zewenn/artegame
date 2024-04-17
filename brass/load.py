
from entities import *

def load():

    Entities.create(Entity(
        id="test_card",
        tags=["card"],
        transform=Transform(
            Vector2(100, -100),
            Vector3(0, 0, 0),
            Vector2(256, 256)
        ),
        crop=Crop(
            Vector2(47, 0),
            Vector2(162, 256)
        ),
        sprite="character.png",
        bones={
            "border": Bone(
                transform=Transform(
                    Vector2(-2, -2),
                    Vector3(),
                    Vector2(166, 260)
                ),
                anchor=Vector2(83, 131),
                sprite="border.png"
            )
        }
    ))

    Entities.create(
        Entity(
            id="player",
            tags=["player", "entity"],
            transform=Transform(
                Vector2(0, (250 - 128)),
                Vector3(0, 0, 0),
                Vector2(64, 128)
            ),
            fill_color=[20, 20, 20],
            can_move=True, 
            movement_speed=300,
            bones={
                "leg_left": Bone(
                    transform=Transform(
                        Vector2(0, 96),
                        Vector3(0, 0, 0),
                        Vector2(32, 32)
                    ),
                    anchor=Vector2(16, 16),
                    fill_color=[255, 255, 255]
                    # sprite="test.png"
                ),
                "leg_right": Bone(
                    transform=Transform(
                        Vector2(32, 96),
                        Vector3(0, 0, 0),
                        Vector2(32, 32)
                    ),
                    anchor=Vector2(16, 16),
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
