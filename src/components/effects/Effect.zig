const std = @import("std");
const Stats = @import("../Stats.zig");
const EffectVisual = @import("EffectVisual.zig").EffectVisual;

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
    weaken,
    custom,
};

pub const EffectCallback = *const fn (stats: *Stats) void;

pub const EffectTarget = union(enum) {
    id: []const u8,
    effect_type: EffectType,

    pub fn byType(target_type: EffectType) EffectTarget {
        return .{ .effect_type = target_type };
    }
};

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
