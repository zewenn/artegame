const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Self = @This();

id: []const u8,
mana_cost: f32 = 10,
level: u32 = 1,
icon: []const u8,
slot: enum { left, right } = .left,
cast_fn: *const fn (target: *lm.Entity, level: u32) anyerror!void,

pub fn cast(self: *Self, target: *lm.Entity) void {
    if (target.getComponent(Stats)) |stats| {
        if (stats.current.mana <= lm.tof32(self.mana_cost)) return;

        stats.current.mana -= self.mana_cost;
    }

    self.cast_fn(target, self.level) catch {
        std.log.err("Spell cast failed: ({s}@{d})->{s}", .{ target.id, target.uuid, self.id });
    };
}

pub fn onLevel(self: Self, level: u32) Self {
    var new_spell = self;
    new_spell.level = level;

    return new_spell;
}
