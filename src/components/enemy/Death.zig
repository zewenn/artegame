const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;
const TIMER = 0.1;

const Stats = @import("../Stats.zig");
const prefabs = @import("../../prefabs/prefabs.zig");

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

    const enemy_pos: lm.Vector2 = if (entity.getComponent(lm.Transform)) |t|
        lm.vec3ToVec2(t.position)
    else
        .init(0, 0);

    const orb_count = lm.random.intRangeAtMostBiased(u8, 1, 3);
    for (0..orb_count) |_| {
        const angle = lm.randFloat(f32, 0, std.math.pi * 2);
        const scatter_speed = lm.randFloat(f32, 100, 220);
        const initial_vel = lm.Vec2(
            std.math.cos(angle) * scatter_speed,
            std.math.sin(angle) * scatter_speed,
        );
        const orb = try prefabs.items.ExperienceOrb(enemy_pos, 1, initial_vel);
        try lm.summoning.entity(orb);
    }

    if (self.player_stats) |player_stats| {
        player_stats.current.mana = @min(player_stats.current.mana + player_stats.max.mana * 0.15, player_stats.max.mana);
    }

    lm.removeEntity(.{ .uuid = entity.uuid });
}
