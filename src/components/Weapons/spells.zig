const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Spell = @import("Spell.zig");

pub const heal: Spell = Spell{
    .id = "Heal",
    .mana_cost = 60,
    .slot = .left,
    .icon = "heal_icon.png",
    .cast_fn = struct {
        pub fn callback(target: *lm.Entity, level: u32) !void {
            const stats = target.getComponent(Stats) orelse return;
            stats.current.regeneration_amount = 20 * lm.tof32(level);
            stats.current.timer_regen_remaining = 2;
        }
    }.callback,
};
