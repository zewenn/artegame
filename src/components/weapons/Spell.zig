const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");

const Self = @This();

pub const Slot = enum(usize) {
    left = 0,
    right = 1,
};

id: []const u8,
cooldown: f32 = 5,
cooldown_remaining: f32 = 0,
level: u32 = 1,
icon: []const u8,
slot: Slot = .left,
cast_fn: *const fn (target: *lm.Entity, level: u32) anyerror!void,

pub fn update(self: *Self, delta_seconds: f32) void {
    if (self.cooldown_remaining > 0) {
        self.cooldown_remaining = @max(0, self.cooldown_remaining - delta_seconds);
    }
}

pub fn reduceCooldown(self: *Self, amount_seconds: f32) void {
    self.update(amount_seconds);
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

test "Spell cooldown update, reduceCooldown, and cast" {
    var target_entity = lm.Entity.init(std.testing.allocator, "spell_target");
    defer target_entity.deinit();

    var base_stats = Stats.init(.player, .{ .health = 50.0 });
    defer base_stats.deinit();
    try target_entity.addComponent(base_stats);
    try target_entity.addPreparedComponents(false);

    var dummy_spell = Self{
        .id = "TestSpell",
        .cooldown = 5.0,
        .cooldown_remaining = 5.0,
        .level = 2,
        .icon = "",
        .cast_fn = struct {
            pub fn cb(target: *lm.Entity, level: u32) anyerror!void {
                const stats = target.getComponent(Stats) orelse return;
                stats.current.health += @as(f32, @floatFromInt(level * 10));
            }
        }.cb,
    };

    try std.testing.expect(!dummy_spell.cast(&target_entity));
    try std.testing.expectEqual(@as(f32, 50.0), target_entity.getComponent(Stats).?.current.health);

    dummy_spell.update(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), dummy_spell.cooldown_remaining, 0.001);

    dummy_spell.reduceCooldown(1.5);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), dummy_spell.cooldown_remaining, 0.001);

    dummy_spell.reduceCooldown(5.0);
    try std.testing.expectEqual(@as(f32, 0), dummy_spell.cooldown_remaining);

    try std.testing.expect(dummy_spell.cast(&target_entity));
    try std.testing.expectEqual(@as(f32, 5.0), dummy_spell.cooldown_remaining);
    try std.testing.expectEqual(@as(f32, 70.0), target_entity.getComponent(Stats).?.current.health);

    try std.testing.expect(!dummy_spell.cast(&target_entity));
}
