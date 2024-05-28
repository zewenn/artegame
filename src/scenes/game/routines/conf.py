from brass.base import *

# fmt: off
from brass import (
    enums, 
    pgapi,
    items, 
    saves, 
    inpt, 
    animator,
    assets
)
# fmt: on


def spawn() -> None:
    pgapi.use_background(assets.use("background.png"), Vec2(2540, 1440))
    

    inpt.bind_buttons(enums.keybinds.PLAYER_DASH, [{"space"}, "a@ctrl#0"], "down")
    inpt.bind_buttons(
        enums.keybinds.PLAYER_LIGHT_ATTACK,
        [{"left@mouse"}, {"shoulder-right@ctrl#0"}],
        "down",
    )
    inpt.bind_buttons(
        enums.keybinds.PLAYER_HEAVY_ATTACK,
        [{"right@mouse"}, {"shoulder-left@ctrl#0"}],
        "down",
    )

    animator.store.add(
        "hit",
        animator.create(
            duration_seconds=0.2,
            mode=enums.animations.MODES.NORMAL,
            timing_function=enums.animations.TIMING.EASE_IN_OUT,
            animations=[
                Animation(
                    "player_hand_holder->left_hand",
                    {
                        1: Keyframe(position_y=16),
                        30: Keyframe(position_y=64),
                        60: Keyframe(position_y=16),
                    },
                ),
                Animation(
                    "player_hand_holder->right_hand", 
                    {
                        20: Keyframe(position_y=16),
                        50: Keyframe(position_y=64),
                        80: Keyframe(position_y=16),
                    }
                ),
            ],
        ),
    )

    # res_loaded: Result[None, Mishap] = saves.load()
    # if res_loaded.is_ok():
    #     return

    # if loaded.is_ok():

    # items.add(
    #     Item(
    #         id="CHUNKYBOY",
    #         tags=["asd", "item"],
    #         transform=Transform(
    #             position=Vec2(0, 0), rotation=Vec3(), scale=Vec2(2048, 2048)
    #         ),
    #         sprite="test.png",
    #         render=True
    #     )
    # )
    items.add(
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
            dash_movement_multiplier=6,
            dash_charge_refill_time=0.5,
            max_hitpoints=100,
            max_mana=100,
            team="Player",
            inventory={
                "box_gloves": Weapon(damage=3, damage_area=Vec2(50, 150)),
                "weight_plate": Weapon(damage=10, damage_area=Vec2(100, 50)),
                "banana": 0,
                "strawberry": 0,
                "blueberry": 0,
            },
        )
    )
    items.add(
        Item(
            id="player_hand_holder",
            tags=["player_hand_holder", "item"],
            transform=Transform(Vec2(-32, -32), Vec3(0, 0, 0), Vec2(64, 64)),
            bones={
                "left_hand": Bone(
                    transform=Transform(Vec2(-32, 16), Vec3(0, 0, -40), Vec2(48, 48)),
                    anchor=Vec2(0, 0),
                    # fill_color=[255, 255, 255]
                    sprite="weight_plate.png",
                ),
                "right_hand": Bone(
                    transform=Transform(Vec2(32, 16), Vec3(0, 0, 40), Vec2(48, 48)),
                    anchor=Vec2(0, 0),
                    sprite="weight_plate.png",
                ),
            },
        )
    )

    items.add(
        Item(
            id="enemy1",
            tags=["enemy", "item"],
            transform=Transform(Vec2(-512, -32), Vec3(0, 0, 0), Vec2(64, 64)),
            # fill_color=[20, 20, 20],
            sprite="test.png",
            can_move=True,
            can_collide=True,
            can_repulse=True,
            lightness=1,
            base_movement_speed=300,
            dash_count=2,
            dash_movement_multiplier=10,
            dash_charge_refill_time=0.5,
            max_hitpoints=100,
            hitpoints=100,
            max_mana=100,
            team="Enemy",
            inventory={
                "box_gloves": Weapon(damage=3, damage_area=Vec2(50, 150)),
                "weight_plate": Weapon(damage=10, damage_area=Vec2(100, 50)),
                "banana": 0,
                "strawberry": 0,
                "blueberry": 0,
            },
        )
    )

    items.add(
        Item(
            id="box",
            tags=["box", "item"],
            transform=Transform(
                position=Vec2(64, 0), rotation=Vec3(), scale=Vec2(64, 64)
            ),
            can_collide=True,
            can_repulse=True,
            lightness=3,
            fill_color=[20, 20, 20],
        )
    )

    items.add(
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