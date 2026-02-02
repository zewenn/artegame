const lm = @import("loom");

const prefabs = @import("../prefabs/prefabs.zig");
const Self = @This();

pub fn Awake(_: *Self) !void {
    try lm.summon(&.{
        .{ .entity = try prefabs.Player(.init(0, 0)) },
        .{ .entity = try prefabs.Background(20, 10) },
    });
}
