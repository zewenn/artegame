const std = @import("std");
const lm = @import("loom");

const Stats = @import("../components/Stats.zig");
const Dashing = @import("../components/Dashing.zig");
const Hands = @import("../components/Weapons/Hands.zig");

const player = @import("../components/player/export.zig");

const player_animations = &.{
    lm.Animation.init("walk-left", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{
            .sprite = "characters/player_left_0.png",
            .rotation = 0,
        },
        lm.Keyframe{
            .sprite = "characters/player_left_1.png",
            .rotation = 15,
        },
        lm.Keyframe{
            .sprite = "characters/player_left_1.png",
            .rotation = 5,
        },
        lm.Keyframe{
            .sprite = "characters/player_left_0.png",
            .rotation = -2,
        },
        lm.Keyframe{
            .sprite = "characters/player_left_1.png",
            .rotation = 0,
        },
    }),
    lm.Animation.init("walk-right", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{
            .sprite = "characters/player_right_0.png",
            .rotation = 0,
        },
        lm.Keyframe{
            .sprite = "characters/player_right_1.png",
            .rotation = 15,
        },
        lm.Keyframe{
            .sprite = "characters/player_right_1.png",
            .rotation = 5,
        },
        lm.Keyframe{
            .sprite = "characters/player_right_0.png",
            .rotation = -2,
        },
        lm.Keyframe{
            .sprite = "characters/player_right_0.png",
            .rotation = 0,
        },
    }),
};

pub fn Player(position: lm.Vector2) !*lm.Entity {
    return try lm.makeEntity("player", .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(64, 64),
        },
        lm.Renderer.init(.{
            .img_path = "characters/player_left_0.png",
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
        }),
        lm.Animator.init(player_animations),

        lm.CameraTarget.init("main", .{
            .follow_speed = 50,
            .max_distance = 16,
        }),

        Stats{
            .team = .player,
            .current = .{
                .attack_speed = 5,
                .armour = 30,
                .experience = 250_000,
            },
        },
        Dashing{},
        Hands{},

        player.Movement{},
        player.Attack{},
        player.Objectives{},
    });
}
