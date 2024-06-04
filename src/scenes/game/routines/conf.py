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

    # pgapi.use_background(assets.use("background3.png"), Vec2(7960, 4320))
    pgapi.use_background(assets.use("background4.png"), Vec2(2304, 1536))
    # print(pgapi.SETTINGS.background_size)

    inpt.bind_buttons(
        enums.keybinds.PLAYER_DASH,
        [{"space"}, {"a@ctrl#0"}, {"shoulder-left@ctrl#0"}],
        "down",
    )
    inpt.bind_buttons(
        enums.keybinds.PLAYER_WEAPON_SWITCH,
        [{"tab"}, {"shoulder-right@ctrl#0"}],
        "down",
    )
    inpt.bind_buttons(enums.keybinds.SPELLS.SPELL1, [{"q"}, {"x@ctrl#0"}], "down")
    inpt.bind_buttons(enums.keybinds.SPELLS.SPELL2, [{"e"}, {"y@ctrl#0"}], "down")
    inpt.bind_buttons(
        enums.keybinds.PLAYER_LIGHT_ATTACK,
        [{"left@mouse"}, {"right-trigger@ctrl#0"}],
        "down",
    )
    inpt.bind_buttons(
        enums.keybinds.PLAYER_HEAVY_ATTACK,
        [{"right@mouse"}, {"left-trigger@ctrl#0"}],
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
                    },
                ),
            ],
        ),
    )
    animator.store.add(
        "player_get_hit",
        animator.create(
            duration_seconds=0.1,
            mode=enums.animations.MODES.NORMAL,
            timing_function=enums.animations.TIMING.EASE_IN_OUT,
            animations=[
                Animation(
                    "player",
                    {
                        1: Keyframe(rotation_z=0),
                        30: Keyframe(rotation_z=20),
                        60: Keyframe(rotation_z=-20),
                        100: Keyframe(rotation_z=0),
                    },
                )
            ],
        ),
    )

    # res_loaded: Result[None, Mishap] = saves.load()
    # if res_loaded.is_ok():
    #     return

    #                       ITEMS ADD - PLAYER
    items.add(
        [
            Item(
                id="player",
                tags=["player", "item"],
                team="Player",
                transform=Transform(Vec2(), Vec3(), Vec2(64, 64)),
                # fill_color=[20, 20, 20],
                sprite="gyuri.png",
                # Collision
                can_collide=True,
                can_repulse=True,
                lightness=0.9,
                # Movement
                can_move=True,
                base_movement_speed=400,
                # Dashing
                dash_count=2,
                dash_movement_multiplier=2.5,
                dash_charge_refill_time=0.5,
                dash_time=200,
                # Vitals & Stats
                max_hitpoints=100,
                max_mana=100,
                base_attack_speed=5,
                spells=[],
                # Inventory
                inventory=Inventory(10, 10, 10),
                weapons=[
                    Weapon(
                        id="plates",
                        #
                        light_sprite="light_attack_projectile.png",
                        light_lifetime=1,
                        light_damage_multiplier=1,
                        light_speed=0.9,
                        light_size=Vec2(64, 64),
                        #
                        heavy_sprite="heavy_attack_projectile.png",
                        heavy_lifetime=1.5,
                        heavy_damage_multiplier=2,
                        heavy_speed=0.75,
                        heavy_size=Vec2(64, 64),
                        #
                        dash_sprite="light_attack_projectile.png",
                        dash_lifetime=2.25,
                        dash_damage_multiplier=1.25,
                        dash_speed=1.75,
                        dash_size=Vec2(256, 64),
                        #
                        spell0_effectiveness=5,
                        spell1_effectiveness=5,
                    ),
                    Weapon(
                        id="gloves",
                        #
                        light_sprite="light_attack_projectile.png",
                        light_lifetime=1,
                        light_speed=1,
                        light_damage_multiplier=1,
                        light_size=Vec2(32, 96),
                        #
                        heavy_sprite="heavy_attack_projectile.png",
                        heavy_lifetime=1.5,
                        heavy_speed=0.8,
                        heavy_damage_multiplier=2,
                        heavy_size=Vec2(32, 96),
                        #
                        dash_sprite="light_attack_projectile.png",
                        dash_lifetime=2.25,
                        dash_speed=2,
                        dash_damage_multiplier=1.25,
                        dash_size=Vec2(64, 256),
                        #
                        spell0_effectiveness=5,
                        spell1_effectiveness=5,
                    ),
                ],
            ),
            Item(
                id="player_hand_holder",
                tags=["player_hand_holder", "item"],
                transform=Transform(Vec2(-32, -32), Vec3(0, 0, 0), Vec2(64, 64)),
                bones={
                    "left_hand": Bone(
                        transform=Transform(
                            Vec2(-32, 16), Vec3(0, 0, -40), Vec2(48, 48)
                        ),
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
            ),
        ]
    )

    #                       ITEMS ADD - WALLS
    items.add(
        [
            Item(
                id="invisible_wall_left",
                tags=["invisible", "wall", "wall-left"],
                transform=Transform(
                    Vec2(
                        -pgapi.SETTINGS.background_size.x / 2 - 32,
                        -pgapi.SETTINGS.background_size.y / 2 + 32,
                    ),
                    Vec3(),
                    Vec2(64, pgapi.SETTINGS.background_size.y),
                ),
                can_collide=True,
            ),
            Item(
                id="invisible_wall_right",
                tags=["invisible", "wall", "wall-right"],
                transform=Transform(
                    Vec2(
                        pgapi.SETTINGS.background_size.x / 2 + 32,
                        -pgapi.SETTINGS.background_size.y / 2 + 32,
                    ),
                    Vec3(),
                    Vec2(64, pgapi.SETTINGS.background_size.y),
                ),
                can_collide=True,
            ),
            Item(
                id="invisible_wall_top",
                tags=["invisible", "wall", "wall-top"],
                transform=Transform(
                    Vec2(
                        -pgapi.SETTINGS.background_size.x / 2 + 32,
                        -pgapi.SETTINGS.background_size.y / 2 - 32,
                    ),
                    Vec3(),
                    Vec2(pgapi.SETTINGS.background_size.x, 64),
                ),
                can_collide=True,
            ),
            Item(
                id="invisible_wall_bottom",
                tags=["invisible", "wall", "wall-bottom"],
                transform=Transform(
                    Vec2(
                        -pgapi.SETTINGS.background_size.x / 2 + 32,
                        pgapi.SETTINGS.background_size.y / 2 + 32,
                    ),
                    Vec3(),
                    Vec2(pgapi.SETTINGS.background_size.x, 64),
                ),
                can_collide=True,
            ),
        ]
    )

    # items.add(
    #     Item(
    #         id="enemy1",
    #         tags=["enemy", "item"],
    #         transform=Transform(Vec2(-512, -32), Vec3(0, 0, 0), Vec2(64, 64)),
    #         # fill_color=[20, 20, 20],
    #         sprite="test.png",
    #         can_move=True,
    #         can_collide=True,
    #         can_repulse=True,
    #         lightness=1,
    #         base_movement_speed=300,
    #         dash_count=2,
    #         dash_movement_multiplier=10,
    #         dash_charge_refill_time=0.25,
    #         max_hitpoints=100,
    #         effective_range=100,
    #         hitpoints=100,
    #         max_mana=100,
    #         team="Enemy",
    #         inventory={
    #             "box_gloves": Weapon(damage=3, damage_area=Vec2(50, 150)),
    #             "weight_plate": Weapon(damage=10, damage_area=Vec2(100, 50)),
    #             "banana": 0,
    #             "strawberry": 0,
    #             "blueberry": 0,
    #         },
    #     )
    # )
    # items.add(
    #     Item(
    #         id="enemy2",
    #         tags=["enemy", "item"],
    #         transform=Transform(Vec2(512, 32), Vec3(0, 0, 0), Vec2(64, 64)),
    #         # fill_color=[20, 20, 20],
    #         sprite="test.png",
    #         can_move=True,
    #         can_collide=True,
    #         can_repulse=True,
    #         lightness=1,
    #         base_movement_speed=300,
    #         dash_count=2,
    #         dash_movement_multiplier=10,
    #         dash_charge_refill_time=0.5,
    #         max_hitpoints=100,
    #         effective_range=400,
    #         hitpoints=100,
    #         max_mana=100,
    #         team="Enemy",
    #         inventory={
    #             "box_gloves": Weapon(damage=3, damage_area=Vec2(50, 150)),
    #             "weight_plate": Weapon(damage=10, damage_area=Vec2(100, 50)),
    #             "banana": 0,
    #             "strawberry": 0,
    #             "blueberry": 0,
    #         },
    #     )
    # )

    # items.add(
    #     Item(
    #         id="box",
    #         tags=["box", "item"],
    #         transform=Transform(
    #             position=Vec2(64, 0), rotation=Vec3(), scale=Vec2(64, 64)
    #         ),
    #         can_collide=True,
    #         can_repulse=True,
    #         lightness=3,
    #         fill_color=[20, 20, 20],
    #     )
    # )

    # items.add(
    #     Item(
    #         id="asd",
    #         tags=["asd", "item"],
    #         transform=Transform(
    #             position=Vec2(200, 0), rotation=Vec3(), scale=Vec2(64, 64)
    #         ),
    #         sprite="test.png",
    #         render=True,
    #         can_collide=True,
    #         can_repulse=False,
    #         lightness=10,
    #     )
    # )
