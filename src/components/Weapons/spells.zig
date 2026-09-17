const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Spell = @import("Spell.zig");

const Projectile = @import("../../prefabs/Projectile.zig").Projectile;

pub const heal: Spell = Spell{
    .id = "Heal",
    .cooldown = 8,
    .slot = .left,
    .icon = "ui/icons/heal_icon.png",
    .cast_fn = struct {
        fn onTick(stats: *Stats) void {
            if (stats.getEffect(.{ .id = "heal_regen" })) |effect| {
                stats.current.health = @min(stats.max.health, stats.current.health + effect.value * lm.time.deltaTime());
            }
        }

        pub fn callback(target: *lm.Entity, level: u32) !void {
            const stats = target.getComponent(Stats) orelse return;
            const regen_value = 20 * lm.tof32(level);
            stats.addEffect(.{
                .id = "heal_regen",
                .effect_type = .regen,
                .duration = 2.0,
                .value = regen_value,
                .on_tick = onTick,
                .visual = .{
                    .frames = &.{
                        "effects/heal_effect_0.png",
                        "effects/heal_effect_1.png",
                    },
                    .frame_duration = 0.1,
                    .offset = .init(0, 0),
                    .scale = .init(64, 64),
                    .icon = "ui/icons/heal_icon.png",
                },
            });
        }
    }.callback,
};

pub const root: Spell = Spell{
    .id = "Root",
    .cooldown = 3,
    .slot = .right,
    .icon = "ui/icons/sleep_icon.png",
    .cast_fn = struct {
        pub fn callback(target: *lm.Entity, level: u32) !void {
            const transform = target.getComponent(lm.Transform) orelse return;

            for (@as([]const f32, &.{ -180, -45, -90, -135, 0, 45, 90, 135 })) |value| {
                const target_position = lm.Vec2(1, 0)
                    .rotate(std.math.degreesToRadians(value))
                    .add(lm.vec3ToVec2(transform.position));

                const projectile = try Projectile(.{
                    .target_team = .enemy,
                    .size = .init(128, 64),
                    .onhit_effect = if (level < 10) .root else .stun,
                    .onhit_duration = if (level < 10) lm.tof32(level + 1) else lm.tof32((level) + 1) - 9.5,
                    .passtrough = true,
                    .damage = 0,

                    .target_position = target_position,
                    .start_position = lm.vec3ToVec2(transform.position),
                });

                try lm.summoning.entity(projectile);
            }
        }
    }.callback,
};

pub const goliath: Spell = Spell{
    .id = "Goliath",
    .cooldown = 8,
    .slot = .left,
    .icon = "ui/icons/goliath_icon.png",
    .cast_fn = struct {
        fn onEnable(stats: *Stats) void {
            if (stats.getEffect(.{ .id = "goliath" })) |effect| {
                stats.max.health += effect.value;
                stats.current.health += effect.value;
                stats.current.physical_damage += effect.secondary_value;
            }
        }

        fn onDisable(stats: *Stats) void {
            if (stats.getEffect(.{ .id = "goliath" })) |effect| {
                stats.max.health = @max(1, stats.max.health - effect.value);
                stats.current.health = @min(stats.current.health, stats.max.health);
                stats.current.physical_damage = @max(0, stats.current.physical_damage - effect.secondary_value);
            }
        }

        pub fn callback(target: *lm.Entity, level: u32) !void {
            const stats = target.getComponent(Stats) orelse return;
            const health_boost = 50 * lm.tof32(level);
            const damage_boost = 15 * lm.tof32(level);
            stats.addEffect(.{
                .id = "goliath",
                .effect_type = .goliath,
                .duration = 6.0,
                .value = health_boost,
                .secondary_value = damage_boost,
                .on_enable = onEnable,
                .on_disable = onDisable,
                .visual = .{
                    .icon = "ui/icons/goliath_icon.png",
                },
            });
        }
    }.callback,
};

pub const haste: Spell = Spell{
    .id = "Haste",
    .cooldown = 6,
    .slot = .right,
    .icon = "ui/icons/haste_icon.png",
    .cast_fn = struct {
        fn onEnable(stats: *Stats) void {
            if (stats.getEffect(.{ .id = "haste" })) |effect| {
                stats.current.movement_speed += effect.value;
                stats.current.attack_speed += effect.secondary_value;
            }
        }

        fn onDisable(stats: *Stats) void {
            if (stats.getEffect(.{ .id = "haste" })) |effect| {
                stats.current.movement_speed = @max(10, stats.current.movement_speed - effect.value);
                stats.current.attack_speed = @max(0.1, stats.current.attack_speed - effect.secondary_value);
            }
        }

        pub fn callback(target: *lm.Entity, level: u32) !void {
            const stats = target.getComponent(Stats) orelse return;
            const speed_boost = 60 * lm.tof32(level);
            const attack_speed_boost = 0.3 * lm.tof32(level);
            stats.addEffect(.{
                .id = "haste",
                .effect_type = .haste,
                .duration = 5.0,
                .value = speed_boost,
                .secondary_value = attack_speed_boost,
                .on_enable = onEnable,
                .on_disable = onDisable,
                .visual = .{
                    .icon = "ui/icons/haste_icon.png",
                },
            });
        }
    }.callback,
};

pub fn getById(id: []const u8) ?Spell {
    if (std.ascii.eqlIgnoreCase(id, "Heal")) return heal;
    if (std.ascii.eqlIgnoreCase(id, "Root")) return root;
    if (std.ascii.eqlIgnoreCase(id, "Goliath")) return goliath;
    if (std.ascii.eqlIgnoreCase(id, "Haste")) return haste;
    return null;
}

test "spells getById resolves known spells" {
    try std.testing.expect(getById("Heal") != null);
    try std.testing.expect(getById("Root") != null);
    try std.testing.expect(getById("Goliath") != null);
    try std.testing.expect(getById("Haste") != null);
    try std.testing.expect(getById("Unknown") == null);
}
