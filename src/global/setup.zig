const std = @import("std");
const lm = @import("loom");

const Player = @import("../prefabs/Player.zig").Player;

pub fn Awake() !void {
    try lm.summon(&.{
        .{ .entity = try Player(.init(0, 0)) },
    });
}
