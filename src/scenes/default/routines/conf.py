from brass.base import *

# fmt: off
from brass import (
    enums, 
    events,
    items, 
    saves, 
    inpt, 
    animator
)
# fmt: on


def spawn() -> None:
    saves.select_slot(0)

    inpt.bind_buttons(enums.keybinds.PLAYER_DASH, ["space", "a@ctrl#0"], "down")
    inpt.bind_buttons(
        enums.keybinds.PLAYER_LIGHT_ATTACK,
        ["left@mouse", "shoulder-right@ctrl#0"],
        "down",
    )

    animator.store.add(
        "hit",
        animator.create(
            duration_seconds=.2,
            mode=enums.animations.MODES.NORMAL,
            timing_function=enums.animations.TIMING.EASE_IN_OUT,
            animations=[
                Animation(
                    "player_hand_holder->left_hand",
                    {
                        1: Keyframe(position_y=16),
                        50: Keyframe(position_y=100),
                        100: Keyframe(position_y=16),
                    },
                )
            ],
        ),
    )

    # res_loaded: Result[None, Mishap] = saves.load()
    # if res_loaded.is_ok():
    #     return

    # if loaded.is_ok():
    items.create(
        Item(
            id="player",
            tags=["player", "item"],
            transform=Transform(Vec2(-32, -32), Vec3(0, 0, 0), Vec2(64, 64)),
            # fill_color=[20, 20, 20],
            sprite="gyuri.png",
            can_move=True,
            can_collide=True,
            can_repulse=True,
            lightness=1,
            base_movement_speed=300,
            dash_count=2,
            dash_movement_multiplier=10,
            dash_charge_refill_time=0.5,
            inventory={
                "box_gloves": Weapon(damage=3, damage_area=Vec2(50, 150)),
                "weight_plate": Weapon(damage=10, damage_area=Vec2(100, 50)),
                "banana": 0,
                "strawberry": 0,
                "blueberry": 0,
            },
        )
    )
    items.create(
        Item(
            id="player_hand_holder",
            tags=["player_hand_holder", "item"],
            transform=Transform(Vec2(-32, -32), Vec3(0, 0, 0), Vec2(64, 64)),
            bones={
                "left_hand": Bone(
                    transform=Transform(
                        Vec2(-36, 16), Vec3(0, 0, -40), Vec2(48, 48)
                    ),
                    anchor=Vec2(0, 0),
                    # fill_color=[255, 255, 255]
                    sprite="weight_plate.png",
                ),
                "right_hand": Bone(
                    transform=Transform(
                        Vec2(36, 16), Vec3(0, 0, 40), Vec2(48, 48)
                    ),
                    anchor=Vec2(0, 0),
                    sprite="weight_plate.png",
                ),
            },
        )
    )

    items.create(
        Item(
            id="box",
            tags=["box", "item"],
            transform=Transform(
                position=Vec2(64, 0), rotation=Vec3(), scale=Vec2(64, 64)
            ),
            can_collide=True,
            can_repulse=True,
            lightness=2,
            fill_color=[20, 20, 20],
        )
    )

    items.create(
        Item(
            id="asd",
            tags=["asd", "item"],
            transform=Transform(
                position=Vec2(200, 0), rotation=Vec3(), scale=Vec2(64, 64)
            ),
            sprite="test.png",
            render=True,
            can_collide=True,
            can_repulse=False,
            lightness=10,
        )
    )
