const std = @import("std");
const lm = @import("loom");

const Stats = @import("../components/Stats.zig");
const Movement = @import("../components/Movement.zig");

pub fn Player(position: lm.Vector2) !*lm.Entity {
    return try lm.makeEntity("player", .{
        lm.Transform{
            .position = .init(position.x, position.y, 0)
        },
        lm.Renderer.sprite("player_left_0.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
        }),

        Stats{},
        Movement{},
    });
}
