const std = @import("std");
const lm = @import("loom");

const Player = @import("../prefabs/Player.zig").Player;
const BasicEnemy = @import("../prefabs/enemies/Basic.zig").BasicEnemy;
const Projectile = @import("../prefabs/Projectile.zig").Projectile;

pub fn Awake() !void {
    try lm.summon(&.{
        .{ .entity = try Player(.init(0, 0)) },
    });

    try lm.summon(&.{
        .{ .entity = try BasicEnemy(.init(256, 0)) },
    });
}

// pub fn Update() !void {
//     if (lm.input.getKeyDown(.f)) {
//         lm.time.togglePause();
//     }
// }
