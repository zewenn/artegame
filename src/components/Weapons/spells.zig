const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Spell = @import("Spell.zig");

const Projectile = @import("../../prefabs/Projectile.zig").Projectile;

pub const heal: Spell = Spell{
    .id = "Heal",
    .mana_cost = 60,
    .slot = .left,
    .icon = "ui/heal_icon.png",
    .cast_fn = struct {
        pub fn callback(target: *lm.Entity, level: u32) !void {
            const stats = target.getComponent(Stats) orelse return;
            stats.current.regeneration_amount = 20 * lm.tof32(level);
            stats.current.timer_regen_remaining = 2;
        }
    }.callback,
};

pub const root: Spell = Spell{
    .id = "Root",
    .mana_cost = 10,
    .slot = .right,
    .icon = "ui/sleep_icon.png",
    .cast_fn = struct {
        pub fn callback(target: *lm.Entity, level: u32) !void {
            const transform = target.getComponent(lm.Transform) orelse return;

            for (@as([]const f32, &.{ -180, -90, 0, 90 })) |value| {
                const vec = lm.Vec2(1, 0)
                    .rotate(std.math.degreesToRadians(value))
                    .add(lm.vec3ToVec2(transform.position));

                const projectile = try Projectile(.{
                    .target_team = .enemy,
                    .size = .init(512, 64),
                    .onhit_effect = .root,
                    .onhit_duration = lm.tof32(level + 1),
                    .passtrough = true,
                    .damage = 0,

                    .target_position = vec,
                    .start_position = lm.vec3ToVec2(transform.position),
                });

                try lm.summoning.entity(projectile);
            }
        }
    }.callback,
};

pub const goliath: Spell = Spell{
    .id = "Goliath",
    .mana_cost = 40,
    .slot = .left,
    .icon = "ui/goliath_icon.png",
    .cast_fn = struct {
        pub fn callback(target: *lm.Entity, level: u32) !void {
            const stats = target.getComponent(Stats) orelse return;
            const heal_amount = 25 * lm.tof32(level);
            stats.current.health = @min(stats.max.health, stats.current.health + heal_amount);
        }
    }.callback,
};

pub const haste: Spell = Spell{
    .id = "Haste",
    .mana_cost = 30,
    .slot = .right,
    .icon = "ui/haste_icon.png",
    .cast_fn = struct {
        pub fn callback(target: *lm.Entity, level: u32) !void {
            const stats = target.getComponent(Stats) orelse return;
            stats.applySlow(-20 * lm.tof32(level), 5);
            stats.current.attack_speed += 0.2 * lm.tof32(level);
        }
    }.callback,
};
