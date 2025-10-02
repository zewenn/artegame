const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;
const TIMER = 0.1;

const Stats = @import("../Stats.zig");
const Self = @This();

stats: ?*Stats = null,
player_stats: ?*Stats = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    if (lm.activeScene().?.getEntityById("player")) |player| {
        self.player_stats = player.getComponent(Stats);
    }
}

pub fn Update(self: *Self, entity: *lm.Entity) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);

    if (stats.current.health > 0) return;

    lm.removeEntity(.{ .uuid = entity.uuid });

    if (self.player_stats) |player_stats| {
        player_stats.current.mana = @min(player_stats.current.mana + player_stats.max.mana * 0.15, player_stats.max.mana);
    }
}
