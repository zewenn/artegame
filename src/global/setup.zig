const std = @import("std");
const lm = @import("loom");

const Player = @import("../prefabs/Player.zig").Player;
const Projectile = @import("../prefabs/Projectile.zig").Projectile;

pub fn Awake() !void {
    try lm.summon(&.{
        .{ .entity = try Player(.init(0, 0)) },
    });
}

pub fn Update() !void {
    const mouse_pos = lm.screenToWorldPos(lm.rl.getMousePosition());

    if (lm.input.getMouseDown(.left)) {
        try lm.summon(&.{.{
            .entity = try Projectile(.{
                .start_position = .init(0, 0),
                .target_position = mouse_pos,
                .target_team = .player,
            }),
        }});
    }
}
