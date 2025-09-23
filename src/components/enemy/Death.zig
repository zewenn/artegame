const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;
const TIMER = 0.1;

const Stats = @import("../Stats.zig");
const Self = @This();

stats: ?*Stats = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
}

pub fn Update(self: *Self, entity: *lm.Entity) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);

    if (stats.current.health > 0) return;

    lm.removeEntity(.{ .uuid = entity.uuid });
}
