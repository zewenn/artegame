const lm = @import("loom");

const Stats = @import("../Stats.zig");
const BondOfLife = @import("BondOfLife.zig");

const Self = @This();

stats: ?*Stats = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    if (stats.current.health <= 0.0) {
        BondOfLife.instance.reset();
        return;
    }

    const delta_seconds = lm.time.deltaTime();
    try BondOfLife.instance.update(delta_seconds);
}

pub fn End(self: *Self) void {
    _ = self;
    BondOfLife.instance.deinit();
}
