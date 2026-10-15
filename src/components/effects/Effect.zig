const std = @import("std");
const Stats = @import("../Stats.zig");

const Self = @This();

pub const EffectType = enum {
    stun,
    root,
    slow,
    sleep,
    haste,
    goliath,
    regen,
    stasis,
    bond_of_life,
    custom,
};

pub const EffectCallback = *const fn (stats: *Stats) void;

pub const EffectTargetTag = enum {
    id,
    effect_type,
};

pub const EffectTarget = union(EffectTargetTag) {
    id: []const u8,
    effect_type: EffectType,

    pub fn byId(target_id: []const u8) EffectTarget {
        return .{ .id = target_id };
    }

    pub fn byType(target_type: EffectType) EffectTarget {
        return .{ .effect_type = target_type };
    }
};

pub const visual_module = @import("EffectVisual.zig");
pub const EffectVisual = visual_module.EffectVisual;
pub const EffectVisualRegistry = visual_module.EffectVisualRegistry;

id: []const u8,
effect_type: EffectType = .custom,
duration: f32 = 0,
time_remaining: f32 = 0,
anim_time: f32 = 0,
value: f32 = 0,
secondary_value: f32 = 0,
on_enable: ?EffectCallback = null,
on_disable: ?EffectCallback = null,
on_tick: ?EffectCallback = null,
visual: ?EffectVisual = null,

pub fn isExpired(self: Self) bool {
    return self.duration > 0 and self.time_remaining <= 0;
}

test "Effect isExpired reflects remaining time" {
    const effect = Self{
        .id = "test_stun",
        .effect_type = .stun,
        .duration = 2.0,
        .time_remaining = 2.0,
    };

    try std.testing.expect(!effect.isExpired());

    var expired_effect = effect;
    expired_effect.time_remaining = 0.0;
    try std.testing.expect(expired_effect.isExpired());
}
