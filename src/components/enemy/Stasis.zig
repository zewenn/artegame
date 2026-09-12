const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Animation = @import("Animation.zig");
const Attack = @import("Attack.zig");

const Self = @This();

duration_seconds: f32 = 0.0,
elapsed_seconds: f32 = 0.0,
is_active: bool = false,
is_indefinite: bool = false,

stats: ?*Stats = null,
animator: ?*Animation = null,
attack: ?*Attack = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.animator = entity.getComponent(Animation);
    self.attack = entity.getComponent(Attack);
}

pub fn Update(self: *Self) void {
    if (lm.time.paused()) return;
    if (!self.is_active) return;
    if (self.is_indefinite) return;

    self.elapsed_seconds += lm.time.deltaTime();
    if (self.elapsed_seconds >= self.duration_seconds) {
        self.exitStasis();
    }
}

pub fn enterStasis(self: *Self, duration_seconds: ?f32) void {
    self.is_active = true;
    self.elapsed_seconds = 0.0;

    if (duration_seconds) |duration| {
        self.duration_seconds = duration;
        self.is_indefinite = false;
    } else {
        self.duration_seconds = 0.0;
        self.is_indefinite = true;
    }

    if (self.attack) |attack| {
        attack.cancelCurrentAction();
    }

    const stats = self.stats orelse return;
    stats.addEffect(.{
        .id = "stasis",
        .effect_type = .stasis,
        .duration = if (self.is_indefinite) 0.0 else self.duration_seconds,
    });
}

pub fn exitStasis(self: *Self) void {
    self.is_active = false;
    self.elapsed_seconds = 0.0;
    self.duration_seconds = 0.0;
    self.is_indefinite = false;

    const stats = self.stats orelse return;
    stats.removeEffect(.{ .effect_type = .stasis });
}

test "Stasis component timed lifecycle" {
    var stats = Stats.init(.enemy, .{});
    defer stats.deinit();

    var stasis = Self{
        .stats = &stats,
    };

    try std.testing.expect(!stasis.is_active);
    try std.testing.expect(!stats.isStasis());
    try std.testing.expect(!stats.isInvulnerable());
    try std.testing.expect(stats.canMove());

    stasis.enterStasis(10.0);

    try std.testing.expect(stasis.is_active);
    try std.testing.expect(!stasis.is_indefinite);
    try std.testing.expect(stats.isStasis());
    try std.testing.expect(stats.isInvulnerable());
    try std.testing.expect(!stats.canMove());

    // Simulate elapsed time below duration
    stasis.elapsed_seconds = 9.9;
    try std.testing.expect(stasis.is_active);

    // Simulate duration completion
    stasis.exitStasis();

    try std.testing.expect(!stasis.is_active);
    try std.testing.expect(!stats.isStasis());
    try std.testing.expect(!stats.isInvulnerable());
    try std.testing.expect(stats.canMove());
}

test "Stasis component indefinite lifecycle" {
    var stats = Stats.init(.enemy, .{});
    defer stats.deinit();

    var stasis = Self{
        .stats = &stats,
    };

    stasis.enterStasis(null);

    try std.testing.expect(stasis.is_active);
    try std.testing.expect(stasis.is_indefinite);
    try std.testing.expect(stats.isInvulnerable());

    stasis.exitStasis();

    try std.testing.expect(!stasis.is_active);
    try std.testing.expect(!stats.isInvulnerable());
}
