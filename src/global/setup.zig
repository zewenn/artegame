const std = @import("std");
const lm = @import("loom");

const Player = @import("../prefabs/Player.zig").Player;
const Anchor = @import("../prefabs/Anchor.zig").Anchor;
const BasicEnemy = @import("../prefabs/enemies/Basic.zig").BasicEnemy;
const Projectile = @import("../prefabs/Projectile.zig").Projectile;
const Background = @import("../prefabs/Background.zig").Background;

pub fn Awake() !void {
    // try lm.summon(&.{
    //     .{ .entity = try Player(.init(0, 0)) },
    //     .{ .entity = try BasicEnemy(.init(512, 0)) },
    //     .{ .entity = try Anchor(.init(0, 64)) },
    //     .{ .entity = try Anchor(.init(0, -64)) },
    // });

    try lm.loadScene("demo_map");
}
