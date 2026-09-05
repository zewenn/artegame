const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Self = @This();

id: []const u8,
cooldown: f32 = 5,
cooldown_remaining: f32 = 0,
level: u32 = 1,
icon: []const u8,
slot: enum { left, right } = .left,
cast_fn: *const fn (target: *lm.Entity, level: u32) anyerror!void,

pub fn canCast(self: *const Self) bool {
    return self.cooldown_remaining <= 0;
}

pub fn update(self: *Self, dt: f32) void {
    if (self.cooldown_remaining > 0) {
        self.cooldown_remaining = @max(0, self.cooldown_remaining - dt);
    }
}

pub fn reduceCooldown(self: *Self, amount: f32) void {
    if (self.cooldown_remaining > 0) {
        self.cooldown_remaining = @max(0, self.cooldown_remaining - amount);
    }
}

pub fn cast(self: *Self, target: *lm.Entity) bool {
    if (self.cooldown_remaining > 0) return false;

    self.cooldown_remaining = self.cooldown;

    self.cast_fn(target, self.level) catch {
        std.log.err("Spell cast failed: ({s}@{d})->{s}", .{ target.id, target.uuid, self.id });
        return false;
    };
    return true;
}

pub fn onLevel(self: Self, level: u32) Self {
    var new_spell = self;
    new_spell.level = level;

    return new_spell;
}

test "Spell canCast, cooldown update, reduceCooldown, and cast" {
    var dummy_spell = Self{
        .id = "TestSpell",
        .cooldown = 5.0,
        .cooldown_remaining = 0,
        .icon = "",
        .cast_fn = struct {
            pub fn cb(_: *lm.Entity, _: u32) anyerror!void {}
        }.cb,
    };

    try std.testing.expect(dummy_spell.canCast());

    dummy_spell.cooldown_remaining = 5.0;
    try std.testing.expect(!dummy_spell.canCast());

    dummy_spell.update(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), dummy_spell.cooldown_remaining, 0.001);
    try std.testing.expect(!dummy_spell.canCast());

    dummy_spell.reduceCooldown(1.5);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), dummy_spell.cooldown_remaining, 0.001);

    dummy_spell.reduceCooldown(5.0);
    try std.testing.expectEqual(@as(f32, 0), dummy_spell.cooldown_remaining);
    try std.testing.expect(dummy_spell.canCast());
}
