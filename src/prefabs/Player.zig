const std = @import("std");
const lm = @import("loom");

const Stats = @import("../components/Stats.zig");
const Dashing = @import("../components/Dashing.zig");
const PlayerMovement = @import("../components/PlayerMovement.zig");
const CombinatedAttacks = @import("../components/CombinatedAttacks.zig");

pub fn Player(position: lm.Vector2) !*lm.Entity {
    return try lm.makeEntity("player", .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
        },
        lm.Renderer.sprite("player_left_0.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
        }),

        Stats{
            .team = .player,
            .current = .{
                .attack_speed = 2,
                .armour = 30,
            },
        },
        PlayerMovement{},
        CombinatedAttacks{},
        Dashing{},
    });
}
