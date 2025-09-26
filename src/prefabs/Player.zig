const std = @import("std");
const lm = @import("loom");

const Stats = @import("../components/Stats.zig");
const Dashing = @import("../components/Dashing.zig");
const player = @import("../components/player/export.zig");

pub fn Player(position: lm.Vector2) !*lm.Entity {
    return try lm.makeEntity("player", .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(64, 64),
        },
        lm.Renderer.init(.{
            .img_path = "player_left_0.png",
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
        }),

        lm.CameraTarget.init("main", .{
            .follow_speed = 400,
            // .max_distance = 128,
        }),

        Stats{
            .team = .player,
            .current = .{
                .attack_speed = 2,
                .armour = 30,
            },
        },
        Dashing{},

        player.Movement{},
        player.Attack{},
    });
}
